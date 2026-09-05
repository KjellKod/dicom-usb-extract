#!/bin/bash
set -euo pipefail

APP_NAME="DICOM USB Extract"

SOURCE=""
DESTINATION=""
INCLUDE_DICOM=0
NO_UI=0
OPEN_RESULT=1

usage() {
  cat <<'USAGE'
DICOM USB Extract

Usage:
  src/dicom-usb-extract.sh --source /Volumes/NO\ NAME --destination ~/Pictures

Options:
  --source PATH        USB volume, IMAGES folder, or copied medical image folder
  --destination PATH   Parent folder where the extracted study folder is created
  --include-dicom      Also copy original DICOM files
  --no-ui             Do not show macOS folder picker dialogs
  --no-open           Do not reveal the result in Finder
  --help              Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --include-dicom)
      INCLUDE_DICOM=1
      shift
      ;;
    --no-ui)
      NO_UI=1
      shift
      ;;
    --no-open)
      OPEN_RESULT=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

have_osascript() {
  command -v osascript >/dev/null 2>&1
}

show_dialog() {
  local message="$1"
  if [ "$NO_UI" -eq 0 ] && have_osascript; then
    osascript - "$APP_NAME" "$message" <<'OSA' >/dev/null
on run argv
  display dialog item 2 of argv buttons {"OK"} default button "OK" with title item 1 of argv
end run
OSA
  else
    echo "$message"
  fi
}

choose_folder() {
  local prompt="$1"
  local default_path="${2:-$HOME}"
  osascript <<OSA
set chosenFolder to choose folder with prompt "$prompt" default location POSIX file "$default_path"
POSIX path of chosenFolder
OSA
}

if [ -z "$SOURCE" ]; then
  if [ "$NO_UI" -eq 1 ] || ! have_osascript; then
    echo "Missing --source" >&2
    exit 2
  fi
  SOURCE="$(choose_folder "Choose the medical USB drive, its IMAGES folder, or a copied study folder." "/Volumes")"
fi

if [ -z "$DESTINATION" ]; then
  if [ "$NO_UI" -eq 1 ] || ! have_osascript; then
    echo "Missing --destination" >&2
    exit 2
  fi
  DESTINATION="$(choose_folder "Choose where extracted images should be saved." "$HOME/Pictures")"
fi

SOURCE="${SOURCE%/}"
DESTINATION="${DESTINATION%/}"

if [ ! -d "$SOURCE" ]; then
  echo "Source folder does not exist: $SOURCE" >&2
  exit 1
fi

if [ ! -d "$DESTINATION" ]; then
  echo "Destination folder does not exist: $DESTINATION" >&2
  exit 1
fi

STUDY_ROOT="$SOURCE"
if [ -d "$SOURCE/IMAGES" ]; then
  STUDY_ROOT="$SOURCE/IMAGES"
fi

if [ ! -d "$STUDY_ROOT" ]; then
  echo "Study folder does not exist: $STUDY_ROOT" >&2
  exit 1
fi

sanitize_name() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '\r\n\t' '   ')"
  value="$(printf '%s' "$value" | sed -E 's/<[^>]*>//g; s/&nbsp;/ /g; s/[^[:alnum:] _.-]+/-/g; s/[[:space:]_]+/-/g; s/-+/-/g; s/^-//; s/-$//')"
  if [ -z "$value" ]; then
    value="study"
  fi
  printf '%s' "$value"
}

title_case_word() {
  local word="$1"
  local first rest
  first="$(printf '%s' "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  rest="$(printf '%s' "$word" | cut -c2- | tr '[:upper:]' '[:lower:]')"
  printf '%s%s' "$first" "$rest"
}

extract_xml_tag() {
  local tag="$1"
  local file="$2"
  sed -n "s:.*<$tag>\\(.*\\)</$tag>.*:\\1:p" "$file" | head -1
}

STUDYLIST=""
if [ -f "$STUDY_ROOT/STUDYLIST.XML" ]; then
  STUDYLIST="$STUDY_ROOT/STUDYLIST.XML"
else
  STUDYLIST="$(find "$STUDY_ROOT" -maxdepth 3 -type f -iname 'STUDYLIST.XML' -print 2>/dev/null | head -1 || true)"
fi

STUDY_DATE=""
PATIENT_NAME=""
STUDY_DESCRIPTION=""
SERIES_LABELS=()

if [ -n "$STUDYLIST" ] && [ -f "$STUDYLIST" ]; then
  STUDY_DATE="$(extract_xml_tag "itsStudyDate" "$STUDYLIST" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2}).*/\1-\2-\3/')"
  PATIENT_NAME="$(extract_xml_tag "itsPatientName" "$STUDYLIST" | sed 's/\^/ /g')"
  STUDY_DESCRIPTION="$(extract_xml_tag "itsStudyDescription" "$STUDYLIST")"
  while IFS= read -r series_label; do
    if [ -n "$series_label" ]; then
      SERIES_LABELS+=("$series_label")
    fi
  done < <(sed -n 's:.*<itsSeriesDescription>\(.*\)</itsSeriesDescription>.*:\1:p' "$STUDYLIST")
fi

if ! printf '%s' "$STUDY_DATE" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  STUDY_DATE="$(date +%F)"
fi

if [ -z "$PATIENT_NAME" ]; then
  PATIENT_NAME="Patient"
fi

GIVEN_NAME="$(printf '%s' "$PATIENT_NAME" | awk '{print $2}')"
if [ -z "$GIVEN_NAME" ]; then
  GIVEN_NAME="$(printf '%s' "$PATIENT_NAME" | awk '{print $1}')"
fi
if [ -z "$GIVEN_NAME" ]; then
  GIVEN_NAME="Patient"
fi
GIVEN_NAME="$(title_case_word "$GIVEN_NAME")"

if [ -z "$STUDY_DESCRIPTION" ]; then
  STUDY_DESCRIPTION="medical-images"
fi

FOLDER_NAME="$(sanitize_name "$STUDY_DATE-$GIVEN_NAME-$STUDY_DESCRIPTION")"
OUTPUT_DIR="$DESTINATION/$FOLDER_NAME"
IMAGE_DIR="$OUTPUT_DIR/Viewable Images"
DICOM_DIR="$OUTPUT_DIR/Original DICOM Files"

mkdir -p "$IMAGE_DIR"
if [ "$INCLUDE_DICOM" -eq 1 ]; then
  mkdir -p "$DICOM_DIR"
fi

is_ignored_path() {
  case "$1" in
    */.Spotlight-V100/*|*/.fseventsd/*|*/System\ Volume\ Information/*|*/AMICAS/*|*/._*|*/autorun.inf|*/AutoRun.exe|*.exe|*.EXE)
      return 0
      ;;
  esac
  return 1
}

safe_extension() {
  local path="$1"
  local base ext
  base="$(basename "$path")"
  ext="${base##*.}"
  if [ "$base" = "$ext" ]; then
    ext="jpg"
  fi
  printf '%s' "$ext" | tr '[:upper:]' '[:lower:]'
}

copy_numbered() {
  local source_file="$1"
  local target_dir="$2"
  local number="$3"
  local label="$4"
  local ext="$5"
  local target
  target="$target_dir/$(printf '%02d' "$number")-$(sanitize_name "$label").$ext"
  cp -p "$source_file" "$target"
}

label_for_number() {
  local number="$1"
  local fallback="$2"
  local index=$((number - 1))
  if [ "${SERIES_LABELS[$index]+set}" = "set" ] && [ -n "${SERIES_LABELS[$index]}" ]; then
    printf '%s' "${SERIES_LABELS[$index]}"
  else
    printf '%s' "$fallback"
  fi
}

IMAGE_COUNT=0
while IFS= read -r image_file; do
  if is_ignored_path "$image_file"; then
    continue
  fi
  IMAGE_COUNT=$((IMAGE_COUNT + 1))
  parent_label="$(basename "$(dirname "$image_file")")"
  copy_numbered "$image_file" "$IMAGE_DIR" "$IMAGE_COUNT" "$(label_for_number "$IMAGE_COUNT" "$parent_label")" "$(safe_extension "$image_file")"
done < <(find "$STUDY_ROOT" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \) -print 2>/dev/null | sort)

DICOM_COUNT=0
if [ "$INCLUDE_DICOM" -eq 1 ]; then
  while IFS= read -r candidate; do
    if is_ignored_path "$candidate"; then
      continue
    fi
    base="$(basename "$candidate")"
    case "$base" in
      DICOMDIR|*.htm|*.HTM|*.html|*.HTML|*.xml|*.XML|*.txt|*.TXT|*.css|*.CSS|*.jpg|*.JPG|*.jpeg|*.JPEG|*.png|*.PNG|*.tif|*.TIF|*.tiff|*.TIFF)
        continue
        ;;
    esac
    if file "$candidate" | grep -qi 'DICOM medical imaging data'; then
      DICOM_COUNT=$((DICOM_COUNT + 1))
      parent_label="$(basename "$(dirname "$candidate")")"
      copy_numbered "$candidate" "$DICOM_DIR" "$DICOM_COUNT" "$(label_for_number "$DICOM_COUNT" "$parent_label")" "dcm"
    fi
  done < <(find "$STUDY_ROOT" -type f -print 2>/dev/null | sort)
fi

SUMMARY="$APP_NAME finished.

Saved to:
$OUTPUT_DIR

Viewable images: $IMAGE_COUNT
Original DICOM files copied: $DICOM_COUNT

Bundled Windows viewers, autorun files, and support assets were skipped."

echo "$SUMMARY"

if [ "$IMAGE_COUNT" -eq 0 ] && [ "$DICOM_COUNT" -eq 0 ]; then
  show_dialog "No viewable images were found in the selected folder."
  exit 1
fi

if [ "$OPEN_RESULT" -eq 1 ] && [ "$NO_UI" -eq 0 ] && command -v open >/dev/null 2>&1; then
  open "$OUTPUT_DIR" >/dev/null 2>&1 || true
fi

if [ "$NO_UI" -eq 0 ]; then
  show_dialog "$SUMMARY"
fi
