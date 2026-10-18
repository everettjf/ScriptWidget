// Web renderer for resolved ScriptWidget element trees. Builders mirror the
// native ScriptWidgetElementTag* classes and ScriptWidgetAttributeGeneral's
// modifier order; layout.js reproduces SwiftUI sizing; drawing uses
// absolutely positioned elements. User text is inserted with textContent.

import {
  alignments, cssColor, defaultFont, fontFamily, gradientCSS, parseColor, parseFont, parseFrame,
  parsePadding, parsePaint, propReader, swiftDouble, systemBackground, textStyles,
} from "./props.js";
import { coverage, generalProps, ignoredProp } from "./coverage.js";
import { widgetSize } from "./profiles.js";
import {
  AspectNode, DecorationNode, FixedNode, FlexibleNode, FrameNode, PaddingNode, SpacerNode, StackNode, TextNode,
  ZStackNode, createTextMeasurer,
} from "./layout.js";

const naturalLineRatio = 1.1934;

/// Single-line Text height: SF natural line height on the 2x pixel grid.
export const lineHeight = (size) => Math.ceil(size * naturalLineRatio * 2) / 2;

function textStyleFor(font) {
  const natural = lineHeight(font.size);
  const leading = Math.max(natural, font.lineHeight ?? font.size * 1.29);
  const family = fontFamily(font);
  return { ...font, natural, leading, family, key: `${family}|${font.size}|${font.weight}|${leading}` };
}

// MARK: - Tree decoding

function decodeTree(treeJSON) {
  const decodeDictionary = (map) => Object.fromEntries(Object.entries(map).map(([key, item]) => [key, decode(item)]));
  function decode(value) {
    if (value === null || typeof value !== "object") return value;
    if (Array.isArray(value)) return value.map(decode);
    if ("$element" in value) {
      return { tag: typeof value.$element === "string" ? value.$element : null, props: value.props ? decodeDictionary(value.props) : null, children: value.children ? value.children.map(decode) : null };
    }
    if ("$dict" in value) return decodeDictionary(value.$dict);
    if ("$date" in value) return { $date: value.$date };
    if ("$number" in value) return value.$number === "-0" ? -0 : Number(value.$number);
    return value;
  }
  return decode(JSON.parse(treeJSON));
}

const isElement = (value) => value !== null && typeof value === "object" && "tag" in value && "children" in value && "props" in value;

function childrenAsElements(element) {
  const result = [];
  const visit = (items) => { for (const item of items) { if (isElement(item)) result.push(item); else if (Array.isArray(item)) visit(item); } };
  visit(element.children ?? []);
  return result;
}

/// String(describing: NSNumber) for text children.
function numberText(value) {
  if (typeof value === "boolean") return value ? "1" : "0";
  if (Number.isInteger(value) && Math.abs(value) >= 1e16) return value.toExponential();
  return String(value);
}

function textFromChildren(element) {
  let text = "";
  for (const child of element.children ?? []) {
    if (typeof child === "string") text += child;
    else if (typeof child === "number" || typeof child === "boolean") text += numberText(child);
    else text += "#ErrorChildType#";
  }
  return text;
}

function collectImageURLs(element, urls) {
  if (!isElement(element)) return;
  const reader = propReader(element.props);
  if (element.tag === "image") { const url = reader.string("url", "src"); if (url && /^data:image\/(png|jpeg);base64,/.test(url)) urls.add(url); }
  childrenAsElements(element).forEach((child) => collectImageURLs(child, urls));
}

async function naturalSizes(urls, doc) {
  const sizes = new Map();
  await Promise.all([...urls].map(async (url) => {
    const image = doc.createElement("img");
    image.src = url;
    try { await image.decode(); sizes.set(url, [image.naturalWidth, image.naturalHeight]); } catch { /* broken image */ }
  }));
  return sizes;
}

// MARK: - Renderer

/// Renders a canonical tree JSON string into a widget-sized element.
/// Must run in a document with layout (text is measured by the browser).
export async function renderWidget(treeJSON, {
  family = "medium", profile = "iphone-393", appearance = "light", resources = {}, document: doc = globalThis.document,
} = {}) {
  const size = widgetSize(profile, family);
  const diagnostics = [];
  const reported = new Set();
  const report = (severity, code, message) => {
    const key = `${code}:${message}`;
    if (!reported.has(key)) { reported.add(key); diagnostics.push({ severity, code, message }); }
  };
  const color = (value) => parseColor(value, appearance);
  // Button labels default to the accent color, like SwiftUI's button style.
  let tint = null;
  const primary = () => tint ?? color("primary");
  const root = decodeTree(treeJSON);
  const urls = new Set();
  for (const [path, url] of Object.entries(resources)) if (path.startsWith("image/")) urls.add(url);
  collectImageURLs(root, urls);
  const imageSizes = await naturalSizes(urls, doc);
  const measurer = createTextMeasurer(doc);

  // Leaves carry a draw(node, element) callback.
  const leaf = (node, draw) => Object.assign(node, { draw });

  function checkProps(element, reader) {
    const known = coverage.tags[element.tag];
    for (const key of reader.keys()) {
      const reason = ignoredProp(element.tag, key);
      const entry = known?.props?.[key] ?? generalProps[key];
      if (reason) report("info", "prop.ignored", `<${element.tag} ${key}> ${reason}`);
      else if (entry?.state === "unsupported") report("warning", "prop.unsupported", `<${element.tag} ${key}> is not rendered by the web preview yet`);
      else if (entry?.state === "approximated") report("info", "prop.approximated", `<${element.tag} ${key}> is approximated: ${entry.note}`);
    }
  }

  // MARK: Text

  function text(value, font, inputPaint, alignment = "left") {
    const style = textStyleFor(font);
    const paint = inputPaint ?? { color: primary() };
    return leaf(new TextNode(value, style, measurer), (node, element) => {
      Object.assign(element.style, {
        fontFamily: style.family, fontSize: `${style.size}px`, fontWeight: String(style.weight), lineHeight: `${style.leading}px`,
        whiteSpace: "pre-wrap", overflowWrap: "break-word", textAlign: alignment,
      });
      const content = element.ownerDocument.createElement("div");
      content.textContent = value;
      const trim = (style.leading - style.natural) / 2;
      Object.assign(content.style, { marginTop: `${-trim}px`, width: `${node.frame.width + 1}px` });
      if (alignment !== "left") content.style.width = `${node.frame.width}px`;
      if (node.lines && node.lines.lines < node.lines.total) {
        Object.assign(content.style, { display: "-webkit-box", webkitBoxOrient: "vertical", webkitLineClamp: String(node.lines.lines), overflow: "hidden" });
      }
      applyTextPaint(content, paint, node.frame.width, node.frame.height);
      element.appendChild(content);
    });
  }

  function applyTextPaint(element, paint, width, height) {
    if (paint?.gradient) {
      Object.assign(element.style, { color: "transparent", backgroundImage: gradientCSS(paint.gradient, width, height) });
      element.style.webkitBackgroundClip = "text"; element.style.backgroundClip = "text";
    } else element.style.color = cssColor(paint?.color ?? primary());
  }

  const paintOf = (reader, field) => (reader.string(field) !== null ? parsePaint(reader.string(field), appearance) : null);
  const styleFont = (name) => { const [size, leading, weight] = textStyles[name]; return { size, lineHeight: leading, weight, design: "default" }; };

  // MARK: Shapes

  function shape(kind, paint, { strokeWidth = null, trim = null, cornerRadius = 0 } = {}) {
    return leaf(new FlexibleNode(), (node, element) => {
      const { width, height } = node.frame;
      let x = 0; let y = 0; let w = width; let h = height; let r = 0;
      if (kind === "circle") { const d = Math.min(width, height); x = (width - d) / 2; y = (height - d) / 2; w = d; h = d; }
      if (kind === "capsule") r = Math.min(width, height) / 2;
      if (kind === "rounded") r = Math.min(cornerRadius, width / 2, height / 2);
      const elliptical = kind === "circle" || kind === "ellipse";
      if (strokeWidth === null && !trim) {
        const fill = element.ownerDocument.createElement("div");
        Object.assign(fill.style, { position: "absolute", left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`, borderRadius: elliptical ? "50%" : `${r}px` });
        if (paint.gradient) {
          fill.style.backgroundImage = gradientCSS(paint.gradient, width, height);
          fill.style.backgroundPosition = `${-x}px ${-y}px`;
          fill.style.backgroundSize = `${width}px ${height}px`;
        } else fill.style.backgroundColor = cssColor(paint.color);
        element.appendChild(fill);
        return;
      }
      const svgNS = "http://www.w3.org/2000/svg";
      const svg = element.ownerDocument.createElementNS(svgNS, "svg");
      svg.setAttribute("width", String(width)); svg.setAttribute("height", String(height));
      Object.assign(svg.style, { overflow: "visible", position: "absolute", left: "0", top: "0" });
      const outline = element.ownerDocument.createElementNS(svgNS, elliptical ? "ellipse" : "rect");
      const attributes = elliptical ? { cx: x + w / 2, cy: y + h / 2, rx: w / 2, ry: h / 2 } : { x, y, width: w, height: h, rx: r, ry: r };
      for (const [key, value] of Object.entries(attributes)) outline.setAttribute(key, String(value));
      let colorValue = paint.color;
      if (paint.gradient) { report("info", "prop.approximated", "Gradient strokes use the first gradient color"); colorValue = paint.gradient.colors[0] ?? primary(); }
      if (strokeWidth !== null) {
        outline.setAttribute("fill", "none"); outline.setAttribute("stroke", cssColor(colorValue)); outline.setAttribute("stroke-width", String(strokeWidth));
      } else {
        outline.setAttribute("fill", cssColor(colorValue));
        report("info", "prop.approximated", "trim without stroke renders the untrimmed shape");
      }
      if (trim && strokeWidth !== null) {
        outline.setAttribute("pathLength", "1");
        outline.setAttribute("stroke-dasharray", `${Math.max(0, trim[1] - trim[0])} 2`);
        outline.setAttribute("stroke-dashoffset", String(-trim[0]));
      }
      svg.appendChild(outline);
      element.appendChild(svg);
    });
  }

  function shapeOptions(reader) {
    let strokeWidth = null;
    const stroke = reader.string("stroke");
    if (stroke !== null && swiftDouble(stroke) !== null) strokeWidth = swiftDouble(stroke);
    let trim = null;
    if (typeof reader.raw("trim") === "number") trim = [reader.raw("trim"), 1];
    else if (reader.string("trim") !== null) {
      const parts = reader.string("trim").split(",");
      if (parts.length === 1) { const from = swiftDouble(parts[0]); if (from !== null && from >= 0 && from <= 1) trim = [from, 1]; }
      else if (parts.length === 2 && swiftDouble(parts[0]) !== null && swiftDouble(parts[1]) !== null) trim = [swiftDouble(parts[0]), swiftDouble(parts[1])];
    }
    return { strokeWidth, trim };
  }

  function ring(thickness, tint, track, progress, fixedSize = null) {
    const node = fixedSize ? new FixedNode(fixedSize, fixedSize) : new FlexibleNode();
    return leaf(node, (target, element) => {
      const { width, height } = target.frame;
      const svgNS = "http://www.w3.org/2000/svg";
      const svg = element.ownerDocument.createElementNS(svgNS, "svg");
      svg.setAttribute("width", String(width)); svg.setAttribute("height", String(height));
      Object.assign(svg.style, { position: "absolute", left: "0", top: "0", overflow: "visible" });
      const circle = (stroke, dash) => {
        const item = element.ownerDocument.createElementNS(svgNS, "circle");
        for (const [key, value] of Object.entries({ cx: width / 2, cy: height / 2, r: Math.min(width, height) / 2, fill: "none", stroke: cssColor(stroke), "stroke-width": thickness })) item.setAttribute(key, String(value));
        if (dash !== undefined) {
          item.setAttribute("pathLength", "1"); item.setAttribute("stroke-dasharray", `${dash} 2`);
          item.setAttribute("stroke-linecap", "round"); item.setAttribute("transform", `rotate(-90 ${width / 2} ${height / 2})`);
        }
        return item;
      };
      svg.appendChild(circle(track));
      if (progress > 0) svg.appendChild(circle(tint, progress));
      element.appendChild(svg);
    });
  }

  // MARK: Images

  /// ScriptWidgetPackage.getImage: image/<name>, trying common extensions.
  function packageImage(name) {
    const trimmed = name.trim();
    if (trimmed === "" || trimmed.includes("..")) return null;
    const base = `image/${trimmed}`;
    const candidates = /\.[A-Za-z0-9]+$/.test(trimmed) ? [base] : ["png", "jpg", "jpeg", "webp", "heic"].map((ext) => `${base}.${ext}`);
    for (const candidate of candidates) if (resources[candidate]) return { path: candidate, url: resources[candidate] };
    return null;
  }

  /// ScriptWidgetPackage.getGifFile: exact .gif, bare name + .gif, then a
  /// case-insensitive match in image/.
  function packageGif(name) {
    const trimmed = name.trim();
    if (trimmed === "" || trimmed.includes("..")) return null;
    const direct = `image/${trimmed}`;
    if (/\.gif$/i.test(trimmed) && resources[direct]) return resources[direct];
    if (!/\.[A-Za-z0-9]+$/.test(trimmed) && resources[`${direct}.gif`]) return resources[`${direct}.gif`];
    const target = trimmed.replace(/\.[^.]*$/, "").toLowerCase();
    for (const [path, url] of Object.entries(resources)) {
      if (!path.startsWith("image/") || !/\.gif$/i.test(path)) continue;
      const file = path.slice("image/".length).toLowerCase();
      if (file === trimmed.toLowerCase() || file.replace(/\.gif$/, "") === target) return url;
    }
    return null;
  }

  function drawPicture(url, fit) {
    return (node, element) => {
      const image = element.ownerDocument.createElement("img");
      image.src = url; image.alt = "";
      Object.assign(image.style, { position: "absolute", left: "0", top: "0", width: "100%", height: "100%", objectFit: fit });
      element.appendChild(image);
    };
  }

  // SF Symbols are fixed-size images: about 1.2 em wide, one line tall.
  function glyph(systemName, font, inputPaint) {
    const paint = inputPaint ?? { color: primary() };
    report("info", "icon.approximated", `SF Symbol "${systemName}" is shown as a placeholder glyph`);
    const style = textStyleFor(font);
    const node = leaf(new FixedNode(Math.ceil(style.size * 1.2 * 2) / 2, style.natural), (target, element) => {
      Object.assign(element.style, { fontFamily: style.family, fontSize: `${style.size * 0.9}px`, lineHeight: `${style.natural}px`, textAlign: "center" });
      element.textContent = "◉";
      applyTextPaint(element, paint, target.frame.width, target.frame.height);
    });
    node.title = systemName;
    return node;
  }

  function imageNode(reader) {
    const systemName = reader.string("systemName");
    const name = reader.string("name", "id");
    const url = reader.string("url", "src");
    const mode = reader.string("mode");
    if (systemName === null && name !== null) {
      const found = packageImage(name);
      if (found) {
        if (/\.heic$/i.test(found.path)) report("warning", "image.format", `HEIC image ${found.path} may not display in this browser`);
        const natural = imageSizes.get(found.url) ?? [10, 10];
        if (mode === "fit" || mode === "fill") return leaf(new AspectNode(natural, reader.double("ratio"), mode), drawPicture(found.url, mode === "fill" ? "cover" : "contain"));
        return leaf(new FlexibleNode(natural), drawPicture(found.url, "fill"));
      }
      report("warning", "image.missing", `Package image "${name}" was not found in image/`);
    }
    if (systemName === null && url !== null && /^data:image\/(png|jpeg);base64,/.test(url)) {
      const natural = imageSizes.get(url) ?? [10, 10];
      return leaf(new FixedNode(...natural), drawPicture(url, "fill"));
    }
    if (systemName === null && url !== null) report("warning", "image.remote", `Remote image ${url.slice(0, 80)} is not loaded by the web preview`);
    return glyph(systemName ?? "questionmark.circle", parseFont(reader.string("font")) ?? defaultFont, null);
  }

  // MARK: Stacks

  // Measured on iOS 27: HStack children are 8 apart. In a VStack, text to
  // text uses the style's leading minus its natural height, and text to
  // other views 8 + 0.18 x the font size. Spacers add no spacing.
  function defaultSpacing(axis) {
    return (previous, next) => {
      if (previous.isSpacer || next.isSpacer) return 0;
      if (axis === "h") return 8;
      const above = previous.edge("bottom"); const below = next.edge("top");
      const half = (value) => Math.round(value * 2) / 2;
      if (above && below) return Math.max(0, half(above.leading - above.natural));
      if (above) return half(8 + 0.18 * above.size);
      if (below) return half(8 + 0.18 * below.size);
      return 8;
    };
  }

  function stack(axis, children, reader) {
    const alignment = reader.string("alignment");
    const cross = axis === "v"
      ? ({ leading: "start", trailing: "end" }[alignment] ?? "center")
      : ({ top: "start", bottom: "end", firstTextBaseline: "start", lastTextBaseline: "end" }[alignment] ?? "center");
    const explicit = reader.double("spacing");
    return new StackNode(axis, children, { alignment: cross, spacing: explicit !== null ? () => explicit : defaultSpacing(axis) });
  }

  /// Fragments are SwiftUI Groups: their children join the parent layout.
  function buildChildren(element, axis) {
    const result = [];
    for (const child of childrenAsElements(element)) {
      if (child.tag === "Fragment") result.push(...buildChildren(child, axis));
      else result.push(build(child, axis));
    }
    return result;
  }

  // MARK: General modifiers (ScriptWidgetAttributeGeneralModifier order)

  function applyGeneral(content, element, reader, { isRoot = false } = {}) {
    let node = content;
    const padding = parsePadding(reader);
    if (padding) node = new PaddingNode(node, padding);
    const frame = parseFrame(reader);
    if (frame.mode !== "none") node = new FrameNode(node, { ...frame, alignment: alignments[frame.alignment] ?? alignments.center });

    const decoration = {};
    const background = reader.string("background");
    if (background !== null && !isRoot) {
      const paint = parsePaint(background, appearance);
      if (paint) decoration.background = paint;
    }
    const corner = reader.double("corner");
    if (corner !== null) decoration.cornerRadius = corner;
    let clipShape = reader.int("clip") === 1 ? "" : null;
    if (reader.string("clip") !== null) clipShape = reader.string("clip");
    if (clipShape !== null) decoration.clip = clipShape;
    const opacity = reader.double("opacity");
    if (opacity !== null) decoration.opacity = Math.max(0, Math.min(1, opacity));
    if (reader.string("animation") !== null) report("info", "prop.approximated", `<${element.tag} animation> renders the first frame only`);
    const transforms = [];
    const rotation = reader.double("rotation");
    if (rotation !== null) transforms.push(`rotate(${rotation}deg)`);
    const rotation3d = reader.string("rotation3d");
    if (rotation3d !== null) {
      const parts = rotation3d.split(",");
      if (parts.length === 4 && swiftDouble(parts[0]) !== null) {
        const [x, y, z] = parts.slice(1).map((part) => swiftDouble(part));
        transforms.push(`perspective(400px) rotate3d(${x ?? 1}, ${y ?? 0}, ${z ?? 0}, ${swiftDouble(parts[0])}deg)`);
      }
    }
    if (transforms.length) decoration.transform = transforms.join(" ");
    const shadow = reader.string("shadow");
    if (shadow !== null) {
      const parts = shadow.split(",");
      let shadowColor = null; let radius = 3; let x = 0; let y = 3;
      if (parts.length === 1) shadowColor = color(shadow);
      else if (parts.length === 4) {
        shadowColor = color(parts[0]);
        radius = swiftDouble(parts[1]) ?? radius; x = swiftDouble(parts[2]) ?? x; y = swiftDouble(parts[3]) ?? y;
      }
      if (shadowColor) decoration.filter = `drop-shadow(${x}px ${y}px ${radius / 2}px ${cssColor(shadowColor)})`;
    }
    if (Object.keys(decoration).length) {
      // Backgrounds and effects keep the content's spacing preferences;
      // padding and frames replace them.
      decoration.keepsEdges = !padding && frame.mode === "none";
      node = new DecorationNode(node, decoration);
    }
    return node;
  }

  // MARK: Tags

  function build(element, axis = "z", { isRoot = false } = {}) {
    const reader = propReader(element.props);
    checkProps(element, reader);
    const tag = element.tag;
    let content;
    switch (tag) {
      case "vstack": content = stack("v", buildChildren(element, "v"), reader); break;
      case "hstack": content = stack("h", buildChildren(element, "h"), reader); break;
      case "zstack": content = new ZStackNode(buildChildren(element, "z")); break;
      case "text": case "date": {
        const font = parseFont(reader.string("font")) ?? defaultFont;
        const align = { leading: "left", center: "center", trailing: "right" }[reader.string("alignment")] ?? "left";
        if (tag === "date") report("info", "tag.approximated", "<date> shows a fixed-clock value");
        content = text(tag === "date" ? formatDate(reader) : textFromChildren(element), font, paintOf(reader, "color"), align);
        break;
      }
      case "spacer": {
        const spacer = new SpacerNode(axis);
        const frame = parseFrame(reader);
        return frame.mode === "none" ? spacer : new FrameNode(spacer, { ...frame, alignment: alignments[frame.alignment] ?? alignments.center });
      }
      case "rect": {
        const corner = reader.string("corner");
        const radius = corner !== null ? swiftDouble(corner) : null;
        content = shape(radius !== null ? "rounded" : "rect", paintOf(reader, "color") ?? { color: primary() }, { ...shapeOptions(reader), cornerRadius: radius ?? 0 });
        break;
      }
      case "capsule": case "ellipse": case "circle":
        content = shape(tag, paintOf(reader, "color") ?? { color: primary() }, shapeOptions(reader)); break;
      case "roundedrect":
        content = shape("rounded", { color: color(reader.string("color") ?? "#e2e8f0") ?? color("gray") }, { cornerRadius: reader.double("radius") ?? 12 }); break;
      case "divider": case "line": {
        const thickness = reader.double("thickness") ?? (tag === "divider" ? 1 : 2);
        const fill = { color: color(reader.string("color") ?? "secondary") ?? color("secondary") };
        const vertical = reader.string("axis") === "vertical";
        const length = reader.double("length") ?? 48;
        const frame = tag === "line"
          ? { mode: "size", width: vertical ? thickness : length, height: vertical ? length : thickness }
          : vertical ? { mode: "width", width: thickness } : { mode: "height", height: thickness };
        content = new FrameNode(shape("rect", fill), { ...frame, alignment: alignments.center });
        break;
      }
      case "icon": {
        const base = reader.double("size") !== null ? { ...defaultFont, lineHeight: null, size: reader.double("size") } : defaultFont;
        content = glyph(reader.string("systemName") ?? "questionmark.circle", parseFont(reader.string("font")) ?? base, paintOf(reader, "color"));
        break;
      }
      case "image": content = imageNode(reader); break;
      case "gif": {
        const url = packageGif(reader.string("file") ?? "");
        if (url) { report("info", "tag.approximated", "<gif> animates with the browser's GIF player"); content = leaf(new FlexibleNode(), drawPicture(url, "contain")); }
        else content = text("GIF unavailable", defaultFont, null);
        break;
      }
      case "label": {
        const font = parseFont(reader.string("font")) ?? defaultFont;
        const paint = paintOf(reader, "color");
        content = new StackNode("h", [glyph(reader.string("systemName") ?? "circle.fill", font, paint), text(reader.string("title") ?? textFromChildren(element), font, paint)], { alignment: "center", spacing: () => 8 });
        break;
      }
      case "badge": case "chip": {
        const isBadge = tag === "badge";
        const font = styleFont(isBadge ? "caption2" : "caption");
        const textColor = reader.string("color") !== null ? color(reader.string("color")) : color(isBadge ? "#e2e8f0" : "#0f172a");
        const padded = new PaddingNode(text(reader.string("text") ?? textFromChildren(element), font, { color: textColor ?? [0, 0, 0, 0] }), isBadge ? [4, 8, 4, 8] : [5, 10, 5, 10]);
        const decoration = { cornerRadius: reader.double("radius") ?? (isBadge ? 6 : 14) };
        if (reader.string("background") === null) decoration.background = { color: color(isBadge ? "#0f172a" : "#f1f5f9") };
        if (!isBadge) decoration.border = color(reader.string("borderColor") ?? "#cbd5f5") ?? color("gray");
        content = new DecorationNode(padded, decoration);
        break;
      }
      case "stat": {
        const muted = { color: color(reader.string("mutedColor") ?? "#64748b") ?? color("gray") };
        const children = [text(reader.string("title") ?? "Title", styleFont("caption"), muted), text(reader.string("value") ?? "0", styleFont("title3"), { color: color(reader.string("color") ?? "#0f172a") ?? color("black") })];
        const subtitle = reader.string("subtitle") ?? "";
        if (subtitle) children.push(text(subtitle, styleFont("caption2"), muted));
        content = new StackNode("v", children, { alignment: "start", spacing: () => 4 });
        break;
      }
      case "progress": content = progressNode(reader); break;
      case "ring": {
        const value = Math.min(Math.max(reader.double("value") ?? 0, 0), 1);
        content = ring(reader.double("thickness") ?? 8, color(reader.string("color") ?? "#3b82f6") ?? color("blue"), color(reader.string("trackColor") ?? "#e2e8f0") ?? [142, 142, 147, 0.2], value);
        break;
      }
      case "link": case "button": case "toggle": {
        const outerTint = tint;
        if (tag === "button") tint = color("blue");
        const children = buildChildren(element, "v");
        tint = outerTint;
        if (tag === "toggle") {
          const on = reader.bool("on") ?? false;
          report("info", "tag.approximated", "<toggle> is drawn as a static switch");
          const knob = leaf(new FixedNode(51, 31), (node, target) => {
            Object.assign(target.style, { borderRadius: "16px", backgroundColor: cssColor(on ? color("green") : [120, 120, 128, 0.16]) });
            const thumb = target.ownerDocument.createElement("div");
            Object.assign(thumb.style, { position: "absolute", top: "2px", left: on ? "22px" : "2px", width: "27px", height: "27px", borderRadius: "14px", backgroundColor: "white", boxShadow: "0 1px 3px rgba(0,0,0,0.25)" });
            target.appendChild(thumb);
          });
          content = new StackNode("h", [new StackNode("v", children, { alignment: "start", spacing: defaultSpacing("v") }), new SpacerNode("h"), knob], { alignment: "center", spacing: () => 8 });
        } else {
          if (tag === "button") report("info", "tag.approximated", "<button> renders its label; taps run only on iPhone");
          content = new StackNode("v", children, { alignment: "center", spacing: defaultSpacing("v") });
        }
        break;
      }
      case "gauge": case "chart": case "hgrid": case "vgrid": {
        report("warning", "tag.unsupported", `<${tag}> is not rendered by the web preview yet`);
        content = new DecorationNode(new PaddingNode(text(`<${tag}>`, styleFont("caption2"), { color: color("secondary") }), [4, 6, 4, 6]), { dashed: true, cornerRadius: 6 });
        break;
      }
      case "Fragment": {
        const children = buildChildren(element, axis);
        return children.length === 1 ? children[0] : new StackNode("v", children, { alignment: "center", spacing: defaultSpacing("v") });
      }
      default: {
        report("warning", "tag.unknown", tag === null ? "Element has a non-string tag" : `Unknown tag <${tag}> renders as "UnknownTagName" on iPhone`);
        return new DecorationNode(text(tag === null ? "UnknownTagType" : "UnknownTagName", defaultFont, null), { background: { color: color(tag === null ? "purple" : "pink") } });
      }
    }
    return applyGeneral(content, element, reader, { isRoot });
  }

  function progressNode(reader) {
    const value = Math.max(reader.double("value") ?? 0, 0);
    const total = Math.max(reader.double("total") ?? 1, 0.000001);
    const progress = Math.min(value / total, 1);
    const label = reader.string("label") ?? "";
    const tint = color(reader.string("color") ?? "#3b82f6") ?? color("blue");
    const track = (reader.string("trackColor") !== null ? color(reader.string("trackColor")) : null) ?? [255, 255, 255, 0.15];
    const thickness = reader.double("thickness") ?? 6;
    if ((reader.string("style") ?? "linear") === "circular") {
      const side = reader.double("frame") ?? 32;
      const children = [ring(thickness, tint, track, progress, side)];
      if (label) children.push(text(label, styleFont("caption2"), null));
      return new FrameNode(new ZStackNode(children), { mode: "size", width: side, height: side, alignment: alignments.center });
    }
    const bar = leaf(new FlexibleNode(), (node, element) => {
      Object.assign(element.style, { borderRadius: `${thickness / 2}px`, backgroundColor: cssColor(track), overflow: "hidden" });
      const fill = element.ownerDocument.createElement("div");
      Object.assign(fill.style, { position: "absolute", left: "0", top: "0", height: "100%", width: `${node.frame.width * progress}px`, borderRadius: `${thickness / 2}px`, backgroundColor: cssColor(tint) });
      element.appendChild(fill);
    });
    const barFrame = new FrameNode(bar, { mode: "height", height: thickness, alignment: alignments.center });
    const children = label ? [text(label, styleFont("caption2"), null), barFrame] : [barFrame];
    return new StackNode("v", children, { alignment: "start", spacing: () => (label ? 4 : 0) });
  }

  function formatDate(reader) {
    const now = new Date(Date.UTC(2026, 0, 1, 12, 0, 0));
    const style = reader.string("style") ?? "timer";
    if (style === "time") return now.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
    if (style === "date") return now.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });
    if (style === "relative" || style === "offset") return "0 min";
    return "0:00";
  }

  // MARK: Drawing

  function draw(node, parent) {
    const element = doc.createElement("div");
    const { x, y, width, height } = node.frame;
    Object.assign(element.style, { position: "absolute", left: `${x}px`, top: `${y}px`, width: `${width}px`, height: `${height}px` });
    if (node instanceof DecorationNode) applyDecoration(element, node.decoration, width, height);
    if (node.title) element.title = node.title;
    parent.appendChild(element);
    if (node.draw) node.draw(node, element);
    for (const child of node.children ?? (node.child ? [node.child] : [])) draw(child, element);
  }

  function applyDecoration(element, decoration, width, height) {
    const style = element.style;
    if (decoration.background?.color) style.backgroundColor = cssColor(decoration.background.color);
    else if (decoration.background?.gradient) style.backgroundImage = gradientCSS(decoration.background.gradient, width, height);
    if (decoration.cornerRadius !== undefined) { style.borderRadius = `${decoration.cornerRadius}px`; style.overflow = "hidden"; }
    if (decoration.clip !== undefined) {
      const path = { circle: "circle(closest-side at 50% 50%)", ellipse: "ellipse(50% 50% at 50% 50%)", capsule: "inset(0 round 9999px)" }[decoration.clip];
      if (path) style.clipPath = path; else style.overflow = "hidden";
    }
    if (decoration.opacity !== undefined) style.opacity = String(decoration.opacity);
    if (decoration.transform) style.transform = decoration.transform;
    if (decoration.filter) style.filter = decoration.filter;
    if (decoration.border) style.boxShadow = `inset 0 0 0 1px ${cssColor(decoration.border)}`;
    if (decoration.dashed) { style.border = "1px dashed rgba(127,127,127,0.8)"; style.boxSizing = "border-box"; }
  }

  // MARK: Widget container (ScriptWidgetWidgetElementRootView)

  try {
    const rootNode = build(root, "z", { isRoot: root.tag !== "Fragment" });
    const [w, h] = rootNode.size(size.width, size.height);
    rootNode.place((size.width - w) / 2, (size.height - h) / 2, w, h);
    const widget = doc.createElement("div");
    widget.className = "sw-widget";
    widget.setAttribute("role", "img");
    widget.setAttribute("aria-label", "Widget preview");
    Object.assign(widget.style, { position: "relative", width: `${size.width}px`, height: `${size.height}px`, overflow: "hidden", backgroundColor: cssColor(systemBackground[appearance]), colorScheme: appearance });
    const rootPaint = parsePaint(propReader(root.props).string("background"), appearance);
    if (rootPaint?.color) widget.style.backgroundColor = cssColor(rootPaint.color);
    else if (rootPaint?.gradient) widget.style.backgroundImage = gradientCSS(rootPaint.gradient, size.width, size.height);
    draw(rootNode, widget);
    return { element: widget, size, diagnostics };
  } finally {
    measurer.dispose();
  }
}
