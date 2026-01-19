import ArgumentParser
import Foundation

@main
struct ZohoMigration: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoho-migration",
        abstract: "Migrate data from FreshBooks to Zoho Books",
        version: "1.0.0",
        subcommands: [Migrate.self, Auth.self],
        defaultSubcommand: Migrate.self
    )
}

struct Auth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Authenticate with FreshBooks or Zoho to get new OAuth tokens"
    )

    @Option(name: .long, help: "Path to configuration file")
    var config: String = "./config.json"

    @Option(name: .long, help: "Custom redirect URI (must match what's registered in the app)")
    var redirectUri: String?

    @Argument(help: "Service to authenticate: 'freshbooks' or 'zoho'")
    var service: String

    func run() async throws {
        let configData = try Configuration.load(from: config)

        switch service.lowercased() {
        case "freshbooks", "fb":
            try await authenticateFreshBooks(config: configData, customRedirectUri: redirectUri)
        case "zoho":
            try await authenticateZoho(config: configData, customRedirectUri: redirectUri)
        default:
            print("Unknown service: \(service)")
            print("Use 'freshbooks' or 'zoho'")
            return
        }
    }

    func authenticateFreshBooks(config: Configuration, customRedirectUri: String?) async throws {
        let clientId = config.freshbooks.clientId
        let clientSecret = config.freshbooks.clientSecret
        let redirectUri = customRedirectUri ?? "https://localhost:8080/callback"

        // Build authorization URL
        var components = URLComponents(string: "https://my.freshbooks.com/service/auth/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
        ]

        let authURL = components.url!.absoluteString

        print("FreshBooks OAuth Authentication")
        print("================================")
        print("")
        print("1. Open this URL in your browser:")
        print("")
        print("   \(authURL)")
        print("")
        print("2. Log in to FreshBooks and authorize the application")
        print("")
        print("3. After authorization, you'll be redirected to localhost.")
        print("   Copy the 'code' parameter from the URL and paste it below.")
        print("")
        print("Enter the authorization code: ", terminator: "")

        guard let code = readLine(), !code.isEmpty else {
            print("No code entered. Aborting.")
            return
        }

        // Exchange code for tokens
        print("\nExchanging code for tokens...")

        let tokenURL = URL(string: "https://api.freshbooks.com/auth/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectUri
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }

        if httpResponse.statusCode != 200 {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed: \(error)")
            return
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        print("\nSuccess! New tokens obtained.")
        print("")
        print("Update your config.json with these values:")
        print("")
        print("  \"accessToken\": \"\(tokenResponse.accessToken)\",")
        if let refreshToken = tokenResponse.refreshToken {
            print("  \"refreshToken\": \"\(refreshToken)\"")

            // Try to update config.json automatically
            try updateConfigFile(
                configPath: self.config,
                service: "freshbooks",
                accessToken: tokenResponse.accessToken,
                refreshToken: refreshToken
            )
        }
    }

    func authenticateZoho(config: Configuration, customRedirectUri: String?) async throws {
        let clientId = config.zoho.clientId
        let clientSecret = config.zoho.clientSecret
        let redirectUri = customRedirectUri ?? "https://localhost:8080/callback"

        // Determine OAuth URL based on region
        let authBaseURL: String
        let tokenURL: String
        switch config.zoho.region.lowercased() {
        case "eu":
            authBaseURL = "https://accounts.zoho.eu/oauth/v2/auth"
            tokenURL = "https://accounts.zoho.eu/oauth/v2/token"
        case "in":
            authBaseURL = "https://accounts.zoho.in/oauth/v2/auth"
            tokenURL = "https://accounts.zoho.in/oauth/v2/token"
        case "au":
            authBaseURL = "https://accounts.zoho.com.au/oauth/v2/auth"
            tokenURL = "https://accounts.zoho.com.au/oauth/v2/token"
        default:
            authBaseURL = "https://accounts.zoho.com/oauth/v2/auth"
            tokenURL = "https://accounts.zoho.com/oauth/v2/token"
        }

        var components = URLComponents(string: authBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: "ZohoBooks.fullaccess.all"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        let authURL = components.url!.absoluteString

        print("Zoho OAuth Authentication")
        print("=========================")
        print("")
        print("1. Open this URL in your browser:")
        print("")
        print("   \(authURL)")
        print("")
        print("2. Log in to Zoho and authorize the application")
        print("")
        print("3. After authorization, you'll be redirected to localhost.")
        print("   Copy the 'code' parameter from the URL and paste it below.")
        print("")
        print("Enter the authorization code: ", terminator: "")

        guard let code = readLine(), !code.isEmpty else {
            print("No code entered. Aborting.")
            return
        }

        // Exchange code for tokens
        print("\nExchanging code for tokens...")

        var tokenComponents = URLComponents(string: tokenURL)!
        tokenComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
        ]

        var request = URLRequest(url: tokenComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }

        if httpResponse.statusCode != 200 {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed: \(error)")
            return
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        print("\nSuccess! New tokens obtained.")
        print("")
        print("Update your config.json with these values:")
        print("")
        print("  \"accessToken\": \"\(tokenResponse.accessToken)\",")
        if let refreshToken = tokenResponse.refreshToken {
            print("  \"refreshToken\": \"\(refreshToken)\"")

            // Try to update config.json automatically
            try updateConfigFile(
                configPath: self.config,
                service: "zoho",
                accessToken: tokenResponse.accessToken,
                refreshToken: refreshToken
            )
        } else {
            print("\n  Note: No refresh token returned. You may need to add 'access_type=offline' and 'prompt=consent' to get one.")
        }
    }

    func updateConfigFile(configPath: String, service: String, accessToken: String, refreshToken: String) throws {
        let url = URL(fileURLWithPath: configPath)
        let data = try Data(contentsOf: url)

        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var serviceConfig = json[service] as? [String: Any] else {
            print("\nCould not automatically update config.json. Please update manually.")
            return
        }

        serviceConfig["accessToken"] = accessToken
        serviceConfig["refreshToken"] = refreshToken
        json[service] = serviceConfig

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try updatedData.write(to: url)

        print("\nconfig.json has been updated automatically!")
    }
}

struct Migrate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Migrate entities from FreshBooks to Zoho Books",
        subcommands: [All.self, Customers.self, Vendors.self, Invoices.self, Expenses.self, Categories.self, Items.self, Payments.self, UpdateInvoiceStatuses.self, ExpenseAttachments.self]
    )

    @OptionGroup var options: MigrationOptions

    struct All: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate all entities"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateAll()
        }
    }

    struct Customers: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate customers only"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateCustomers()
        }
    }

    struct Vendors: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate vendors only"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateVendors()
        }
    }

    struct Invoices: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate invoices only"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateInvoices()
        }
    }

    struct Expenses: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate expenses only"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateExpenses()
        }
    }

    struct Categories: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate expense categories to chart of accounts"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateCategories()
        }
    }

    struct Items: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate items/products"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateItems()
        }
    }

    struct Payments: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Migrate customer payments"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migratePayments()
        }
    }

    struct UpdateInvoiceStatuses: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update-invoice-statuses",
            abstract: "Update status of existing Zoho invoices based on FreshBooks status (e.g., DRAFT -> SENT)"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.updateInvoiceStatuses()
        }
    }

    struct ExpenseAttachments: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "expense-attachments",
            abstract: "Migrate receipts/attachments for existing expenses (matches by date + amount + description)"
        )

        @OptionGroup var options: MigrationOptions

        func run() async throws {
            let service = try createMigrationService(options: options)
            try await service.migrateExpenseAttachments()
        }
    }
}

struct MigrationOptions: ParsableArguments {
    @Flag(name: .long, help: "Perform a dry run without making changes")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Use hierarchical category mapping from config (creates parent/child accounts in Zoho)")
    var useConfigMapping: Bool = false

    @Flag(name: .long, help: "Include items/products migration (usually unnecessary - invoice line items are created inline)")
    var includeItems: Bool = false

    @Flag(name: .long, help: "Include expense attachments/receipts (downloads from FreshBooks and uploads to Zoho)")
    var includeAttachments: Bool = false

    @Option(name: .long, help: "Path to configuration file")
    var config: String = "./config.json"
}

func createMigrationService(options: MigrationOptions) throws -> MigrationService {
    let config = try Configuration.load(from: options.config)
    return MigrationService(
        config: config,
        dryRun: options.dryRun,
        verbose: options.verbose,
        useConfigMapping: options.useConfigMapping,
        includeItems: options.includeItems,
        includeAttachments: options.includeAttachments
    )
}
