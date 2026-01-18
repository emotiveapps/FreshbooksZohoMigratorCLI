import ArgumentParser
import Foundation

@main
struct ZohoMigration: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoho-migration",
        abstract: "Migrate data from FreshBooks to Zoho Books",
        version: "1.0.0",
        subcommands: [Migrate.self],
        defaultSubcommand: Migrate.self
    )
}

struct Migrate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Migrate entities from FreshBooks to Zoho Books",
        subcommands: [All.self, Customers.self, Vendors.self, Invoices.self, Expenses.self, Categories.self, Items.self, Payments.self]
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
        includeItems: options.includeItems
    )
}
