// Checks the web engine's push-out rule (Web/preview-engine/src/render/
// layout.js, TextNode.pushOut) against TextKit's .standard line break
// strategy over many texts, font sizes, weights, and widths.
//
//   swiftc -O -parse-as-library -o /tmp/line-break-sweep Tools/ScriptWidgetPreview/Scripts/line-break-sweep.swift
//   /tmp/line-break-sweep
import AppKit

func lines(_ text: String, font: NSFont, width: CGFloat, strategy: NSParagraphStyle.LineBreakStrategy) -> [String] {
    let style = NSMutableParagraphStyle()
    style.lineBreakStrategy = strategy
    let storage = NSTextStorage(string: text, attributes: [.font: font, .paragraphStyle: style])
    let manager = NSLayoutManager()
    storage.addLayoutManager(manager)
    let container = NSTextContainer(size: CGSize(width: width, height: 10_000))
    container.lineFragmentPadding = 0
    manager.addTextContainer(container)
    var result: [String] = []
    var index = 0
    while index < manager.numberOfGlyphs {
        var range = NSRange()
        manager.lineFragmentRect(forGlyphAt: index, effectiveRange: &range)
        let characters = manager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
        result.append((text as NSString).substring(with: characters).trimmingCharacters(in: .whitespaces))
        index = NSMaxRange(range)
    }
    return result
}

func measure(_ text: String, _ font: NSFont) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }

/// Break units: no break before closing punctuation (UAX #14).
func units(_ line: String) -> [String] {
    var result: [String] = []
    for word in line.split(separator: " ").map(String.init) {
        if let last = result.last, let first = word.first, ":;,.!?)]}%".contains(first) { result[result.count - 1] = last + " " + word }
        else { result.append(word) }
    }
    return result
}

/// The web rule, applied to the greedy (no strategy) lines.
func pushOut(_ greedy: [String], font: NSFont, width: CGFloat) -> [String] {
    guard greedy.count == 2, !greedy[1].contains(" ") else { return greedy }
    let first = units(greedy[0]), last = units(greedy[1])
    guard last.count == 1, first.count >= 2 else { return greedy }
    let moved = first.last! + " " + last[0]
    let rest = first.dropLast().joined(separator: " ")
    guard measure(moved, font) <= width, measure(rest, font) >= measure(moved, font) * 0.55 else { return greedy }
    return [rest, moved]
}

@main
struct LineBreakSweep {
    static func main() {
        let texts = [
            "58° · Light rain", "Widget Size : small", "October 18, 2026", "Choose one meaningful priority.",
            "Centered multiline caption text that wraps too", "Hello from GitHub", "Make today count", "one two three four five six",
            "The quick brown fox jumps over the lazy dog", "Daily affirmation for a calm day", "Battery level is low",
            "Remaining budget this month", "Plan your week with focus", "A long headline that will wrap across lines",
            "Go to the store and buy milk eggs bread", "Edit me in Studio · small", "Rain · 58° today", "Meeting at noon · Room 4",
            "Steps · 8,400 today · great", "Plan • Do • Review it", "Hello world · ok",
        ]
        var cases = 0, pushes = 0, mismatches = 0
        for text in texts {
            for size in [11.0, 13, 15, 17, 22, 28] as [CGFloat] {
                for weight in [NSFont.Weight.regular, .bold] {
                    let font = NSFont.systemFont(ofSize: size, weight: weight)
                    for width in stride(from: 40.0, through: 330.0, by: 3.0) {
                        let greedy = lines(text, font: font, width: width, strategy: [])
                        // Words wider than the line hyphenate or break instead.
                        if greedy.contains(where: { measure($0, font) > width + 0.5 }) { continue }
                        let standard = lines(text, font: font, width: width, strategy: .standard)
                        cases += 1
                        if standard != greedy { pushes += 1 }
                        if pushOut(greedy, font: font, width: width) != standard { mismatches += 1 }
                    }
                }
            }
        }
        print("cases \(cases), TextKit pushes \(pushes), rule mismatches \(mismatches)")
    }
}
