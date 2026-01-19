import Foundation

struct InvoiceMapper {
    /// Determines if a FreshBooks invoice should be marked as "sent" in Zoho Books.
    /// Returns true if the FreshBooks status indicates it was sent (not draft).
    static func shouldMarkAsSent(_ invoice: FBInvoice) -> Bool {
        // Check v3Status first (more reliable string status)
        if let v3Status = invoice.v3Status?.lowercased() {
            // If it's anything other than draft, it should be marked as sent
            return v3Status != "draft"
        }

        // Fallback to numeric status if v3Status not available
        // FreshBooks status: 1 = draft, 2 = sent, etc.
        if let status = invoice.status {
            return status >= 2
        }

        // Default to not sent if we can't determine
        return false
    }

    static func map(
        _ invoice: FBInvoice,
        customerIdMapping: [Int: String],
        taxMapping: [String: String] = [:],  // FreshBooks taxName (lowercased) -> Zoho taxId
        servicesExemptionId: String? = nil  // Tax exemption ID for non-taxable line items
    ) -> ZBInvoiceCreateRequest? {
        guard let customerId = invoice.customerId,
              let zohoCustomerId = customerIdMapping[customerId] else {
            return nil
        }

        var lineItems: [ZBInvoiceLineItemRequest] = []
        if let lines = invoice.lines {
            for line in lines {
                let rate: Double
                if let unitCost = line.unitCost?.amount, let value = Double(unitCost) {
                    rate = value
                } else {
                    rate = 0
                }

                let quantity: Double
                if let qty = line.qty, let value = Double(qty) {
                    quantity = value
                } else {
                    quantity = 1
                }

                // Only apply tax if the FreshBooks line actually has a non-zero tax amount
                var taxId: String? = nil
                var isTaxable: Bool = false
                if let fbTaxName = line.taxName1, !fbTaxName.isEmpty,
                   let taxAmountStr = line.taxAmount1,
                   let taxAmount = Double(taxAmountStr), taxAmount > 0 {
                    taxId = taxMapping[fbTaxName.lowercased()]
                    isTaxable = true
                }

                lineItems.append(ZBInvoiceLineItemRequest(
                    name: line.name ?? "Item",
                    description: line.description,
                    rate: rate,
                    quantity: quantity,
                    taxId: taxId,
                    isTaxable: isTaxable,
                    taxExemptionId: isTaxable ? nil : servicesExemptionId
                ))
            }
        }

        if lineItems.isEmpty {
            if let amount = invoice.amount?.amount, let value = Double(amount) {
                lineItems.append(ZBInvoiceLineItemRequest(
                    name: "Invoice Total",
                    description: invoice.description,
                    rate: value,
                    quantity: 1,
                    taxId: nil,
                    isTaxable: false,
                    taxExemptionId: servicesExemptionId
                ))
            }
        }

        return ZBInvoiceCreateRequest(
            customerId: zohoCustomerId,
            invoiceNumber: invoice.invoiceNumber,
            referenceNumber: invoice.poNumber,
            date: invoice.createDate,
            dueDate: invoice.dueDate,
            currencyCode: invoice.currencyCode,
            lineItems: lineItems,
            notes: invoice.notes,
            terms: invoice.terms,
            paymentTerms: 15,
            isInclusiveTax: false
        )
    }
}
