#if os(iOS)
import Foundation

/// Opt-in for authored Indonesian messages that are safe to show in the UI.
protocol TeacherUserFacingError: LocalizedError { }
extension MetraMaterialError: TeacherUserFacingError { }

#endif
