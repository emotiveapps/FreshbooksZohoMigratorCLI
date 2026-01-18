import Foundation

struct TaxMapper {
    static func map(_ tax: FBTax) -> ZBTaxCreateRequest? {
        guard let name = tax.name, !name.isEmpty else {
            return nil
        }

        let percentage = tax.percentage ?? 0.0

        return ZBTaxCreateRequest(
            taxName: name,
            taxPercentage: percentage,
            taxType: "tax"
        )
    }
}
