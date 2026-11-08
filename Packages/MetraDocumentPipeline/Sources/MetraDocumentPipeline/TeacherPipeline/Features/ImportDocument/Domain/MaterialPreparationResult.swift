#if os(iOS)
import Foundation

struct TeacherExtractionResult: Sendable {
    let material: StudyMaterial
    let runID: String
    let groupingNote: String
}

struct TeacherConversionRecovery: Error {
    let assessments: [TeacherPageAssessment]
    let partialResult: TeacherExtractionResult?
}

#endif
