import Foundation

/// Helper for category mapping operations
struct CategoryMapping {
    let config: CategoryMappingConfig

    init(config: CategoryMappingConfig) {
        self.config = config
    }

    /// Get the Zoho category name for a FreshBooks category name
    /// Uses explicit mapping if configured, otherwise returns the same name
    func getZohoCategory(for fbCategoryName: String) -> String {
        return config.getZohoCategory(for: fbCategoryName)
    }

    /// Get all parent categories that will be created
    var parentCategories: [String] {
        return config.parentCategories
    }

    /// Get children for a parent category
    func children(for parentName: String) -> [String] {
        return config.children(for: parentName)
    }

    /// Get all category names (parents and children flattened)
    var allCategoryNames: [String] {
        return config.allCategoryNames
    }

    /// Find which parent a category belongs to (nil if it's a parent itself or not found)
    func parentName(for categoryName: String) -> String? {
        return config.parentName(for: categoryName)
    }

    /// Check if a category name is a parent (top-level) category
    func isParentCategory(_ name: String) -> Bool {
        return config.parentCategories.contains(name)
    }

    /// Check if a category name exists in the config (as parent or child)
    func categoryExists(_ name: String) -> Bool {
        return config.allCategoryNames.contains(name)
    }

    /// Get a default/fallback category name for unmapped categories
    var defaultCategory: String {
        // Look for "Other Expenses" or similar
        if let other = config.allCategoryNames.first(where: { $0.lowercased().contains("other") }) {
            return other
        }
        // Fall back to first parent category
        return config.parentCategories.first ?? "Other Expenses"
    }
}
