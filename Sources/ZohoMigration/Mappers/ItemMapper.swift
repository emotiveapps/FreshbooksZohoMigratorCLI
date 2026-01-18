import Foundation

struct ItemMapper {
    static func map(_ item: FBItem) -> ZBItemCreateRequest {
        let name = item.name ?? "Item \(item.id)"

        var rate: Double?
        if let unitCost = item.unitCost, let amountStr = unitCost.amount {
            rate = Double(amountStr)
        }

        return ZBItemCreateRequest(
            name: name,
            description: item.description,
            rate: rate,
            unit: nil,
            sku: item.sku,
            taxId: nil,
            productType: "goods"
        )
    }
}
