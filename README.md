# Image Extract

A simple offline web page for previewing and downloading image files from any folder, USB drive, phone download folder, or medical DICOM USB without running bundled viewer software.

## Use it now
<div align="center">

## ✦ [**Use Image Extract live →**](https://kjellkod.github.io/dicom-usb-extract) ✦

*Privacy first: local files stay in your browser. Nothing is uploaded or shared.*

</div>

Privacy first: the page runs in your browser, reads only the folder you choose, and does not upload or share your files. You can review exactly what it does in this repository: <https://github.com/KjellKod/dicom-usb-extract>

The repository publishes `index.html` to a `gh-pages` branch on every `main` update. If the live link is not active yet, enable GitHub Pages once in the repository settings with source `gh-pages` / root.

## Who this is for

This is for nontechnical Mac users who want to collect pictures from a folder without digging through confusing file trees. It works with ordinary image folders, copied phone downloads, USB drives, and clinic imaging USBs.

Some clinics hand out USB drives that expect you to run a Windows `AutoRun.exe` viewer. This page does not run anything from the USB drive. It only reads files that you choose in your browser, shows viewable image exports, and downloads selected pictures as a ZIP.

## How to use it

1. Open <https://kjellkod.github.io/dicom-usb-extract/> or double-click `index.html` from a downloaded copy of this repository.
2. Choose a folder, USB drive, phone download folder, medical imaging USB, or copied study folder.
3. For clinic USBs, choosing the `IMAGES` folder usually gives the cleanest result.
4. Preview the images in the page.
5. Download one image, selected pictures, or all pictures as a ZIP.
6. If a clinician asks for the original study files, turn on **Add original medical files (DICOM) to ZIP** before downloading a ZIP.

No Terminal commands are needed. There is no Mac app to approve, no Rosetta prompt, and no notarization requirement.

## What appears in the page

- JPEG, PNG, BMP, and GIF images are shown as previews.
- TIFF files are included for download, but most browsers do not preview TIFF images.
- Original DICOM files are listed as an optional advanced download.

The downloaded ZIP is organized like this:

```text
2026-05-14-Patient-LT-WRIST-3V/
  Viewable Images/
    01-WRIST-PA.jpg
    02-WRIST-OBL.jpg
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

Browser folder access is intentionally permission-based. The page uses the browser's available folder picker and only reads the folder you choose.

The page cannot silently save into `Pictures` because browsers block local web pages from writing wherever they want. Instead, it creates a normal downloaded ZIP.

## DICOM note

By default, ZIP downloads include pictures only. Original DICOM files are useful when a clinician asks for the original study or when opening the study in a dedicated DICOM viewer, so the page can include them if you turn on **Add original medical files (DICOM) to ZIP**.

If a USB drive contains DICOM files but no exported JPEG/PNG/TIFF images, the page will list the DICOM originals but it cannot preview them as pictures. It does not yet convert arbitrary DICOM pixel data into JPEGs because DICOM image encoding varies between clinics and devices.

## Command-line extractor

The old shell extractor is still included for technical users:

```bash
src/dicom-usb-extract.sh --source "/Volumes/NO NAME" --destination "$HOME/Pictures" --no-ui --no-open
```

To include original DICOM files with the pictures:

```bash
src/dicom-usb-extract.sh --source "/Volumes/NO NAME" --destination "$HOME/Pictures" --include-dicom --no-ui --no-open
```
