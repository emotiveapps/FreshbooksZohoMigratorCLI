import Foundation

struct MigrationResult {
    var succeeded: Int = 0
    var failed: Int = 0
    var skipped: Int = 0
    var errors: [(entity: String, error: String)] = []

    mutating func recordSuccess() {
        succeeded += 1
    }

    mutating func recordFailure(entity: String, error: String) {
        failed += 1
        errors.append((entity: entity, error: error))
    }

    mutating func recordSkip() {
        skipped += 1
    }

    func printSummary(entityType: String) {
        print("\n\(entityType) Migration Summary:")
        print("  Succeeded: \(succeeded)")
        print("  Failed: \(failed)")
        print("  Skipped: \(skipped)")
        if !errors.isEmpty {
            print("  Errors:")
            for (entity, error) in errors.prefix(10) {
                print("    - \(entity): \(error)")
            }
            if errors.count > 10 {
                print("    ... and \(errors.count - 10) more errors")
            }
        }
    }
}

class MigrationService {
    private let config: Configuration
    private let dryRun: Bool
    private let verbose: Bool

    private let oauthHelper: OAuthHelper
    private let freshBooksAPI: FreshBooksAPI
    private let zohoAPI: ZohoAPI

    private var customerIdMapping: [Int: String] = [:]
    private var vendorIdMapping: [Int: String] = [:]
    private var accountIdMapping: [Int: String] = [:]
    private var taxIdMapping: [Int: String] = [:]
    private var itemIdMapping: [Int: String] = [:]
    private var invoiceIdMapping: [Int: String] = [:]
    private var defaultExpenseAccountId: String?

    init(config: Configuration, dryRun: Bool, verbose: Bool) {
        self.config = config
        self.dryRun = dryRun
        self.verbose = verbose

        self.oauthHelper = OAuthHelper(config: config)
        self.freshBooksAPI = FreshBooksAPI(
            config: config.freshbooks,
            oauthHelper: oauthHelper,
            verbose: verbose
        )
        self.zohoAPI = ZohoAPI(
            config: config.zoho,
            oauthHelper: oauthHelper,
            verbose: verbose,
            dryRun: dryRun
        )
    }

    func migrateAll() async throws {
        print("Starting full migration from FreshBooks to Zoho Books")
        if dryRun {
            print("[DRY RUN MODE - No changes will be made]")
        }
        print("")

        try await migrateCategories()
        print("")

        try await migrateTaxes()
        print("")

        try await migrateItems()
        print("")

        try await migrateCustomers()
        print("")

        try await migrateVendors()
        print("")

        try await migrateInvoices()
        print("")

        try await migrateExpenses()
        print("")

        try await migratePayments()

        print("\n========================================")
        print("Migration Complete!")
        print("========================================")
    }

    func migrateCategories() async throws {
        print("Migrating expense categories to chart of accounts...")

        print("Fetching categories from FreshBooks...")
        let categories = try await freshBooksAPI.fetchCategories()
        print("Found \(categories.count) categories")

        if dryRun {
            print("Fetching existing accounts from Zoho (to find default)...")
        }
        let existingAccounts = try await zohoAPI.fetchAccounts()
        defaultExpenseAccountId = existingAccounts.first { $0.accountType == "expense" }?.accountId

        var result = MigrationResult()

        for category in categories {
            let request = AccountMapper.map(category)

            if verbose {
                print("  Creating account: \(request.accountName)")
            }

            do {
                if let created = try await zohoAPI.createAccount(request) {
                    if let accountId = created.accountId {
                        accountIdMapping[category.id] = accountId
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: category.name, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Categories/Accounts")
    }

    func migrateCustomers() async throws {
        print("Migrating clients to customers...")

        print("Fetching clients from FreshBooks...")
        let clients = try await freshBooksAPI.fetchClients()
        print("Found \(clients.count) clients")

        var result = MigrationResult()

        for client in clients {
            if client.visState != 0 && client.visState != nil {
                result.recordSkip()
                continue
            }

            let request = CustomerMapper.map(client)

            if verbose {
                print("  Creating customer: \(request.contactName)")
            }

            do {
                if let created = try await zohoAPI.createContact(request) {
                    if let contactId = created.contactId {
                        customerIdMapping[client.id] = contactId
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: client.displayName, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Customers")
    }

    func migrateVendors() async throws {
        print("Migrating vendors...")

        print("Fetching vendors from FreshBooks...")
        let vendors = try await freshBooksAPI.fetchVendors()
        print("Found \(vendors.count) vendors")

        var result = MigrationResult()

        for vendor in vendors {
            if vendor.visState != 0 && vendor.visState != nil {
                result.recordSkip()
                continue
            }

            let request = VendorMapper.map(vendor)

            if verbose {
                print("  Creating vendor: \(request.contactName)")
            }

            do {
                if let created = try await zohoAPI.createContact(request) {
                    if let contactId = created.contactId {
                        vendorIdMapping[vendor.id] = contactId
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: vendor.displayName, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Vendors")
    }

    func migrateInvoices() async throws {
        print("Migrating invoices...")

        if customerIdMapping.isEmpty && !dryRun {
            print("Warning: No customer ID mappings available. Running customer migration first...")
            try await migrateCustomers()
        }

        print("Fetching invoices from FreshBooks...")
        let invoices = try await freshBooksAPI.fetchInvoices()
        print("Found \(invoices.count) invoices")

        var result = MigrationResult()

        for invoice in invoices {
            if invoice.visState != 0 && invoice.visState != nil {
                result.recordSkip()
                continue
            }

            guard let request = InvoiceMapper.map(invoice, customerIdMapping: customerIdMapping) else {
                if verbose {
                    print("  Skipping invoice \(invoice.invoiceNumber ?? String(invoice.id)): no customer mapping")
                }
                result.recordSkip()
                continue
            }

            if verbose {
                print("  Creating invoice: \(request.invoiceNumber ?? "unknown")")
            }

            do {
                if let created = try await zohoAPI.createInvoice(request) {
                    if let invoiceId = created.invoiceId {
                        invoiceIdMapping[invoice.id] = invoiceId
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                let invoiceDesc = invoice.invoiceNumber ?? String(invoice.id)
                result.recordFailure(entity: invoiceDesc, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Invoices")
    }

    func migrateTaxes() async throws {
        print("Migrating taxes...")

        print("Fetching taxes from FreshBooks...")
        let taxes = try await freshBooksAPI.fetchTaxes()
        print("Found \(taxes.count) taxes")

        var result = MigrationResult()

        for tax in taxes {
            guard let request = TaxMapper.map(tax) else {
                if verbose {
                    print("  Skipping tax \(tax.id): invalid or missing name")
                }
                result.recordSkip()
                continue
            }

            if verbose {
                print("  Creating tax: \(request.taxName)")
            }

            do {
                if let created = try await zohoAPI.createTax(request) {
                    if let taxId = created.taxId {
                        taxIdMapping[tax.id] = taxId
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: tax.displayName, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Taxes")
    }

    func migrateItems() async throws {
        print("Migrating items/products...")

        if taxIdMapping.isEmpty && !dryRun {
            print("Note: No tax ID mappings available. Items will be created without tax associations.")
        }

        print("Fetching items from FreshBooks...")
        let items = try await freshBooksAPI.fetchItems()
        print("Found \(items.count) items")

        var result = MigrationResult()

        for item in items {
            if item.visState != 0 && item.visState != nil {
                result.recordSkip()
                continue
            }

            let request = ItemMapper.map(item, taxIdMapping: taxIdMapping)

            if verbose {
                print("  Creating item: \(request.name)")
            }

            do {
                if let created = try await zohoAPI.createItem(request) {
                    if let itemId = created.itemId {
                        itemIdMapping[item.id] = itemId
                    }
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: item.displayName, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Items/Products")
    }

    func migratePayments() async throws {
        print("Migrating payments...")

        if customerIdMapping.isEmpty && !dryRun {
            print("Warning: No customer ID mappings available. Running customer migration first...")
            try await migrateCustomers()
        }

        print("Fetching payments from FreshBooks...")
        let payments = try await freshBooksAPI.fetchPayments()
        print("Found \(payments.count) payments")

        var result = MigrationResult()

        for payment in payments {
            if payment.visState != 0 && payment.visState != nil {
                result.recordSkip()
                continue
            }

            guard let request = PaymentMapper.map(
                payment,
                customerIdMapping: customerIdMapping,
                invoiceIdMapping: invoiceIdMapping
            ) else {
                if verbose {
                    print("  Skipping payment \(payment.id): no customer mapping or invalid amount")
                }
                result.recordSkip()
                continue
            }

            if verbose {
                print("  Creating payment: \(request.amount) on \(request.date)")
            }

            do {
                if let _ = try await zohoAPI.createPayment(request) {
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: payment.displayName, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Payments")
    }

    func migrateExpenses() async throws {
        print("Migrating expenses...")

        if accountIdMapping.isEmpty && !dryRun {
            print("Warning: No account ID mappings available. Running category migration first...")
            try await migrateCategories()
        }

        print("Fetching expenses from FreshBooks...")
        let expenses = try await freshBooksAPI.fetchExpenses()
        print("Found \(expenses.count) expenses")

        var result = MigrationResult()

        for expense in expenses {
            if expense.visState != 0 && expense.visState != nil {
                result.recordSkip()
                continue
            }

            guard let request = ExpenseMapper.map(
                expense,
                accountIdMapping: accountIdMapping,
                vendorIdMapping: vendorIdMapping,
                customerIdMapping: customerIdMapping,
                defaultAccountId: defaultExpenseAccountId
            ) else {
                if verbose {
                    print("  Skipping expense \(expense.id): no account mapping and no default")
                }
                result.recordSkip()
                continue
            }

            if verbose {
                print("  Creating expense: \(request.description ?? String(expense.id))")
            }

            do {
                if let _ = try await zohoAPI.createExpense(request) {
                    result.recordSuccess()
                } else if dryRun {
                    result.recordSuccess()
                }
            } catch {
                let expenseDesc = expense.notes ?? String(expense.id)
                result.recordFailure(entity: expenseDesc, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        result.printSummary(entityType: "Expenses")
    }
}
