import Foundation

/// Minimal BERT **uncased** WordPiece tokenizer for the bundled MiniLM model.
/// Matches HuggingFace `BertTokenizer(do_lower_case=True)`: clean → lowercase →
/// strip accents → split on whitespace and punctuation → greedy WordPiece.
struct BertTokenizer {
    private let vocab: [String: Int32]
    private let unkID: Int32
    let clsID: Int32
    let sepID: Int32
    let padID: Int32
    private let maxInputChars = 100

    init?(vocabURL: URL) {
        guard let text = try? String(contentsOf: vocabURL, encoding: .utf8) else { return nil }
        var v: [String: Int32] = [:]
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let tok = line.trimmingCharacters(in: .whitespaces)
            if !tok.isEmpty { v[tok] = Int32(i) }
        }
        guard let unk = v["[UNK]"], let cls = v["[CLS]"], let sep = v["[SEP]"], let pad = v["[PAD]"]
        else { return nil }
        vocab = v; unkID = unk; clsID = cls; sepID = sep; padID = pad
    }

    /// `input_ids` and `attention_mask` for `text`, padded / truncated to `maxLen`.
    func encode(_ text: String, maxLen: Int) -> (ids: [Int32], mask: [Int32]) {
        var pieces: [Int32] = [clsID]
        for basic in basicTokens(text) {
            for wp in wordPiece(basic) {
                if pieces.count >= maxLen - 1 { break }
                pieces.append(wp)
            }
        }
        pieces.append(sepID)
        let mask = [Int32](repeating: 1, count: pieces.count)
            + [Int32](repeating: 0, count: max(0, maxLen - pieces.count))
        let ids = pieces + [Int32](repeating: padID, count: max(0, maxLen - pieces.count))
        return (Array(ids.prefix(maxLen)), Array(mask.prefix(maxLen)))
    }

    // MARK: - basic tokenization

    private func basicTokens(_ text: String) -> [String] {
        let cleaned = text.unicodeScalars.filter { s in
            s != "\u{0}" && s != "\u{FFFD}" && !isControl(s)
        }
        let lowered = String(String.UnicodeScalarView(cleaned)).lowercased()
        let stripped = lowered.folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))

        var out: [String] = []
        var current = ""
        for scalar in stripped.unicodeScalars {
            if isWhitespace(scalar) {
                if !current.isEmpty { out.append(current); current = "" }
            } else if isPunctuation(scalar) {
                if !current.isEmpty { out.append(current); current = "" }
                out.append(String(scalar))
            } else {
                current.unicodeScalars.append(scalar)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    // MARK: - WordPiece

    private func wordPiece(_ token: String) -> [Int32] {
        let chars = Array(token)
        if chars.count > maxInputChars { return [unkID] }

        var ids: [Int32] = []
        var start = 0
        while start < chars.count {
            var end = chars.count
            var matched: Int32?
            while start < end {
                let sub = String(chars[start..<end])
                let candidate = start > 0 ? "##" + sub : sub
                if let id = vocab[candidate] { matched = id; break }
                end -= 1
            }
            guard let id = matched else { return [unkID] }
            ids.append(id)
            start = end
        }
        return ids.isEmpty ? [unkID] : ids
    }

    // MARK: - scalar classes (BERT's definitions)

    private func isWhitespace(_ s: Unicode.Scalar) -> Bool {
        s == " " || s == "\t" || s == "\n" || s == "\r" || s.properties.isWhitespace
    }
    private func isControl(_ s: Unicode.Scalar) -> Bool {
        if s == "\t" || s == "\n" || s == "\r" { return false }
        return s.properties.generalCategory == .control || s.properties.generalCategory == .format
    }
    private func isPunctuation(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        if (v >= 33 && v <= 47) || (v >= 58 && v <= 64) || (v >= 91 && v <= 96) || (v >= 123 && v <= 126) {
            return true
        }
        switch s.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }
}
