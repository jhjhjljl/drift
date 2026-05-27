import Foundation

/// Turns PDF line-per-row extraction into flowing paragraphs for reflow.
enum TextNormalizer {
    static func reflowableText(from raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")

        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var paragraphs: [String] = []
        var current: [String] = []

        for line in lines {
            if line.isEmpty {
                flush(&current, into: &paragraphs)
                continue
            }
            current.append(line)
        }

        flush(&current, into: &paragraphs)
        return paragraphs.joined(separator: "\n\n")
    }

    private static func flush(_ current: inout [String], into paragraphs: inout [String]) {
        guard !current.isEmpty else { return }
        let joined = current
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
        paragraphs.append(joined)
        current = []
    }
}
