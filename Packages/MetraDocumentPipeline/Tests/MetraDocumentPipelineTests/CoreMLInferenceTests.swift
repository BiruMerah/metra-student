import XCTest
import CoreML
@testable import MetraDocumentPipeline

final class CoreMLInferenceTests: XCTestCase {
    func testTensorShapeAndTokenValidation() throws {
        let tensor = try CoreMLInference.tensor([1, 2, 3, 4], shape: [1, 2, 2])
        XCTAssertEqual(try CoreMLInference.floats(tensor), [1, 2, 3, 4])
        XCTAssertThrowsError(try CoreMLInference.tensor([1], shape: [2]))
        XCTAssertThrowsError(try CoreMLInference.tensor([], shape: [0]))
        XCTAssertThrowsError(try CoreMLInference.tensor([1], shape: [Int.max, 2]))
        XCTAssertEqual(try CoreMLInference.integer(CoreMLInference.token(49_999)), 49_999)
        XCTAssertThrowsError(try CoreMLInference.token(Int.max))
    }

    func testPaddedOutputStrides() throws {
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: 8)
        defer { pointer.deallocate() }
        for i in 0..<8 { pointer[i] = -999 }
        for (offset, value) in zip([0, 1, 2, 5, 6, 7], [Float(1), 2, 3, 4, 5, 6]) { pointer[offset] = value }
        let tensor = try MLMultiArray(dataPointer: pointer, shape: [2, 3], dataType: .float32,
                                     strides: [5, 1], deallocator: nil)
        XCTAssertEqual(try CoreMLInference.floats(tensor), [1, 2, 3, 4, 5, 6])
    }

    func testBundledUniMERNetFunctionsAndCache() throws {
        let encoder = try CoreMLInference(name: "UniMERNet-Encoder",
            sourceSHA256: "b1c03135fd8ffa264b3b4e477d6f2a1929b95ef531df03c1f62fd3068845d8ce",
            inputs: ["pixel_values"], outputs: ["encoder_hidden_states"])
        let image = try CoreMLInference.tensor(Array(repeating: 0, count: 192 * 672), shape: [1, 1, 192, 672])
        let hidden = try XCTUnwrap(encoder.predict(["pixel_values": image], outputs: ["encoder_hidden_states"])["encoder_hidden_states"])
        XCTAssertEqual(CoreMLInference.shape(hidden), [1, 126, 512])
        let outputs = Set(["logits"] + (0..<8).flatMap { ["present_key_\($0)", "present_value_\($0)"] })
        let first = try CoreMLInference(name: "UniMERNet-Decoder",
            sourceSHA256: "1c8912bac33cf3abbb07097f954f2030b64ddcb0badef30062471b6f6789a233",
            inputs: ["input_ids", "encoder_hidden_states"], outputs: outputs, function: "first_token")
        let prediction = try first.predict(["input_ids": CoreMLInference.token(0), "encoder_hidden_states": hidden], outputs: outputs)
        XCTAssertEqual(CoreMLInference.shape(try XCTUnwrap(prediction["logits"])), [1, 1, 50_000])
        var inputs = ["input_ids": try CoreMLInference.token(5), "encoder_hidden_states": hidden]
        for layer in 0..<8 {
            inputs["past_key_\(layer)"] = try XCTUnwrap(prediction["present_key_\(layer)"])
            inputs["past_value_\(layer)"] = try XCTUnwrap(prediction["present_value_\(layer)"])
        }
        let cached = try CoreMLInference(name: "UniMERNet-Decoder",
            sourceSHA256: "331c8a61eb2483f8cc610e0c17ab842b856a0c936be263048ca67ba7f378a359",
            inputs: Set(inputs.keys), outputs: outputs, function: "cached_token")
        let next = try cached.predict(inputs, outputs: outputs)
        XCTAssertEqual(CoreMLInference.shape(try XCTUnwrap(next["present_key_0"])), [1, 16, 2, 16])
        XCTAssertEqual(CoreMLInference.shape(try XCTUnwrap(next["present_value_7"])), [1, 16, 2, 32])
    }

    func testModelIdentityMustMatch() {
        XCTAssertThrowsError(try CoreMLInference(name: "PP-DocLayout-L", sourceSHA256: "wrong",
            inputs: ["im_shape", "image", "scale_factor"], outputs: ["fetch_name_0", "fetch_name_1"]))
    }
}
