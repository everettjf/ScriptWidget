// Coverage matrix for the web renderer. Every tag in the native
// ScriptWidgetElementView switch and every property a native builder reads
// has an entry; test/coverage.test.js derives both lists from the Swift
// sources and fails when one is missing. States: supported, approximated
// (with the known difference), unsupported.

const s = (note = "") => ({ state: "supported", note });
const a = (note) => ({ state: "approximated", note });
const u = (note) => ({ state: "unsupported", note });

/// ScriptWidgetAttributeGeneralModifier plus ScriptWidgetElementView.widgetURL.
export const generalProps = Object.freeze({
  padding: s("String values only, as on iPhone: \"10\", \"horizontal,8\", \"t,r,b,l\""),
  frame: s("Includes the native quirk: \"max,20\" sets only the height"),
  background: s("Color or $gradient; on the root element it becomes the widget container background"),
  corner: s(),
  clip: s(),
  opacity: s(),
  animation: a("First frame only; widget animations run on iPhone"),
  rotation: s(),
  rotation3d: a("CSS perspective differs from SwiftUI's"),
  shadow: a("Blur radius mapped to CSS drop-shadow; edges may differ slightly"),
  widgetAccentable: a("Only affects accented rendering mode, which the web preview does not emulate yet"),
  linkurl: s("Tap targets are not interactive in the preview"),
});

export const coverage = Object.freeze({
  tags: {
    vstack: { state: "supported", props: { alignment: s(), spacing: s("Default spacing measured on iOS 27") } },
    hstack: { state: "supported", props: { alignment: s(), spacing: s() } },
    zstack: { state: "supported", props: {} },
    hgrid: { state: "unsupported", note: "Shown as a placeholder", props: { columns: u("Grid tracks"), alignment: u(""), spacing: u("") } },
    vgrid: { state: "unsupported", note: "Shown as a placeholder", props: { columns: u("Grid tracks"), alignment: u(""), spacing: u("") } },
    text: { state: "supported", props: { font: s("SF metrics on Apple systems; fallback fonts elsewhere"), color: s(), alignment: s() } },
    date: { state: "approximated", note: "Fixed clock, English formatting", props: { date: a("Fixed clock"), style: a("time/date/timer formats approximated"), font: s(), color: s(), alignment: s() } },
    image: { state: "approximated", note: "Package images render; SF Symbols and remote URLs show placeholders", props: {
      systemName: a("Placeholder glyph"), name: s("Needs the package image file"), id: s("Alias of name"), url: a("data: PNG/JPEG only; remote URLs are not loaded"),
      src: a("Alias of url"), ratio: u("Aspect ratio is not applied yet"), mode: s(), font: s(), accentedRenderingMode: a("Accented mode is not emulated"),
    } },
    gif: { state: "approximated", note: "Browser GIF playback; the widget's frame sequencing differs", props: { file: s("Resolved like ScriptWidgetPackage.getGifFile") } },
    spacer: { state: "supported", props: {} },
    rect: { state: "supported", props: { corner: s(), trim: a("Trim applies to strokes only"), stroke: s(), color: s() } },
    capsule: { state: "supported", props: { trim: a("Trim applies to strokes only"), stroke: s(), color: s() } },
    ellipse: { state: "supported", props: { trim: a("Trim applies to strokes only"), stroke: s(), color: s() } },
    circle: { state: "supported", props: { trim: a("Trim applies to strokes only"), stroke: s(), color: s() } },
    gauge: { state: "unsupported", note: "Shown as a placeholder", props: Object.fromEntries(["value", "angle", "current", "label", "max", "min", "needleColor", "sections", "style", "text", "thickness", "title", "type", "titleFont", "labelFont"].map((key) => [key, u("")])) },
    chart: { state: "unsupported", note: "Shown as a placeholder", props: Object.fromEntries(["category", "hideLegend", "hideXAxis", "hideYAxis", "data", "type"].map((key) => [key, u("")])) },
    link: { state: "approximated", note: "Children laid out vertically; not interactive", props: { url: s() } },
    divider: { state: "supported", props: { thickness: s(), axis: s(), color: s() } },
    line: { state: "supported", props: { thickness: s(), length: s(), axis: s(), color: s() } },
    roundedrect: { state: "supported", props: { radius: s(), color: s() } },
    icon: { state: "approximated", note: "SF Symbols are shown as placeholder glyphs", props: { systemName: a("Placeholder glyph"), size: s(), color: s(), font: s() } },
    label: { state: "approximated", note: "Icon is a placeholder glyph", props: { title: s(), systemName: a("Placeholder glyph"), color: s(), font: s() } },
    progress: { state: "supported", props: { value: s(), total: s(), label: s(), style: s(), color: s(), trackColor: s(), thickness: s(), frame: s("Circular size") } },
    ring: { state: "supported", props: { value: s(), thickness: s(), color: s(), trackColor: s() } },
    badge: { state: "supported", props: { text: s(), radius: s(), background: s(), color: s() } },
    chip: { state: "supported", props: { text: s(), radius: s(), background: s(), borderColor: s(), color: s() } },
    stat: { state: "supported", props: { title: s(), value: s(), subtitle: s(), color: s(), mutedColor: s() } },
    button: { state: "approximated", note: "Label only; taps run on iPhone", props: { action: s(), actionID: s(), onClick: s() } },
    toggle: { state: "approximated", note: "Static switch", props: { on: s(), actionID: s(), onClick: s(), stateKey: s() } },
    Fragment: { state: "supported", props: {} },
  },
});

// Tags whose native builder does not apply ScriptWidgetAttributeGeneralModifier.
const withoutGeneral = new Set(["spacer", "Fragment"]);

/// Reason a property has no effect on iPhone, or null when it is read.
export function ignoredProp(tag, key) {
  const entry = coverage.tags[tag];
  if (!entry) return null;
  if (Object.prototype.hasOwnProperty.call(entry.props, key)) return null;
  if (tag === "spacer") return key === "frame" ? null : "is ignored by the native runtime (Spacer reads only frame)";
  if (!withoutGeneral.has(tag) && Object.prototype.hasOwnProperty.call(generalProps, key)) return null;
  if (key === "key" || key === "children") return null;
  return "is ignored by the native runtime";
}
