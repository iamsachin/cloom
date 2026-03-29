import Testing
@testable import Cloom

@Suite("AppFeature data model")
struct AppFeatureTests {

    // MARK: - Category

    @Test("All categories have a system image")
    func categoriesHaveSystemImages() {
        for category in AppFeatureCategory.allCases {
            #expect(!category.systemImage.isEmpty, "Category \(category.rawValue) missing systemImage")
        }
    }

    @Test("Category rawValues are human-readable")
    func categoryRawValues() {
        #expect(AppFeatureCategory.recording.rawValue == "Recording")
        #expect(AppFeatureCategory.editing.rawValue == "Editing")
        #expect(AppFeatureCategory.export.rawValue == "Export")
        #expect(AppFeatureCategory.ai.rawValue == "AI")
        #expect(AppFeatureCategory.library.rawValue == "Library")
    }

    @Test("Category id matches rawValue")
    func categoryIdMatchesRawValue() {
        for category in AppFeatureCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    // MARK: - Feature List

    @Test("Feature list is not empty")
    func featureListNotEmpty() {
        #expect(!AppFeature.all.isEmpty)
    }

    @Test("All feature IDs are unique")
    func uniqueFeatureIDs() {
        let ids = AppFeature.all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count, "Duplicate feature IDs found")
    }

    @Test("All features have non-empty name, description, and systemImage")
    func featureFieldsNotEmpty() {
        for feature in AppFeature.all {
            #expect(!feature.name.isEmpty, "Feature \(feature.id) has empty name")
            #expect(!feature.description.isEmpty, "Feature \(feature.id) has empty description")
            #expect(!feature.systemImage.isEmpty, "Feature \(feature.id) has empty systemImage")
        }
    }

    @Test("Every category has at least one feature")
    func allCategoriesRepresented() {
        for category in AppFeatureCategory.allCases {
            let count = AppFeature.all.filter { $0.category == category }.count
            #expect(count > 0, "Category \(category.rawValue) has no features")
        }
    }

    // MARK: - Grouping

    @Test("groupedByCategory covers all categories")
    func groupedCoversAllCategories() {
        let grouped = AppFeature.groupedByCategory
        let groupedCategories = Set(grouped.map(\.category))
        let allCategories = Set(AppFeatureCategory.allCases)
        #expect(groupedCategories == allCategories)
    }

    @Test("groupedByCategory preserves category order")
    func groupedPreservesOrder() {
        let grouped = AppFeature.groupedByCategory
        let orderedCategories = grouped.map(\.category)
        let expected = AppFeatureCategory.allCases.filter { cat in
            AppFeature.all.contains { $0.category == cat }
        }
        #expect(orderedCategories == Array(expected))
    }

    @Test("groupedByCategory total count matches all features")
    func groupedTotalCount() {
        let grouped = AppFeature.groupedByCategory
        let total = grouped.reduce(0) { $0 + $1.features.count }
        #expect(total == AppFeature.all.count)
    }

    // MARK: - Shortcuts

    @Test("Features with shortcuts have non-empty shortcut strings")
    func shortcutsNonEmpty() {
        for feature in AppFeature.all where feature.shortcut != nil {
            #expect(!feature.shortcut!.isEmpty, "Feature \(feature.id) has empty shortcut")
        }
    }

    @Test("Known features have expected shortcuts")
    func knownShortcuts() {
        let byID = Dictionary(uniqueKeysWithValues: AppFeature.all.map { ($0.id, $0) })

        #expect(byID["fullscreen-recording"]?.shortcut != nil)
        #expect(byID["pause-resume"]?.shortcut != nil)
        #expect(byID["open-library"]?.shortcut != nil)
        #expect(byID["undo-redo"]?.shortcut != nil)
        #expect(byID["shuttle-playback"]?.shortcut != nil)
    }

    // MARK: - Equatable

    @Test("AppFeature equality compares all fields")
    func featureEquality() {
        let a = AppFeature(id: "test", name: "Test", description: "Desc", shortcut: "A", systemImage: "star", category: .recording)
        let b = AppFeature(id: "test", name: "Test", description: "Desc", shortcut: "A", systemImage: "star", category: .recording)
        let c = AppFeature(id: "test", name: "Test", description: "Diff", shortcut: "A", systemImage: "star", category: .recording)
        #expect(a == b)
        #expect(a != c)
    }
}
