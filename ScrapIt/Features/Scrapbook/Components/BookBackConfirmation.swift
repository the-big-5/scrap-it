import SwiftUI

/// Back from the book view asks first (change 025, Figma 1533:25816; copy from change 121).
struct BookBackConfirmation: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        BookStarCard(
            title: "Leave the scrapbook?",
            message: "Your changes are saved. You can come back and continue editing anytime.",
            actions: [
                .init(title: "Cancel", style: .plain, action: onCancel),
                .init(title: "Go to Home", style: .primary, action: onConfirm),
            ],
            onDismiss: onCancel
        )
    }
}
