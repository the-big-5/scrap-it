import SwiftUI

/// Picks photos from this scrapbook's roll (own and friends', Live Photos marked) for the current page
/// (change 013, POC picker). Selection order is the order they are added.
struct ScrapbookPhotoPickerView: View {
    let photos: [ScrapPhoto]
    /// Free slots on the page.
    let limit: Int
    let onAdd: ([UUID]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selection: [UUID] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    ContentUnavailableView {
                        Label("No photos yet", systemImage: "photo.on.rectangle")
                    } description: {
                        Text("Photos from this roll appear here.")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos, id: \.id) { photo in
                                cell(for: photo)
                            }
                        }
                    }
                }
            }
            .navigationTitle(selection.isEmpty ? "Choose Photos" : "\(selection.count) Selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(selection)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selection.count >= limit {
                    Text("Up to \(ScrapbookPage.maxItems) items per page")
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.regularMaterial))
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func cell(for photo: ScrapPhoto) -> some View {
        let order = selection.firstIndex(of: photo.id)
        return Button {
            toggle(photo.id)
        } label: {
            PhotoThumbnail(photo: photo)
                .overlay(alignment: .topLeading) {
                    if photo.livePhotoMovieData != nil {
                        Image(systemName: "livephoto")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().fill(order == nil ? Color.black.opacity(0.25) : Color.accentColor)
                        Circle().stroke(.white, lineWidth: 1.5)
                        if let order {
                            Text("\(order + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .padding(5)
                }
                .opacity(order == nil && selection.count >= limit ? 0.4 : 1)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: UUID) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else if selection.count < limit {
            selection.append(id)
        }
    }
}

/// Square, downsampled thumbnail.
private struct PhotoThumbnail: View {
    let photo: ScrapPhoto
    @State private var image: UIImage?

    var body: some View {
        Color(white: 0.85)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: photo.id) {
                image = await ScrapbookImageLoader.shared.image(for: photo.id, data: photo.imageData, pixelSize: 400)
            }
    }
}
