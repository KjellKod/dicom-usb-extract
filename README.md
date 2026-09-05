# DICOM USB Extract

A simple offline web page for safely previewing and downloading X-ray images and original DICOM files from medical imaging USB drives without running bundled Windows viewer software.

## Who this is for

Some clinics hand out USB drives that expect you to run a Windows `AutoRun.exe` viewer. This tool is for Mac users who only want to see and copy the images safely.

It does not run anything from the USB drive. It only reads files that you choose in your browser, shows the viewable image exports, and downloads selected files as a ZIP.

## How to use it

1. Download this repository as a ZIP file and unzip it.
2. Insert the medical imaging USB drive.
3. Double-click `index.html`.
4. Choose the USB drive, the `IMAGES` folder, or a copied study folder.
5. Preview the images in the page.
6. Download one image, selected files, or everything as a ZIP.

No Terminal commands are needed. There is no Mac app to approve, no Rosetta prompt, and no notarization requirement.

## What appears in the page

- JPEG, PNG, BMP, and GIF images are shown as previews when the USB includes browser-viewable exports.
- TIFF files are included for download, but most browsers do not preview TIFF images.
- Original DICOM files are listed for download.

The downloaded ZIP is organized like this:

```text
2026-05-14-Patient-LT-WRIST-3V/
  Viewable Images/
    01-WRIST-PA.jpg
    02-WRIST-OBL.jpg
  Original DICOM Files/
    01-WRIST-PA.dcm
    02-WRIST-OBL.dcm
```

## What it skips

- `AutoRun.exe`
- other `.exe` files
- HTML/CSS viewer pages
- AMICAS/Merge viewer artwork
- macOS metadata files like `._*`
- Spotlight and filesystem bookkeeping folders

## Browser notes

The page works entirely offline. Nothing is uploaded.

Browser folder access is intentionally permission-based. If the main folder button does not work in your browser, use the fallback folder button on the page.

The page cannot silently save into `Pictures` because browsers block local web pages from writing wherever they want. Instead, it creates a normal downloaded ZIP.

## DICOM note

If a USB drive contains DICOM files but no exported JPEG/PNG/TIFF images, this tool will still include the original DICOM files for download. It does not yet convert arbitrary DICOM pixel data into JPEGs because DICOM image encoding varies between clinics and devices.

## Command-line extractor

The old shell extractor is still included for technical users:

```bash
src/dicom-usb-extract.sh --source "/Volumes/NO NAME" --destination "$HOME/Pictures" --no-ui --no-open
```
