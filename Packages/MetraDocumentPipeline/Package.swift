// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MetraDocumentPipeline",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [.library(name: "MetraDocumentPipeline", targets: ["MetraDocumentPipeline"])],
    targets: [
        .binaryTarget(name: "MetraMathCAT", path: "Binaries/MathCAT.xcframework"),
        .target(
            name: "MetraDocumentPipeline",
            dependencies: [
                .target(name: "MetraMathCAT", condition: .when(platforms: [.iOS]))
            ],
            resources: [
                .process("Resources/MathVisualRepresentationClassifier.mlmodel"),
                .process("Resources/PP-DocLayout-L.mlpackage"),
                .process("Resources/Pix2Text-MFD.mlpackage"),
                .process("Resources/PaddleOCR-PP-OCRv5-mobile-rec.mlpackage"),
                .process("Resources/UniMERNet-Encoder.mlpackage"),
                .process("Resources/UniMERNet-Decoder.mlpackage"),
                .copy("Resources/MathCATRules"),
                .copy("Resources/MathJaxExtensions"),
                .copy("Resources/UniMERNet"),
                .copy("Resources/MathJaxBridge.html"),
                .copy("Resources/tex-mml-chtml-nofont.js"),
                .copy("Resources/model-manifest.json"),
                .copy("Resources/PP-DocLayout-L.config.json"),
                .copy("Resources/Pix2Text-MFD.config.json"),
                .copy("Resources/PaddleOCR-PP-OCRv5-mobile-rec.config.json"),
                .copy("Resources/PaddleOCR-PP-OCRv5-mobile-rec.characters.json")
            ],
            linkerSettings: [.linkedLibrary("iconv", .when(platforms: [.iOS]))]
        ),
        .testTarget(name: "MetraDocumentPipelineTests", dependencies: ["MetraDocumentPipeline"])
    ],
    swiftLanguageModes: [.v5]
)
