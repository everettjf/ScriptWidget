// The preview sandbox is a page-wide singleton: one opaque-origin iframe that
// compiles and runs widgets in Workers.
import { createPreviewSandbox } from "../../preview-engine/src/browser/client.js";

export const sandbox = createPreviewSandbox({
  sandboxURL: new URL("./sandbox.html", document.baseURI).href,
  assetBaseURL: new URL("./runtime/", document.baseURI),
});
