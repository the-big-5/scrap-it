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

    /// "Invite via AirDrop" (change 019): every built-in destination except AirDrop, plus the messaging apps
    /// we know. iOS can't open AirDrop directly or hide unknown third-party share extensions, so another app
    /// may still appear in the app row; AirDrop's nearby devices are at the top of the sheet.
    static let airDropOnlyExcludedActivityTypes: [UIActivity.ActivityType] = excludedActivityTypes + [
        .message,
        .postToFacebook,
        .postToTwitter,
        .postToWeibo,
        .postToTencentWeibo,
        .postToFlickr,
        .postToVimeo,
        .sharePlay,
        .collaborationInviteWithLink,
        .collaborationCopyLink,
        UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension"),
        UIActivity.ActivityType("ph.telegra.Telegraph.Share"),
        UIActivity.ActivityType("jp.naver.line.Share"),
        UIActivity.ActivityType("com.burbn.instagram.shareextension"),
        UIActivity.ActivityType("com.facebook.Messenger.ShareExtension"),
        UIActivity.ActivityType("com.hammerandchisel.discord.Share"),
        UIActivity.ActivityType("com.tinyspeck.chatlyio.share"),
        UIActivity.ActivityType("com.google.Gmail.ShareExtension"),
        UIActivity.ActivityType("com.apple.mobileslideshow.StreamShareService"),
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
    /// "Invite via AirDrop": everything but AirDrop hidden (change 019).
    var airDropOnly = false

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [RollInviteItemSource(content: content)],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = airDropOnly
            ? RollInviteContent.airDropOnlyExcludedActivityTypes
            : RollInviteContent.excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
