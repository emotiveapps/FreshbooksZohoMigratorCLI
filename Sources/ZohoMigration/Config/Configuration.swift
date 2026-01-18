import Foundation

struct Configuration: Codable {
    let freshbooks: FreshBooksConfig
    let zoho: ZohoConfig
    let categoryMapping: CategoryMappingConfig?
    let businessTags: BusinessTagConfig?

    static func load(from path: String) throws -> Configuration {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Configuration.self, from: data)
    }
}

/// Configuration for a single category (with optional children for hierarchy)
struct CategoryConfig: Codable {
    let name: String
    let children: [String]?

    init(name: String, children: [String]? = nil) {
        self.name = name
        self.children = children
    }
}

/// Configuration for hierarchical category mapping
struct CategoryMappingConfig: Codable {
    /// Hierarchical list of categories to create in Zoho (with optional children)
    let categories: [CategoryConfig]

    /// Mapping from FreshBooks category name (case-insensitive) to Zoho category name
    /// If empty, uses 1:1 mapping (same name in Zoho as FreshBooks)
    let mapping: [String: String]

    /// Get all parent category names
    var parentCategories: [String] {
        return categories.map { $0.name }
    }

    /// Get children for a parent category
    func children(for parentName: String) -> [String] {
        return categories.first { $0.name == parentName }?.children ?? []
    }

    /// Get all category names (parents and children flattened)
    var allCategoryNames: [String] {
        var names: [String] = []
        for category in categories {
            names.append(category.name)
            if let children = category.children {
                names.append(contentsOf: children)
            }
        }
        return names
    }

    /// Find which parent a child category belongs to (nil if it's a parent or not found)
    func parentName(for childName: String) -> String? {
        for category in categories {
            if let children = category.children, children.contains(childName) {
                return category.name
            }
        }
        return nil
    }

    /// Get the mapped Zoho category for a FreshBooks category name
    /// Returns the mapped name if found in mapping, otherwise returns the original name
    func getZohoCategory(for fbCategoryName: String) -> String {
        let normalized = fbCategoryName.lowercased().trimmingCharacters(in: .whitespaces)
        // Try mapping first
        if let result = mapping.first(where: { $0.key.lowercased() == normalized })?.value {
            return result
        }
        // Default to same name (1:1 mapping)
        return fbCategoryName
    }
}

/// Configuration for business line tagging
struct BusinessTagConfig: Codable {
    /// Tag name for the primary business (e.g., "Emotive Apps (EA)")
    let primaryTag: String

    /// Tag name for the secondary business (e.g., "Lucky Frog Bricks (LF)")
    let secondaryTag: String

    /// Date when secondary business started (format: "YYYY-MM-DD")
    /// Expenses before this date are tagged with primaryTag
    let secondaryStartDate: String

    /// Keywords that indicate secondary business expenses (case-insensitive)
    let secondaryKeywords: [String]

    /// Zoho tracking category IDs (optional, for actual API calls)
    let zohoTagId: String?
    let zohoPrimaryOptionId: String?
    let zohoSecondaryOptionId: String?
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
