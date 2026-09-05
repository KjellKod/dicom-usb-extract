#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE="$TMP_DIR/NO NAME/IMAGES"
DEST="$TMP_DIR/output"

mkdir -p "$SOURCE/IHE_PDI/AMPT0001/AMST0001/AMSE0001"
mkdir -p "$SOURCE/IHE_PDI/AMPT0001/AMST0001/AMSE0002"
mkdir -p "$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0001"
mkdir -p "$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0002"
mkdir -p "$SOURCE/AMICAS"
mkdir -p "$DEST"

cat > "$SOURCE/STUDYLIST.XML" <<'XML'
<list>
  <com.amicas.viewer.synth.osc.model.CDViewerStudySummary>
    <itsPatientName>SAMPLE^PATIENT</itsPatientName>
    <itsStudyDate>2026-05-14 15:24:43.0 UTC</itsStudyDate>
    <itsStudyDescription>LT WRIST 3V</itsStudyDescription>
    <itsSeriesDescription>WRIST PA</itsSeriesDescription>
    <itsSeriesDescription>WRIST OBL</itsSeriesDescription>
  </com.amicas.viewer.synth.osc.model.CDViewerStudySummary>
</list>
XML

printf '\xff\xd8\xff\xe0fake-jpeg-1' > "$SOURCE/IHE_PDI/AMPT0001/AMST0001/AMSE0001/IM000001.JPG"
printf '\xff\xd8\xff\xe0fake-jpeg-2' > "$SOURCE/IHE_PDI/AMPT0001/AMST0001/AMSE0002/IM000001.JPG"
printf 'viewer-art' > "$SOURCE/AMICAS/logo.jpg"
printf 'do-not-copy' > "$SOURCE/AutoRun.exe"

dd if=/dev/zero of="$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0001/IM000001" bs=128 count=1 >/dev/null 2>&1
printf 'DICMfake-dicom-1' >> "$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0001/IM000001"
dd if=/dev/zero of="$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0002/IM000001" bs=128 count=1 >/dev/null 2>&1
printf 'DICMfake-dicom-2' >> "$SOURCE/DICOM/AMPT0001/AMST0001/AMSE0002/IM000001"

run_extractor() {
  local source_path="$1"
  local destination_path="$2"
  "$ROOT_DIR/src/dicom-usb-extract.sh" \
    --source "$source_path" \
    --destination "$destination_path" \
    --no-ui \
    --no-open
}

run_extractor "$TMP_DIR/NO NAME" "$DEST"

RESULT="$DEST/2026-05-14-Patient-LT-WRIST-3V"

test -d "$RESULT/Viewable Images"

IMAGE_COUNT="$(find "$RESULT/Viewable Images" -type f | wc -l | tr -d ' ')"
DICOM_COUNT=0
if [ -d "$RESULT/Original DICOM Files" ]; then
  DICOM_COUNT="$(find "$RESULT/Original DICOM Files" -type f | wc -l | tr -d ' ')"
fi

test "$IMAGE_COUNT" = "2"
test "$DICOM_COUNT" = "0"
test -f "$RESULT/Viewable Images/01-WRIST-PA.jpg"
test -f "$RESULT/Viewable Images/02-WRIST-OBL.jpg"
test ! -d "$RESULT/Original DICOM Files"

if find "$RESULT" -type f | grep -Eq 'AutoRun|logo'; then
  echo "Copied a skipped viewer or autorun file" >&2
  exit 1
fi

WITH_DICOM_DEST="$TMP_DIR/output-with-dicom"
mkdir -p "$WITH_DICOM_DEST"
"$ROOT_DIR/src/dicom-usb-extract.sh" \
  --source "$TMP_DIR/NO NAME" \
  --destination "$WITH_DICOM_DEST" \
  --include-dicom \
  --no-ui \
  --no-open

WITH_DICOM_RESULT="$WITH_DICOM_DEST/2026-05-14-Patient-LT-WRIST-3V"
test -f "$WITH_DICOM_RESULT/Original DICOM Files/01-WRIST-PA.dcm"
test -f "$WITH_DICOM_RESULT/Original DICOM Files/02-WRIST-OBL.dcm"

JS_CHECK="$TMP_DIR/index.js"
perl -0ne 'print $1 if /<script>(.*)<\/script>/s' "$ROOT_DIR/index.html" > "$JS_CHECK"
node --check "$JS_CHECK" >/dev/null
node "$ROOT_DIR/tests/browser_logic_test.mjs"

echo "All tests passed"
