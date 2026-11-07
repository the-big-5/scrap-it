import LinkPresentation
import SwiftUI
import UIKit

/// Invite content for a roll (change 011).
/// AirDrop gets the iCloud link only (opens ScrapIt and joins); messaging apps get a text-only CTA with the link.
struct RollInviteContent: Equatable {
    let rollName: String
    let rollCode: String
    let link: URL

    /// Text for Messages, WhatsApp and other messaging apps [Draft]. No image.
    var message: String {
        "Join my roll \u{201C}\(rollName)\u{201D} on \(AppBrand.name)! 📸\nRoll code: \(rollCode)\n\(link.absoluteString)"
    }

    /// AirDrop: the link alone; everything else: the message.
    func item(for activityType: UIActivity.ActivityType?) -> Any {
        activityType == .airDrop ? link : message
    }

    /// Only AirDrop and messaging apps (user decision). iOS cannot whitelist apps, so the built-in
    /// non-messaging destinations are excluded; a third-party non-messaging app may still show up.
    static let excludedActivityTypes: [UIActivity.ActivityType] = [
        .mail,
        .print,
        .copyToPasteboard,
        .assignToContact,
        .saveToCameraRoll,
        .addToReadingList,
        .openInIBooks,
        .markupAsPDF,
        UIActivity.ActivityType("com.apple.reminders.sharingextension"),
        UIActivity.ActivityType("com.apple.mobilenotes.SharingExtension"),
        UIActivity.ActivityType("com.apple.freeform.sharingextension"),
        UIActivity.ActivityType("com.apple.DocumentManagerUICore.SaveToFiles"),
    ]
}

/// Picks the shared item after the user chooses a destination.
final class RollInviteItemSource: NSObject, UIActivityItemSource {
    let content: RollInviteContent

    init(content: RollInviteContent) {
        self.content = content
    }

    /// A URL placeholder keeps AirDrop available.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        content.link
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        content.item(for: activityType)
    }

    /// Share sheet preview: title only, no image.
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Join \u{201C}\(content.rollName)\u{201D} on \(AppBrand.name)"
        metadata.originalURL = content.link
        return metadata
    }
}

/// System share sheet (Figma 768:1623) with the invite item source.
struct RollInviteShareSheet: UIViewControllerRepresentable {
    let content: RollInviteContent

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [RollInviteItemSource(content: content)],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = RollInviteContent.excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
