import Foundation

struct CustomerMapper {
    static func map(_ client: FBClient) -> ZBContactCreateRequest {
        let displayName = client.displayName.isEmpty ? "Unknown Client \(client.id)" : client.displayName

        var billingAddress: ZBAddress?
        if client.pStreet != nil || client.pCity != nil || client.pCountry != nil {
            billingAddress = ZBAddress(
                attention: nil,
                address: [client.pStreet, client.pStreet2].compactMap { $0 }.joined(separator: "\n"),
                street2: nil,
                city: client.pCity,
                state: client.pProvince,
                zip: client.pCode,
                country: client.pCountry,
                phone: nil,
                fax: nil
            )
        }

        var shippingAddress: ZBAddress?
        if client.sStreet != nil || client.sCity != nil || client.sCountry != nil {
            shippingAddress = ZBAddress(
                attention: nil,
                address: [client.sStreet, client.sStreet2].compactMap { $0 }.joined(separator: "\n"),
                street2: nil,
                city: client.sCity,
                state: client.sProvince,
                zip: client.sCode,
                country: client.sCountry,
                phone: nil,
                fax: nil
            )
        }

        var contactPersons: [ZBContactPerson] = []
        if client.fname != nil || client.lname != nil || client.email != nil {
            contactPersons.append(ZBContactPerson(
                contactPersonId: nil,
                salutation: nil,
                firstName: client.fname,
                lastName: client.lname,
                email: client.email,
                phone: client.busPhone ?? client.homePhone,
                mobile: client.mobPhone,
                isPrimaryContact: true
            ))
        }

        return ZBContactCreateRequest(
            contactName: displayName,
            companyName: client.organization,
            contactType: "customer",
            billingAddress: billingAddress,
            shippingAddress: shippingAddress,
            contactPersons: contactPersons.isEmpty ? nil : contactPersons,
            currencyCode: client.currencyCode,
            notes: client.note,
            website: nil,
            taxId: client.vatNumber
        )
    }
}
