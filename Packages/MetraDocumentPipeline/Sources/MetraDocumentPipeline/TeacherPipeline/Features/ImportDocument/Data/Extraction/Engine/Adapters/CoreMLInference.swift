import Foundation
import CoreML

enum CoreMLInferenceError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self { case .invalid(let reason): return "Core ML: \(reason)" }
    }
}

/// Models are compiled by Xcode from versioned resources. Inference is entirely native.
/// FP32 on CPU retains the validated numerical behavior of the original extraction models.
final class CoreMLInference {
    static let runtime = "Core ML"
    static let backend = "CPU; FP32"
    private let model: MLModel

    init(name: String, sourceSHA256: String, inputs: Set<String>, outputs: Set<String>,
         function: String? = nil, bundle: Bundle = .module) throws {
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else {
            throw CoreMLInferenceError.invalid("Model \(name) belum tersedia di bundle. Pastikan aset Git LFS sudah terunduh.")
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        configuration.functionName = function
        let loaded = try MLModel(contentsOf: url, configuration: configuration)
        let metadata = loaded.modelDescription.metadata[.creatorDefinedKey] as? [String: String] ?? [:]
        let hashKey = function.map { "metra.source.\($0).sha256" } ?? "metra.source.sha256"
        guard metadata[hashKey] == sourceSHA256, metadata["metra.precision"] == "FP32" else {
            throw CoreMLInferenceError.invalid("Identitas model \(name) berbeda dari manifest.")
        }
        guard Set(loaded.modelDescription.inputDescriptionsByName.keys) == inputs,
              Set(loaded.modelDescription.outputDescriptionsByName.keys) == outputs else {
            throw CoreMLInferenceError.invalid("Nama tensor \(name) berbeda dari manifest.")
        }
        model = loaded
    }

    func predict(_ inputs: [String: MLMultiArray], outputs: Set<String>) throws -> [String: MLMultiArray] {
        try Task.checkCancellation()
        let provider = try MLDictionaryFeatureProvider(dictionary: inputs.mapValues { MLFeatureValue(multiArray: $0) })
        let prediction = try model.prediction(from: provider)
        try Task.checkCancellation()
        var tensors: [String: MLMultiArray] = [:]
        for name in outputs {
            guard let tensor = prediction.featureValue(for: name)?.multiArrayValue else {
                throw CoreMLInferenceError.invalid("Output \(name) tidak tersedia.")
            }
            tensors[name] = tensor
        }
        return tensors
    }

    static func tensor(_ values: [Float], shape: [Int]) throws -> MLMultiArray {
        try validate(count: values.count, shape: shape)
        let result = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float32)
        values.withUnsafeBufferPointer { source in
            result.dataPointer.assumingMemoryBound(to: Float.self).update(from: source.baseAddress!, count: values.count)
        }
        return result
    }

    static func token(_ value: Int) throws -> MLMultiArray {
        guard let token = Int32(exactly: value) else { throw CoreMLInferenceError.invalid("Token di luar rentang Int32.") }
        let result = try MLMultiArray(shape: [1, 1], dataType: .int32)
        result.dataPointer.assumingMemoryBound(to: Int32.self).pointee = token
        return result
    }

    static func shape(_ tensor: MLMultiArray) -> [Int] { tensor.shape.map(\.intValue) }

    /// Core ML output tensors may have padding between rows or channels.
    /// Respect strides instead of assuming that the data pointer is contiguous.
    static func floats(_ tensor: MLMultiArray) throws -> [Float] {
        guard tensor.dataType == .float32 else { throw CoreMLInferenceError.invalid("Output bukan float32.") }
        let dimensions = shape(tensor), strides = tensor.strides.map(\.intValue)
        let pointer = tensor.dataPointer.assumingMemoryBound(to: Float.self)
        var expected = 1, contiguous = true
        for axis in dimensions.indices.reversed() {
            if dimensions[axis] > 1 && strides[axis] != expected { contiguous = false }
            expected *= dimensions[axis]
        }
        if contiguous { return Array(UnsafeBufferPointer(start: pointer, count: tensor.count)) }
        return (0..<tensor.count).map { flat in
            var remaining = flat, offset = 0
            for axis in dimensions.indices.reversed() {
                offset += (remaining % dimensions[axis]) * strides[axis]
                remaining /= dimensions[axis]
            }
            return pointer[offset]
        }
    }

    static func integer(_ tensor: MLMultiArray) throws -> Int {
        guard tensor.dataType == .int32, tensor.count == 1 else {
            throw CoreMLInferenceError.invalid("Output bukan satu int32.")
        }
        return Int(tensor.dataPointer.assumingMemoryBound(to: Int32.self).pointee)
    }

    private static func validate(count: Int, shape: [Int]) throws {
        guard !shape.isEmpty, shape.allSatisfy({ $0 > 0 }) else { throw CoreMLInferenceError.invalid("Shape input tidak valid.") }
        var size = 1
        for dimension in shape {
            let product = size.multipliedReportingOverflow(by: dimension)
            guard !product.overflow else { throw CoreMLInferenceError.invalid("Shape input terlalu besar.") }
            size = product.partialValue
        }
        guard size == count else { throw CoreMLInferenceError.invalid("Jumlah nilai input berbeda dari shape.") }
    }
}
