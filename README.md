# DICOM USB Extract

A simple offline Apple silicon Mac tool for safely extracting viewable X-ray images and original DICOM files from medical imaging USB drives without running bundled Windows viewer software.

## Who this is for

Some clinics hand out USB drives that expect you to run a Windows `AutoRun.exe` viewer. This tool is for Apple silicon Mac users who only want the images copied out safely.

It does not run anything from the USB drive. It only reads the selected folder and copies detected images and DICOM files to a folder you choose.

## How to use it on an Apple silicon Mac

This tool is for Macs with Apple chips, such as M1, M2, M3, M4, and newer. Intel Macs are not a target for this project.

1. Download this repository as a ZIP file and unzip it.
2. Insert the medical imaging USB drive.
3. Double-click `DICOM USB Extract.app`.
4. Choose the USB drive, the `IMAGES` folder, or a copied study folder when prompted.
5. Choose where the extracted folder should be saved, such as `Pictures`.

No Terminal commands are needed. The app opens normal Mac folder picker dialogs, then opens the extracted folder in Finder when it finishes.

If macOS says the app cannot be opened because it was downloaded from the internet, right-click `DICOM USB Extract.app`, choose **Open**, then choose **Open** again.

The result will look like:

```text
2026-05-14-Patient-LT-WRIST-3V/
  Viewable Images/
    01-AMSE0001.jpg
    02-AMSE0002.jpg
  Original DICOM Files/
    01-AMSE0001.dcm
    02-AMSE0002.dcm
```

## What it copies

- JPEG, PNG, and TIFF images that are part of the study
- Original DICOM image files detected by macOS's `file` command

## What it skips

- `AutoRun.exe`
- other `.exe` files
- HTML/CSS viewer pages
- AMICAS/Merge viewer artwork
- macOS metadata files like `._*`
- Spotlight and filesystem bookkeeping folders

## Notes

This is intentionally Apple silicon Mac-first. It uses built-in macOS shell commands and AppleScript folder picker dialogs, so there are no packages to install and no Rosetta support is needed.

If a USB drive contains DICOM files but no exported JPEG/PNG/TIFF images, this tool will still copy the original DICOM files. It does not yet convert arbitrary DICOM pixel data into JPEGs because DICOM image encoding varies between clinics and devices.

## Command-line use

You can also run it directly:

```bash
src/dicom-usb-extract.sh --source "/Volumes/NO NAME" --destination "$HOME/Pictures"
```

For automated runs:

```bash
src/dicom-usb-extract.sh --source "/Volumes/NO NAME" --destination "$HOME/Pictures" --no-ui --no-open
```
