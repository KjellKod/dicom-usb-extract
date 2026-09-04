#include <errno.h>
#include <libgen.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/utsname.h>
#include <unistd.h>

static void show_error(const char *message) {
  fprintf(stderr, "%s\n", message);
  const char *script =
      "on run argv\n"
      "  display dialog item 1 of argv buttons {\"OK\"} default button \"OK\" "
      "with title \"DICOM USB Extract\"\n"
      "end run";
  execl("/usr/bin/osascript", "osascript", "-e", script, message, NULL);
}

static int require_arm64(void) {
  struct utsname system_info;
  if (uname(&system_info) != 0) {
    return 0;
  }
  return strcmp(system_info.machine, "arm64") == 0;
}

static int executable_path(char *buffer, uint32_t buffer_size) {
  uint32_t size = buffer_size;
  if (_NSGetExecutablePath(buffer, &size) != 0) {
    return -1;
  }

  char resolved[MAXPATHLEN];
  if (realpath(buffer, resolved) == NULL) {
    return -1;
  }

  if (snprintf(buffer, buffer_size, "%s", resolved) >= (int)buffer_size) {
    return -1;
  }

  return 0;
}

static int find_script_path(const char *start_dir, char *script_path,
                            size_t script_path_size) {
  char current[MAXPATHLEN];
  if (realpath(start_dir, current) == NULL) {
    return -1;
  }

  for (int depth = 0; depth < 8; depth++) {
    if (snprintf(script_path, script_path_size,
                 "%s/src/dicom-usb-extract.sh", current) >=
        (int)script_path_size) {
      return -1;
    }

    if (access(script_path, X_OK) == 0) {
      return 0;
    }

    char parent_candidate[MAXPATHLEN];
    if (snprintf(parent_candidate, sizeof(parent_candidate), "%s/..",
                 current) >= (int)sizeof(parent_candidate)) {
      return -1;
    }

    char parent[MAXPATHLEN];
    if (realpath(parent_candidate, parent) == NULL) {
      return -1;
    }

    if (strcmp(parent, current) == 0) {
      break;
    }

    snprintf(current, sizeof(current), "%s", parent);
  }

  return -1;
}

int main(int argc, char **argv) {
  if (!require_arm64()) {
    show_error("DICOM USB Extract is built for Apple silicon Macs only.");
    return 1;
  }

  char path[MAXPATHLEN];
  if (executable_path(path, sizeof(path)) != 0) {
    show_error("DICOM USB Extract could not locate itself.");
    return 1;
  }

  char *macos_dir = dirname(path);
  char script_path[MAXPATHLEN];
  if (find_script_path(macos_dir, script_path, sizeof(script_path)) != 0) {
    show_error("The extraction script could not be found. Keep DICOM USB "
               "Extract.app in the unzipped repository folder and try again.");
    return 1;
  }

  char **args = calloc((size_t)argc + 2, sizeof(char *));
  if (args == NULL) {
    show_error("DICOM USB Extract could not allocate memory.");
    return 1;
  }

  args[0] = "/bin/bash";
  args[1] = script_path;
  for (int i = 1; i < argc; i++) {
    args[i + 1] = argv[i];
  }
  args[argc + 1] = NULL;

  execv("/bin/bash", args);

  char error_message[512];
  snprintf(error_message, sizeof(error_message),
           "DICOM USB Extract could not start: %s", strerror(errno));
  show_error(error_message);
  return 1;
}
