#if os(iOS)
import Foundation

/// A separate image-model description, never a replacement for accepted
/// MathCAT speech or evidence that a withheld expression passed validation.
struct FormulaFallbackDescription: Codable, Sendable {
    let policy: String
    let provider: String
    let status: String
    let description: String
    let visibleNotation: String
    let uncertainties: [String]
    let artifacts: [String:String]

    var readerText: String? {
        guard status != "not_math", status != "invalid_output" else { return nil }
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        let notation = visibleNotation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notation.isEmpty else { return nil }
        let verbalized = FormulaSpeechVerbalizer.verbalize(notation)
        return verbalized.isEmpty ? nil : verbalized
    }
}

/// Multi-tier Indonesian formula fallback resolver & LaTeX/symbol verbalizer.
enum FormulaSpeechVerbalizer {
    /// Resolves the best Indonesian reading for a formula across 4 tiers:
    /// 1. Primary MathCAT Indonesian speech (`spokenText`)
    /// 2. Apple Foundation Models Vision fallback description (`fallbackText`)
    /// 3. Spoken candidate or Indonesian verbalization of LaTeX / OCR (`spokenCandidate`, `latex`, `sourceText`)
    /// 4. Returns `nil` if all sources are empty (silent skip for false-positive detections)
    static func resolve(
        spokenText: String?,
        fallbackText: String?,
        spokenCandidate: String?,
        latex: String?,
        sourceText: String?
    ) -> String? {
        if let primary = cleaned(spokenText) {
            return primary
        }
        if let fallback = cleaned(fallbackText) {
            return fallback
        }
        if let candidate = cleaned(spokenCandidate) {
            return candidate
        }
        if let rawLatex = cleaned(latex) {
            let verbalized = verbalize(rawLatex)
            if !verbalized.isEmpty { return verbalized }
        }
        if let rawSource = cleaned(sourceText) {
            let verbalized = verbalize(rawSource)
            if !verbalized.isEmpty { return verbalized }
        }
        return nil
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Converts raw LaTeX or Unicode mathematical notation into natural Indonesian speech for VoiceOver/TTS.
    static func verbalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        // 1. Strip math mode delimiters and layout/sizing commands
        for delimiter in ["$$", "\\[", "\\]", "\\(", "\\)"] {
            text = text.replacingOccurrences(of: delimiter, with: " ")
        }
        if text.hasPrefix("$") && text.hasSuffix("$") && text.count >= 2 {
            text = String(text.dropFirst().dropLast())
        }
        text = replaceRegex(#"\\(?:begin|end)\s*\{[^}]*\}"#, in: text, with: " ")
        text = replaceRegex(#"\\(?:displaystyle|textstyle|scriptstyle|scriptscriptstyle|left|right|bigl|bigr|Bigl|Bigr|biggl|biggr|Biggl|Biggr|big|Big|bigg|Bigg|limits|nolimits)\b"#, in: text, with: " ")
        for spaceCmd in ["\\quad", "\\qquad", "\\,", "\\;", "\\:", "\\!", "\\ ", "~", "\\\\", "&"] {
            text = text.replacingOccurrences(of: spaceCmd, with: " ")
        }

        // 2. Expand structural LaTeX constructs (fractions, roots, wrappers, scripts)
        text = expandStructures(text, depth: 0)

        // 3. Expand Unicode superscripts and subscripts
        text = expandUnicodeScripts(text)

        // 4. Replace LaTeX commands and Unicode symbols with Indonesian readings
        for (pattern, replacement) in commandReplacements {
            text = replaceRegex(pattern, in: text, with: replacement)
        }
        for (symbol, replacement) in symbolReplacements {
            text = text.replacingOccurrences(of: symbol, with: replacement)
        }

        // 5. Strip any remaining LaTeX command backslashes and stray braces
        text = replaceRegex(#"\\([A-Za-z]+)"#, in: text, with: " $1 ")
        text = text.replacingOccurrences(of: "{", with: " ")
        text = text.replacingOccurrences(of: "}", with: " ")
        text = text.replacingOccurrences(of: "\\", with: " ")

        // 6. Collapse whitespace
        text = replaceRegex(#"\s+"#, in: text, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    private static func expandStructures(_ input: String, depth: Int) -> String {
        guard depth < 12 else { return input }
        var result = ""
        var index = input.startIndex

        while index < input.endIndex {
            // Handle superscripts ^
            if input[index] == "^" {
                let next = input.index(after: index)
                let skipped = skipWhitespace(in: input, from: next)
                if let group = extractBraceGroup(in: input, from: skipped) {
                    let inner = group.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if ["\\circ", "°", "º"].contains(inner) {
                        result += " derajat "
                    } else if ["\\prime", "'", "′"].contains(inner) {
                        result += " aksen "
                    } else {
                        let expanded = expandStructures(inner, depth: depth + 1)
                        if !expanded.isEmpty { result += " pangkat \(expanded) " }
                    }
                    index = group.afterIndex
                    continue
                } else if input[skipped...].hasPrefix("\\circ") {
                    result += " derajat "
                    index = input.index(skipped, offsetBy: 5)
                    continue
                } else if input[skipped...].hasPrefix("\\prime") {
                    result += " aksen "
                    index = input.index(skipped, offsetBy: 6)
                    continue
                } else if let token = extractSimpleScriptToken(in: input, from: skipped) {
                    result += " pangkat \(token.text) "
                    index = token.afterIndex
                    continue
                }
            }

            // Handle subscripts _
            if input[index] == "_" {
                let next = input.index(after: index)
                let skipped = skipWhitespace(in: input, from: next)
                if let group = extractBraceGroup(in: input, from: skipped) {
                    let inner = expandStructures(group.content, depth: depth + 1)
                    if !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result += " indeks \(inner) "
                    }
                    index = group.afterIndex
                    continue
                } else if let token = extractSimpleScriptToken(in: input, from: skipped) {
                    result += " indeks \(token.text) "
                    index = token.afterIndex
                    continue
                }
            }

            // Handle LaTeX structural commands starting with \
            if input[index] == "\\" {
                let cmdStart = input.index(after: index)
                var cmdEnd = cmdStart
                while cmdEnd < input.endIndex && input[cmdEnd].isLetter {
                    cmdEnd = input.index(after: cmdEnd)
                }
                let cmd = String(input[cmdStart..<cmdEnd])
                let afterCmd = skipWhitespace(in: input, from: cmdEnd)

                if ["frac", "dfrac", "tfrac", "cfrac"].contains(cmd),
                   let num = extractBraceGroup(in: input, from: afterCmd),
                   let den = extractBraceGroup(in: input, from: skipWhitespace(in: input, from: num.afterIndex)) {
                    let numText = expandStructures(num.content, depth: depth + 1)
                    let denText = expandStructures(den.content, depth: depth + 1)
                    result += " \(numText) per \(denText) "
                    index = den.afterIndex
                    continue
                }

                if cmd == "sqrt" {
                    var cursor = afterCmd
                    var rootDegree: String?
                    if let bracket = extractBracketGroup(in: input, from: cursor) {
                        rootDegree = expandStructures(bracket.content, depth: depth + 1)
                        cursor = skipWhitespace(in: input, from: bracket.afterIndex)
                    }
                    if let radicand = extractBraceGroup(in: input, from: cursor) {
                        let radText = expandStructures(radicand.content, depth: depth + 1)
                        if let degree = rootDegree?.trimmingCharacters(in: .whitespacesAndNewlines), !degree.isEmpty {
                            result += " akar pangkat \(degree) dari \(radText) "
                        } else {
                            result += " akar \(radText) "
                        }
                        index = radicand.afterIndex
                        continue
                    }
                }

                if ["vec", "overrightarrow"].contains(cmd),
                   let arg = extractBraceGroup(in: input, from: afterCmd) {
                    result += " vektor \(expandStructures(arg.content, depth: depth + 1)) "
                    index = arg.afterIndex
                    continue
                }

                if ["overline", "bar"].contains(cmd),
                   let arg = extractBraceGroup(in: input, from: afterCmd) {
                    result += " \(expandStructures(arg.content, depth: depth + 1)) bar "
                    index = arg.afterIndex
                    continue
                }

                if ["hat", "widehat"].contains(cmd),
                   let arg = extractBraceGroup(in: input, from: afterCmd) {
                    result += " \(expandStructures(arg.content, depth: depth + 1)) topi "
                    index = arg.afterIndex
                    continue
                }

                if ["text", "mathrm", "mathbf", "mathit", "mathsf", "mathcal", "mathbb", "textbf", "textit", "operatorname", "mbox", "hbox", "underline"].contains(cmd),
                   let arg = extractBraceGroup(in: input, from: afterCmd) {
                    result += " \(expandStructures(arg.content, depth: depth + 1)) "
                    index = arg.afterIndex
                    continue
                }
            }

            result.append(input[index])
            index = input.index(after: index)
        }
        return result
    }

    private static func skipWhitespace(in text: String, from index: String.Index) -> String.Index {
        var cur = index
        while cur < text.endIndex && text[cur].isWhitespace {
            cur = text.index(after: cur)
        }
        return cur
    }

    private static func extractBraceGroup(in text: String, from index: String.Index) -> (content: String, afterIndex: String.Index)? {
        guard index < text.endIndex, text[index] == "{" else { return nil }
        var depth = 0
        var cur = index
        let contentStart = text.index(after: index)
        while cur < text.endIndex {
            if text[cur] == "{" {
                depth += 1
            } else if text[cur] == "}" {
                depth -= 1
                if depth == 0 {
                    return (String(text[contentStart..<cur]), text.index(after: cur))
                }
            }
            cur = text.index(after: cur)
        }
        // Unclosed brace in truncated LaTeX: consume until end
        return (String(text[contentStart..<text.endIndex]), text.endIndex)
    }

    private static func extractBracketGroup(in text: String, from index: String.Index) -> (content: String, afterIndex: String.Index)? {
        guard index < text.endIndex, text[index] == "[" else { return nil }
        var depth = 0
        var cur = index
        let contentStart = text.index(after: index)
        while cur < text.endIndex {
            if text[cur] == "[" {
                depth += 1
            } else if text[cur] == "]" {
                depth -= 1
                if depth == 0 {
                    return (String(text[contentStart..<cur]), text.index(after: cur))
                }
            }
            cur = text.index(after: cur)
        }
        return nil
    }

    private static func extractSimpleScriptToken(in text: String, from index: String.Index) -> (text: String, afterIndex: String.Index)? {
        guard index < text.endIndex else { return nil }
        var cur = index
        if text[cur] == "+" || text[cur] == "-" {
            let next = text.index(after: cur)
            if next < text.endIndex && text[next].isNumber {
                cur = next
                while cur < text.endIndex && text[cur].isNumber {
                    cur = text.index(after: cur)
                }
                let sign = text[index] == "-" ? "minus " : "plus "
                return (sign + String(text[next..<cur]), cur)
            }
        }
        if text[cur].isNumber {
            while cur < text.endIndex && text[cur].isNumber {
                cur = text.index(after: cur)
            }
            return (String(text[index..<cur]), cur)
        }
        if text[cur].isLetter {
            return (String(text[cur]), text.index(after: cur))
        }
        return nil
    }

    private static func expandUnicodeScripts(_ input: String) -> String {
        let supMap: [Character: String] = [
            "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4",
            "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9",
            "⁺": " plus ", "⁻": " minus ", "⁼": " sama dengan ",
            "⁽": "(", "⁾": ")", "ⁿ": "n", "ⁱ": "i"
        ]
        let subMap: [Character: String] = [
            "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4",
            "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9",
            "₊": " plus ", "₋": " minus ", "₌": " sama dengan ",
            "₍": "(", "₎": ")", "ₐ": "a", "ₑ": "e", "ₒ": "o",
            "ₓ": "x", "ₕ": "h", "ₖ": "k", "ₗ": "l", "ₘ": "m",
            "ₙ": "n", "ₚ": "p", "ₛ": "s", "ₜ": "t"
        ]
        var output = ""
        var index = input.startIndex
        while index < input.endIndex {
            let ch = input[index]
            if supMap[ch] != nil {
                var run = ""
                while index < input.endIndex, let mapped = supMap[input[index]] {
                    run += mapped
                    index = input.index(after: index)
                }
                output += " pangkat \(run) "
            } else if subMap[ch] != nil {
                var run = ""
                while index < input.endIndex, let mapped = subMap[input[index]] {
                    run += mapped
                    index = input.index(after: index)
                }
                output += " indeks \(run) "
            } else {
                output.append(ch)
                index = input.index(after: index)
            }
        }
        return output
    }

    private static func replaceRegex(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    private static let commandReplacements: [(String, String)] = [
        (#"\\%"#, " persen "),
        (#"\\circ\b"#, " derajat "),
        (#"\\(?:times|cdot|ast)\b"#, " kali "),
        (#"\\div\b"#, " bagi "),
        (#"\\pm\b"#, " plus minus "),
        (#"\\mp\b"#, " minus plus "),
        (#"\\(?:neq|ne)\b"#, " tidak sama dengan "),
        (#"\\(?:leq|le|leqslant)\b"#, " kurang dari atau sama dengan "),
        (#"\\(?:geq|ge|geqslant)\b"#, " lebih dari atau sama dengan "),
        (#"\\ll\b"#, " jauh kurang dari "),
        (#"\\gg\b"#, " jauh lebih dari "),
        (#"\\(?:approx|simeq)\b"#, " kira-kira sama dengan "),
        (#"\\equiv\b"#, " ekuivalen dengan "),
        (#"\\(?:sim|propto)\b"#, " sebanding dengan "),
        (#"\\cong\b"#, " kongruen dengan "),
        (#"\\(?:rightarrow|to|longrightarrow)\b"#, " menuju "),
        (#"\\(?:leftarrow|gets)\b"#, " dari "),
        (#"\\(?:Rightarrow|implies|Longrightarrow)\b"#, " maka "),
        (#"\\(?:Leftrightarrow|iff|Longleftrightarrow)\b"#, " jika dan hanya jika "),
        (#"\\infty\b"#, " tak hingga "),
        (#"\\partial\b"#, " parsial "),
        (#"\\nabla\b"#, " nabla "),
        (#"\\forall\b"#, " untuk semua "),
        (#"\\exists\b"#, " terdapat "),
        (#"\\notin\b"#, " bukan elemen dari "),
        (#"\\in\b"#, " elemen dari "),
        (#"\\(?:subseteq|subset)\b"#, " himpunan bagian dari "),
        (#"\\(?:supseteq|supset)\b"#, " memuat "),
        (#"\\cup\b"#, " gabungan "),
        (#"\\cap\b"#, " irisan "),
        (#"\\(?:emptyset|varnothing)\b"#, " himpunan kosong "),
        (#"\\(?:angle|measuredangle)\b"#, " sudut "),
        (#"\\(?:triangle|bigtriangleup)\b"#, " segitiga "),
        (#"\\perp\b"#, " tegak lurus "),
        (#"\\parallel\b"#, " sejajar "),
        (#"\\sum\b"#, " sigma "),
        (#"\\prod\b"#, " produk "),
        (#"\\int\b"#, " integral "),
        (#"\\lim\b"#, " limit "),
        (#"\\arcsin\b"#, " arkus sinus "),
        (#"\\arccos\b"#, " arkus cosinus "),
        (#"\\arctan\b"#, " arkus tangen "),
        (#"\\sin\b"#, " sinus "),
        (#"\\cos\b"#, " cosinus "),
        (#"\\tan\b"#, " tangen "),
        (#"\\cot\b"#, " kotangen "),
        (#"\\sec\b"#, " sekan "),
        (#"\\csc\b"#, " kosekan "),
        (#"\\log\b"#, " log "),
        (#"\\ln\b"#, " lon "),
        (#"\\det\b"#, " determinan "),
        (#"\\max\b"#, " maksimum "),
        (#"\\min\b"#, " minimum "),
        (#"\\(?:dots|ldots|cdots)\b"#, " titik-titik "),
        (#"\\prime\b"#, " aksen "),
        (#"\\alpha\b"#, " alfa "),
        (#"\\beta\b"#, " beta "),
        (#"\\Gamma\b"#, " Gamma "),
        (#"\\gamma\b"#, " gamma "),
        (#"\\Delta\b"#, " Delta "),
        (#"\\delta\b"#, " delta "),
        (#"\\(?:epsilon|varepsilon)\b"#, " epsilon "),
        (#"\\zeta\b"#, " zeta "),
        (#"\\eta\b"#, " eta "),
        (#"\\Theta\b"#, " Teta "),
        (#"\\(?:theta|vartheta)\b"#, " teta "),
        (#"\\iota\b"#, " iota "),
        (#"\\kappa\b"#, " kapa "),
        (#"\\Lambda\b"#, " Lambda "),
        (#"\\lambda\b"#, " lambda "),
        (#"\\mu\b"#, " mu "),
        (#"\\nu\b"#, " nu "),
        (#"\\Xi\b"#, " Ksi "),
        (#"\\xi\b"#, " ksi "),
        (#"\\Pi\b"#, " Pi "),
        (#"\\pi\b"#, " pi "),
        (#"\\(?:rho|varrho)\b"#, " ro "),
        (#"\\Sigma\b"#, " Sigma "),
        (#"\\(?:sigma|varsigma)\b"#, " sigma "),
        (#"\\tau\b"#, " tau "),
        (#"\\Upsilon\b"#, " Upsilon "),
        (#"\\upsilon\b"#, " upsilon "),
        (#"\\Phi\b"#, " Fi "),
        (#"\\(?:phi|varphi)\b"#, " fi "),
        (#"\\chi\b"#, " khi "),
        (#"\\Psi\b"#, " Psi "),
        (#"\\psi\b"#, " psi "),
        (#"\\Omega\b"#, " Omega "),
        (#"\\omega\b"#, " omega ")
    ]

    private static let symbolReplacements: [(String, String)] = [
        ("°", " derajat "),
        ("º", " derajat "),
        ("∛", " akar pangkat 3 dari "),
        ("∜", " akar pangkat 4 dari "),
        ("√", " akar "),
        ("×", " kali "),
        ("·", " kali "),
        ("∗", " kali "),
        ("÷", " bagi "),
        ("±", " plus minus "),
        ("∓", " minus plus "),
        ("≠", " tidak sama dengan "),
        ("≤", " kurang dari atau sama dengan "),
        ("⩽", " kurang dari atau sama dengan "),
        ("≥", " lebih dari atau sama dengan "),
        ("⩾", " lebih dari atau sama dengan "),
        ("≪", " jauh kurang dari "),
        ("≫", " jauh lebih dari "),
        ("≈", " kira-kira sama dengan "),
        ("≃", " kira-kira sama dengan "),
        ("≡", " ekuivalen dengan "),
        ("∼", " sebanding dengan "),
        ("∝", " sebanding dengan "),
        ("≅", " kongruen dengan "),
        ("→", " menuju "),
        ("⟶", " menuju "),
        ("←", " dari "),
        ("⇒", " maka "),
        ("⟹", " maka "),
        ("⇔", " jika dan hanya jika "),
        ("⟺", " jika dan hanya jika "),
        ("∞", " tak hingga "),
        ("∂", " parsial "),
        ("∇", " nabla "),
        ("∀", " untuk semua "),
        ("∃", " terdapat "),
        ("∉", " bukan elemen dari "),
        ("∈", " elemen dari "),
        ("⊆", " himpunan bagian dari "),
        ("⊂", " himpunan bagian dari "),
        ("⊇", " memuat "),
        ("⊃", " memuat "),
        ("∪", " gabungan "),
        ("∩", " irisan "),
        ("∅", " himpunan kosong "),
        ("∠", " sudut "),
        ("∡", " sudut "),
        ("△", " segitiga "),
        ("∆", " Delta "),
        ("⊥", " tegak lurus "),
        ("∥", " sejajar "),
        ("∑", " sigma "),
        ("∏", " produk "),
        ("∫", " integral "),
        ("…", " titik-titik "),
        ("′", " aksen "),
        ("α", " alfa "),
        ("β", " beta "),
        ("Γ", " Gamma "),
        ("γ", " gamma "),
        ("Δ", " Delta "),
        ("δ", " delta "),
        ("ε", " epsilon "),
        ("ϵ", " epsilon "),
        ("ζ", " zeta "),
        ("η", " eta "),
        ("Θ", " Teta "),
        ("θ", " teta "),
        ("ϑ", " teta "),
        ("ι", " iota "),
        ("κ", " kapa "),
        ("Λ", " Lambda "),
        ("λ", " lambda "),
        ("μ", " mu "),
        ("ν", " nu "),
        ("Ξ", " Ksi "),
        ("ξ", " ksi "),
        ("Π", " Pi "),
        ("π", " pi "),
        ("ρ", " ro "),
        ("Σ", " Sigma "),
        ("σ", " sigma "),
        ("ς", " sigma "),
        ("τ", " tau "),
        ("Υ", " Upsilon "),
        ("υ", " upsilon "),
        ("Φ", " Fi "),
        ("φ", " fi "),
        ("ϕ", " fi "),
        ("χ", " khi "),
        ("Ψ", " Psi "),
        ("ψ", " psi "),
        ("Ω", " Omega "),
        ("ω", " omega ")
    ]
}

#endif
