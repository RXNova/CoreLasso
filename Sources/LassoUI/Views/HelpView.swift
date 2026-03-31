import SwiftUI

public struct HelpView: View {

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
                        .foregroundStyle(LassoColors.antBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Help & Documentation")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(LassoColors.antTextPrimary)
                        Text("CoreLasso · macOS Container Manager")
                            .font(.subheadline)
                            .foregroundStyle(LassoColors.antTextSecondary)
                    }
                    Spacer()
                }
                .padding(24)
                .background(LassoColors.antCardBg)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LassoColors.antBorder)
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
        .background(LassoColors.antPageBg.ignoresSafeArea())
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
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(LassoColors.antTextPrimary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LassoColors.antTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LassoColors.arcTableHeader)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)

            if expanded {
                Divider()
                // Render markdown body via AttributedString
                if let attr = try? AttributedString(
                    markdown: section.body,
                    options: .init(allowsExtendedAttributes: true,
                                  interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attr)
                        .font(.body)
                        .foregroundStyle(LassoColors.antTextPrimary)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(section.body)
                        .font(.body)
                        .foregroundStyle(LassoColors.antTextPrimary)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}
