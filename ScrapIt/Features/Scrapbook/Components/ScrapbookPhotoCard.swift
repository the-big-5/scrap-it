import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ScrapbookPhotoCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var photo: ScrapPhoto
    var viewModel: ScrapbookViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                ScrapDataImageView(data: photo.imageData)
                    .frame(height: 148)
                    .frame(maxWidth: .infinity)
                    .background(ScrapTheme.filmStripDark)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if photo.livePhotoMovieData != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "livephoto")
                            .font(.system(size: 10, weight: .bold))
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(6)
                }
            }

            TextField("Add a caption...", text: $photo.caption)
                .font(.system(size: 13))
                .foregroundStyle(ScrapTheme.charcoal)
                .onSubmit {
                    viewModel.commitCaption(modelContext: modelContext)
                }

            HStack {
                Text(photo.authorName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ScrapTheme.secondaryText)
                Spacer()
                Text(viewModel.timeText(for: photo))
                    .font(.system(size: 10))
                    .foregroundStyle(ScrapTheme.secondaryText.opacity(0.8))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ScrapTheme.charcoal.opacity(0.85), lineWidth: 1)
                )
        )
    }
}
