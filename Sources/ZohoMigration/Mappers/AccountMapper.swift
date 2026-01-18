import Foundation

struct AccountMapper {
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
}
