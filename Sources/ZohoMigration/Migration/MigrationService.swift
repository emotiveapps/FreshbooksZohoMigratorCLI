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
    private let useConfigMapping: Bool

    private let oauthHelper: OAuthHelper
    private let freshBooksAPI: FreshBooksAPI
    private let zohoAPI: ZohoAPI

    private var customerIdMapping: [Int: String] = [:]
    private var vendorIdMapping: [Int: String] = [:]
    private var accountIdMapping: [Int: String] = [:]
    private var configAccountIdMapping: [String: String] = [:]  // category name -> Zoho account ID
    private var taxIdMapping: [Int: String] = [:]
    private var itemIdMapping: [Int: String] = [:]
    private var invoiceIdMapping: [Int: String] = [:]
    private var defaultExpenseAccountId: String?

    // Helpers initialized from config
    private var categoryMapping: CategoryMapping?
    private var businessTagHelper: BusinessTagHelper?

    init(config: Configuration, dryRun: Bool, verbose: Bool, useConfigMapping: Bool = false) {
        self.config = config
        self.dryRun = dryRun
        self.verbose = verbose
        self.useConfigMapping = useConfigMapping

        // Initialize category mapping if configured
        if let mappingConfig = config.categoryMapping {
            self.categoryMapping = CategoryMapping(config: mappingConfig)
        }

        // Initialize business tag helper if configured
        if let tagConfig = config.businessTags {
            self.businessTagHelper = BusinessTagHelper(config: tagConfig)
        }

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
        if useConfigMapping {
            try await migrateCategoriesFromConfig()
        } else {
            try await migrateCategoriesDirect()
        }
    }

    /// Migrate categories using hierarchical Zoho chart of accounts from config
    private func migrateCategoriesFromConfig() async throws {
        print("Migrating expense categories to HIERARCHICAL chart of accounts...")

        guard let mapping = categoryMapping else {
            print("Error: Category mapping not configured. Add 'categoryMapping' section to config.json")
            return
        }

        print("Fetching categories from FreshBooks...")
        let categories = try await freshBooksAPI.fetchCategories()
        print("Found \(categories.count) FreshBooks categories")

        // Map each FB category to a Zoho category name
        var categoryToZoho: [Int: String] = [:]
        var zohoCategoriesNeeded: Set<String> = []

        for category in categories {
            let zohoName = AccountMapper.mapToZohoCategory(category, using: mapping)
            categoryToZoho[category.id] = zohoName
            zohoCategoriesNeeded.insert(zohoName)
        }

        // Determine which parent categories are needed (for categories that have parents)
        var parentCategoriesNeeded: Set<String> = []
        for zohoName in zohoCategoriesNeeded {
            if let parentName = mapping.parentName(for: zohoName) {
                parentCategoriesNeeded.insert(parentName)
            } else if mapping.isParentCategory(zohoName) {
                parentCategoriesNeeded.insert(zohoName)
            }
        }

        print("Will create \(parentCategoriesNeeded.count) parent categories and \(zohoCategoriesNeeded.count) total accounts")

        if dryRun {
            print("Fetching existing accounts from Zoho (to find default)...")
        }
        let existingAccounts = try await zohoAPI.fetchAccounts()
        defaultExpenseAccountId = existingAccounts.first { $0.accountType == "expense" }?.accountId

        var result = MigrationResult()
        var parentAccountIds: [String: String] = [:] // parent name -> Zoho account ID

        // Step 1: Create parent categories first
        print("\nCreating parent categories...")
        for parentName in parentCategoriesNeeded.sorted() {
            let isCogs = parentName.lowercased().contains("cost of goods")
            let request = AccountMapper.createAccount(parentName, parentAccountId: nil, isCogs: isCogs)

            do {
                if let created = try await zohoAPI.createAccount(request, parentInfo: nil) {
                    if let accountId = created.accountId {
                        parentAccountIds[parentName] = accountId
                        configAccountIdMapping[parentName] = accountId
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    let placeholderId = "dry-run-parent-\(parentName.replacingOccurrences(of: " ", with: "-"))"
                    parentAccountIds[parentName] = placeholderId
                    configAccountIdMapping[parentName] = placeholderId
                    if defaultExpenseAccountId == nil {
                        defaultExpenseAccountId = "dry-run-default-account"
                    }
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: parentName, error: error.localizedDescription)
            }
        }

        // Step 2: Create child categories with parent references
        print("\nCreating child categories...")
        for zohoName in zohoCategoriesNeeded.sorted() {
            // Skip if this is a parent category (already created)
            if parentCategoriesNeeded.contains(zohoName) {
                continue
            }

            let parentName = mapping.parentName(for: zohoName)
            let parentAccountId = parentName.flatMap { parentAccountIds[$0] }

            let isCogs = zohoName.lowercased().contains("cost of")
            let request = AccountMapper.createAccount(zohoName, parentAccountId: parentAccountId, isCogs: isCogs)

            let parentInfo = parentName.map { " (parent: \($0))" }

            do {
                if let created = try await zohoAPI.createAccount(request, parentInfo: parentInfo) {
                    if let accountId = created.accountId {
                        configAccountIdMapping[zohoName] = accountId
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    let placeholderId = "dry-run-child-\(zohoName.replacingOccurrences(of: " ", with: "-"))"
                    configAccountIdMapping[zohoName] = placeholderId
                    if defaultExpenseAccountId == nil {
                        defaultExpenseAccountId = "dry-run-default-account"
                    }
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: zohoName, error: error.localizedDescription)
            }
        }

        // Build accountIdMapping from FB category ID -> Zoho account ID
        for (fbCategoryId, zohoCategory) in categoryToZoho {
            if let zohoAccountId = configAccountIdMapping[zohoCategory] {
                accountIdMapping[fbCategoryId] = zohoAccountId
            }
        }

        result.printSummary(entityType: "Hierarchical Categories/Accounts")
    }

    /// Migrate categories using direct 1:1 mapping from FreshBooks
    private func migrateCategoriesDirect() async throws {
        print("Migrating expense categories to chart of accounts...")

        print("Fetching categories from FreshBooks...")
        let categories = try await freshBooksAPI.fetchCategories()
        print("Found \(categories.count) categories")

        // Build a lookup for parent category names
        let categoryLookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        // Detect and report duplicates, then deduplicate
        var seenCategories: [String: FBCategory] = [:] // deduplicationKey -> first category
        var duplicateMapping: [Int: Int] = [:] // duplicate category ID -> canonical category ID
        var uniqueCategories: [FBCategory] = []

        for category in categories {
            let key = category.deduplicationKey
            if let existing = seenCategories[key] {
                // This is a duplicate
                duplicateMapping[category.id] = existing.id

                // Report the duplicate and any differences
                let differences = category.differences(from: existing)
                let parentName = category.parentId.flatMap { categoryLookup[$0] }
                let parentInfo = parentName.map { " (parent: \($0))" } ?? ""

                if differences.isEmpty {
                    print("  [DUPLICATE] '\(category.name)'\(parentInfo) - IDs \(existing.id) and \(category.id) are identical, merging")
                } else {
                    print("  [DUPLICATE] '\(category.name)'\(parentInfo) - IDs \(existing.id) and \(category.id) differ:")
                    for diff in differences {
                        print("    - \(diff)")
                    }
                    print("    -> Merging to use ID \(existing.id)")
                }
            } else {
                seenCategories[key] = category
                uniqueCategories.append(category)
            }
        }

        if !duplicateMapping.isEmpty {
            print("Found \(duplicateMapping.count) duplicate categories, reduced to \(uniqueCategories.count) unique categories")
        }

        if dryRun {
            print("Fetching existing accounts from Zoho (to find default)...")
        }
        let existingAccounts = try await zohoAPI.fetchAccounts()
        defaultExpenseAccountId = existingAccounts.first { $0.accountType == "expense" }?.accountId

        var result = MigrationResult()

        // Process only unique categories
        for category in uniqueCategories {
            let request = AccountMapper.map(category)

            // Build display name with parent info
            let parentInfo: String
            if let parentId = category.parentId, let parentName = categoryLookup[parentId] {
                parentInfo = " (parent: \(parentName))"
            } else {
                parentInfo = ""
            }

            if verbose {
                print("  Creating account: \(request.accountName)\(parentInfo)")
            }

            do {
                if let created = try await zohoAPI.createAccount(request, parentInfo: parentInfo.isEmpty ? nil : parentInfo) {
                    if let accountId = created.accountId {
                        accountIdMapping[category.id] = accountId
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    // Populate placeholder ID for dependent migrations
                    let placeholderId = "dry-run-account-\(category.id)"
                    accountIdMapping[category.id] = placeholderId
                    if defaultExpenseAccountId == nil {
                        defaultExpenseAccountId = "dry-run-default-account"
                    }
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: category.name, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        // Map duplicate category IDs to the same Zoho account ID as their canonical category
        for (duplicateId, canonicalId) in duplicateMapping {
            if let accountId = accountIdMapping[canonicalId] {
                accountIdMapping[duplicateId] = accountId
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
                    // Populate placeholder ID for dependent migrations
                    customerIdMapping[client.id] = "dry-run-customer-\(client.id)"
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
                    // Populate placeholder ID for dependent migrations
                    vendorIdMapping[vendor.id] = "dry-run-vendor-\(vendor.id)"
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
        var customersCreatedFromInvoices = 0

        for invoice in invoices {
            if invoice.visState != 0 && invoice.visState != nil {
                result.recordSkip()
                continue
            }

            // If customer doesn't exist in mapping, try to create from invoice data
            if let customerId = invoice.customerId, customerIdMapping[customerId] == nil {
                let customerRequest = CustomerMapper.mapFromInvoice(invoice)

                do {
                    if let created = try await zohoAPI.createContact(customerRequest) {
                        if let contactId = created.contactId {
                            customerIdMapping[customerId] = contactId
                            customersCreatedFromInvoices += 1
                            print("  [CREATED CUSTOMER] '\(customerRequest.contactName)' from invoice \(invoice.invoiceNumber ?? String(invoice.id))")
                        }
                    } else if dryRun {
                        // Populate placeholder ID for dependent migrations
                        customerIdMapping[customerId] = "dry-run-customer-from-invoice-\(customerId)"
                        customersCreatedFromInvoices += 1
                        print("  [DRY RUN] Would create customer '\(customerRequest.contactName)' from invoice \(invoice.invoiceNumber ?? String(invoice.id))")
                    }
                } catch {
                    print("  [WARNING] Could not create customer from invoice \(invoice.invoiceNumber ?? String(invoice.id)): \(error.localizedDescription)")
                }
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
                    // Populate placeholder ID for dependent migrations
                    invoiceIdMapping[invoice.id] = "dry-run-invoice-\(invoice.id)"
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

        if customersCreatedFromInvoices > 0 {
            print("Created \(customersCreatedFromInvoices) customers from invoice data")
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
                    // Populate placeholder ID for dependent migrations
                    taxIdMapping[tax.id] = "dry-run-tax-\(tax.id)"
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
                    // Populate placeholder ID for dependent migrations
                    itemIdMapping[item.id] = "dry-run-item-\(item.id)"
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
        var tagCounts: [BusinessLine: Int] = [:]

        for expense in expenses {
            if expense.visState != 0 && expense.visState != nil {
                result.recordSkip()
                continue
            }

            guard let mapperResult = ExpenseMapper.map(
                expense,
                accountIdMapping: accountIdMapping,
                vendorIdMapping: vendorIdMapping,
                customerIdMapping: customerIdMapping,
                defaultAccountId: defaultExpenseAccountId,
                businessTagHelper: businessTagHelper,
                businessTagConfig: config.businessTags
            ) else {
                if verbose {
                    print("  Skipping expense \(expense.id): no account mapping and no default")
                }
                result.recordSkip()
                continue
            }

            let request = mapperResult.request
            if let businessLine = mapperResult.businessLine {
                tagCounts[businessLine, default: 0] += 1

                if verbose {
                    print("  Creating expense: \(request.description ?? String(expense.id)) [\(businessLine.name)]")
                }
            } else if verbose {
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

        // Print tag summary if business tagging is configured
        if !tagCounts.isEmpty {
            print("\nExpense Tags Summary:")
            for (line, count) in tagCounts.sorted(by: { $0.key.name < $1.key.name }) {
                print("  \(line.name): \(count)")
            }
        }

        result.printSummary(entityType: "Expenses")
    }
}
