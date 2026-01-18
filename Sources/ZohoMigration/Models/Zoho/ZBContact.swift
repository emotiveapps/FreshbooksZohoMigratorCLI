import Foundation

struct ZBContactResponse: Codable {
    let code: Int
    let message: String
    let contact: ZBContact?
}

struct ZBContact: Codable {
    var contactId: String?
    var contactName: String
    var companyName: String?
    var contactType: String
    var customerSubType: String?
    var billingAddress: ZBAddress?
    var shippingAddress: ZBAddress?
    var contactPersons: [ZBContactPerson]?
    var currencyId: String?
    var currencyCode: String?
    var paymentTerms: Int?
    var paymentTermsLabel: String?
    var notes: String?
    var website: String?
    var taxId: String?
    var email: String?
    var phone: String?
    var mobile: String?
    var fax: String?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case contactName = "contact_name"
        case companyName = "company_name"
        case contactType = "contact_type"
        case customerSubType = "customer_sub_type"
        case billingAddress = "billing_address"
        case shippingAddress = "shipping_address"
        case contactPersons = "contact_persons"
        case currencyId = "currency_id"
        case currencyCode = "currency_code"
        case paymentTerms = "payment_terms"
        case paymentTermsLabel = "payment_terms_label"
        case notes
        case website
        case taxId = "tax_id"
        case email
        case phone
        case mobile
        case fax
    }
}

struct ZBAddress: Codable {
    var attention: String?
    var address: String?
    var street2: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?
    var phone: String?
    var fax: String?
}

struct ZBContactPerson: Codable {
    var contactPersonId: String?
    var salutation: String?
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var mobile: String?
    var isPrimaryContact: Bool?

    enum CodingKeys: String, CodingKey {
        case contactPersonId = "contact_person_id"
        case salutation
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case mobile
        case isPrimaryContact = "is_primary_contact"
    }
}

struct ZBContactCreateRequest: Codable {
    var contactName: String
    var companyName: String?
    var contactType: String
    var billingAddress: ZBAddress?
    var shippingAddress: ZBAddress?
    var contactPersons: [ZBContactPerson]?
    var currencyCode: String?
    var notes: String?
    var website: String?
    var taxId: String?

    enum CodingKeys: String, CodingKey {
        case contactName = "contact_name"
        case companyName = "company_name"
        case contactType = "contact_type"
        case billingAddress = "billing_address"
        case shippingAddress = "shipping_address"
        case contactPersons = "contact_persons"
        case currencyCode = "currency_code"
        case notes
        case website
        case taxId = "tax_id"
    }
}
