// SwiftUI-style layout for the web renderer. Each node answers
// size(proposedWidth, proposedHeight) and is then placed at a final rect.
// Proposals follow SwiftUI: null = ideal size, 0 = minimum, Infinity =
// maximum, finite = offered space. Stacks distribute space to the least
// flexible children first, which is what makes text truncate and fixed
// content overflow the way it does on iPhone.

export const sub = (value, amount) => (value === null || value === Infinity ? value : Math.max(0, value - amount));
const snap = (value) => Math.ceil(value * 2 - 1e-6) / 2;

export class Node {
  constructor() { this.frame = { x: 0, y: 0, width: 0, height: 0 }; }
  size() { return [0, 0]; }
  place(x, y, width, height) { this.frame = { x, y, width, height }; }
  edge() { return null; }
}

/// Text: one line is the natural height; extra lines advance by `leading`.
export class TextNode extends Node {
  constructor(text, style, measurer) {
    super();
    this.text = text; this.style = style; this.measurer = measurer;
  }
  /// Like UIKit, a word wider than the line is hyphenated: it is split into
  /// the longest prefixes that fit with a trailing "-" instead of breaking
  /// at an arbitrary character. AppKit (style.hyphenate false) breaks such
  /// words between characters without a hyphen, as the browser does.
  displayText(width) {
    if (width === null || width === Infinity || width <= 0) return this.text;
    const key = `${width}`;
    this.hyphenated ??= new Map();
    if (this.hyphenated.has(key)) return this.hyphenated.get(key);
    if (this.style.hyphenate === false) {
      const result = this.text.split("\n").map((paragraph) => this.pushOut(paragraph, width)).join("\n");
      this.hyphenated.set(key, result);
      return result;
    }
    const fits = (piece) => this.measurer.measure(piece, this.style, null).width <= width + 0.01;
    const result = this.text.replace(/\S+/g, (word) => {
      if (fits(word) || [...word].length < 4) return word;
      const characters = [...word];
      const pieces = [];
      let start = 0;
      while (start < characters.length) {
        const rest = characters.slice(start).join("");
        if (fits(rest)) { pieces.push(rest); break; }
        let end = start + 1;
        while (end < characters.length && fits(`${characters.slice(start, end + 1).join("")}-`)) end += 1;
        // Like iOS, carry at least three letters to the next line.
        if (characters.length - end < 3) end = Math.max(start + 1, characters.length - 3);
        pieces.push(`${characters.slice(start, end).join("")}-`);
        start = end;
      }
      return pieces.join("\n");
    });
    this.hyphenated.set(key, result);
    return result;
  }
  /// AppKit's standard line break strategy pushes a word down so that the
  /// last line of a paragraph is not a single short word ("October /
  /// 18, 2026").
  /// Breaks before punctuation are not allowed (UAX #14), so "Size :" stays
  /// together. Paragraphs with a word wider than the line are left alone.
  pushOut(paragraph, width) {
    const words = paragraph.split(/ +/).filter(Boolean).reduce((tokens, word) => {
      if (tokens.length && /^[:;,.!?)\]}%]/.test(word)) tokens[tokens.length - 1] += ` ${word}`;
      else tokens.push(word);
      return tokens;
    }, []);
    const fits = (line) => this.measurer.measure(line.join(" "), this.style, null).width <= width + 0.01;
    if (words.length < 3 || fits(words) || !words.every((word) => fits([word]))) return paragraph;
    const lines = [[]];
    for (const word of words) {
      const line = lines.at(-1);
      if (!line.length || fits([...line, word])) line.push(word); else lines.push([word]);
    }
    const last = lines.at(-1); const previous = lines.at(-2);
    if (lines.length < 2 || last.length !== 1 || previous.length < 2) return paragraph;
    // Only a short orphan is pushed out: "Hello from / GitHub" stays.
    if (this.measurer.measure(last[0], this.style, null).width >= width * 0.5) return paragraph;
    const moved = [previous.at(-1), ...last];
    if (!fits(moved)) return paragraph;
    lines.splice(-2, 2, previous.slice(0, -1), moved);
    return lines.map((line) => line.join(" ")).join("\n");
  }
  /// AppKit keeps breaking a word one character per line in a column
  /// narrower than "…" as long as its first character fits.
  wrapsCharacters(width) {
    if (this.style.hyphenate !== false) return false;
    const first = [...this.text.trim()][0];
    return first !== undefined && this.measurer.measure(first, this.style, null).width <= width + 0.01;
  }
  metrics(width) { return this.measurer.measure(width === null ? this.text : this.displayText(width), this.style, width); }
  layout(pw, ph) {
    const { natural, leading } = this.style;
    if (this.text === "") return { width: 0, height: 0, lines: 0, total: 0 };
    let width; let lines;
    if (pw === null || pw === Infinity) { const m = this.metrics(null); width = m.width; lines = m.lines; }
    else if (pw < this.measurer.ellipsisWidth(this.style) && !this.wrapsCharacters(pw)) { width = this.measurer.ellipsisWidth(this.style); lines = 1; }
    else {
      // Offered at least the natural width: keep the unwrapped layout rather
      // than re-measuring at an explicit width, which can wrap on sub-pixel
      // differences.
      const free = this.metrics(null);
      if (pw >= free.width - 0.01) { width = free.width; lines = free.lines; }
      else { const m = this.metrics(pw); width = Math.min(pw, m.width); lines = m.lines; }
    }
    const total = lines;
    if (ph !== null && ph !== Infinity) lines = Math.min(lines, Math.max(1, Math.floor((ph - natural) / leading + 1e-6) + 1));
    // Truncated text reports the whole offered width.
    if (lines < total && pw !== null && pw !== Infinity) width = Math.max(width, pw);
    return { width: snap(width), height: natural + (lines - 1) * leading, lines, total };
  }
  size(pw, ph) { const { width, height } = this.layout(pw, ph); return [width, height]; }
  place(x, y, width, height) { super.place(x, y, width, height); this.lines = this.layout(width, height); }
  edge() { return this.style; }
}

/// Shapes, colors, and resizable images take whatever they are offered.
export class FlexibleNode extends Node {
  constructor(ideal = [10, 10]) { super(); this.ideal = ideal; }
  size(pw, ph) { return [pw ?? this.ideal[0], ph ?? this.ideal[1]]; }
}

/// Fixed intrinsic size (non-resizable images, glyphs, fixed controls).
export class FixedNode extends Node {
  constructor(width, height) { super(); this.width = width; this.height = height; }
  size() { return [this.width, this.height]; }
}

/// Spacer: flexible along its stack axis with a minimum length, empty across.
export class SpacerNode extends Node {
  constructor(axis, minLength = 8) { super(); this.axis = axis; this.minLength = minLength; this.isSpacer = true; }
  size(pw, ph) {
    const along = (proposal) => (proposal === null ? this.minLength : Math.max(this.minLength, proposal));
    if (this.axis === "h") return [along(pw), 0];
    if (this.axis === "v") return [0, along(ph)];
    return [along(pw), along(ph)];
  }
}

/// Image with aspectRatio(ratio, contentMode) inside its proposal.
export class AspectNode extends Node {
  constructor(natural, ratio, mode) { super(); this.natural = natural; this.ratio = ratio ?? natural[0] / Math.max(natural[1], 1e-9); this.mode = mode; }
  size(pw, ph) {
    if (pw === null && ph === null) return this.natural;
    const w = pw ?? (ph === null || ph === Infinity ? this.natural[0] : ph * this.ratio);
    const h = ph ?? (pw === null || pw === Infinity ? this.natural[1] : pw / this.ratio);
    if (w === Infinity || h === Infinity) return [w === Infinity ? (h === Infinity ? Infinity : h * this.ratio) : w, h === Infinity ? (w === Infinity ? Infinity : w / this.ratio) : h];
    const fitWidth = Math.min(w, h * this.ratio);
    const fillWidth = Math.max(w, h * this.ratio);
    const width = this.mode === "fill" ? fillWidth : fitWidth;
    return [width, width / this.ratio];
  }
}

export class PaddingNode extends Node {
  constructor(child, [top, trailing, bottom, leading]) { super(); this.child = child; this.insets = { top, trailing, bottom, leading }; }
  size(pw, ph) {
    const { top, trailing, bottom, leading } = this.insets;
    const [w, h] = this.child.size(sub(pw, leading + trailing), sub(ph, top + bottom));
    return [w + leading + trailing, h + top + bottom];
  }
  place(x, y, width, height) {
    super.place(x, y, width, height);
    const { top, trailing, bottom, leading } = this.insets;
    const innerW = Math.max(0, width - leading - trailing); const innerH = Math.max(0, height - top - bottom);
    const [w, h] = this.child.size(innerW, innerH);
    this.child.place(leading + (innerW - w) / 2, top + (innerH - h) / 2, w, h);
  }
}

const alignOffset = (space, size, where) => (where === "start" ? 0 : where === "end" ? space - size : (space - size) / 2);

/// frame(width:height:alignment:) and frame(maxWidth: .infinity, ...).
export class FrameNode extends Node {
  constructor(child, { mode, width, height, alignment }) { super(); this.child = child; this.mode = mode; this.width = width; this.height = height; this.alignment = alignment; }
  size(pw, ph) {
    if (this.mode === "max") {
      const [cw, ch] = this.child.size(pw, ph);
      return [pw === null ? cw : pw, ph === null ? ch : ph];
    }
    const fixedW = this.mode === "size" || this.mode === "width" ? this.width : null;
    const fixedH = this.mode === "size" || this.mode === "height" ? this.height : null;
    const [cw, ch] = this.child.size(fixedW ?? pw, fixedH ?? ph);
    return [fixedW ?? cw, fixedH ?? ch];
  }
  place(x, y, width, height) {
    super.place(x, y, width, height);
    const [w, h] = this.child.size(width, height);
    const [horizontal, vertical] = this.alignment;
    this.child.place(alignOffset(width, w, horizontal), alignOffset(height, h, vertical), w, h);
  }
}

/// Background, corner radius, clipping, opacity, transforms, shadow: same
/// size as the content.
export class DecorationNode extends Node {
  constructor(child, decoration) { super(); this.child = child; this.decoration = decoration; }
  size(pw, ph) { return this.child.size(pw, ph); }
  place(x, y, width, height) { super.place(x, y, width, height); this.child.place(0, 0, width, height); }
  edge(side) { return this.decoration.keepsEdges ? this.child.edge(side) : null; }
}

/// HStack / VStack.
export class StackNode extends Node {
  constructor(axis, children, { alignment, spacing }) {
    super();
    this.axis = axis; this.children = children; this.alignment = alignment;
    this.spacing = children.map((child, index) => (index === 0 ? 0 : spacing(children[index - 1], child)));
  }
  along(size) { return this.axis === "h" ? size[0] : size[1]; }
  cross(size) { return this.axis === "h" ? size[1] : size[0]; }
  propose(child, along, cross) { return this.axis === "h" ? child.size(along, cross) : child.size(cross, along); }
  // Spacers only take what is left: reserve their minimum lengths, share the
  // rest among the other children (least flexible first), then split the
  // leftover between spacers.
  allocate(pAlong, pCross) {
    const gaps = this.spacing.reduce((sum, value) => sum + value, 0);
    if (pAlong === null || pAlong === Infinity) return this.children.map((child) => this.propose(child, pAlong, pCross));
    const spacers = this.children.map((child) => child.isSpacer === true);
    const reserved = this.children.reduce((sum, child, index) => sum + (spacers[index] ? child.minLength : 0), 0);
    const order = this.children.map((child, index) => ({ child, index })).filter(({ index }) => !spacers[index]).map(({ child, index }) => {
      const min = this.along(this.propose(child, 0, pCross));
      const max = this.along(this.propose(child, Infinity, pCross));
      return { index, flexibility: max - min };
    }).sort((a, b) => a.flexibility - b.flexibility || a.index - b.index);
    let remaining = pAlong - gaps - reserved;
    let count = order.length;
    const sizes = new Array(this.children.length);
    for (const { index } of order) {
      const offer = Math.max(0, remaining / count);
      sizes[index] = this.propose(this.children[index], offer, pCross);
      remaining -= this.along(sizes[index]);
      count -= 1;
    }
    const spacerCount = spacers.filter(Boolean).length;
    const leftover = Math.max(0, remaining + reserved);
    this.children.forEach((child, index) => {
      if (spacers[index]) sizes[index] = this.propose(child, Math.max(child.minLength, leftover / spacerCount), pCross);
    });
    return sizes;
  }
  size(pw, ph) {
    const pAlong = this.axis === "h" ? pw : ph; const pCross = this.axis === "h" ? ph : pw;
    const sizes = this.allocate(pAlong, pCross);
    const along = sizes.reduce((sum, size) => sum + this.along(size), 0) + this.spacing.reduce((sum, value) => sum + value, 0);
    const cross = sizes.reduce((max, size) => Math.max(max, this.cross(size)), 0);
    return this.axis === "h" ? [along, cross] : [cross, along];
  }
  place(x, y, width, height) {
    super.place(x, y, width, height);
    const pAlong = this.axis === "h" ? width : height; const pCross = this.axis === "h" ? height : width;
    const sizes = this.allocate(pAlong, pCross);
    let cursor = 0;
    this.children.forEach((child, index) => {
      cursor += this.spacing[index];
      const size = sizes[index];
      const offset = alignOffset(pCross, this.cross(size), this.alignment);
      if (this.axis === "h") child.place(cursor, offset, size[0], size[1]);
      else child.place(offset, cursor, size[0], size[1]);
      cursor += this.along(size);
    });
  }
  // Spacing preferences: a VStack exposes its first/last child; an HStack
  // merges its children (the largest text edge wins).
  edge(side) {
    if (this.children.length === 0) return null;
    if (this.axis === "v") return side === "top" ? this.children[0].edge("top") : this.children.at(-1).edge("bottom");
    return mergedEdge(this.children, side);
  }
}

function mergedEdge(children, side) {
  return children.map((child) => child.edge(side)).filter(Boolean).reduce((best, edge) => (!best || edge.size > best.size ? edge : best), null);
}

export class ZStackNode extends Node {
  constructor(children) { super(); this.children = children; }
  edge(side) { return mergedEdge(this.children, side); }
  size(pw, ph) {
    return this.children.map((child) => child.size(pw, ph)).reduce(([w, h], [cw, ch]) => [Math.max(w, cw), Math.max(h, ch)], [0, 0]);
  }
  place(x, y, width, height) {
    super.place(x, y, width, height);
    for (const child of this.children) {
      const [w, h] = child.size(width, height);
      child.place((width - w) / 2, (height - h) / 2, w, h);
    }
  }
}

/// LazyVGrid / LazyHGrid: columns (or rows) from fixed, flexible, and
/// adaptive items; cells are centered and lines take their tallest cell.
export class GridNode extends Node {
  constructor(axis, children, { items, spacing, alignment }) {
    super();
    this.axis = axis; this.children = children; this.items = items; this.spacing = spacing; this.alignment = alignment;
  }
  tracks(available) {
    const spacing = this.spacing;
    const fixed = this.items.filter((item) => item.type === "fixed").reduce((sum, item) => sum + item.value, 0);
    const flexibleCount = this.items.filter((item) => item.type !== "fixed").length;
    const free = Math.max(0, available - fixed - spacing * Math.max(0, this.items.length - 1));
    const tracks = [];
    for (const item of this.items) {
      if (item.type === "fixed") tracks.push(item.value);
      else if (item.type === "adaptive") {
        const share = flexibleCount ? free / flexibleCount : free;
        const count = Math.max(1, Math.floor((share + spacing) / (item.min + spacing)));
        const size = Math.min(item.max ?? Infinity, (share - spacing * (count - 1)) / count);
        for (let index = 0; index < count; index += 1) tracks.push(Math.max(item.min, size));
      } else tracks.push(flexibleCount ? free / flexibleCount : free);
    }
    return tracks;
  }
  arrange(pAlong) {
    const available = pAlong === null || pAlong === Infinity ? this.items.length * 60 : pAlong;
    const tracks = this.tracks(available);
    const lines = [];
    this.children.forEach((child, index) => {
      const line = Math.floor(index / tracks.length);
      const track = index % tracks.length;
      const size = this.axis === "v" ? child.size(tracks[track], null) : child.size(null, tracks[track]);
      (lines[line] ??= []).push({ child, track, size });
    });
    const extents = lines.map((line) => Math.max(...line.map(({ size }) => (this.axis === "v" ? size[1] : size[0]))));
    return { tracks, lines, extents };
  }
  size(pw, ph) {
    const { tracks, extents } = this.arrange(this.axis === "v" ? pw : ph);
    const along = tracks.reduce((sum, value) => sum + value, 0) + this.spacing * Math.max(0, tracks.length - 1);
    const cross = extents.reduce((sum, value) => sum + value, 0) + this.spacing * Math.max(0, extents.length - 1);
    const width = this.axis === "v" ? (pw === null || pw === Infinity ? along : pw) : cross;
    const height = this.axis === "v" ? cross : (ph === null || ph === Infinity ? along : ph);
    return [width, height];
  }
  place(x, y, width, height) {
    super.place(x, y, width, height);
    const { tracks, lines, extents } = this.arrange(this.axis === "v" ? width : height);
    const total = tracks.reduce((sum, value) => sum + value, 0) + this.spacing * Math.max(0, tracks.length - 1);
    const start = ((this.axis === "v" ? width : height) - total) / 2;
    let lineOffset = 0;
    lines.forEach((line, lineIndex) => {
      for (const { child, track, size } of line) {
        const trackOffset = start + tracks.slice(0, track).reduce((sum, value) => sum + value, 0) + this.spacing * track;
        if (this.axis === "v") child.place(trackOffset + (tracks[track] - size[0]) / 2, lineOffset + (extents[lineIndex] - size[1]) / 2, size[0], size[1]);
        else child.place(lineOffset + (extents[lineIndex] - size[0]) / 2, trackOffset + (tracks[track] - size[1]) / 2, size[0], size[1]);
      }
      lineOffset += extents[lineIndex] + this.spacing;
    });
  }
}

/// Measures text with the browser's line breaker. Results are cached.
export function createTextMeasurer(doc) {
  const host = doc.createElement("div");
  Object.assign(host.style, { position: "absolute", left: "-100000px", top: "0", visibility: "hidden", contain: "layout style" });
  const probe = doc.createElement("div");
  probe.style.whiteSpace = "pre-wrap";
  probe.style.overflowWrap = "break-word";
  host.appendChild(probe);
  doc.body.appendChild(host);
  const cache = new Map();
  const apply = (style) => {
    probe.style.fontFamily = style.family; probe.style.fontSize = `${style.size}px`;
    probe.style.fontWeight = String(style.weight); probe.style.lineHeight = `${style.leading}px`;
  };
  const measure = (text, style, width) => {
    const key = `${style.key}|${width}|${text}`;
    if (cache.has(key)) return cache.get(key);
    apply(style);
    probe.style.width = width === null ? "max-content" : `${width}px`;
    probe.textContent = text;
    const range = doc.createRange();
    range.selectNodeContents(probe);
    const rects = [...range.getClientRects()].filter((rect) => rect.width > 0 || rect.height > 0);
    const measuredWidth = rects.length ? Math.max(...rects.map((rect) => rect.right)) - Math.min(...rects.map((rect) => rect.left)) : 0;
    const lines = Math.max(1, Math.round(probe.getBoundingClientRect().height / style.leading));
    const result = { width: measuredWidth, lines };
    cache.set(key, result);
    return result;
  };
  return {
    measure,
    ellipsisWidth: (style) => measure("…", style, null).width,
    dispose() { host.remove(); },
  };
}
