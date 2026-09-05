import assert from "node:assert/strict";
import { File } from "node:buffer";
import fs from "node:fs";
import vm from "node:vm";

class FakeElement {
  constructor(tagName = "div") {
    this.tagName = tagName;
    this.children = [];
    this.listeners = {};
    this.style = {};
    this.textContent = "";
    this.className = "";
    this.hidden = false;
    this.disabled = false;
    this.checked = false;
    this.type = "";
    this.clickCount = 0;
  }

  append(...children) {
    this.children.push(...children);
  }

  addEventListener(event, callback) {
    this.listeners[event] = callback;
  }

  click() {
    this.clickCount++;
    if (this.listeners.click) this.listeners.click();
  }

  dispatch(event) {
    if (this.listeners[event]) this.listeners[event]();
  }
}

const elements = new Map();
const ids = [
  "chooseDirectoryButton",
  "folderInput",
  "status",
  "summary",
  "studyName",
  "imageCount",
  "dicomCount",
  "selectedCount",
  "imageGrid",
  "dicomList",
  "downloadSelectedButton",
  "downloadAllButton",
  "includeDicomCheckbox",
  "selectImagesButton",
  "clearImagesButton",
  "selectDicomButton",
  "clearDicomButton"
];

for (const id of ids) {
  elements.set(id, new FakeElement());
}

const html = fs.readFileSync(new URL("../index.html", import.meta.url), "utf8");
const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
assert.ok(script, "index.html should contain an inline script");

const context = {
  console,
  Blob,
  TextEncoder,
  Uint8Array,
  setTimeout,
  URL: {
    createObjectURL() {
      return "blob:test";
    },
    revokeObjectURL() {}
  },
  window: {},
  document: {
    body: new FakeElement("body"),
    getElementById(id) {
      assert.ok(elements.has(id), `unexpected element id: ${id}`);
      return elements.get(id);
    },
    createElement(tagName) {
      return new FakeElement(tagName);
    }
  }
};

vm.createContext(context);
vm.runInContext(script, context);

function makeFile(name, bytes, relativePath) {
  const file = new File([bytes], name);
  Object.defineProperty(file, "webkitRelativePath", { value: relativePath });
  return file;
}

const entries = [
  {
    path: "NO NAME/IMAGES/STUDYLIST.XML",
    file: makeFile(
      "STUDYLIST.XML",
      `<list>
        <itsPatientName>SAMPLE^PATIENT</itsPatientName>
        <itsStudyDate>2026-05-14 15:24:43.0 UTC</itsStudyDate>
        <itsStudyDescription>LT WRIST 3V</itsStudyDescription>
        <itsSeriesDescription>WRIST PA</itsSeriesDescription>
        <itsSeriesDescription>WRIST OBL</itsSeriesDescription>
      </list>`,
      "NO NAME/IMAGES/STUDYLIST.XML"
    )
  },
  {
    path: "NO NAME/IMAGES/IHE_PDI/AMPT0001/AMST0001/AMSE0001/IM000001.JPG",
    file: makeFile("IM000001.JPG", new Uint8Array([255, 216, 255, 224]), "NO NAME/IMAGES/IHE_PDI/AMPT0001/AMST0001/AMSE0001/IM000001.JPG")
  },
  {
    path: "NO NAME/IMAGES/IHE_PDI/AMPT0001/AMST0001/AMSE0002/IM000001.JPG",
    file: makeFile("IM000001.JPG", new Uint8Array([255, 216, 255, 224]), "NO NAME/IMAGES/IHE_PDI/AMPT0001/AMST0001/AMSE0002/IM000001.JPG")
  },
  {
    path: "NO NAME/IMAGES/DICOM/AMPT0001/AMST0001/AMSE0001/IM000001",
    file: makeFile("IM000001", new Uint8Array([...new Uint8Array(128), 68, 73, 67, 77, 1]), "NO NAME/IMAGES/DICOM/AMPT0001/AMST0001/AMSE0001/IM000001")
  },
  {
    path: "NO NAME/IMAGES/AMICAS/logo.jpg",
    file: makeFile("logo.jpg", "viewer art", "NO NAME/IMAGES/AMICAS/logo.jpg")
  }
];

await context.analyze(entries);

assert.equal(elements.get("imageCount").textContent, "2");
assert.equal(elements.get("dicomCount").textContent, "1");
assert.equal(elements.get("selectedCount").textContent, "2");
assert.equal(elements.get("status").textContent, "Found 2 pictures and 1 optional DICOM original.");
assert.equal(elements.get("downloadAllButton").textContent, "Download All Pictures ZIP");
assert.equal(elements.get("includeDicomCheckbox").disabled, false);
assert.equal(elements.get("selectDicomButton").disabled, true);
assert.equal(context.selectedItems().length, 2);
assert.equal(context.allItems().length, 2);

elements.get("includeDicomCheckbox").checked = true;
elements.get("includeDicomCheckbox").dispatch("change");

assert.equal(elements.get("selectedCount").textContent, "3");
assert.equal(elements.get("downloadAllButton").textContent, "Download All ZIP");
assert.equal(elements.get("selectDicomButton").disabled, false);
assert.equal(context.selectedItems().length, 3);
assert.equal(context.allItems().length, 3);

elements.get("chooseDirectoryButton").click();
assert.equal(elements.get("folderInput").clickCount, 1);

const zip = await context.createZip(context.selectedItems());
assert.equal(zip.type, "application/zip");
assert.ok(zip.size > 0);
