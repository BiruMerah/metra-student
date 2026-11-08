#if os(iOS)
import Foundation
import FoundationModels

@Generable
struct FoundationMaterialOverviewResponse {
    @Guide(description: "Informasi materi ringkas dalam bahasa Indonesia untuk siswa tunanetra (maksimal 2 kalimat, paling banyak 65 kata). Kalimat pertama menyebutkan total halaman ('Materi ini terdiri dari X halaman.'). Kalimat kedua menyebutkan apa yang dibahas di setiap halaman atau rentang halaman ('Halaman A membahas ..., halaman B membahas ..., dan halaman C sampai D berisi ...') sambil menyebutkan secara natural jika ada gambar/diagram, rumus, atau latihan soal. Jangan menyelesaikan soal atau mengarang isi di luar sumber.")
    var overview: String
}

/// A separate serial text-only request after OCR, formulas and diagrams finish.
/// Uses the on-device system model, without a cloud provider.
actor FoundationMaterialOverviewRuntime: OverviewTextSummarizing {
    static let version = "foundation_material_overview_v3"
    static let instructions = """
    Anda menyusun informasi orientasi dokumen yang sangat ringkas dalam bahasa Indonesia untuk siswa tunanetra pengguna VoiceOver.
    Gunakan tepat pola berikut dalam 1–2 kalimat mengalir (maksimal 65 kata):
    "Materi ini terdiri dari [X] halaman. Halaman [A] membahas [topik/materi], halaman [B] membahas [topik/materi], dan halaman [C] sampai [D] berisi [topik/latihan soal]."
    Jika materi hanya 1 halaman, gunakan pola: "Materi ini terdiri dari 1 halaman (halaman [A]) yang membahas [topik/materi]."
    Selipkan konteks singkat secara natural pada halaman terkait jika terdapat gambar/diagram (misalnya "disertai gambar segitiga"), rumus/contoh perhitungan, atau latihan soal (misalnya "berisi latihan soal pilihan ganda").
    Jangan merinci angka statistik seperti jumlah bagian/chunk, jangan menjawab soal, dan jangan menyertakan kalimat pembuka.
    """

    func summarize(_ source: String) async throws -> String {
        try Task.checkCancellation()
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw MaterialOverviewUnavailable(reason: "model_unavailable: \(model.availability)")
        }
        // supportsLocale is advisory: this OS reports false for id_ID while
        // the available model successfully generates Indonesian. Attempt the
        // request and fall back on an actual generation/guardrail failure.
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let request = Task {
            try await session.respond(to: "Susun informasi materi per halaman yang ringkas dari SUMBER berikut.\n<SUMBER>\n\(source)\n</SUMBER>",
                generating: FoundationMaterialOverviewResponse.self,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 384)).content.overview
        }
        let deadline = Task { do { try await Task.sleep(for: .seconds(45)); request.cancel() } catch {} }
        defer { deadline.cancel() }
        do {
            let text = try await withTaskCancellationHandler(operation: { try await request.value }, onCancel: { request.cancel() })
            try Task.checkCancellation()
            guard !request.isCancelled else { throw MaterialOverviewUnavailable(reason: "generation_timed_out") }
            return text
        } catch {
            try Task.checkCancellation()
            if request.isCancelled { throw MaterialOverviewUnavailable(reason: "generation_timed_out") }
            throw error
        }
    }
}

#endif
