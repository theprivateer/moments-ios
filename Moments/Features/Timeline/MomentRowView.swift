import SwiftUI

struct MomentRowView: View {
    let moment: Moment
    @State private var attributedBody: AttributedString?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let attributedBody {
                Text(attributedBody)
                    .foregroundStyle(.primary)
            } else if let plainBody = moment.body {
                Text(plainBody)
                    .font(.body)
            }

            if !moment.images.isEmpty {
                let columns = moment.images.count == 1
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(moment.images) { image in
                        AsyncImage(url: URL(string: image.url)) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            default:
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .overlay(ProgressView())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4/3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .task(id: moment.id) {
            guard let html = moment.bodyHTML, !html.isEmpty else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Self.parseHTML(html)
            }.value
            attributedBody = result
        }
    }

    private var relativeTimestamp: String {
        let date = parseDate(moment.createdAt)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func parseDate(_ string: String) -> Date {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string) ?? Date()
    }

    private static func parseHTML(_ html: String) -> AttributedString? {
        let styledHTML = """
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 17px; }
        p { margin: 0 0 14px 0; }
        p:last-child { margin-bottom: 0; }
        </style>
        \(html)
        """
        guard let data = styledHTML.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let nsAttr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        guard var result: AttributedString = try? AttributedString(nsAttr, including: \.uiKit) else { return nil }
        for run in result.runs {
            result[run.range].uiKit.foregroundColor = nil
        }
        return result
    }
}
