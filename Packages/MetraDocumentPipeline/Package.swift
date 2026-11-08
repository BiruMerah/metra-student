// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MetraDocumentPipeline",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [.library(name: "MetraDocumentPipeline", targets: ["MetraDocumentPipeline"])],
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", exact: "1.24.2")
    ],
    targets: [
        .binaryTarget(name: "MetraMathCAT", path: "Binaries/MathCAT.xcframework"),
        .target(
            name: "MetraDocumentPipeline",
            dependencies: [
                .target(name: "MetraMathCAT", condition: .when(platforms: [.iOS])),
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager",
                         condition: .when(platforms: [.iOS]))
            ],
            resources: [
                .process("Resources/MathVisualRepresentationClassifier.mlmodel"),
                .copy("Resources/MathCATRules"),
                .copy("Resources/MathJaxExtensions"),
                .copy("Resources/UniMERNet"),
                .copy("Resources/MathJaxBridge.html"),
                .copy("Resources/tex-mml-chtml-nofont.js"),
                .copy("Resources/model-manifest.json"),
                .copy("Resources/PP-DocLayout-L.onnx"),
                .copy("Resources/PP-DocLayout-L.config.json"),
                .copy("Resources/Pix2Text-MFD.onnx"),
                .copy("Resources/Pix2Text-MFD.config.json"),
                .copy("Resources/PaddleOCR-PP-OCRv5-mobile-rec.onnx"),
                .copy("Resources/PaddleOCR-PP-OCRv5-mobile-rec.config.json"),
                .copy("Resources/PaddleOCR-PP-OCRv5-mobile-rec.characters.json")
            ],
            linkerSettings: [.linkedLibrary("iconv", .when(platforms: [.iOS]))]
        )
    ],
    swiftLanguageModes: [.v5]
)
