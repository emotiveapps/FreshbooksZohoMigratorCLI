import Foundation

struct Configuration: Codable {
    let freshbooks: FreshBooksConfig
    let zoho: ZohoConfig

    static func load(from path: String) throws -> Configuration {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Configuration.self, from: data)
    }
}

struct FreshBooksConfig: Codable {
    let clientId: String
    let clientSecret: String
    var accessToken: String
    var refreshToken: String
    let accountId: String
}

struct ZohoConfig: Codable {
    let clientId: String
    let clientSecret: String
    var accessToken: String
    var refreshToken: String
    let organizationId: String
    let region: String

    var baseURL: String {
        switch region.lowercased() {
        case "eu":
            return "https://www.zohoapis.eu/books/v3"
        case "in":
            return "https://www.zohoapis.in/books/v3"
        case "au":
            return "https://www.zohoapis.com.au/books/v3"
        default:
            return "https://www.zohoapis.com/books/v3"
        }
    }

    var oauthURL: String {
        switch region.lowercased() {
        case "eu":
            return "https://accounts.zoho.eu/oauth/v2/token"
        case "in":
            return "https://accounts.zoho.in/oauth/v2/token"
        case "au":
            return "https://accounts.zoho.com.au/oauth/v2/token"
        default:
            return "https://accounts.zoho.com/oauth/v2/token"
        }
    }
}

enum ConfigurationError: LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found at: \(path)"
        case .invalidFormat(let message):
            return "Invalid configuration format: \(message)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        }
    }
}
