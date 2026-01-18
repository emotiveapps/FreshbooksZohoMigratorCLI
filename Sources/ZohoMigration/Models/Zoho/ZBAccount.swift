import Foundation

struct ZBAccountResponse: Codable {
    let code: Int
    let message: String
    let chartOfAccount: ZBAccount?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case chartOfAccount = "chart_of_account"
    }
}

struct ZBAccountListResponse: Codable {
    let code: Int
    let message: String
    let chartOfAccounts: [ZBAccount]?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case chartOfAccounts = "chart_of_accounts"
    }
}

struct ZBAccount: Codable {
    var accountId: String?
    var accountName: String?
    var accountCode: String?
    var accountType: String?
    var description: String?
    var isActive: Bool?
    var isUserCreated: Bool?
    var isSystemAccount: Bool?
    var parentAccountId: String?
    var parentAccountName: String?
    var depth: Int?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case accountName = "account_name"
        case accountCode = "account_code"
        case accountType = "account_type"
        case description
        case isActive = "is_active"
        case isUserCreated = "is_user_created"
        case isSystemAccount = "is_system_account"
        case parentAccountId = "parent_account_id"
        case parentAccountName = "parent_account_name"
        case depth
    }
}

struct ZBAccountCreateRequest: Codable {
    var accountName: String
    var accountType: String
    var accountCode: String?
    var description: String?
    var parentAccountId: String?

    enum CodingKeys: String, CodingKey {
        case accountName = "account_name"
        case accountType = "account_type"
        case accountCode = "account_code"
        case description
        case parentAccountId = "parent_account_id"
    }
}

struct ZBAccountUpdateRequest: Codable {
    var accountName: String?
    var parentAccountId: String?

    enum CodingKeys: String, CodingKey {
        case accountName = "account_name"
        case parentAccountId = "parent_account_id"
    }
}

enum ZBAccountType: String, Codable {
    case otherAsset = "other_asset"
    case otherCurrentAsset = "other_current_asset"
    case cash = "cash"
    case bank = "bank"
    case fixedAsset = "fixed_asset"
    case otherCurrentLiability = "other_current_liability"
    case creditCard = "credit_card"
    case longTermLiability = "long_term_liability"
    case otherLiability = "other_liability"
    case equity = "equity"
    case income = "income"
    case otherIncome = "other_income"
    case expense = "expense"
    case costOfGoodsSold = "cost_of_goods_sold"
    case otherExpense = "other_expense"
    case accountsReceivable = "accounts_receivable"
    case accountsPayable = "accounts_payable"
}
