// Stand-in drawings for SF Symbols whose closest Lucide icon differs a lot in
// silhouette. They are original drawings built from simple primitives
// (rounded rectangles, circles, arcs, four-point stars) and sized from
// native renders mapped into the same 24-unit box the Lucide icons use
// (test/render/cases.json: symbol-* cases). Each entry returns SVG markup
// drawn in `currentColor`; `id` makes mask ids unique in the page.

const roundedRect = (x, y, w, h, r) =>
  `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;

/// A four-point star with concave sides.
const star = (cx, cy, r, pinch = 0.14) => {
  const k = r * pinch;
  return `M${cx} ${cy - r}Q${cx + k} ${cy - k} ${cx + r} ${cy}Q${cx + k} ${cy + k} ${cx} ${cy + r}Q${cx - k} ${cy + k} ${cx - r} ${cy}Q${cx - k} ${cy - k} ${cx} ${cy - r}Z`;
};

const ellipse = (cx, cy, rx, ry) => `M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}Z`;

/// Gap lines from (cx, cy) outward at the given angles (degrees).
const spokes = (cx, cy, r, angles) => angles.map((a) => `M${cx} ${cy}L${(cx + r * Math.cos(a * Math.PI / 180)).toFixed(2)} ${(cy + r * Math.sin(a * Math.PI / 180)).toFixed(2)}`).join("");

const dots = (cells) => cells.map(([x, y]) => `<rect x="${x}" y="${y}" width="1.5" height="1.4" rx="0.35"/>`).join("");

const calendarBody = (dy = 0) => `<path fill-rule="evenodd" d="${roundedRect(1.5, 2 + dy, 21, 19.6, 3.2)}${roundedRect(3, 7 + dy, 18, 13.1, 1.4)}"/>`
  + dots([[9.5, 9.6], [13, 9.6], [16.5, 9.6], [5.5, 13.1], [9.5, 13.1], [13, 13.1], [16.5, 13.1], [5.5, 16.6], [9.5, 16.6], [13, 16.6]].map(([x, y]) => [x, y + dy]));

/// Half sun on a ground line with side rays (sunrise / sunset), plus `arrow`.
const horizon = (arrow) => `<path d="${arrow}M4.4 8.8L6.6 11.1M19.6 8.8L17.4 11.1M0 17H3.3M20.7 17H24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>`
  + `<path d="M6.3 18.7A5.7 5.7 0 0 1 17.7 18.7Z${roundedRect(-1.5, 19.9, 27, 1.7, 0.85)}"/>`;

export const symbolShapes = Object.freeze({
  calendar: () => calendarBody(),
  "moon.stars.fill": () => `<path d="M9 5.5A9.3 9.3 0 1 0 20.5 17.5A9.33 9.33 0 0 1 9 5.5Z"/>`
    + `<path d="${star(15.2, 3.4, 2.3)}${star(21, 9.5, 4)}"/>`,
  "mosaic.fill": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/>`
    + `<path d="M15.5 0V24M0 14.75H24M15.5 8.25H24M8.25 14.75V24" stroke="black" stroke-width="0.95"/></mask></defs>`
    + `<path mask="url(#${id})" d="${roundedRect(2, 2, 19.3, 18.6, 3)}"/>`,
  sparkles: () => `<path d="${star(13.5, 15.6, 8.2)}${star(6.1, 8, 4.1)}${star(11.25, 2, 2.5)}"/>`,
  // Wider than the 24-unit box, like the symbol itself.
  "battery.100": () => `<path fill-rule="evenodd" d="${roundedRect(-3, 5, 27, 14.3, 4.3)}${roundedRect(-1.5, 6.6, 24, 11.1, 2.8)}"/>`
    + `<path d="${roundedRect(-0.8, 8, 21.8, 8.3, 1.5)}${roundedRect(26, 9.5, 1.3, 5, 0.65)}"/>`,
  timer: () => `<path d="M11.75 2A9.75 9.75 0 1 1 4.74 4.98" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>`
    + `<path d="M11.75 2V6.3" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/>`
    + `<path d="M12.87 12.33L6.96 6.18L6.64 6.42L11.13 13.67Z"/><circle cx="12" cy="13" r="1.1"/>`,
  checklist: (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="28" height="28"><rect x="-2" y="-2" width="28" height="28" fill="white"/>`
    + `<path d="M2.4 5.9L3.9 7.4L6.7 4.4" fill="none" stroke="black" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></mask></defs>`
    + `<circle mask="url(#${id})" cx="4.5" cy="5.75" r="4.25"/><circle cx="4.5" cy="14.75" r="3.5" fill="none" stroke="currentColor" stroke-width="1.5"/>`
    + `<path d="${roundedRect(11.5, 4.9, 12.5, 1.8, 0.9)}${roundedRect(11.5, 13.9, 12.5, 1.8, 0.9)}"/>`,
  "books.vertical.fill": () => `<path fill-rule="evenodd" d="${roundedRect(-1, 3, 4.5, 20, 1)}${roundedRect(5, 7, 6.5, 16.5, 1)}${roundedRect(7, 9.4, 3, 1, 0.3)}${roundedRect(7, 20, 3, 1, 0.3)}${roundedRect(13, 0, 5.5, 23, 1)}"/>`
    + `<path d="M19.8 3.3L22.8 3L24.8 23.4L21.6 23.6Z" stroke="currentColor" stroke-width="0.8" stroke-linejoin="round"/>`,
  // The screen is the symbol's secondary layer, drawn dimmed.
  desktopcomputer: () => `<path fill-rule="evenodd" d="${roundedRect(-1, 1.5, 25.5, 16.8, 2)}${roundedRect(0.6, 3, 22.4, 10.8, 0.6)}"/>`
    + `<path fill-opacity="0.35" d="${roundedRect(0.6, 3, 22.4, 10.8, 0.6)}"/>`
    + `<path d="M8.5 18H15V20.2H8.5Z${roundedRect(7.5, 20, 8.5, 1.8, 0.9)}"/>`,
  "banknote.fill": () => `<path fill-rule="evenodd" d="${roundedRect(-2.5, 3, 28.5, 17.5, 2.2)}${roundedRect(-1, 4.6, 25.5, 14.4, 1)}${roundedRect(0.5, 6.5, 23.5, 10.5, 0.5)}${ellipse(12.25, 12, 3.6, 5.2)}${ellipse(12.25, 12, 2.7, 4.1)}"/>`,
  "chart.pie.fill": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="28" height="28"><rect x="-2" y="-2" width="28" height="28" fill="white"/>`
    + `<path d="${spokes(11.75, 11.75, 13, [-90, 38])}" stroke="black" stroke-width="1.1"/><path d="${spokes(11.75, 11.75, 13, [-19])}" stroke="black" stroke-width="1.6"/></mask></defs>`
    + `<circle mask="url(#${id})" cx="11.75" cy="11.75" r="10.75"/>`,
  "fork.knife": () => `<path d="${roundedRect(4.6, -0.5, 1.5, 8.5, 0.75)}${roundedRect(7.4, -0.5, 1.5, 8.5, 0.75)}${roundedRect(10.4, -0.5, 1.5, 8.5, 0.75)}M4.6 7H11.9V7.6Q11.9 10 9.6 10.4H6.9Q4.6 10 4.6 7.6Z${roundedRect(7, 9, 2.5, 15, 1.25)}"/>`
    + `<path d="M18.5 -0.5Q19 -0.5 19 0.5V23Q19 24 18 24Q17 24 17 23V14.5L15.6 13.6Q15 13.3 15 12.5V7Q15 1.5 18.5 -0.5Z"/>`,
  "flame.fill": () => `<path fill-rule="evenodd" d="M5.6 0.5C9 0.5 20.5 7 20.5 14.5C20.5 20 16.5 23.5 11.5 23.5C6.5 23.5 3 20 3 15C3 11 4.8 8.5 5.8 6.8C6.3 7.8 7 7.9 7.2 7.2C7.8 4.5 6.5 2 5.6 0.5Z`
    + `M12.5 11.5C14.5 13.5 15.2 15 15.2 16.5C15.2 18.5 13.8 20 12 20C10.2 20 8.8 18.7 8.8 16.9C8.8 15.8 9.3 15 9.8 14.4C10.3 15 10.8 15 11.1 14.4C11.8 13.3 12.3 12.4 12.5 11.5Z"/>`,
  "cloud.rain.fill": () => `<circle cx="11.5" cy="7.5" r="8"/><circle cx="4.7" cy="11.2" r="4.4"/><circle cx="20" cy="10.3" r="5.2"/><rect x="4.7" y="9" width="15.3" height="6.5"/>`
    + `<path d="M6.4 16.2L5.1 18.8M11 16.2L9.7 18.8M15.8 16.2L14.5 18.8M20.5 16.2L19.2 18.8M8.6 20.3L7.6 22.5M17.6 20.3L16.6 22.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>`,
  "battery.100.bolt": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-6" y="-2" width="36" height="28"><rect x="-6" y="-2" width="36" height="28" fill="white"/>`
    + `<path d="M12.8 4.6L6.6 12.6H11L8.3 19.4L14.9 11.2H10.6Z" fill="black" stroke="black" stroke-width="2.6" stroke-linejoin="round"/></mask></defs>`
    + `<g mask="url(#${id})"><path fill-rule="evenodd" d="${roundedRect(-3, 5, 27, 14.3, 4.3)}${roundedRect(-1.5, 6.6, 24, 11.1, 2.8)}"/>`
    + `<path d="${roundedRect(-0.8, 8, 21.8, 8.3, 1.5)}${roundedRect(26, 9.5, 1.3, 5, 0.65)}"/></g>`
    + `<path d="M12.8 4.6L6.6 12.6H11L8.3 19.4L14.9 11.2H10.6Z" stroke="currentColor" stroke-width="0.6" stroke-linejoin="round"/>`,
  "quote.opening": () => `<path d="${ellipse(5.7, 14, 5.3, 4.7)}${ellipse(18.6, 14, 5.3, 4.7)}"/>`
    + `<path d="M1.6 12Q1.6 6.4 7.6 5.2M14.5 12Q14.5 6.4 20.5 5.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>`,
  "graduationcap.fill": () => `<path fill-rule="evenodd" d="M12 -1L26.5 6.5L12 13.5L-2.5 6.5Z${ellipse(12, 5.6, 3, 1)}" stroke="currentColor" stroke-width="0.8" stroke-linejoin="round"/>`
    + `<path d="M4.5 11.8L12 15.3L22.5 11.3V16.4Q14 19.8 6 19.2Q4.5 18.8 4.5 17.5Z"/>`
    + `<path d="M12 6.5L2 8.5V17" fill="none" stroke="currentColor" stroke-width="1"/><path d="${roundedRect(2.5, 19.6, 2.6, 4.2, 0.8)}"/>`,
  "bed.double.fill": () => `<path fill-rule="evenodd" d="${roundedRect(1, 3, 22, 7, 2.5)}${roundedRect(4.5, 6, 5, 4, 1)}${roundedRect(14.5, 6, 5, 4, 1)}"/>`
    + `<path d="${roundedRect(-1.5, 9, 27, 8.2, 2.2)}${roundedRect(-1.5, 15, 2, 4.5, 0.6)}${roundedRect(23.5, 15, 2, 4.5, 0.6)}"/>`,
  "suitcase.rolling.fill": () => `<path fill-rule="evenodd" d="${roundedRect(7.1, -2.5, 10.6, 8, 2.2)}${roundedRect(8.8, -0.9, 7.2, 8, 1)}"/>`
    + `<path d="${roundedRect(3.5, 4, 17, 19, 2.2)}${roundedRect(6, 22, 3, 3.2, 1.2)}${roundedRect(15.3, 22, 3, 3.2, 1.2)}"/>`,
  "figure.run": () => `<circle cx="14.6" cy="2.2" r="2.2"/>`
    + `<path d="M14 5.6L12.3 11.6" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>`
    + `<path d="M13 6.2L8.4 6.4L7 10.4M13.6 6.4L16.6 9L21 8.6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`
    + `<path d="M12.5 11.8L16.6 15.5L13.6 19M12.3 12L9.4 15.5L7.6 19.8L4 22.6" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>`,
  "calendar.badge.exclamationmark": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="32" height="28"><rect x="-2" y="-2" width="32" height="28" fill="white"/><circle cx="22" cy="16.5" r="6.4" fill="black"/></mask>`
    + `<mask id="${id}b" maskUnits="userSpaceOnUse" x="-2" y="-2" width="32" height="28"><rect x="-2" y="-2" width="32" height="28" fill="white"/><path d="M22 12.6V16.8" stroke="black" stroke-width="1.5" stroke-linecap="round"/><circle cx="22" cy="19.4" r="0.85" fill="black"/></mask></defs>`
    + `<g mask="url(#${id})">${calendarBody(-1.5)}</g><circle mask="url(#${id}b)" cx="22" cy="16.5" r="5"/>`,
  "video.fill": () => `<path d="${roundedRect(-0.5, 3, 18.5, 17.5, 3.2)}M19.5 9.6L24.3 5.3Q26 4.3 26 6.4V16.8Q26 18.6 24.3 17.6L19.5 13.7Z"/>`,
  "forward.fill": () => `<path d="M-1.5 5.3Q-1.5 3.7 0 4.6L12.4 11.1Q13.2 11.6 12.4 12.1L0 19.4Q-1.5 20.3 -1.5 18.7ZM13 5.3Q13 3.7 14.5 4.6L26.9 11.1Q27.7 11.6 26.9 12.1L14.5 19.4Q13 20.3 13 18.7Z"/>`,
  "backward.fill": () => `<path transform="translate(24 0) scale(-1 1)" d="M-1.5 5.3Q-1.5 3.7 0 4.6L12.4 11.1Q13.2 11.6 12.4 12.1L0 19.4Q-1.5 20.3 -1.5 18.7ZM13 5.3Q13 3.7 14.5 4.6L26.9 11.1Q27.7 11.6 26.9 12.1L14.5 19.4Q13 20.3 13 18.7Z"/>`,
  "house.fill": () => `<path d="M-0.3 11.2L10.6 1.6Q12 0.4 13.4 1.6L24.3 11.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`
    + `<path d="${roundedRect(19.3, 3.5, 2.3, 6.5, 0.4)}"/><path fill-rule="evenodd" d="M12 5L21 13V21.3Q21 23 19.3 23H4.2Q2.5 23 2.5 21.3V13Z${roundedRect(9.6, 14.6, 5.4, 7.4, 1.2)}"/>`,
  "briefcase.fill": () => `<path fill-rule="evenodd" d="${roundedRect(7, 1.5, 10.5, 6, 2)}${roundedRect(8.6, 3, 7.3, 6, 1)}"/>`
    + `<path d="${roundedRect(-0.5, 5.5, 25.5, 6.6, 2.4)}${roundedRect(-0.5, 13.6, 25.5, 8, 2.4)}"/>`,
  airplane: () => `<path d="${roundedRect(1, 9.9, 24, 3.4, 1.7)}M6.3 1.2L7.8 0.9L18.8 10H9.6ZM6.3 22L7.8 22.3L18.8 13.2H9.6ZM1 7H2.6L5.2 10.2H1ZM1 16.5H2.6L5.2 13H1Z"/>`,
  "sunrise.fill": () => horizon(`M12 7.5V1.5M8.6 4.4L12 1.1L15.4 4.4`),
  "sunset.fill": () => horizon(`M12 0.8V7.2M8.6 4.2L12 7.6L15.4 4.2`),
  "arrow.clockwise": () => `<path d="M14.63 5.39A9 9 0 1 0 21 13.2M11.2 0.8L15.3 4.8L11.4 9" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`,
  "figure.walk": () => `<circle cx="12" cy="1.6" r="2.2"/>`
    + `<path d="M11.5 4.8L11 12.4" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>`
    + `<path d="M10 5.8L6.3 9V12.4M12.4 7.2L14.6 9.4H19.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`
    + `<path d="M11.5 13L16 22.6M10.2 14.6L5.3 22.3" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>`,
  "chevron.left.forwardslash.chevron.right": () => `<path d="M5.2 5.2L-1.9 12L5.2 18.8M18.8 5.2L25.9 12L18.8 18.8M14.4 2.4L9.3 21.4" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>`,
  "chart.line.uptrend.xyaxis": () => `<path d="M1.5 2.3V21H20.8M2 12.4L6.8 8.6L12.8 13.6L18 8.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`
    + `<path d="M15.8 6.1L22.8 4.2L21 11Z" stroke="currentColor" stroke-width="0.8" stroke-linejoin="round"/>`,
  "cloud.fill": () => `<circle cx="11.5" cy="10.5" r="7"/><circle cx="19.5" cy="13.3" r="5.5"/><circle cx="4.3" cy="14.8" r="4.8"/><rect x="4.3" y="12" width="15.2" height="7.6"/>`,
  "bolt.fill": () => `<path d="M15 -0.2L4.8 13.6H11.6L8.2 24.2L19.2 10.1H12.4Z" stroke="currentColor" stroke-width="0.8" stroke-linejoin="round"/>`,
  "wand.and.stars": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="28" height="28"><rect x="-2" y="-2" width="28" height="28" fill="white"/><path d="M6.9 4.5L12 10" stroke="black" stroke-width="0.9" stroke-linecap="round"/></mask></defs>`
    + `<path mask="url(#${id})" d="M6.9 4.5L12 10" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round"/>`
    + `<path d="M12.6 10.6L21.2 21.2" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round"/>`
    + `<path d="${star(16, 4.5, 3)}${star(3.9, 14.5, 2.7)}${star(8.2, 18.5, 1.8)}"/>`,
  hourglass: () => `<path d="M6 2.6H18Q18.3 2.6 18 4L16.8 7.2H7.2L6 4Q5.7 2.6 6 2.6ZM12 12.4L17.4 16.9H6.6Z${roundedRect(5.6, 20.4, 12.8, 1.3, 0.6)}" stroke="currentColor" stroke-width="0.6" stroke-linejoin="round"/>`
    + `<path d="M7.6 7.4L11.6 12.6M16.4 7.4L12.4 12.6M8 16.6L5.9 20.4M16 16.6L18.1 20.4" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>`,
  magnifyingglass: () => `<circle cx="10" cy="9.5" r="7.5" fill="none" stroke="currentColor" stroke-width="2"/>`
    + `<path d="M15.6 15.4L21 20.9" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>`,
  "music.note": () => `<path d="M11 3.4L17 1.6Q18.6 1.2 18.6 2.8V6.4L11 8.6Z${roundedRect(11, 3, 1.5, 15.5, 0.5)}${ellipse(8.9, 19.6, 3.5, 2.7)}"/>`,
  "arrow.up.right": () => `<path d="M8 4.9H18.7V16.4M18.4 5.2L5 18.8" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`,
  "arrow.down.right": () => `<path d="M8 19.1H18.7V7.6M18.4 18.8L5 5.2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`,
  "leaf.fill": (id) => `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="28" height="28"><rect x="-2" y="-2" width="28" height="28" fill="white"/><path d="M6.8 5.8Q13 9.5 19.6 11.2" fill="none" stroke="black" stroke-width="1.1" stroke-linecap="round"/></mask></defs>`
    + `<path mask="url(#${id})" d="M0.6 2.5C10 2 20.5 3 21.4 9.5C22 15 18 19.8 12 19.8C6 19.8 2 15.5 1.2 9.5C0.9 7 0.6 4.5 0.6 2.5Z"/>`
    + `<path d="M19.4 14.8L22.6 21.2" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>`,
  "sun.max.fill": () => `<circle cx="12" cy="12" r="5.2"/><path d="M20.30 12.00L23.30 12.00M17.59 17.59L19.35 19.35M12.00 20.30L12.00 23.30M6.41 17.59L4.65 19.35M3.70 12.00L0.70 12.00M6.41 6.41L4.65 4.65M12.00 3.70L12.00 0.70M17.59 6.41L19.35 4.65" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>`,
  "face.smiling": () => `<circle cx="11.75" cy="11.75" r="10.1" fill="none" stroke="currentColor" stroke-width="1.8"/>`
    + `<path d="${ellipse(8.8, 8.9, 1.2, 1.6)}${ellipse(15.2, 8.9, 1.2, 1.6)}"/><path d="M7.9 14.2Q11.8 18.6 15.7 14.2" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>`,
});
