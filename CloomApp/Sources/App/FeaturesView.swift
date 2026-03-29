import SwiftUI

// MARK: - Features View

struct FeaturesView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(AppFeature.groupedByCategory, id: \.category) { group in
                    FeatureCategorySection(
                        category: group.category,
                        features: group.features
                    )
                }
            }
            .padding(28)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Category Section

private struct FeatureCategorySection: View {
    let category: AppFeatureCategory
    let features: [AppFeature]

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(category.rawValue, systemImage: category.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(features) { feature in
                    FeatureCardView(feature: feature)
                }
            }
        }
    }
}

// MARK: - Feature Card

private struct FeatureCardView: View {
    let feature: AppFeature
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feature.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    if let shortcut = feature.shortcut {
                        ShortcutBadge(shortcut: shortcut)
                    }
                }

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(
            color: isHovered ? .cardShadowHover : .cardShadow,
            radius: isHovered ? 4 : 2,
            y: isHovered ? 2 : 1
        )
        .brightness(isHovered ? 0.02 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Shortcut Badge

private struct ShortcutBadge: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
    }
}
