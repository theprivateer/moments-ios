import SwiftUI

struct AttachedImagesStrip: View {
    let uploads: [AttachedImageUpload]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(uploads) { upload in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: upload.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        stateOverlay(for: upload.state)

                        Button {
                            onRemove(upload.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .font(.system(size: 18))
                        }
                        .accessibilityLabel("Remove photo")
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func stateOverlay(for state: AttachedImageUpload.UploadState) -> some View {
        switch state {
        case .uploading:
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.4))
                .frame(width: 80, height: 80)
                .overlay {
                    ProgressView()
                        .tint(.white)
                }
        case .failed:
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.4))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 24))
                        .accessibilityLabel("Upload failed")
                }
        case .uploaded:
            EmptyView()
        }
    }
}
