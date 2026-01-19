import Foundation

struct ExpenseMapperResult {
    let request: ZBExpenseCreateRequest
    let businessLine: BusinessLine?
    let categoryName: String?
    let paidThroughMapped: Bool
    let unmappedPaidThrough: String?  // FreshBooks account name that wasn't mapped
}

struct ExpenseMapper {
    static func map(
        _ expense: FBExpense,
        accountIdMapping: [Int: String],
        accountNameMapping: [String: String],  // accountId -> category name
        vendorIdMapping: [Int: String],
        customerIdMapping: [Int: String],
        paidThroughMapping: [String: String],  // FreshBooks accountName (lowercased) -> Zoho accountId
        taxMapping: [String: String],          // FreshBooks taxName (lowercased) -> Zoho taxId
        defaultAccountId: String?,
        businessTagHelper: BusinessTagHelper? = nil,
        businessTagConfig: BusinessTagConfig? = nil
    ) -> ExpenseMapperResult? {
        let zohoAccountId: String
        var categoryName: String? = nil

        if let categoryId = expense.categoryId,
           let mappedId = accountIdMapping[categoryId] {
            zohoAccountId = mappedId
            categoryName = accountNameMapping[mappedId]
        } else if let defaultId = defaultAccountId {
            zohoAccountId = defaultId
            categoryName = accountNameMapping[defaultId] ?? "Uncategorized"
        } else {
            return nil
        }

        let amount: Double
        if let expenseAmount = expense.amount?.amount, let value = Double(expenseAmount) {
            amount = value
        } else {
            return nil
        }

        let date = expense.date ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        var zohoVendorId: String?
        if let vendorId = expense.vendorId {
            zohoVendorId = vendorIdMapping[vendorId]
        }

        var zohoCustomerId: String?
        if let clientId = expense.clientId {
            zohoCustomerId = customerIdMapping[clientId]
        }

        // Determine business line if tagging is configured
        var businessLine: BusinessLine? = nil
        var tags: [ZBTag]? = nil

        if let helper = businessTagHelper {
            businessLine = helper.determineBusinessLine(date: expense.date, description: expense.notes)

            // Build tags array if Zoho tag IDs are configured
            if let tagConfig = businessTagConfig,
               let tagId = tagConfig.zohoTagId,
               let primaryOptionId = tagConfig.zohoPrimaryOptionId,
               let secondaryOptionId = tagConfig.zohoSecondaryOptionId {
                let tagOptionId: String
                switch businessLine {
                case .secondary:
                    tagOptionId = secondaryOptionId
                default:
                    tagOptionId = primaryOptionId
                }
                tags = [ZBTag(tagId: tagId, tagOptionId: tagOptionId)]
            }
        }

        // Look up paid-through account from FreshBooks accountName
        var paidThroughAccountId: String? = nil
        var paidThroughMapped = false
        var unmappedPaidThrough: String? = nil

        if let fbAccountName = expense.accountName, !fbAccountName.isEmpty {
            if let mappedId = paidThroughMapping[fbAccountName.lowercased()] {
                paidThroughAccountId = mappedId
                paidThroughMapped = true
            } else {
                unmappedPaidThrough = fbAccountName
            }
        } else {
            // Empty/nil account name is normal for manually entered or Gusto-imported expenses
            paidThroughMapped = true
        }

        // Look up tax ID from FreshBooks taxName1
        var taxId: String? = nil
        if let fbTaxName = expense.taxName1?.lowercased() {
            taxId = taxMapping[fbTaxName]
        }

        let request = ZBExpenseCreateRequest(
            accountId: zohoAccountId,
            paidThroughAccountId: paidThroughAccountId,
            vendorId: zohoVendorId,
            date: date,
            amount: amount,
            taxId: taxId,
            isBillable: expense.billable,
            customerId: zohoCustomerId,
            projectId: nil,
            currencyCode: expense.amount?.code,
            referenceNumber: expense.transactionId.map { String($0) },
            description: expense.notes,
            tags: tags
        )

        return ExpenseMapperResult(
            request: request,
            businessLine: businessLine,
            categoryName: categoryName,
            paidThroughMapped: paidThroughMapped,
            unmappedPaidThrough: unmappedPaidThrough
        )
    }
}
