import SwiftUI

struct TimelineImageViewer: View {
    let images: [MomentImage]
    let initialIndex: Int
    let onClose: () -> Void

    @State private var selectedIndex: Int

    init(images: [MomentImage], initialIndex: Int, onClose: @escaping () -> Void) {
        self.images = images
        self.initialIndex = initialIndex
        self.onClose = onClose
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    GeometryReader { geometry in
                        AsyncImage(url: URL(string: image.url)) { phase in
                            switch phase {
                            case .success(let loadedImage):
                                loadedImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            case .failure:
                                VStack(spacing: 12) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.secondary)
                                    Text("Unable to load image")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            default:
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        }
                    }
                    .tag(index)
                    .padding(.vertical, 40)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Close image viewer")

                if images.count > 1 {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .statusBarHidden()
    }
}
