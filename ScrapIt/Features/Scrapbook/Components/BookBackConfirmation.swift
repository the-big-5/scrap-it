import SwiftUI

/// Back from the book view asks first (change 025, Figma 1533:25816). The copy is still the Figma placeholder until
/// copywriting is ready [Open].
struct BookBackConfirmation: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        BookStarCard(
            title: "Back to … ?",
            message: "Your scrapbook can be saved and continue to be edited later apalah",
            actions: [
                .init(title: "Cancel", style: .plain, action: onCancel),
                .init(title: "Yes", style: .primary, action: onConfirm),
            ],
            onDismiss: onCancel
        )
    }
}
