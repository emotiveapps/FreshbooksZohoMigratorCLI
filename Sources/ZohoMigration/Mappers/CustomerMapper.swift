import Foundation

struct CustomerMapper {
    /// Create a customer from FBClient data
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

    /// Create a customer from invoice data (for archived/deleted customers)
    static func mapFromInvoice(_ invoice: FBInvoice) -> ZBContactCreateRequest {
        // Build display name from invoice data
        let displayName: String
        if let org = invoice.organization, !org.isEmpty {
            displayName = org
        } else if let currentOrg = invoice.currentOrganization, !currentOrg.isEmpty {
            displayName = currentOrg
        } else {
            let first = invoice.fname ?? ""
            let last = invoice.lname ?? ""
            let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            displayName = fullName.isEmpty ? "Unknown Customer \(invoice.customerId ?? invoice.id)" : fullName
        }

        // Build billing address from invoice data
        var billingAddress: ZBAddress?
        if invoice.street != nil || invoice.city != nil || invoice.country != nil {
            billingAddress = ZBAddress(
                attention: nil,
                address: [invoice.street, invoice.street2].compactMap { $0 }.joined(separator: "\n"),
                street2: nil,
                city: invoice.city,
                state: invoice.province,
                zip: invoice.code,
                country: invoice.country,
                phone: nil,
                fax: nil
            )
        }

        // Build contact person from invoice data
        var contactPersons: [ZBContactPerson] = []
        if invoice.fname != nil || invoice.lname != nil {
            contactPersons.append(ZBContactPerson(
                contactPersonId: nil,
                salutation: nil,
                firstName: invoice.fname,
                lastName: invoice.lname,
                email: nil,  // Invoice doesn't have email
                phone: nil,
                mobile: nil,
                isPrimaryContact: true
            ))
        }

        return ZBContactCreateRequest(
            contactName: displayName,
            companyName: invoice.organization ?? invoice.currentOrganization,
            contactType: "customer",
            billingAddress: billingAddress,
            shippingAddress: nil,
            contactPersons: contactPersons.isEmpty ? nil : contactPersons,
            currencyCode: invoice.currencyCode,
            notes: "Created from invoice \(invoice.invoiceNumber ?? String(invoice.id))",
            website: nil,
            taxId: invoice.vatNumber
        )
    }
}
