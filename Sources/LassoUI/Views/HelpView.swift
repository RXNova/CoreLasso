import SwiftUI

public struct HelpView: View {

    @Environment(\.md3Scheme) private var scheme
    private let sections: [HelpSection]

    public init() {
        self.sections = HelpView.parsedSections()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(scheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Help & Documentation")
                            .font(MD3Typography.headlineSmall)
                            .foregroundStyle(scheme.onSurface)
                        Text("CoreLasso \u{00B7} macOS Container Manager")
                            .font(MD3Typography.bodyMedium)
                            .foregroundStyle(scheme.onSurfaceVariant)
                    }
                    Spacer()
                }
                .padding(24)
                .background(scheme.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(scheme.outlineVariant)
                        .frame(height: 1)
                }

                // Sections
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(sections) { section in
                        HelpSectionCard(section: section)
                    }
                }
                .padding(20)
            }
        }
        .background(scheme.surfaceContainerLowest.ignoresSafeArea())
        .navigationTitle("Help")
    }

    // MARK: - Markdown parser

    private static func parsedSections() -> [HelpSection] {
        guard
            let url = Bundle.module.url(forResource: "Help", withExtension: "md"),
            let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var sections: [HelpSection] = []
        var currentTitle = ""
        var currentBody: [String] = []

        for line in raw.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                if !currentTitle.isEmpty {
                    sections.append(HelpSection(title: currentTitle,
                                                body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = String(line.dropFirst(3))
                currentBody = []
            } else if !line.hasPrefix("# ") && !line.hasPrefix("---") {
                currentBody.append(line)
            }
        }
        if !currentTitle.isEmpty {
            sections.append(HelpSection(title: currentTitle,
                                        body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return sections
    }
}

// MARK: - Models

struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

// MARK: - Section card

private struct HelpSectionCard: View {
    let section: HelpSection
    @Environment(\.md3Scheme) private var scheme
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(section.title)
                        .font(MD3Typography.titleMedium)
                        .foregroundStyle(scheme.onSurface)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(MD3Typography.labelMedium)
                        .foregroundStyle(scheme.onSurfaceVariant)
                }
                .padding(.horizontal, LassoSpacing.lg.rawValue)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)

            if expanded {
                Rectangle()
                    .fill(scheme.outlineVariant.opacity(0.25))
                    .frame(height: 0.5)
                    .padding(.horizontal, LassoSpacing.md.rawValue)

                if let attr = try? AttributedString(
                    markdown: section.body,
                    options: .init(allowsExtendedAttributes: true,
                                  interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attr)
                        .font(MD3Typography.bodyMedium)
                        .foregroundStyle(scheme.onSurface)
                        .textSelection(.enabled)
                        .padding(LassoSpacing.lg.rawValue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(section.body)
                        .font(MD3Typography.bodyMedium)
                        .foregroundStyle(scheme.onSurface)
                        .textSelection(.enabled)
                        .padding(LassoSpacing.lg.rawValue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .md3Card(.outlined)
    }
}
