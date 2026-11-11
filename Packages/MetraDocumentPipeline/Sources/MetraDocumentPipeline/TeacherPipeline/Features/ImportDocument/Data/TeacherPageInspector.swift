#if os(iOS)
import Foundation

/// Runs before expensive formula/diagram generation. Original normalized inputs
/// are reused by extraction. Assessments are cached by immutable input identity;
/// explicit Retry repeats the checks, and technical failures are never cached.
actor TeacherPageInspector {
    private var sources: [UUID: ImportedSourcePage] = [:]
    private var assessments: [UUID: TeacherPageAssessment] = [:]
    private let layoutRuntime = PPDocLayoutRuntime()

    func inspect(_ pages: [MaterialImageInput], retry: Bool = false,
                 onAssessment: @escaping @MainActor (TeacherPageAssessment) -> Void = { _ in },
                 onProgress: @escaping @MainActor (String) -> Void) async throws -> [TeacherPageAssessment] {
        let ids = Set(pages.map(\.id))
        sources = sources.filter { ids.contains($0.key) }
        assessments = assessments.filter { ids.contains($0.key) }
        var results: [TeacherPageAssessment] = []
        for (index, page) in pages.enumerated() {
            try Task.checkCancellation()
            await onProgress("Memeriksa halaman \(index + 1) dari \(pages.count)…")
            if !retry, let cached = assessments[page.id] { results.append(cached); await onAssessment(cached); continue }
            let result: TeacherPageAssessment
            do {
                let source = try await prepare(page)
                let imageURL = try ImageIngestor.normalizedURL(for: source)
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("metra-page-check-\(UUID().uuidString)")
                let pageRoot = root.appendingPathComponent("pages/check")
                try FileManager.default.createDirectory(at: pageRoot.appendingPathComponent("crops"), withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: root) }
                var evidence = TeacherPageReadability.Evidence()
                do {
                    let ocr = try await VisionOCRAdapter.recognize(imageURL: imageURL, pageID: "check", priority: .utility)
                    let area = max(1, Double(source.normalizedWidth) * Double(source.normalizedHeight))
                    for observation in ocr.observations {
                        let count = observation.selectedText.filter { $0.isLetter || $0.isNumber }.count
                        evidence.characters += count
                        if (observation.candidates.first?.confidence ?? 0) >= 0.5 { evidence.confidentCharacters += count }
                        evidence.textAreaFraction += observation.bboxPageXYXY.area / area
                    }
                } catch is CancellationError { throw CancellationError() }
                catch { evidence.ocrSucceeded = false }
                try Task.checkCancellation()
                do {
                    let layout = try await layoutRuntime.detect(imageURL: imageURL, pageID: "check", pageRoot: pageRoot,
                        enqueuedAt: ProcessInfo.processInfo.systemUptime)
                    // Release ONNX weights before loading the existing visual classifier.
                    await layoutRuntime.unload()
                    let visual = layout.regions.contains { DiagramSpokenService.visualLabels.contains($0.label) }
                    let regions: [LayoutRegion]
                    if visual {
                        let classified = Task.detached(priority: .utility) {
                            try MathVisualClassifier.classify(regions: layout.regions, pageRoot: pageRoot)
                        }
                        regions = try await withTaskCancellationHandler { try await classified.value }
                            onCancel: { classified.cancel() }
                    } else { regions = layout.regions }
                    let textLabels: Set<String> = ["text", "paragraph_title", "doc_title", "content", "abstract", "algorithm", "aside_text"]
                    let area = max(1, Double(source.normalizedWidth) * Double(source.normalizedHeight))
                    for region in regions {
                        evidence.hasTextLayout = evidence.hasTextLayout || textLabels.contains(region.label)
                        evidence.hasFormulaOrTable = evidence.hasFormulaOrTable || ["formula", "table"].contains(region.label)
                        guard DiagramSpokenService.visualLabels.contains(region.label) else { continue }
                        let classification = region.visualClassification
                        if classification?.status == "succeeded", let kind = classification?.predictedClass {
                            if kind == .others {
                                evidence.ordinaryPhotoDominates = evidence.ordinaryPhotoDominates || region.bboxPageXYXY.area / area >= 0.55
                            } else if (classification?.probabilities[kind.rawValue] ?? 0) >= 0.7 {
                                evidence.hasSupportedVisual = true
                            } else { evidence.hasUncertainVisual = true }
                        } else { evidence.hasUncertainVisual = true }
                    }
                } catch is CancellationError { await layoutRuntime.unload(); throw CancellationError() }
                catch { evidence.layoutSucceeded = false; await layoutRuntime.unload() }
                try Task.checkCancellation()
                result = TeacherPageReadability.assess(evidence, id: page.id)
            } catch is CancellationError { throw CancellationError() }
            catch {
                result = .init(id: page.id, status: .processingFailed,
                    message: "Gambar belum dapat disiapkan untuk diperiksa. Coba lagi atau ganti gambar tersebut.")
            }
            if result.status != .processingFailed { assessments[page.id] = result }
            else { assessments[page.id] = nil }
            results.append(result)
            await onAssessment(result)
        }
        return results
    }

    func preparedSources(for pages: [MaterialImageInput]) async throws -> [ImportedSourcePage] {
        var result: [ImportedSourcePage] = []
        for page in pages { try Task.checkCancellation(); result.append(try await prepare(page)) }
        return result
    }

    private func prepare(_ page: MaterialImageInput) async throws -> ImportedSourcePage {
        if let source = sources[page.id] { return source }
        let task = Task.detached(priority: .utility) {
            let source: ImportedSourcePage
            switch page.origin {
            case .camera: source = try ImageIngestor().ingestCameraData(page.data, fileName: page.fileName)
            case .files: source = try ImageIngestor().ingestFileData(page.data, fileName: page.fileName)
            case .photoLibrary: source = try ImageIngestor().ingestPhotoData(page.data, fileName: page.fileName)
            #if DEBUG
            case .verificationFixture(let url): source = try ImageIngestor().ingestFile(url)
            #endif
            }
            if let preparation = page.preparation { try PreparedCaptureArchive.record(preparation, for: source) }
            return source
        }
        let source = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try Task.checkCancellation()
        sources[page.id] = source
        return source
    }
}

#endif
