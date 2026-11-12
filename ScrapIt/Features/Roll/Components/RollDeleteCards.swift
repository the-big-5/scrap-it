import SwiftUI

/// "Delete Roll?" (change 081, Figma 1600:50620): asked before the host deletes a roll, from the lobby or from a
/// Resume Roll card.
struct DeleteRollCard: View {
    let onKeep: () -> Void
    let onDelete: () -> Void

    var body: some View {
        StarCard(
            starImage: "StarCharacterSquint",
            starSize: CGSize(width: 63, height: 133),
            titleSize: 24,
            messageSize: 15,
            title: "Delete Roll?",
            message: "This roll will be gone for good and you won’t be able to get it back.",
            actions: [
                .init(title: "Keep Roll", style: .primary, action: onKeep),
                .init(title: "Delete Roll", style: .destructive, action: onDelete),
            ],
            stacked: true,
            onDismiss: onKeep
        )
    }
}

/// "Roll Deleted" (change 081, Figma 1600:50745): no buttons, gone after about 2.5 s or on a tap.
struct RollDeletedCard: View {
    let onDismiss: () -> Void

    var body: some View {
        StarCard(
            starImage: "StarCharacterHappy",
            starSize: CGSize(width: 85, height: 108),
            titleSize: 22,
            messageSize: 16,
            title: "Roll Deleted",
            message: "All set. Start a new roll whenever you’re ready.",
            actions: [],
            onDismiss: onDismiss
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            onDismiss()
        }
    }
}
