import Foundation

enum ZohoError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case rateLimited
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Zoho Books API URL"
        case .httpError(let code, let message):
            return "Zoho Books API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode Zoho response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - token may be expired"
        case .rateLimited:
            return "Rate limited - too many requests"
        case .apiError(let code, let message):
            return "Zoho API error (\(code)): \(message)"
        }
    }
}

actor ZohoAPI {
    private let baseURL: String
    private let organizationId: String
    private let oauthHelper: OAuthHelper
    private let verbose: Bool
    private let dryRun: Bool

    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 100

    init(config: ZohoConfig, oauthHelper: OAuthHelper, verbose: Bool = false, dryRun: Bool = false) {
        self.baseURL = config.baseURL
        self.organizationId = config.organizationId
        self.oauthHelper = oauthHelper
        self.verbose = verbose
        self.dryRun = dryRun
    }

    private func checkRateLimit() async {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }

        if requestTimestamps.count >= maxRequestsPerMinute {
            let oldestRequest = requestTimestamps.first!
            let waitTime = 60 - now.timeIntervalSince(oldestRequest)
            if waitTime > 0 {
                print("Rate limit approaching, waiting \(Int(waitTime)) seconds...")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        requestTimestamps.append(now)
    }

    private func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        retryOnAuth: Bool = true
    ) async throws -> Data {
        await checkRateLimit()

        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        // Append organization_id to existing query items (don't replace them)
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "organization_id", value: organizationId))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ZohoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        let token = await oauthHelper.zohoAccessToken
        request.setValue("Zoho-oauthtoken \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        if verbose {
            print("  \(method) \(url.absoluteString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZohoError.networkError(NSError(domain: "Zoho", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 && retryOnAuth {
            try await oauthHelper.refreshZohoToken()
            return try await makeRequest(endpoint: endpoint, method: method, body: body, retryOnAuth: false)
        }

        if httpResponse.statusCode == 429 {
            print("Rate limited, waiting 60 seconds...")
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return try await makeRequest(endpoint: endpoint, method: method, body: body, retryOnAuth: retryOnAuth)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ZohoError.httpError(httpResponse.statusCode, errorMessage)
        }

        return data
    }

    func createContact(_ contact: ZBContactCreateRequest) async throws -> ZBContact? {
        if dryRun {
            print("  [DRY RUN] Would create contact: \(contact.contactName)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(contact)

        let data = try await makeRequest(endpoint: "/contacts", method: "POST", body: body)

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBContactResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.contact
    }

    func createInvoice(_ invoice: ZBInvoiceCreateRequest) async throws -> ZBInvoice? {
        if dryRun {
            print("  [DRY RUN] Would create invoice: \(invoice.invoiceNumber ?? "unknown")")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(invoice)

        let data = try await makeRequest(endpoint: "/invoices", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBInvoiceResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.invoice
    }

    /// Mark an invoice as sent without sending an email to the customer
    func markInvoiceAsSent(_ invoiceId: String, invoiceNumber: String? = nil) async throws {
        let displayNum = invoiceNumber ?? invoiceId
        if dryRun {
            print("  [DRY RUN] Would mark invoice \(displayNum) as sent")
            return
        }

        _ = try await makeRequest(endpoint: "/invoices/\(invoiceId)/status/sent", method: "POST")
    }

    func createExpense(_ expense: ZBExpenseCreateRequest, categoryName: String? = nil, businessTag: String? = nil) async throws -> ZBExpense? {
        if dryRun {
            let desc = expense.description ?? "unknown"
            let category = categoryName ?? "Unknown"
            let tag = businessTag ?? "--"
            print("  [DRY RUN] \(expense.date) | \(tag) | \(category) | \(desc) | $\(String(format: "%.2f", expense.amount))")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(expense)

        let data = try await makeRequest(endpoint: "/expenses", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBExpenseResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.expense
    }

    func createAccount(_ account: ZBAccountCreateRequest, parentInfo: String? = nil) async throws -> ZBAccount? {
        if dryRun {
            let suffix = parentInfo ?? ""
            print("  [DRY RUN] Would create account: \(account.accountName)\(suffix)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(account)

        let data = try await makeRequest(endpoint: "/chartofaccounts", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBAccountResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.chartOfAccount
    }

    func updateAccount(_ accountId: String, request: ZBAccountUpdateRequest) async throws -> ZBAccount? {
        if dryRun {
            print("  [DRY RUN] Would update account: \(accountId)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)

        let data = try await makeRequest(endpoint: "/chartofaccounts/\(accountId)", method: "PUT", body: body)

        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBAccountResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.chartOfAccount
    }

    func fetchAccounts() async throws -> [ZBAccount] {
        let data = try await makeRequest(endpoint: "/chartofaccounts")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBAccountListResponse.self, from: data)

        return response.chartOfAccounts ?? []
    }

    func createItem(_ item: ZBItemCreateRequest) async throws -> ZBItem? {
        if dryRun {
            print("  [DRY RUN] Would create item: \(item.name)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(item)

        let data = try await makeRequest(endpoint: "/items", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBItemResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.item
    }

    func createTax(_ tax: ZBTaxCreateRequest) async throws -> ZBTax? {
        if dryRun {
            print("  [DRY RUN] Would create tax: \(tax.taxName)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(tax)

        let data = try await makeRequest(endpoint: "/settings/taxes", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBTaxResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.tax
    }

    func fetchTaxes() async throws -> [ZBTax] {
        let data = try await makeRequest(endpoint: "/settings/taxes")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBTaxListResponse.self, from: data)

        return response.taxes ?? []
    }

    func createPayment(_ payment: ZBPaymentCreateRequest) async throws -> ZBPayment? {
        if dryRun {
            print("  [DRY RUN] Would create payment: \(payment.amount) on \(payment.date)")
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(payment)

        let data = try await makeRequest(endpoint: "/customerpayments", method: "POST", body: body)

        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let response = try decoder.decode(ZBPaymentResponse.self, from: data)

        if response.code != 0 {
            throw ZohoError.apiError(response.code, response.message)
        }

        return response.payment
    }

    func fetchItems() async throws -> [ZBItem] {
        let data = try await makeRequest(endpoint: "/items")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBItemListResponse.self, from: data)

        return response.items ?? []
    }

    func fetchContacts(contactType: String? = nil) async throws -> [ZBContact] {
        var allContacts: [ZBContact] = []
        var page = 1
        let perPage = 200  // Zoho's max per page

        while true {
            var endpoint = "/contacts?page=\(page)&per_page=\(perPage)"
            if let type = contactType {
                endpoint += "&contact_type=\(type)"
            }
            let data = try await makeRequest(endpoint: endpoint)

            // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
            let decoder = JSONDecoder()
            let response = try decoder.decode(ZBContactListResponse.self, from: data)

            if let contacts = response.contacts {
                allContacts.append(contentsOf: contacts)
            }

            // Check if there are more pages
            if let pageContext = response.pageContext, pageContext.hasMorePage == true {
                page += 1
            } else {
                break
            }
        }

        return allContacts
    }

    func fetchInvoices() async throws -> [ZBInvoice] {
        let data = try await makeRequest(endpoint: "/invoices")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBInvoiceListResponse.self, from: data)

        return response.invoices ?? []
    }

    func fetchExpenses() async throws -> [ZBExpense] {
        let data = try await makeRequest(endpoint: "/expenses")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBExpenseListResponse.self, from: data)

        return response.expenses ?? []
    }

    func fetchPayments() async throws -> [ZBPayment] {
        let data = try await makeRequest(endpoint: "/customerpayments")

        // Don't use .convertFromSnakeCase - conflicts with explicit CodingKeys
        let decoder = JSONDecoder()
        let response = try decoder.decode(ZBPaymentListResponse.self, from: data)

        return response.customerpayments ?? []
    }

    /// Upload an attachment/receipt to an expense in Zoho Books
    func uploadExpenseAttachment(expenseId: String, fileData: Data, filename: String) async throws {
        if dryRun {
            print("    [DRY RUN] Would upload attachment: \(filename)")
            return
        }

        await checkRateLimit()

        var components = URLComponents(string: "\(baseURL)/expenses/\(expenseId)/attachment")!
        components.queryItems = [URLQueryItem(name: "organization_id", value: organizationId)]

        guard let url = components.url else {
            throw ZohoError.invalidURL
        }

        // Create multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let token = await oauthHelper.zohoAccessToken
        request.setValue("Zoho-oauthtoken \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"attachment\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)

        // Determine content type from filename
        let contentType: String
        let lowercaseFilename = filename.lowercased()
        if lowercaseFilename.hasSuffix(".jpg") || lowercaseFilename.hasSuffix(".jpeg") {
            contentType = "image/jpeg"
        } else if lowercaseFilename.hasSuffix(".png") {
            contentType = "image/png"
        } else if lowercaseFilename.hasSuffix(".gif") {
            contentType = "image/gif"
        } else if lowercaseFilename.hasSuffix(".pdf") {
            contentType = "application/pdf"
        } else if lowercaseFilename.hasSuffix(".webp") {
            contentType = "image/webp"
        } else if lowercaseFilename.hasSuffix(".heic") {
            contentType = "image/heic"
        } else {
            contentType = "application/octet-stream"
        }

        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        if verbose {
            print("    POST \(url.absoluteString) (uploading \(filename), \(fileData.count) bytes)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZohoError.networkError(NSError(domain: "Zoho", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 {
            try await oauthHelper.refreshZohoToken()
            return try await uploadExpenseAttachment(expenseId: expenseId, fileData: fileData, filename: filename)
        }

        if httpResponse.statusCode == 429 {
            print("Rate limited, waiting 60 seconds...")
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return try await uploadExpenseAttachment(expenseId: expenseId, fileData: fileData, filename: filename)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ZohoError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
}
