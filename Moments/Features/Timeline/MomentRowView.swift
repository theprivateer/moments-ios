import SwiftUI

struct MomentRowView: View {
    let moment: Moment
    @State private var paragraphs: [AttributedString] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !paragraphs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                        Text(para)
                            .foregroundStyle(.primary)
                    }
                }
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
                Self.splitParagraphs(html).compactMap { Self.parseFragment($0) }
            }.value
            paragraphs = result
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

    private static func splitParagraphs(_ html: String) -> [String] {
        // Two-level split:
        //   1. Walk <pre> boundaries (keeps nested <p> inside <pre> intact).
        //   2. For every prose chunk, further split on <p> boundaries.
        var result: [String] = []
        var remaining = html[...]
        let prePattern = /<pre[^>]*>[\s\S]*?<\/pre>/
        while let match = remaining.firstMatch(of: prePattern) {
            let prose = String(remaining[..<match.range.lowerBound])
            result.append(contentsOf: splitByParagraphs(prose))
            result.append(String(match.output))
            remaining = remaining[match.range.upperBound...]
        }
        result.append(contentsOf: splitByParagraphs(String(remaining)))
        return result.isEmpty ? [html] : result
    }

    private static func splitByParagraphs(_ html: String) -> [String] {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let matches = trimmed.matches(of: /<p[^>]*>[\s\S]*?<\/p>/)
        let fragments = matches.map { String($0.output) }
        return fragments.isEmpty ? [trimmed] : fragments
    }

    private static func parseFragment(_ html: String) -> AttributedString? {
        let styledHTML = """
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 17px; }
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
        // Trim the trailing \n the HTML parser always appends. That \n carries
        // NSParagraphStyle.paragraphSpacing for <p> blocks; removing it makes all
        // fragment bottoms uniform so only the VStack spacing controls gaps.
        let mutable = nsAttr.mutableCopy() as! NSMutableAttributedString
        while mutable.length > 0 && mutable.string.hasSuffix("\n") {
            mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
        }
        guard var result = try? AttributedString(mutable, including: \.uiKit) else { return nil }
        for run in result.runs {
            result[run.range].uiKit.foregroundColor = nil
        }
        return result
    }
}
