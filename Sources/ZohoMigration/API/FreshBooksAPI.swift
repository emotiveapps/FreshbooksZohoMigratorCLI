import Foundation

enum FreshBooksError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid FreshBooks API URL"
        case .httpError(let code, let message):
            return "FreshBooks API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode FreshBooks response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - token may be expired"
        }
    }
}

actor FreshBooksAPI {
    private let baseURL = "https://api.freshbooks.com"
    private let accountId: String
    private let oauthHelper: OAuthHelper
    private let verbose: Bool

    init(config: FreshBooksConfig, oauthHelper: OAuthHelper, verbose: Bool = false) {
        self.accountId = config.accountId
        self.oauthHelper = oauthHelper
        self.verbose = verbose
    }

    private func makeRequest(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw FreshBooksError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let token = await oauthHelper.freshBooksAccessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if verbose {
            print("  GET \(url.absoluteString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FreshBooksError.networkError(NSError(domain: "FreshBooks", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 {
            try await oauthHelper.refreshFreshBooksToken()
            return try await makeRequest(endpoint: endpoint, queryItems: queryItems)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FreshBooksError.httpError(httpResponse.statusCode, errorMessage)
        }

        return data
    }

    private func fetchPaginated<T: Codable>(
        endpoint: String,
        extractor: @escaping (T) -> (items: [Any], pages: Int)
    ) async throws -> [Any] {
        var allItems: [Any] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(T.self, from: data)
            let result = extractor(response)

            allItems.append(contentsOf: result.items)
            totalPages = result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(result.items.count) items")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allItems
    }

    func fetchClients() async throws -> [FBClient] {
        let endpoint = "/accounting/account/\(accountId)/users/clients"

        var allClients: [FBClient] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBClientResponse.self, from: data)

            allClients.append(contentsOf: response.response.result.clients)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.clients.count) clients")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allClients
    }

    func fetchVendors() async throws -> [FBVendor] {
        let endpoint = "/accounting/account/\(accountId)/bill_vendors/bill_vendors"

        var allVendors: [FBVendor] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBVendorResponse.self, from: data)

            allVendors.append(contentsOf: response.response.result.billVendors)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.billVendors.count) vendors")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allVendors
    }

    func fetchInvoices() async throws -> [FBInvoice] {
        let endpoint = "/accounting/account/\(accountId)/invoices/invoices"

        var allInvoices: [FBInvoice] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBInvoiceResponse.self, from: data)

            allInvoices.append(contentsOf: response.response.result.invoices)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.invoices.count) invoices")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allInvoices
    }

    func fetchExpenses() async throws -> [FBExpense] {
        let endpoint = "/accounting/account/\(accountId)/expenses/expenses"

        var allExpenses: [FBExpense] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBExpenseResponse.self, from: data)

            allExpenses.append(contentsOf: response.response.result.expenses)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.expenses.count) expenses")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allExpenses
    }

    func fetchCategories() async throws -> [FBCategory] {
        let endpoint = "/accounting/account/\(accountId)/expenses/categories"

        var allCategories: [FBCategory] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBCategoryResponse.self, from: data)

            allCategories.append(contentsOf: response.response.result.categories)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.categories.count) categories")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allCategories
    }

    func fetchItems() async throws -> [FBItem] {
        let endpoint = "/accounting/account/\(accountId)/items/items"

        var allItems: [FBItem] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBItemResponse.self, from: data)

            allItems.append(contentsOf: response.response.result.items)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.items.count) items")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allItems
    }

    func fetchTaxes() async throws -> [FBTax] {
        let endpoint = "/accounting/account/\(accountId)/taxes/taxes"

        var allTaxes: [FBTax] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBTaxResponse.self, from: data)

            allTaxes.append(contentsOf: response.response.result.taxes)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.taxes.count) taxes")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allTaxes
    }

    func fetchPayments() async throws -> [FBPayment] {
        let endpoint = "/accounting/account/\(accountId)/payments/payments"

        var allPayments: [FBPayment] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let data = try await makeRequest(endpoint: endpoint, queryItems: queryItems)
            let response = try JSONDecoder().decode(FBPaymentResponse.self, from: data)

            allPayments.append(contentsOf: response.response.result.payments)
            totalPages = response.response.result.pages

            if verbose {
                print("  Page \(currentPage)/\(totalPages) - \(response.response.result.payments.count) payments")
            }

            currentPage += 1
        } while currentPage <= totalPages

        return allPayments
    }

    /// Fetch detailed expense info to get attachment ID
    func fetchExpenseDetails(expenseId: Int) async throws -> FBExpenseDetail? {
        // Must include attachment to get attachment info
        let endpoint = "/accounting/account/\(accountId)/expenses/expenses/\(expenseId)?include[]=attachment"
        let data = try await makeRequest(endpoint: endpoint)

        struct Response: Codable {
            let response: ResponseBody
            struct ResponseBody: Codable {
                let result: ResultBody
                struct ResultBody: Codable {
                    let expense: FBExpenseDetail
                }
            }
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.response.result.expense
    }

    /// Download an expense attachment/receipt from FreshBooks
    /// Returns the file data and suggested filename, or nil if download fails
    /// The JWT is the secure temporary link returned by FreshBooks API
    func downloadAttachment(attachmentId: Int, jwt: String? = nil, mediaType: String? = nil) async throws -> (data: Data, filename: String)? {
        let token = await oauthHelper.freshBooksAccessToken

        // Build list of URLs to try - JWT-based URLs first (the secure link)
        var urlsToTry: [String] = []

        // If we have JWT, try using it as the secure download path
        if let jwt = jwt {
            urlsToTry.append("\(baseURL)/uploads/images/\(jwt)")
            urlsToTry.append("https://my.freshbooks.com/service/uploads/images/\(jwt)")
        }

        // Fallback to ID-based URLs
        urlsToTry.append("\(baseURL)/uploads/images/\(attachmentId)")
        urlsToTry.append("\(baseURL)/uploads/account/\(accountId)/attachments/\(attachmentId)")
        urlsToTry.append("\(baseURL)/uploads/account/\(accountId)/images/\(attachmentId)")

        for urlString in urlsToTry {
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            if verbose {
                print("  GET \(url.absoluteString.prefix(100))...")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { continue }

            if httpResponse.statusCode == 401 {
                try await oauthHelper.refreshFreshBooksToken()
                return try await downloadAttachment(attachmentId: attachmentId, jwt: jwt, mediaType: mediaType)
            }

            if (200...299).contains(httpResponse.statusCode) && data.count > 100 {
                // Success - got data
                var filename = "receipt_\(attachmentId)"
                // Try to get filename from Content-Disposition header
                if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                   let filenameRange = contentDisposition.range(of: "filename=") {
                    let start = filenameRange.upperBound
                    var extractedName = String(contentDisposition[start...])
                    extractedName = extractedName.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if let semicolonIndex = extractedName.firstIndex(of: ";") {
                        extractedName = String(extractedName[..<semicolonIndex])
                    }
                    if !extractedName.isEmpty {
                        filename = extractedName
                    }
                }
                // Add extension based on content type or provided media type
                if !filename.contains(".") {
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? mediaType ?? ""
                    let ext: String
                    switch contentType.lowercased() {
                    case let ct where ct.contains("jpeg") || ct.contains("jpg"): ext = ".jpg"
                    case let ct where ct.contains("png"): ext = ".png"
                    case let ct where ct.contains("gif"): ext = ".gif"
                    case let ct where ct.contains("pdf"): ext = ".pdf"
                    default: ext = ".jpg"
                    }
                    filename += ext
                }
                return (data: data, filename: filename)
            }
        }

        // All attempts failed
        if verbose {
            print("  Failed to download attachment \(attachmentId): all URL formats returned errors")
        }
        return nil
    }

    /// Legacy download method - kept for compatibility
    func downloadAttachmentLegacy(attachmentId: Int) async throws -> (data: Data, filename: String)? {
        // FreshBooks attachment endpoint
        let endpoint = "/uploads/images/\(attachmentId)"

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw FreshBooksError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let token = await oauthHelper.freshBooksAccessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if verbose {
            print("  GET \(url.absoluteString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FreshBooksError.networkError(NSError(domain: "FreshBooks", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 {
            try await oauthHelper.refreshFreshBooksToken()
            return try await downloadAttachmentLegacy(attachmentId: attachmentId)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if verbose {
                print("  Failed to download attachment \(attachmentId): HTTP \(httpResponse.statusCode)")
            }
            return nil
        }

        // Try to get filename from Content-Disposition header
        var filename = "receipt_\(attachmentId)"
        if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
           let filenameRange = contentDisposition.range(of: "filename=") {
            let start = filenameRange.upperBound
            var extractedName = String(contentDisposition[start...])
            // Remove quotes if present
            extractedName = extractedName.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            // Remove any trailing parameters
            if let semicolonIndex = extractedName.firstIndex(of: ";") {
                extractedName = String(extractedName[..<semicolonIndex])
            }
            if !extractedName.isEmpty {
                filename = extractedName
            }
        }

        // Add extension based on content type if filename doesn't have one
        if !filename.contains(".") {
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                let ext: String
                switch contentType.lowercased() {
                case let ct where ct.contains("jpeg") || ct.contains("jpg"):
                    ext = ".jpg"
                case let ct where ct.contains("png"):
                    ext = ".png"
                case let ct where ct.contains("gif"):
                    ext = ".gif"
                case let ct where ct.contains("pdf"):
                    ext = ".pdf"
                case let ct where ct.contains("webp"):
                    ext = ".webp"
                case let ct where ct.contains("heic"):
                    ext = ".heic"
                default:
                    ext = ".jpg" // Default to jpg for receipts
                }
                filename += ext
            }
        }

        return (data: data, filename: filename)
    }
}
