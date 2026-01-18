import Foundation

struct ExpenseMapper {
    static func map(
        _ expense: FBExpense,
        accountIdMapping: [Int: String],
        vendorIdMapping: [Int: String],
        customerIdMapping: [Int: String],
        defaultAccountId: String?
    ) -> ZBExpenseCreateRequest? {
        let zohoAccountId: String
        if let categoryId = expense.categoryId,
           let mappedId = accountIdMapping[categoryId] {
            zohoAccountId = mappedId
        } else if let defaultId = defaultAccountId {
            zohoAccountId = defaultId
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

        return ZBExpenseCreateRequest(
            accountId: zohoAccountId,
            paidThroughAccountId: nil,
            vendorId: zohoVendorId,
            date: date,
            amount: amount,
            taxId: nil,
            isBillable: expense.billable,
            customerId: zohoCustomerId,
            projectId: nil,
            currencyCode: expense.amount?.code,
            referenceNumber: expense.transactionId.map { String($0) },
            description: expense.notes
        )
    }
}
