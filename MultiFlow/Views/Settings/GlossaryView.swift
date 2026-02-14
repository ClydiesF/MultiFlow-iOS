import SwiftUI

struct GlossaryView: View {
    @State private var searchText = ""
    @State private var expandedTermIDs: Set<String> = []

    private var groupedTerms: [(category: GlossaryCategory, terms: [GlossaryTerm])] {
        GlossaryCatalog.groupedTerms(matching: searchText)
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchBar

                    if groupedTerms.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedTerms, id: \.category) { group in
                            section(group.category, terms: group.terms)
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glossary")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("Definitions for the core metrics and underwriting terms used in MultiFlow.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Search and tap a term to expand details.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.richBlack.opacity(0.55))
            TextField("Search terms (cap rate, cash flow, dscr...)", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Color.richBlack)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.richBlack.opacity(0.12), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No terms found")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Text("Try \"cap rate\" or \"cash flow\".")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.7))
        }
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ category: GlossaryCategory, terms: [GlossaryTerm]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.displayName)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 4)

            ForEach(terms) { term in
                termRow(term)
            }
        }
    }

    private func termRow(_ term: GlossaryTerm) -> some View {
        let isExpanded = expandedTermIDs.contains(term.id)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    if isExpanded {
                        expandedTermIDs.remove(term.id)
                    } else {
                        expandedTermIDs.insert(term.id)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryYellow.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: term.iconSystemName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.richBlack)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                            .multilineTextAlignment(.leading)
                        Text(term.definition)
                            .font(.system(.footnote, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(Color.richBlack.opacity(0.68))
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.5))
                        .padding(.top, 8)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    detailBlock(title: "Definition", body: term.definition)
                    detailBlock(title: "Why it matters", body: term.whyItMatters)

                    if let formula = term.formula, !formula.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Formula")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.7))
                            Text(formula)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.82))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.softGray)
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(term.title), \(term.category.displayName)")
    }

    private func detailBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            Text(body)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.8))
        }
    }
}

#Preview {
    NavigationStack {
        GlossaryView()
    }
}
