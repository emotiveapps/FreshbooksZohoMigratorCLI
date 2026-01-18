import Foundation

struct VendorMapper {
    static func map(_ vendor: FBVendor) -> ZBContactCreateRequest {
        let displayName = vendor.displayName.isEmpty ? "Unknown Vendor \(vendor.id)" : vendor.displayName

        var billingAddress: ZBAddress?
        if vendor.street != nil || vendor.city != nil || vendor.country != nil {
            billingAddress = ZBAddress(
                attention: nil,
                address: [vendor.street, vendor.street2].compactMap { $0 }.joined(separator: "\n"),
                street2: nil,
                city: vendor.city,
                state: vendor.province,
                zip: vendor.postalCode,
                country: vendor.country,
                phone: vendor.phone,
                fax: nil
            )
        }

        var contactPersons: [ZBContactPerson] = []
        if vendor.primaryContactFirstName != nil || vendor.primaryContactLastName != nil || vendor.primaryContactEmail != nil {
            contactPersons.append(ZBContactPerson(
                contactPersonId: nil,
                salutation: nil,
                firstName: vendor.primaryContactFirstName,
                lastName: vendor.primaryContactLastName,
                email: vendor.primaryContactEmail,
                phone: vendor.phone,
                mobile: nil,
                isPrimaryContact: true
            ))
        }

        return ZBContactCreateRequest(
            contactName: displayName,
            companyName: vendor.vendorName,
            contactType: "vendor",
            billingAddress: billingAddress,
            shippingAddress: nil,
            contactPersons: contactPersons.isEmpty ? nil : contactPersons,
            currencyCode: vendor.currencyCode,
            notes: vendor.note,
            website: vendor.website,
            taxId: vendor.taxId
        )
    }
}
