#if os(iOS)
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Serial worker actor: Vision and perspective rendering never run on the UI actor.
actor VisionDocumentImagePreparer: DocumentImagePreparing {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func prepare(_ inputs: [MaterialImageInput], remainingPages: Int) async throws -> [MaterialImageInput] {
        var result: [MaterialImageInput] = []
        for input in inputs {
            try Task.checkCancellation()
            let prepared = try autoreleasepool { try prepareImage(input) }
            result.append(contentsOf: prepared)
            // Check the expanded page count, not the number of selected photos.
            guard result.count <= min(10, remainingPages) else {
                throw DocumentImagePreparationError.pageLimit(found: result.count, available: max(0, remainingPages))
            }
        }
        try Task.checkCancellation()
        return result
    }

    private func prepareImage(_ input: MaterialImageInput) throws -> [MaterialImageInput] {
        // PDF page boundaries are authoritative. Do not split diagrams or boxed
        // exercises in a normal PDF; already-prepared images are also idempotent.
        if case .files = input.origin { return [input] }
        if input.preparation != nil { return [input] }
        guard let source = CGImageSourceCreateWithData(input.data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4_096,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw DocumentImagePreparationError.unreadableImage }
        let ciImage = CIImage(cgImage: image)
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 64
        request.minimumConfidence = 0.55
        request.minimumSize = 0.12
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1
        request.quadratureTolerance = 35
        do { try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request]) }
        catch {
            try Task.checkCancellation()
            return [uncertain(input, "Batas kertas belum dapat diperiksa. Coba foto ulang satu lembar atau periksa foto asli sebelum melanjutkan.")]
        }
        try Task.checkCancellation()
        let detected = (request.results ?? []).map {
            DocumentQuadrilateral(topLeft: $0.topLeft, topRight: $0.topRight,
                bottomRight: $0.bottomRight, bottomLeft: $0.bottomLeft)
        }.filter(\.isValid)
        guard !detected.isEmpty else { return [input] }
        let raster = rasterPixels(ciImage)
        let supported = detected.filter { paperSupport($0, raster: raster) }
        var boundaries = DocumentBoundarySelection.outermost(supported)
        if boundaries.isEmpty {
            if detected.count >= 2 {
                return [uncertain(input, "Beberapa bidang terdeteksi, tetapi batas kertas belum jelas. Foto ulang dengan kertas terpisah di atas latar yang kontras, atau periksa foto asli.")]
            }
            return [input]
        }
        guard detected.count < request.maximumObservations, !DocumentBoundarySelection.overlaps(boundaries) else {
            return [uncertain(input, "Kertas tampak saling menutupi atau batasnya bertumpuk. Pisahkan setiap lembar lalu foto ulang; tulisan yang tertutup tidak dapat dipulihkan.")]
        }
        boundaries = DocumentBoundarySelection.readingOrder(boundaries)
        if boundaries.count == 1, let boundary = boundaries.first, boundary.area > 0.92 { return [input] }
        // Never discard readable material outside a proposed crop, e.g. a title
        // above boxed exercises or a sheet that rectangle detection missed.
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .fast
        text.usesLanguageCorrection = false
        text.minimumTextHeight = 0.006
        do { try VNImageRequestHandler(cgImage: image, orientation: .up).perform([text]) }
        catch {
            try Task.checkCancellation()
            return [uncertain(input, "Hasil potongan belum dapat diperiksa kelengkapannya. Foto asli tetap tersedia; periksa sebelum melanjutkan.")]
        }
        try Task.checkCancellation()
        var total = 0, outside = 0
        for line in text.results ?? [] {
            guard let value = line.topCandidates(1).first, value.confidence >= 0.2 else { continue }
            let weight = value.string.filter { $0.isLetter || $0.isNumber }.count
            let points = [CGPoint(x: line.boundingBox.minX, y: line.boundingBox.midY),
                          CGPoint(x: line.boundingBox.maxX, y: line.boundingBox.midY)]
            total += weight
            if !boundaries.contains(where: { boundary in points.allSatisfy { boundary.contains($0, tolerance: 0.004) } }) {
                outside += weight
            }
        }
        guard outside <= max(6, Int(Double(total) * 0.06)) else {
            return [uncertain(input, "Ada tulisan di luar batas potongan yang terdeteksi. Foto asli dipertahankan agar materi tidak hilang. Ambil foto satu lembar per gambar atau gunakan foto asli setelah diperiksa.")]
        }
        var pages: [MaterialImageInput] = []
        for (index, boundary) in boundaries.enumerated() {
            try Task.checkCancellation()
            guard let data = correctedImage(ciImage, boundary: boundary) else {
                return [uncertain(input, "Kertas terlalu kecil atau sudutnya belum dapat diluruskan. Dekatkan kamera dan foto ulang satu lembar per gambar.")]
            }
            let metadata = DocumentImagePreparation(sourceID: input.id, originalData: input.data,
                originalFileName: input.fileName, outcome: boundaries.count > 1 ? .split : .corrected,
                pageNumber: index + 1, pageCount: boundaries.count, boundary: boundary, explanation: nil)
            pages.append(MaterialImageInput(data: data,
                fileName: "\(URL(fileURLWithPath: input.fileName).deletingPathExtension().lastPathComponent)-lembar-\(index + 1).jpg",
                origin: input.origin, preparation: metadata))
        }
        return pages
    }

    private func uncertain(_ input: MaterialImageInput, _ explanation: String) -> MaterialImageInput {
        MaterialImageInput(data: input.data, fileName: input.fileName, origin: input.origin,
            preparation: .init(sourceID: input.id, originalData: input.data, originalFileName: input.fileName,
                outcome: .needsReview, pageNumber: 1, pageCount: 1, boundary: nil, explanation: explanation))
    }

    private func correctedImage(_ image: CIImage, boundary: DocumentQuadrilateral) -> Data? {
        let center = CGPoint(x: boundary.bounds.midX, y: boundary.bounds.midY)
        func pixel(_ p: CGPoint) -> CIVector {
            // A small margin retains edge strokes instead of trimming to ink.
            let x = min(1, max(0, center.x + (p.x - center.x) * 1.008))
            let y = min(1, max(0, center.y + (p.y - center.y) * 1.008))
            return CIVector(x: x * image.extent.width, y: y * image.extent.height)
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection", parameters: [
            kCIInputImageKey: image, "inputTopLeft": pixel(boundary.topLeft),
            "inputTopRight": pixel(boundary.topRight), "inputBottomLeft": pixel(boundary.bottomLeft),
            "inputBottomRight": pixel(boundary.bottomRight)
        ]), var output = filter.outputImage, output.extent.width.isFinite, output.extent.height.isFinite,
              min(output.extent.width, output.extent.height) >= 240 else { return nil }
        let scale = min(1, 3_200 / max(output.extent.width, output.extent.height))
        output = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(output, from: output.extent),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(destinationData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.97] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    private func rasterPixels(_ image: CIImage) -> [UInt8] {
        let scaled = image.transformed(by: CGAffineTransform(scaleX: 256 / image.extent.width, y: 256 / image.extent.height))
        var pixels = [UInt8](repeating: 0, count: 256 * 256 * 4)
        pixels.withUnsafeMutableBytes { ptr in
            context.render(scaled, toBitmap: ptr.baseAddress!, rowBytes: 256 * 4,
                bounds: CGRect(x: 0, y: 0, width: 256, height: 256), format: .RGBA8,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        }
        return pixels
    }

    private func paperSupport(_ boundary: DocumentQuadrilateral, raster: [UInt8]) -> Bool {
        func sample(_ p: CGPoint) -> (CGFloat, CGFloat, CGFloat) {
            let x = Int(min(255, max(0, p.x * 255))), y = Int(min(255, max(0, p.y * 255)))
            let i = (y * 256 + x) * 4
            return (CGFloat(raster[i]) / 255, CGFloat(raster[i + 1]) / 255, CGFloat(raster[i + 2]) / 255)
        }
        let center = CGPoint(x: boundary.bounds.midX, y: boundary.bounds.midY)
        var light = 0, contrast: CGFloat = 0, count = 0
        for edge in 0..<4 {
            let a = boundary.points[edge], b = boundary.points[(edge + 1) % 4]
            for fraction: CGFloat in [0.15, 0.35, 0.5, 0.65, 0.85] {
                let p = CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
                let inside = CGPoint(x: p.x + (center.x - p.x) * 0.06, y: p.y + (center.y - p.y) * 0.06)
                let outside = CGPoint(x: p.x + (p.x - center.x) * 0.09, y: p.y + (p.y - center.y) * 0.09)
                guard (0...1).contains(outside.x), (0...1).contains(outside.y) else { continue }
                let rgb = sample(inside), backdrop = sample(outside)
                let brightness = (rgb.0 + rgb.1 + rgb.2) / 3
                if brightness > 0.58 && max(rgb.0, rgb.1, rgb.2) - min(rgb.0, rgb.1, rgb.2) < 0.42 { light += 1 }
                contrast += (abs(rgb.0 - backdrop.0) + abs(rgb.1 - backdrop.1) + abs(rgb.2 - backdrop.2)) / 3
                count += 1
            }
        }
        // White space on both sides of a printed table is not a paper edge.
        return count >= 8 && Double(light) / Double(count) >= 0.6 && contrast / CGFloat(count) >= 0.045
    }
}

#endif
