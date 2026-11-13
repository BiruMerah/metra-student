import SwiftUI

private struct AppearSensoryFeedbackModifier: ViewModifier {
    let feedback: SensoryFeedback
    @State private var appearTrigger = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTrigger.toggle()
            }
            .sensoryFeedback(feedback, trigger: appearTrigger)
    }
}

extension View {
    /// Plays SwiftUI sensory feedback each time this view appears.
    func sensoryFeedbackOnAppear(_ feedback: SensoryFeedback = .impact(weight: .medium)) -> some View {
        modifier(AppearSensoryFeedbackModifier(feedback: feedback))
    }
}
