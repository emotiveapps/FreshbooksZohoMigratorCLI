import Foundation

struct AccountMapper {
    /// Map a FreshBooks category to a Zoho account (direct mapping)
    static func map(_ category: FBCategory) -> ZBAccountCreateRequest {
        let accountType: String
        if category.isCogs == true {
            accountType = "cost_of_goods_sold"
        } else {
            accountType = "expense"
        }

        return ZBAccountCreateRequest(
            accountName: category.name,
            accountType: accountType,
            accountCode: category.categoryId.map { String($0) },
            description: "Imported from FreshBooks category",
            parentAccountId: nil
        )
    }

    /// Map a FreshBooks category to a Zoho category name using config
    static func mapToZohoCategory(_ category: FBCategory, using mapping: CategoryMapping) -> String {
        return mapping.getZohoCategory(for: category.name)
    }

    /// Create a Zoho account request for a category (parent or child)
    /// - Parameters:
    ///   - categoryName: The name of the category to create
    ///   - parentAccountId: The Zoho account ID of the parent (nil for top-level categories)
    ///   - isCogs: Whether this is a Cost of Goods Sold category
    static func createAccount(
        _ categoryName: String,
        parentAccountId: String? = nil,
        isCogs: Bool = false
    ) -> ZBAccountCreateRequest {
        let accountType = isCogs ? "cost_of_goods_sold" : "expense"
        let description = parentAccountId != nil
            ? "Sub-account imported from FreshBooks"
            : "Parent account imported from FreshBooks"

        return ZBAccountCreateRequest(
            accountName: categoryName,
            accountType: accountType,
            accountCode: nil,
            description: description,
            parentAccountId: parentAccountId
        )
    }
}
