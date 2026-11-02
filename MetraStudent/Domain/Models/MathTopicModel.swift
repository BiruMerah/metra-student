import Foundation

nonisolated enum MetraSpeechStyle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case clearSpeak, simpleSpeak

    var id: Self { self }
    var label: String { self == .clearSpeak ? "ClearSpeak" : "SimpleSpeak" }
}

nonisolated enum MetraReviewStatus: String, Codable, Hashable, Sendable {
    case draft, validated
}

nonisolated struct MetraContentPart: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable { case text, math }
    var kind: Kind
    var text: String?
    var mathML: String?
    var clearSpeak: String?
    var simpleSpeak: String?

    static func prose(_ text: String) -> Self { .init(kind: .text, text: text) }

    func readingText(style: MetraSpeechStyle) -> String {
        switch kind {
        case .text: return text ?? ""
        case .math: return (style == .clearSpeak ? clearSpeak : simpleSpeak) ?? ""
        }
    }
}

nonisolated struct MetraChunk: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var pageLabel: String?
    var parts: [MetraContentPart]
    var teacherSpokenOverride: String?
    var requiresTeacherCorrection: Bool? = nil
    var reviewNote: String? = nil
    var sourceChunkIDs: [String]? = nil
    var originalParts: [MetraContentPart]? = nil

    func readingText(style: MetraSpeechStyle) -> String {
        if let correction = teacherSpokenOverride,
           !correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return correction
        }
        return parts.map { $0.readingText(style: style) }.joined()
    }

    var isStandaloneMath: Bool {
        let activeParts = parts.filter {
            switch $0.kind {
            case .text: return !($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .math: return true
            }
        }
        return !activeParts.isEmpty && activeParts.allSatisfy { $0.kind == .math }
    }
}

nonisolated struct MathTopicModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: [MathTopicContent]
    var chunks: [MetraChunk]

    init(
        id: UUID = UUID(),
        title: String,
        content: [MathTopicContent] = [],
        chunks: [MetraChunk] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.chunks = chunks
    }
}

nonisolated enum MathTopicContent: Codable, Equatable, Hashable, Sendable {
    case text(String)
    case analogy(String)
    // A standalone mathematical expression written entirely as spoken words.
    case spokenMath(String)
    // A verbal description of a mathematical diagram, without relying on sight.
    case visual(String)
}

extension MathTopicModel {
    nonisolated static let sampleTopics: [MathTopicModel] = [
        MathTopicModel(title: "Pengertian Persamaan Linear", content: [
            .text("Persamaan menyatakan bahwa dua nilai adalah sama. Bagian sebelum kata sama dengan disebut ruas kiri, dan bagian sesudahnya disebut ruas kanan."),
            .text("Persamaan linear satu variabel memiliki satu bilangan yang belum diketahui. Bilangan itu disebut variabel, dan kita akan menyebutnya eks. Pangkat tertinggi variabelnya adalah satu."),
            .analogy("Anggap kedua ruas persamaan sebagai dua sisi timbangan yang seimbang. Berat pada kedua sisi sama. Untuk menjaga keseimbangan, penambahan atau pengurangan berat harus sama pada kedua sisi."),
            .spokenMath("Eks ditambah tiga sama dengan tujuh."),
            .text("Artinya, ada suatu bilangan yang jika ditambah tiga, hasilnya tujuh. Bilangan yang belum diketahui itu adalah empat."),
            .visual("Garis bilangan dapat dibayangkan sebagai urutan posisi dengan jarak yang sama. Bergerak ke kanan berarti menambah, dan bergerak ke kiri berarti mengurangi. Mulai dari posisi empat, lalu bergerak tiga langkah ke kanan. Posisi akhirnya adalah tujuh.")
        ]),
        MathTopicModel(title: "Bentuk Umum", content: [
            .text("Persamaan linear satu variabel memiliki koefisien, variabel, dan konstanta. Koefisien adalah bilangan yang mengalikan variabel. Konstanta adalah bilangan tetap yang tidak dikalikan dengan variabel."),
            .spokenMath("Sebuah koefisien dikalikan dengan eks, kemudian ditambah sebuah konstanta, hasilnya sama dengan nol."),
            .text("Koefisien tersebut tidak boleh bernilai nol. Berikut adalah contoh persamaannya."),
            .spokenMath("Dua kali eks ditambah enam sama dengan nol."),
            .text("Pada persamaan ini, koefisiennya adalah dua, variabelnya eks, dan konstantanya enam."),
            .text("Ungkapan dua kali eks berarti dua dikalikan dengan bilangan yang belum diketahui. Ungkapan itu bukan berarti dua ditambah eks.")
        ]),
        MathTopicModel(title: "Langkah Penyelesaian", content: [
            .text("Tujuan menyelesaikan persamaan adalah menemukan nilai eks yang membuat kedua ruas bernilai sama."),
            .analogy("Pada timbangan yang seimbang, mengambil beban dengan berat yang sama dari kedua sisi akan menjaga keseimbangan. Begitu juga dengan persamaan. Mengurangi kedua ruas dengan bilangan yang sama akan menjaga kesamaannya."),
            .spokenMath("Persamaan yang akan kita selesaikan adalah eks ditambah tiga sama dengan tujuh."),
            .text("Langkah pertama, kurangi kedua ruas dengan tiga. Ruas kiri menjadi eks ditambah tiga, kemudian dikurangi tiga. Ruas kanan menjadi tujuh dikurangi tiga."),
            .text("Langkah kedua, sederhanakan kedua ruas. Tiga dikurangi tiga adalah nol, sehingga ruas kiri tinggal eks. Tujuh dikurangi tiga adalah empat, sehingga ruas kanan menjadi empat. Jadi, eks sama dengan empat."),
            .visual("Pada garis bilangan, mulai dari posisi tujuh. Pengurangan tiga berarti bergerak tiga langkah ke kiri. Posisi yang dilewati adalah enam, lima, lalu empat. Posisi akhir ini menunjukkan hasil tujuh dikurangi tiga."),
            .text("Langkah ketiga, periksa jawabannya. Ganti eks pada persamaan awal dengan empat. Empat ditambah tiga sama dengan tujuh. Kedua ruas bernilai tujuh, sehingga jawaban kita benar.")
        ]),
        MathTopicModel(title: "Contoh Soal", content: [
            .text("Tentukan nilai eks dari persamaan berikut. Dengarkan persamaannya terlebih dahulu, lalu ikuti setiap langkah penyelesaian."),
            .spokenMath("Dua kali eks ditambah empat sama dengan dua belas."),
            .text("Artinya, bilangan yang belum diketahui dikalikan dua, kemudian hasilnya ditambah empat, sehingga menjadi dua belas."),
            .text("Langkah pertama, kurangi kedua ruas dengan empat. Pada ruas kiri, empat dikurangi empat adalah nol, sehingga tersisa dua kali eks. Pada ruas kanan, dua belas dikurangi empat adalah delapan. Sekarang, dua kali eks sama dengan delapan."),
            .text("Langkah kedua, bagi kedua ruas dengan dua. Pada ruas kiri, dua kali eks dibagi dua menghasilkan eks. Pada ruas kanan, delapan dibagi dua menghasilkan empat. Jadi, eks sama dengan empat."),
            .text("Langkah ketiga, periksa jawabannya. Ganti eks dengan empat. Dua kali empat adalah delapan. Delapan ditambah empat adalah dua belas. Kedua ruas bernilai dua belas, sehingga jawabannya benar.")
        ])
    ]
}
