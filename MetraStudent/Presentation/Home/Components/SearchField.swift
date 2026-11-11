//
//  SearchField.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Cari judul dokumen..."
    @ScaledMetric(relativeTo: .body) private var iconInset: CGFloat = 28
    
    var body: some View {
        #if os(iOS)
        DocumentSearchInput(text: $text, placeholder: placeholder, iconInset: iconInset)
        #else
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .font(AppTypography.body)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityLabel(IndonesianSpeech.text("Cari dokumen"))
                .accessibilityHint(IndonesianSpeech.text("Ketik untuk menyaring daftar dokumen di bawah"))
                .accessibilityActions {
                    if !text.isEmpty {
                        Button(indonesian: "Hapus pencarian") { text = "" }
                    }
                }
                .padding(.leading, iconInset)
                .background(alignment: .leading) {
                    // Draw the symbol into the field background without an accessibility element.
                    Canvas { context, size in
                        let icon = Text(Image(systemName: "magnifyingglass"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                        context.draw(icon, at: CGPoint(x: 0, y: size.height / 2), anchor: .leading)
                    }
                    .frame(width: iconInset)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AppSize.Spacing.tight)
        .frame(minHeight: AppSize.Height.searchField)
        #endif
    }
}

#if os(iOS)
private struct DocumentSearchInput: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let iconInset: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .search
        field.accessibilityLabel = "Cari dokumen"
        field.accessibilityHint = "Ketik untuk menyaring daftar dokumen di bawah"
        field.accessibilityLanguage = IndonesianSpeech.languageTag

        // Keep the decorative icon inside the native field's VoiceOver frame.
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.preferredSymbolConfiguration = .init(textStyle: .body)
        icon.tintColor = .secondaryLabel
        icon.contentMode = .left
        icon.isAccessibilityElement = false
        icon.isUserInteractionEnabled = false
        field.leftView = icon
        field.leftViewMode = .always

        let clearButton = UIButton(type: .system)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.setPreferredSymbolConfiguration(.init(textStyle: .body), forImageIn: .normal)
        clearButton.tintColor = .secondaryLabel
        clearButton.contentHorizontalAlignment = .trailing
        clearButton.isAccessibilityElement = false
        clearButton.addAction(UIAction { [weak field] _ in
            field?.text = ""
            field?.sendActions(for: .editingChanged)
        }, for: .touchUpInside)
        field.rightView = clearButton

        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.addAction(UIAction { [weak field] _ in
            field?.resignFirstResponder()
        }, for: .editingDidEndOnExit)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text {
            field.text = text
        }
        field.placeholder = placeholder
        field.isEnabled = isEnabled
        field.leftView?.frame.size = CGSize(width: iconInset, height: iconInset)
        field.rightView?.frame.size = CGSize(width: iconInset, height: max(AppSize.Height.tapTarget, iconInset))
        field.rightViewMode = text.isEmpty ? .never : .always
        field.accessibilityCustomActions = text.isEmpty || !isEnabled ? nil : [
            UIAccessibilityCustomAction(name: "Hapus pencarian") { [weak field] _ in
                guard let field else { return false }
                field.text = ""
                field.sendActions(for: .editingChanged)
                return true
            }
        ]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let paddedHeight = uiView.intrinsicContentSize.height + 2 * AppSize.Spacing.tight
        return CGSize(width: width, height: max(AppSize.Height.searchField, paddedHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }
    }
}
#endif

#Preview {
    List {
        SearchField(text: .constant(""))
        SearchField(text: .constant("Aljabar"))
    }
    .listStyle(.insetGrouped)
}
