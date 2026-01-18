import Foundation

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

enum OAuthError: LocalizedError {
    case refreshFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .refreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidResponse:
            return "Invalid OAuth response"
        case .networkError(let error):
            return "Network error during OAuth: \(error.localizedDescription)"
        }
    }
}

actor OAuthHelper {
    private var freshBooksToken: String
    private var freshBooksRefreshToken: String
    private let freshBooksClientId: String
    private let freshBooksClientSecret: String

    private var zohoToken: String
    private var zohoRefreshToken: String
    private let zohoClientId: String
    private let zohoClientSecret: String
    private let zohoOAuthURL: String

    init(config: Configuration) {
        self.freshBooksToken = config.freshbooks.accessToken
        self.freshBooksRefreshToken = config.freshbooks.refreshToken
        self.freshBooksClientId = config.freshbooks.clientId
        self.freshBooksClientSecret = config.freshbooks.clientSecret

        self.zohoToken = config.zoho.accessToken
        self.zohoRefreshToken = config.zoho.refreshToken
        self.zohoClientId = config.zoho.clientId
        self.zohoClientSecret = config.zoho.clientSecret
        self.zohoOAuthURL = config.zoho.oauthURL
    }

    var freshBooksAccessToken: String {
        freshBooksToken
    }

    var zohoAccessToken: String {
        zohoToken
    }

    func refreshFreshBooksToken() async throws {
        let url = URL(string: "https://api.freshbooks.com/auth/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": freshBooksClientId,
            "client_secret": freshBooksClientSecret,
            "refresh_token": freshBooksRefreshToken
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.refreshFailed(errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        freshBooksToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            freshBooksRefreshToken = newRefresh
        }

        print("FreshBooks token refreshed successfully")
    }

    func refreshZohoToken() async throws {
        var components = URLComponents(string: zohoOAuthURL)!
        components.queryItems = [
            URLQueryItem(name: "refresh_token", value: zohoRefreshToken),
            URLQueryItem(name: "client_id", value: zohoClientId),
            URLQueryItem(name: "client_secret", value: zohoClientSecret),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.refreshFailed(errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        zohoToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            zohoRefreshToken = newRefresh
        }

        print("Zoho token refreshed successfully")
    }
}
