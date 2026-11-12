//
//  SectionSentenceView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SectionSentenceView: View {
    let sentence: SectionReadingBlock.Sentence
    let onDoubleTap: () -> Void

    var body: some View {
        IndonesianSpeech.text(sentence.text)
            .font(AppTypography.readingBody)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: AppSize.Height.tapTarget, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onDoubleTap() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text(sentence.text))
            .accessibilityAction { onDoubleTap() }
            .accessibilityIdentifier("topic-sentence-\(sentence.id)")
    }
}

#Preview {
    SectionSentenceView(
        sentence: SectionReadingBlock.Sentence(id: "0.0", text: "Persamaan linear adalah persamaan aljabar."),
        onDoubleTap: {}
    )
    .padding()
}
