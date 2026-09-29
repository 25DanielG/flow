import Foundation

// catches a few words turning into a paragraph ("Yeah." -> made up email talk once)
public enum HallucinationGuard {
    public static func looksFabricated(raw: String, final: String) -> Bool {
        let rawWordCount = wordCount(raw)
        guard rawWordCount > 0, rawWordCount <= 6 else {
            return false
        }
        let finalWordCount = wordCount(final)
        return finalWordCount > rawWordCount * 4 + 5
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
