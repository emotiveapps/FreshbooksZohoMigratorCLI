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
}
