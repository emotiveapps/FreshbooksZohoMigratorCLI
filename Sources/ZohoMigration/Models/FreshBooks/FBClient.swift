import Foundation

struct FBClientResponse: Codable {
    let response: FBClientResponseBody
}

struct FBClientResponseBody: Codable {
    let result: FBClientResult
}

struct FBClientResult: Codable {
    let clients: [FBClient]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case clients
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBClient: Codable, Identifiable {
    let id: Int
    let accountingSystemId: String?
    let busPhone: String?
    let companyIndustry: String?
    let companySize: String?
    let currencyCode: String?
    let email: String?
    let fax: String?
    let fname: String?
    let homePhone: String?
    let language: String?
    let lname: String?
    let mobPhone: String?
    let note: String?
    let organization: String?
    let pCity: String?
    let pCode: String?
    let pCountry: String?
    let pProvince: String?
    let pStreet: String?
    let pStreet2: String?
    let sCity: String?
    let sCode: String?
    let sCountry: String?
    let sProvince: String?
    let sStreet: String?
    let sStreet2: String?
    let userId: Int?
    let vatName: String?
    let vatNumber: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case accountingSystemId = "accounting_systemid"
        case busPhone = "bus_phone"
        case companyIndustry = "company_industry"
        case companySize = "company_size"
        case currencyCode = "currency_code"
        case email
        case fax
        case fname
        case homePhone = "home_phone"
        case language
        case lname
        case mobPhone = "mob_phone"
        case note
        case organization
        case pCity = "p_city"
        case pCode = "p_code"
        case pCountry = "p_country"
        case pProvince = "p_province"
        case pStreet = "p_street"
        case pStreet2 = "p_street2"
        case sCity = "s_city"
        case sCode = "s_code"
        case sCountry = "s_country"
        case sProvince = "s_province"
        case sStreet = "s_street"
        case sStreet2 = "s_street2"
        case userId = "userid"
        case vatName = "vat_name"
        case vatNumber = "vat_number"
        case visState = "vis_state"
    }

    var displayName: String {
        if let org = organization, !org.isEmpty {
            return org
        }
        let first = fname ?? ""
        let last = lname ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
}
