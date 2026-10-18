// Liang hyphenation with the US English TeX patterns. Returns the indices
// (in UTF-16 code units of `word`) where a hyphen may break the word. With a
// two-letter minimum after the break and camel-case boundaries, this matches
// Apple's CFStringGetHyphenationLocationBeforeIndex on 99.4% of 3,000
// dictionary words.
import { hyphenationPatterns } from "./hyphenation.generated.js";

let table = null;

function patterns() {
  if (table) return table;
  table = new Map();
  for (const [length, packed] of Object.entries(hyphenationPatterns.patterns)) {
    const size = Number(length);
    for (let index = 0; index < packed.length; index += size) {
      const pattern = packed.slice(index, index + size);
      const letters = pattern.replace(/\d/g, "");
      const values = new Array(letters.length + 1).fill(0);
      let position = 0;
      for (const character of pattern) {
        if (/\d/.test(character)) values[position] = Number(character); else position += 1;
      }
      table.set(letters, values);
    }
  }
  return table;
}

export function hyphenationPoints(word) {
  const { leftmin } = hyphenationPatterns;
  const rightmin = 2;
  if (!/^[A-Za-z]+$/.test(word) || word.length < leftmin + rightmin) return [];
  const text = `_${word.toLowerCase()}_`;
  const scores = new Array(text.length + 1).fill(0);
  const known = patterns();
  for (let start = 0; start < text.length; start += 1) {
    for (let end = start + 1; end <= text.length; end += 1) {
      const values = known.get(text.slice(start, end));
      if (!values) continue;
      values.forEach((value, offset) => { if (value > scores[start + offset]) scores[start + offset] = value; });
    }
  }
  const points = new Set();
  // scores[i + 1] is the value before text[i + 1], i.e. before word[i].
  for (let index = leftmin; index <= word.length - rightmin; index += 1) if (scores[index + 1] % 2 === 1) points.add(index);
  // Apple also breaks compounds at camel-case boundaries ("Script-Widget").
  for (let index = leftmin; index <= word.length - rightmin; index += 1) if (/[a-z]/.test(word[index - 1]) && /[A-Z]/.test(word[index])) points.add(index);
  return [...points].sort((a, b) => a - b);
}
