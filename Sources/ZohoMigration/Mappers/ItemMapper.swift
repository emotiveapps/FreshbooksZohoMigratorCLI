import Foundation

struct ItemMapper {
    static func map(_ item: FBItem, taxIdMapping: [Int: String] = [:]) -> ZBItemCreateRequest {
        let name = item.name ?? "Item \(item.id)"

        var rate: Double?
        if let unitCost = item.unitCost, let amountStr = unitCost.amount {
            rate = Double(amountStr)
        }

        var taxId: String?
        if let tax1 = item.tax1 {
            taxId = taxIdMapping[tax1]
        }

        return ZBItemCreateRequest(
            name: name,
            description: item.description,
            rate: rate,
            unit: nil,
            sku: item.sku,
            taxId: taxId,
            productType: "goods"
        )
    }
}
