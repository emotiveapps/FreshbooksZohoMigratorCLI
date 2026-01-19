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
    private let includeItems: Bool
    private let includeAttachments: Bool

    private let oauthHelper: OAuthHelper
    private let freshBooksAPI: FreshBooksAPI
    private let zohoAPI: ZohoAPI

    private var customerIdMapping: [Int: String] = [:]
    private var vendorIdMapping: [Int: String] = [:]
    private var accountIdMapping: [Int: String] = [:]
    private var configAccountIdMapping: [String: String] = [:]  // category name -> Zoho account ID
    private var accountNameMapping: [String: String] = [:]  // Zoho account ID -> category name (reverse)
    private var itemIdMapping: [Int: String] = [:]
    private var invoiceIdMapping: [Int: String] = [:]
    private var defaultExpenseAccountId: String?

    // Helpers initialized from config
    private var categoryMapping: CategoryMapping?
    private var businessTagHelper: BusinessTagHelper?

    init(config: Configuration, dryRun: Bool, verbose: Bool, useConfigMapping: Bool = false, includeItems: Bool = false, includeAttachments: Bool = false) {
        self.config = config
        self.dryRun = dryRun
        self.verbose = verbose
        self.useConfigMapping = useConfigMapping
        self.includeItems = includeItems
        self.includeAttachments = includeAttachments

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

        if includeItems {
            try await migrateItems()
        } else {
            print("Skipping items/products migration (use --include-items to enable)")
        }
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

        // Fetch existing accounts from Zoho to avoid duplicates
        print("Fetching existing accounts from Zoho...")
        let existingAccounts = try await zohoAPI.fetchAccounts()
        var existingByName: [String: String] = [:] // name (lowercased) -> accountId
        var existingAccountsByName: [String: ZBAccount] = [:] // name (lowercased) -> full account
        for account in existingAccounts {
            if let accountId = account.accountId, let name = account.accountName {
                existingByName[name.lowercased()] = accountId
                existingAccountsByName[name.lowercased()] = account
            }
        }
        print("Found \(existingAccounts.count) existing accounts in Zoho")
        defaultExpenseAccountId = existingAccounts.first { $0.accountType == "expense" }?.accountId

        print("Fetching categories from FreshBooks...")
        let categories = try await freshBooksAPI.fetchCategories()
        print("Found \(categories.count) FreshBooks categories")

        // IMPORTANT: Only create categories that are explicitly defined in config.json
        // Use ALL categories from config, not derived from FreshBooks
        let zohoCategoriesNeeded: Set<String> = Set(mapping.allCategoryNames)
        let parentCategoriesNeeded: Set<String> = Set(mapping.parentCategories)

        print("Will create \(parentCategoriesNeeded.count) parent categories and \(zohoCategoriesNeeded.count - parentCategoriesNeeded.count) child categories from config")

        // Map each FB category to a Zoho category name (only if target exists in config)
        var categoryToZoho: [Int: String] = [:]
        var unmappedCategories: [String] = []

        for category in categories {
            let zohoName = AccountMapper.mapToZohoCategory(category, using: mapping)

            // Only accept mapping if target category exists in config
            if mapping.categoryExists(zohoName) {
                categoryToZoho[category.id] = zohoName
            } else {
                // Use fallback category for unmapped FreshBooks categories
                let fallback = mapping.defaultCategory
                categoryToZoho[category.id] = fallback
                unmappedCategories.append("\(category.name) -> \(fallback)")
            }
        }

        if !unmappedCategories.isEmpty {
            print("\nNote: \(unmappedCategories.count) FreshBooks categories mapped to fallback:")
            for msg in unmappedCategories.prefix(10) {
                print("  - \(msg)")
            }
            if unmappedCategories.count > 10 {
                print("  ... and \(unmappedCategories.count - 10) more")
            }
        }

        var result = MigrationResult()
        var parentAccountIds: [String: String] = [:] // parent name -> Zoho account ID
        var existingCount = 0

        // Step 1: Create parent categories first
        print("\nProcessing parent categories...")
        for parentName in parentCategoriesNeeded.sorted() {
            let nameLower = parentName.lowercased()

            // Check if parent already exists
            if let existingId = existingByName[nameLower] {
                parentAccountIds[parentName] = existingId
                configAccountIdMapping[parentName] = existingId
                accountNameMapping[existingId] = parentName
                existingCount += 1
                if verbose {
                    print("  [EXISTS] Parent: \(parentName)")
                }
                result.recordSuccess()
                continue
            }

            let isCogs = parentName.lowercased().contains("cost of goods")
            let request = AccountMapper.createAccount(parentName, parentAccountId: nil, isCogs: isCogs)

            do {
                if let created = try await zohoAPI.createAccount(request, parentInfo: nil) {
                    if let accountId = created.accountId {
                        parentAccountIds[parentName] = accountId
                        configAccountIdMapping[parentName] = accountId
                        accountNameMapping[accountId] = parentName
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    let placeholderId = "dry-run-parent-\(parentName.replacingOccurrences(of: " ", with: "-"))"
                    parentAccountIds[parentName] = placeholderId
                    configAccountIdMapping[parentName] = placeholderId
                    accountNameMapping[placeholderId] = parentName
                    if defaultExpenseAccountId == nil {
                        defaultExpenseAccountId = "dry-run-default-account"
                    }
                    result.recordSuccess()
                }
            } catch let error as ZohoError {
                // Check if error is "already exists" - if so, fetch and use existing account
                if case .apiError(let code, _) = error, code == 11002 {
                    // Account already exists - re-fetch to get its ID
                    let refreshedAccounts = try await zohoAPI.fetchAccounts()
                    if let existing = refreshedAccounts.first(where: { $0.accountName?.lowercased() == nameLower }) {
                        if let accountId = existing.accountId {
                            parentAccountIds[parentName] = accountId
                            configAccountIdMapping[parentName] = accountId
                            accountNameMapping[accountId] = parentName
                            existingByName[nameLower] = accountId
                            if defaultExpenseAccountId == nil {
                                defaultExpenseAccountId = accountId
                            }
                            if verbose {
                                print("  [EXISTS] Parent: \(parentName) (found after create attempt)")
                            }
                            result.recordSuccess()
                            continue
                        }
                    }
                }
                result.recordFailure(entity: parentName, error: error.localizedDescription)
            } catch {
                result.recordFailure(entity: parentName, error: error.localizedDescription)
            }
        }

        // Step 2: Create child categories with parent references
        print("\nProcessing child categories...")
        for zohoName in zohoCategoriesNeeded.sorted() {
            // Skip if this is a parent category (already handled)
            if parentCategoriesNeeded.contains(zohoName) {
                continue
            }

            let nameLower = zohoName.lowercased()
            let parentName = mapping.parentName(for: zohoName)
            let parentInfo = parentName.map { " (parent: \($0))" } ?? ""

            // Determine expected parent ID first
            var expectedParentId = parentName.flatMap { parentAccountIds[$0] }

            // If parent not in our mapping but exists in Zoho, use that
            if expectedParentId == nil, let pName = parentName {
                let parentLower = pName.lowercased()
                if let existingParentId = existingByName[parentLower] {
                    expectedParentId = existingParentId
                    parentAccountIds[pName] = existingParentId  // Cache for future children
                    if verbose {
                        print("  [FOUND PARENT] '\(pName)' exists in Zoho for child '\(zohoName)'")
                    }
                }
            }

            // Check if child already exists
            if let existingId = existingByName[nameLower] {
                configAccountIdMapping[zohoName] = existingId
                accountNameMapping[existingId] = zohoName

                // Check if the existing account has the correct parent
                if let existingAccount = existingAccountsByName[nameLower] {
                    let currentParentId = existingAccount.parentAccountId

                    // If parent should be set but isn't, or is different, update it
                    if let expected = expectedParentId, currentParentId != expected {
                        if dryRun {
                            print("  [WOULD UPDATE] Child: \(zohoName) - set parent to '\(parentName ?? "unknown")'")
                        } else {
                            let updateRequest = ZBAccountUpdateRequest(parentAccountId: expected)
                            do {
                                _ = try await zohoAPI.updateAccount(existingId, request: updateRequest)
                                print("  [UPDATED] Child: \(zohoName) - set parent to '\(parentName ?? "unknown")'")
                            } catch {
                                print("  [WARNING] Could not update parent for '\(zohoName)': \(error.localizedDescription)")
                            }
                        }
                    } else if verbose {
                        print("  [EXISTS] Child: \(zohoName)\(parentInfo)")
                    }
                } else if verbose {
                    print("  [EXISTS] Child: \(zohoName)\(parentInfo)")
                }

                existingCount += 1
                result.recordSuccess()
                continue
            }

            // Warn if parent should exist but ID wasn't found anywhere
            if parentName != nil && expectedParentId == nil && !dryRun {
                print("  [WARNING] Parent '\(parentName!)' not found for child '\(zohoName)' - will create as top-level")
            }

            let isCogs = zohoName.lowercased().contains("cost of")
            let request = AccountMapper.createAccount(zohoName, parentAccountId: expectedParentId, isCogs: isCogs)

            do {
                if let created = try await zohoAPI.createAccount(request, parentInfo: parentInfo.isEmpty ? nil : parentInfo) {
                    if let accountId = created.accountId {
                        configAccountIdMapping[zohoName] = accountId
                        accountNameMapping[accountId] = zohoName
                        if defaultExpenseAccountId == nil {
                            defaultExpenseAccountId = accountId
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    let placeholderId = "dry-run-child-\(zohoName.replacingOccurrences(of: " ", with: "-"))"
                    configAccountIdMapping[zohoName] = placeholderId
                    accountNameMapping[placeholderId] = zohoName
                    if defaultExpenseAccountId == nil {
                        defaultExpenseAccountId = "dry-run-default-account"
                    }
                    result.recordSuccess()
                }
            } catch let error as ZohoError {
                // Check if error is "already exists" - if so, fetch and use existing account
                if case .apiError(let code, _) = error, code == 11002 {
                    let refreshedAccounts = try await zohoAPI.fetchAccounts()
                    let nameLower = zohoName.lowercased()
                    if let existing = refreshedAccounts.first(where: { $0.accountName?.lowercased() == nameLower }) {
                        if let accountId = existing.accountId {
                            configAccountIdMapping[zohoName] = accountId
                            accountNameMapping[accountId] = zohoName
                            if defaultExpenseAccountId == nil {
                                defaultExpenseAccountId = accountId
                            }
                            if verbose {
                                print("  [EXISTS] Child: \(zohoName) (found after create attempt)")
                            }
                            result.recordSuccess()
                            continue
                        }
                    }
                }
                result.recordFailure(entity: zohoName, error: error.localizedDescription)
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

        if existingCount > 0 {
            print("  (\(existingCount) accounts already existed in Zoho)")
        }
        result.printSummary(entityType: "Hierarchical Categories/Accounts")
    }

    /// Migrate categories using direct 1:1 mapping from FreshBooks
    private func migrateCategoriesDirect() async throws {
        print("Migrating expense categories to chart of accounts...")

        // Fetch existing accounts from Zoho to avoid duplicates
        print("Fetching existing accounts from Zoho...")
        let existingAccounts = try await zohoAPI.fetchAccounts()
        var existingByName: [String: String] = [:] // name (lowercased) -> accountId
        for account in existingAccounts {
            if let accountId = account.accountId, let name = account.accountName {
                existingByName[name.lowercased()] = accountId
            }
        }
        print("Found \(existingAccounts.count) existing accounts in Zoho")
        defaultExpenseAccountId = existingAccounts.first { $0.accountType == "expense" }?.accountId

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

        var result = MigrationResult()
        var existingCount = 0

        // Process only unique categories
        for category in uniqueCategories {
            let request = AccountMapper.map(category)
            let nameLower = request.accountName.lowercased()

            // Build display name with parent info
            let parentInfo: String
            if let parentId = category.parentId, let parentName = categoryLookup[parentId] {
                parentInfo = " (parent: \(parentName))"
            } else {
                parentInfo = ""
            }

            // Check if account already exists in Zoho
            if let existingId = existingByName[nameLower] {
                accountIdMapping[category.id] = existingId
                existingCount += 1
                if verbose {
                    print("  [EXISTS] Account: \(request.accountName)\(parentInfo)")
                }
                result.recordSuccess()
                continue
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

        if existingCount > 0 {
            print("  (\(existingCount) accounts already existed in Zoho)")
        }
        result.printSummary(entityType: "Categories/Accounts")
    }

    func migrateCustomers() async throws {
        print("Migrating clients to customers...")

        // Fetch existing customers from Zoho to avoid duplicates
        print("Fetching existing customers from Zoho...")
        let existingCustomers = try await zohoAPI.fetchContacts(contactType: "customer")
        var existingByName: [String: String] = [:] // name -> contactId
        for customer in existingCustomers {
            if let contactId = customer.contactId, let name = customer.contactName {
                existingByName[name.lowercased()] = contactId
            }
        }
        print("Found \(existingCustomers.count) existing customers in Zoho")

        print("Fetching clients from FreshBooks...")
        let clients = try await freshBooksAPI.fetchClients()
        print("Found \(clients.count) clients")

        var result = MigrationResult()
        var existingCount = 0

        for client in clients {
            if client.visState != 0 && client.visState != nil {
                result.recordSkip()
                continue
            }

            let request = CustomerMapper.map(client)
            let nameLower = request.contactName.lowercased()

            // Check if customer already exists in Zoho
            if let existingId = existingByName[nameLower] {
                customerIdMapping[client.id] = existingId
                existingCount += 1
                if verbose {
                    print("  [EXISTS] Customer: \(request.contactName)")
                }
                result.recordSuccess()
                continue
            }

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

        if existingCount > 0 {
            print("  (\(existingCount) customers already existed in Zoho)")
        }
        result.printSummary(entityType: "Customers")
    }

    func migrateVendors() async throws {
        print("Migrating vendors...")

        // Fetch existing vendors from Zoho to avoid duplicates
        print("Fetching existing vendors from Zoho...")
        let existingVendors = try await zohoAPI.fetchContacts(contactType: "vendor")
        var existingByName: [String: String] = [:] // name -> contactId
        for vendor in existingVendors {
            if let contactId = vendor.contactId, let name = vendor.contactName {
                existingByName[name.lowercased()] = contactId
            }
        }
        print("Found \(existingVendors.count) existing vendors in Zoho")

        print("Fetching vendors from FreshBooks...")
        let vendors = try await freshBooksAPI.fetchVendors()
        print("Found \(vendors.count) vendors")

        var result = MigrationResult()
        var existingCount = 0

        for vendor in vendors {
            if vendor.visState != 0 && vendor.visState != nil {
                result.recordSkip()
                continue
            }

            let request = VendorMapper.map(vendor)
            let nameLower = request.contactName.lowercased()

            // Check if vendor already exists in Zoho
            if let existingId = existingByName[nameLower] {
                vendorIdMapping[vendor.id] = existingId
                existingCount += 1
                if verbose {
                    print("  [EXISTS] Vendor: \(request.contactName)")
                }
                result.recordSuccess()
                continue
            }

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

        if existingCount > 0 {
            print("  (\(existingCount) vendors already existed in Zoho)")
        }
        result.printSummary(entityType: "Vendors")
    }

    func migrateInvoices() async throws {
        print("Migrating invoices...")

        if customerIdMapping.isEmpty && !dryRun {
            print("Warning: No customer ID mappings available. Running customer migration first...")
            try await migrateCustomers()
        }

        // Fetch existing invoices from Zoho to avoid duplicates
        print("Fetching existing invoices from Zoho...")
        let existingInvoices = try await zohoAPI.fetchInvoices()
        var existingByNumber: [String: String] = [:] // invoice number -> invoiceId
        for inv in existingInvoices {
            if let invoiceId = inv.invoiceId, let number = inv.invoiceNumber {
                existingByNumber[number.lowercased()] = invoiceId
            }
        }
        print("Found \(existingInvoices.count) existing invoices in Zoho")
        if verbose && !existingByNumber.isEmpty {
            let sampleNumbers = Array(existingByNumber.keys.prefix(5))
            print("  Sample Zoho invoice numbers: \(sampleNumbers)")
        }

        print("Fetching invoices from FreshBooks...")
        let invoices = try await freshBooksAPI.fetchInvoices()
        print("Found \(invoices.count) invoices")

        // Build tax mapping for invoices (only apply tax to lines that had tax in FreshBooks)
        let zohoTaxes = try await zohoAPI.fetchTaxes()
        var taxMapping: [String: String] = [:]  // FB taxName (lowercased) -> Zoho taxId
        for tax in zohoTaxes {
            if let taxId = tax.taxId {
                taxMapping[tax.taxName.lowercased()] = taxId
            }
        }
        if verbose {
            print("  Built tax mapping with \(taxMapping.count) taxes for invoices")
        }

        // Fetch tax exemptions for non-taxable line items
        let taxExemptions = try await zohoAPI.fetchTaxExemptions()
        if verbose && !taxExemptions.isEmpty {
            print("  Available tax exemptions:")
            for exemption in taxExemptions {
                print("    - \(exemption.taxExemptionCode ?? "no code"): \(exemption.description ?? "no description") (ID: \(exemption.taxExemptionId ?? "?"))")
            }
        }
        var servicesExemptionId: String? = nil
        // Look for "Services are exempt" or similar exemption
        for exemption in taxExemptions {
            let desc = (exemption.description ?? "").lowercased()
            let code = (exemption.taxExemptionCode ?? "").lowercased()
            if desc.contains("service") || code.contains("service") {
                servicesExemptionId = exemption.taxExemptionId
                break
            }
        }
        // If no services-specific exemption, use any non-taxable exemption
        if servicesExemptionId == nil {
            servicesExemptionId = taxExemptions.first?.taxExemptionId
        }
        if verbose {
            if let exemptionId = servicesExemptionId {
                print("  Using tax exemption ID: \(exemptionId) for non-taxable line items")
            } else {
                print("  Warning: No tax exemption found in Zoho Books.")
                print("           Create a tax exemption in Zoho Books: Settings → Taxes → Tax Exemptions")
                print("           Suggested: Code='SERVICES', Description='Services are exempt'")
            }
        }

        var result = MigrationResult()
        var customersCreatedFromInvoices = 0
        var existingCount = 0

        for invoice in invoices {
            if invoice.visState != 0 && invoice.visState != nil {
                result.recordSkip()
                continue
            }

            let invoiceNumber = invoice.invoiceNumber ?? String(invoice.id)

            // Check if invoice already exists in Zoho
            if let existingId = existingByNumber[invoiceNumber.lowercased()] {
                invoiceIdMapping[invoice.id] = existingId
                existingCount += 1
                print("  [EXISTS] Invoice: \(invoiceNumber)")
                result.recordSuccess()
                continue
            }

            // If customer doesn't exist in mapping, check Zoho first, then create if needed
            if let customerId = invoice.customerId, customerIdMapping[customerId] == nil {
                let customerRequest = CustomerMapper.mapFromInvoice(invoice)
                let nameLower = customerRequest.contactName.lowercased()

                // First, check if customer already exists in Zoho by name
                let existingCustomers = try await zohoAPI.fetchContacts(contactType: "customer")
                if let existing = existingCustomers.first(where: { $0.contactName?.lowercased() == nameLower }) {
                    if let contactId = existing.contactId {
                        customerIdMapping[customerId] = contactId
                        print("  [EXISTS] Customer '\(customerRequest.contactName)' for invoice \(invoiceNumber)")
                    }
                } else {
                    // Customer doesn't exist, create it
                    do {
                        if let created = try await zohoAPI.createContact(customerRequest) {
                            if let contactId = created.contactId {
                                customerIdMapping[customerId] = contactId
                                customersCreatedFromInvoices += 1
                                print("  [CREATED] Customer '\(customerRequest.contactName)' from invoice \(invoiceNumber)")
                            }
                        } else if dryRun {
                            // Populate placeholder ID for dependent migrations
                            customerIdMapping[customerId] = "dry-run-customer-from-invoice-\(customerId)"
                            customersCreatedFromInvoices += 1
                            print("  [DRY RUN] Would create customer '\(customerRequest.contactName)' from invoice \(invoiceNumber)")
                        }
                    } catch {
                        print("  [WARNING] Could not create customer from invoice \(invoiceNumber): \(error.localizedDescription)")
                    }
                }
            }

            guard let request = InvoiceMapper.map(invoice, customerIdMapping: customerIdMapping, taxMapping: taxMapping, servicesExemptionId: servicesExemptionId) else {
                if verbose {
                    print("  Skipping invoice \(invoiceNumber): no customer mapping")
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

                        // Mark invoice as sent if FreshBooks status indicates it was sent
                        if InvoiceMapper.shouldMarkAsSent(invoice) {
                            do {
                                try await zohoAPI.markInvoiceAsSent(invoiceId, invoiceNumber: invoiceNumber)
                                if verbose {
                                    print("    Marked as sent (was: \(invoice.v3Status ?? "unknown"))")
                                }
                            } catch {
                                print("  [WARNING] Could not mark invoice \(invoiceNumber) as sent: \(error.localizedDescription)")
                            }
                        }
                    }
                    result.recordSuccess()
                } else if dryRun {
                    // Populate placeholder ID for dependent migrations
                    invoiceIdMapping[invoice.id] = "dry-run-invoice-\(invoice.id)"

                    // Show what would happen with status
                    if InvoiceMapper.shouldMarkAsSent(invoice) {
                        print("  [DRY RUN] Would mark invoice \(invoiceNumber) as sent (was: \(invoice.v3Status ?? "unknown"))")
                    }
                    result.recordSuccess()
                }
            } catch {
                result.recordFailure(entity: invoiceNumber, error: error.localizedDescription)
                if verbose {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }

        if customersCreatedFromInvoices > 0 {
            print("Created \(customersCreatedFromInvoices) customers from invoice data")
        }
        if existingCount > 0 {
            print("  (\(existingCount) invoices already existed in Zoho)")
        }
        result.printSummary(entityType: "Invoices")
    }

    func migrateItems() async throws {
        print("Migrating items/products...")

        // Fetch existing items from Zoho to avoid duplicates
        print("Fetching existing items from Zoho...")
        let existingItems = try await zohoAPI.fetchItems()
        var existingByName: [String: String] = [:] // name (lowercased) -> itemId
        for item in existingItems {
            if let itemId = item.itemId {
                existingByName[item.name.lowercased()] = itemId
            }
        }
        print("Found \(existingItems.count) existing items in Zoho")

        print("Fetching items from FreshBooks...")
        let items = try await freshBooksAPI.fetchItems()
        print("Found \(items.count) items")

        var result = MigrationResult()
        var existingCount = 0

        for item in items {
            if item.visState != 0 && item.visState != nil {
                result.recordSkip()
                continue
            }

            let request = ItemMapper.map(item)
            let nameLower = request.name.lowercased()

            // Check if item already exists in Zoho
            if let existingId = existingByName[nameLower] {
                itemIdMapping[item.id] = existingId
                existingCount += 1
                if verbose {
                    print("  [EXISTS] Item: \(request.name)")
                }
                result.recordSuccess()
                continue
            }

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

        if existingCount > 0 {
            print("  (\(existingCount) items already existed in Zoho)")
        }
        result.printSummary(entityType: "Items/Products")
    }

    func migratePayments() async throws {
        print("Migrating payments...")

        if customerIdMapping.isEmpty && !dryRun {
            print("Warning: No customer ID mappings available. Running customer migration first...")
            try await migrateCustomers()
        }

        // Build invoice ID mapping if not already populated (when running payments standalone)
        if invoiceIdMapping.isEmpty {
            print("Building invoice ID mapping...")

            // Fetch FreshBooks invoices to get FB invoice ID -> invoice number
            let fbInvoices = try await freshBooksAPI.fetchInvoices()
            var fbIdToNumber: [Int: String] = [:]
            for inv in fbInvoices {
                if let number = inv.invoiceNumber {
                    fbIdToNumber[inv.id] = number
                }
            }

            // Fetch Zoho invoices to get invoice number -> Zoho invoice ID
            let zohoInvoices = try await zohoAPI.fetchInvoices()
            var zohoNumberToId: [String: String] = [:]
            for inv in zohoInvoices {
                if let number = inv.invoiceNumber, let id = inv.invoiceId {
                    zohoNumberToId[number.lowercased()] = id
                }
            }

            // Build the mapping: FB invoice ID -> Zoho invoice ID
            for (fbId, fbNumber) in fbIdToNumber {
                if let zohoId = zohoNumberToId[fbNumber.lowercased()] {
                    invoiceIdMapping[fbId] = zohoId
                }
            }

            if verbose {
                print("  Built invoice mapping with \(invoiceIdMapping.count) entries")
            }
        }

        // Check for existing payments in Zoho (potential duplicates warning)
        if !dryRun {
            print("Checking for existing payments in Zoho...")
            let existingPayments = try await zohoAPI.fetchPayments()
            if !existingPayments.isEmpty {
                print("\n⚠️  There are \(existingPayments.count) existing payments in Zoho Books.")
                print("   Migrating may create duplicates if records were already migrated.")
                print("   Do you want to continue? (y/N): ", terminator: "")

                if let response = readLine()?.lowercased(), response == "y" || response == "yes" {
                    print("   Continuing with payment migration...")
                } else {
                    print("   Skipping payment migration.")
                    return
                }
            }
        }

        print("Fetching payments from FreshBooks...")
        let payments = try await freshBooksAPI.fetchPayments()
        print("Found \(payments.count) payments")

        // Build deposit account mapping from Zoho accounts
        let allAccounts = try await zohoAPI.fetchAccounts()
        var accountNameToId: [String: String] = [:] // account name (lowercased) -> Zoho accountId
        for acct in allAccounts {
            guard let name = acct.accountName, let id = acct.accountId else { continue }
            let type = acct.accountType?.lowercased() ?? ""
            if type == "bank" || type == "cash" {
                accountNameToId[name.lowercased()] = id
            }
        }

        // Convert config's depositAccountMapping (gateway -> account name) to (gateway -> account ID)
        var depositAccountMapping: [String: String] = [:] // gateway/type (lowercased) -> Zoho accountId
        if let configMapping = config.depositAccountMapping {
            for (gatewayOrType, accountName) in configMapping {
                if gatewayOrType == "_comment" { continue }
                if let accountId = accountNameToId[accountName.lowercased()] {
                    depositAccountMapping[gatewayOrType.lowercased()] = accountId
                }
            }
        }

        if verbose {
            print("  Built deposit account mapping with \(depositAccountMapping.count) entries")
        }

        // Apply manual customer mapping for archived/deleted clients
        if let manualMapping = config.manualCustomerMapping {
            // Fetch Zoho customers to build name -> ID mapping
            let zohoCustomers = try await zohoAPI.fetchContacts(contactType: "customer")
            var customerNameToId: [String: String] = [:]
            for customer in zohoCustomers {
                if let name = customer.contactName, let id = customer.contactId {
                    customerNameToId[name.lowercased()] = id
                }
            }

            var manualMappingsApplied = 0
            for (fbClientId, zohoCustomerName) in manualMapping {
                if fbClientId == "_comment" { continue }
                guard let clientId = Int(fbClientId) else { continue }
                if let zohoId = customerNameToId[zohoCustomerName.lowercased()] {
                    customerIdMapping[clientId] = zohoId
                    manualMappingsApplied += 1
                } else if verbose {
                    print("  Warning: Manual mapping customer '\(zohoCustomerName)' not found in Zoho")
                }
            }

            if verbose {
                print("  Applied \(manualMappingsApplied) manual customer mappings")
            }
        }

        var result = MigrationResult()

        for payment in payments {
            if payment.visState != 0 && payment.visState != nil {
                result.recordSkip()
                continue
            }

            guard let mapperResult = PaymentMapper.map(
                payment,
                customerIdMapping: customerIdMapping,
                invoiceIdMapping: invoiceIdMapping,
                depositAccountMapping: depositAccountMapping
            ) else {
                if verbose {
                    let clientInfo = payment.clientId.map { "clientId=\($0)" } ?? "no client"
                    print("  Skipping payment \(payment.id) (\(clientInfo)): no customer mapping or invalid amount")
                }
                result.recordSkip()
                continue
            }

            let request = mapperResult.request

            // Warn if deposit account mapping failed
            if !mapperResult.depositAccountMapped {
                let key = mapperResult.unmappedKey ?? "unknown"
                print("  ⚠️  Payment \(payment.id) on \(request.date): no deposit account mapping for '\(key)' (using default)")
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

        // Check for existing expenses in Zoho (potential duplicates warning)
        if !dryRun {
            print("Checking for existing expenses in Zoho...")
            let existingExpenses = try await zohoAPI.fetchExpenses()
            if !existingExpenses.isEmpty {
                print("\n⚠️  There are \(existingExpenses.count) existing expenses in Zoho Books.")
                print("   Migrating may create duplicates if records were already migrated.")
                print("   Do you want to continue? (y/N): ", terminator: "")

                if let response = readLine()?.lowercased(), response == "y" || response == "yes" {
                    print("   Continuing with expense migration...")
                } else {
                    print("   Skipping expense migration.")
                    return
                }
            }
        }

        print("Fetching expenses from FreshBooks...")
        let expenses = try await freshBooksAPI.fetchExpenses()
        print("Found \(expenses.count) expenses")

        var result = MigrationResult()
        var tagCounts: [BusinessLine: Int] = [:]
        var attachmentCount = 0

        // Build paid-through account mapping from Zoho accounts
        let allAccounts = try await zohoAPI.fetchAccounts()
        var paidThroughMapping: [String: String] = [:] // FreshBooks accountName -> Zoho accountId
        for acct in allAccounts {
            guard let name = acct.accountName, let id = acct.accountId else { continue }
            let type = acct.accountType?.lowercased() ?? ""
            if type == "bank" || type == "credit_card" || type == "cash" {
                // Map exact name match
                paidThroughMapping[name.lowercased()] = id
            }
        }

        // Add name variation mappings from config (FreshBooks name -> Zoho name)
        if let nameMappings = config.paidThroughMapping {
            for (fbName, zohoName) in nameMappings {
                if let zohoId = paidThroughMapping[zohoName.lowercased()] {
                    paidThroughMapping[fbName.lowercased()] = zohoId
                }
            }
        }

        if verbose {
            print("  Built paid-through mapping with \(paidThroughMapping.count) accounts")
        }

        // Build tax mapping from Zoho taxes (tax name -> tax ID)
        let zohoTaxes = try await zohoAPI.fetchTaxes()
        var taxMapping: [String: String] = [:]  // FreshBooks taxName (lowercased) -> Zoho taxId
        for tax in zohoTaxes {
            if let id = tax.taxId {
                taxMapping[tax.taxName.lowercased()] = id
            }
        }
        if verbose {
            print("  Built tax mapping with \(taxMapping.count) taxes")
        }

        // Build vendor name cache from existing Zoho vendors (for on-the-fly vendor creation)
        print("Fetching existing vendors from Zoho...")
        let existingVendors = try await zohoAPI.fetchContacts(contactType: "vendor")
        var vendorNameCache: [String: String] = [:] // vendor name (lowercased) -> Zoho vendor ID
        for vendor in existingVendors {
            if let contactId = vendor.contactId, let name = vendor.contactName {
                vendorNameCache[name.lowercased()] = contactId
            }
        }
        print("Found \(existingVendors.count) existing vendors in Zoho")

        var vendorsCreated = 0
        let totalExpenses = expenses.count
        var processedCount = 0

        for expense in expenses {
            processedCount += 1

            // Show progress every 50 expenses or at key milestones
            if processedCount % 50 == 0 || processedCount == totalExpenses {
                let percent = Int((Double(processedCount) / Double(totalExpenses)) * 100)
                print("  Processing expense \(processedCount) of \(totalExpenses) (\(percent)% complete)", terminator: "\r")
                fflush(stdout)
            }

            if expense.visState != 0 && expense.visState != nil {
                result.recordSkip()
                continue
            }

            guard let mapperResult = ExpenseMapper.map(
                expense,
                accountIdMapping: accountIdMapping,
                accountNameMapping: accountNameMapping,
                vendorIdMapping: vendorIdMapping,
                customerIdMapping: customerIdMapping,
                paidThroughMapping: paidThroughMapping,
                taxMapping: taxMapping,
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

            var request = mapperResult.request
            let categoryName = mapperResult.categoryName ?? "Unknown"
            var businessTag: String? = nil
            if let businessLine = mapperResult.businessLine {
                tagCounts[businessLine, default: 0] += 1
                businessTag = businessLine.shortCode
            }

            // Create vendor on-the-fly if needed
            if request.vendorId == nil, let vendorName = mapperResult.vendorName, !vendorName.isEmpty {
                let vendorNameLower = vendorName.lowercased()

                // Check if vendor already exists in cache
                if let existingVendorId = vendorNameCache[vendorNameLower] {
                    request.vendorId = existingVendorId
                } else {
                    // Create new vendor
                    let vendorRequest = ZBContactCreateRequest(
                        contactName: vendorName,
                        companyName: nil,
                        contactType: "vendor",
                        billingAddress: nil,
                        shippingAddress: nil,
                        contactPersons: nil
                    )

                    do {
                        if let created = try await zohoAPI.createContact(vendorRequest) {
                            if let contactId = created.contactId {
                                vendorNameCache[vendorNameLower] = contactId
                                request.vendorId = contactId
                                vendorsCreated += 1
                                if verbose {
                                    print("\n  [CREATED VENDOR] \(vendorName)")
                                }
                            }
                        } else if dryRun {
                            // In dry run, still record the vendor would be created
                            let placeholderId = "dry-run-vendor-\(vendorName.replacingOccurrences(of: " ", with: "-"))"
                            vendorNameCache[vendorNameLower] = placeholderId
                            request.vendorId = placeholderId
                            vendorsCreated += 1
                        }
                    } catch {
                        print("\n  ⚠️  Could not create vendor '\(vendorName)': \(error.localizedDescription)")
                    }
                }
            }

            // Warn if paid-through account mapping failed
            if !mapperResult.paidThroughMapped, let unmapped = mapperResult.unmappedPaidThrough {
                print("  ⚠️  Expense \(expense.id) on \(request.date): no paid-through mapping for '\(unmapped)'")
            }

            do {
                if let created = try await zohoAPI.createExpense(request, categoryName: categoryName, businessTag: businessTag) {
                    // Handle attachment if enabled and expense has one
                    if includeAttachments, expense.hasReceipt == true, let zohoExpenseId = created.expenseId {
                        await migrateExpenseAttachment(
                            fbExpenseId: expense.id,
                            zohoExpenseId: zohoExpenseId,
                            expenseDesc: expense.notes ?? String(expense.id)
                        )
                        attachmentCount += 1
                    }
                    result.recordSuccess()
                } else if dryRun {
                    // Show attachment info in dry-run
                    if includeAttachments, expense.hasReceipt == true {
                        print("    [DRY RUN] Would download and upload receipt for expense \(expense.id)")
                        attachmentCount += 1
                    }
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

        // Clear progress line
        print("")

        // Print tag summary if business tagging is configured
        if !tagCounts.isEmpty {
            print("\nExpense Tags Summary:")
            for (line, count) in tagCounts.sorted(by: { $0.key.name < $1.key.name }) {
                print("  \(line.name): \(count)")
            }
        }

        // Print attachment summary if attachments were processed
        if attachmentCount > 0 {
            print("\nAttachments: \(attachmentCount) receipts \(dryRun ? "would be" : "") migrated")
        }

        // Print vendor summary if vendors were created
        if vendorsCreated > 0 {
            print("\nVendors: \(vendorsCreated) vendors \(dryRun ? "would be" : "were") created on-the-fly")
        }

        result.printSummary(entityType: "Expenses")
    }

    /// Download attachment from FreshBooks and upload to Zoho expense
    private func migrateExpenseAttachment(fbExpenseId: Int, zohoExpenseId: String, expenseDesc: String) async {
        do {
            // First fetch expense details to get attachment ID (with include[]=attachment)
            guard let details = try await freshBooksAPI.fetchExpenseDetails(expenseId: fbExpenseId) else {
                if verbose {
                    print("    [WARNING] Could not fetch expense details for \(fbExpenseId)")
                }
                return
            }

            // Get attachment ID, JWT, and media type from details
            let attachmentId: Int?
            let jwt: String?
            let mediaType: String?

            if let att = details.attachment {
                attachmentId = att.effectiveId
                jwt = att.jwt
                mediaType = att.mediaType
            } else if let attId = details.attachmentId {
                attachmentId = attId
                jwt = nil
                mediaType = nil
            } else {
                if verbose {
                    print("    [WARNING] No attachment ID found for expense \(fbExpenseId)")
                }
                return
            }

            guard let attId = attachmentId else { return }

            // Download from FreshBooks using JWT (secure temporary link)
            guard let attachment = try await freshBooksAPI.downloadAttachment(attachmentId: attId, jwt: jwt, mediaType: mediaType) else {
                if verbose {
                    print("    [WARNING] Could not download attachment \(attId) for expense: \(expenseDesc)")
                }
                return
            }

            // Upload to Zoho
            try await zohoAPI.uploadExpenseAttachment(
                expenseId: zohoExpenseId,
                fileData: attachment.data,
                filename: attachment.filename
            )

            print("    [ATTACHMENT] Uploaded \(attachment.filename) (\(attachment.data.count) bytes)")
        } catch {
            print("    [WARNING] Attachment migration failed for expense \(expenseDesc): \(error.localizedDescription)")
        }
    }

    /// Update status of existing Zoho invoices based on FreshBooks status.
    /// This fixes invoices that were migrated as DRAFT but should be SENT.
    func updateInvoiceStatuses() async throws {
        print("Updating invoice statuses...")

        // Fetch existing invoices from Zoho
        print("Fetching existing invoices from Zoho...")
        let zohoInvoices = try await zohoAPI.fetchInvoices()
        print("Found \(zohoInvoices.count) invoices in Zoho")

        // Build lookup by invoice number
        var zohoByNumber: [String: ZBInvoice] = [:]
        for invoice in zohoInvoices {
            if let number = invoice.invoiceNumber {
                zohoByNumber[number.lowercased()] = invoice
            }
        }

        // Fetch invoices from FreshBooks
        print("Fetching invoices from FreshBooks...")
        let fbInvoices = try await freshBooksAPI.fetchInvoices()
        print("Found \(fbInvoices.count) invoices in FreshBooks")

        var result = MigrationResult()
        var alreadySentCount = 0
        var notFoundCount = 0

        for fbInvoice in fbInvoices {
            // Skip deleted/archived invoices
            if fbInvoice.visState != 0 && fbInvoice.visState != nil {
                result.recordSkip()
                continue
            }

            let invoiceNumber = fbInvoice.invoiceNumber ?? String(fbInvoice.id)
            let invoiceNumberLower = invoiceNumber.lowercased()

            // Find matching Zoho invoice
            guard let zohoInvoice = zohoByNumber[invoiceNumberLower] else {
                notFoundCount += 1
                if verbose {
                    print("  [NOT FOUND] Invoice \(invoiceNumber) not in Zoho")
                }
                result.recordSkip()
                continue
            }

            // Check if the Zoho invoice is in draft status
            let zohoStatus = zohoInvoice.status?.lowercased() ?? "unknown"
            if zohoStatus != "draft" {
                alreadySentCount += 1
                if verbose {
                    print("  [ALREADY \(zohoStatus.uppercased())] Invoice \(invoiceNumber)")
                }
                result.recordSkip()
                continue
            }

            // Check if FreshBooks says it should be sent
            guard InvoiceMapper.shouldMarkAsSent(fbInvoice) else {
                if verbose {
                    print("  [KEEP DRAFT] Invoice \(invoiceNumber) (FB status: \(fbInvoice.v3Status ?? "unknown"))")
                }
                result.recordSkip()
                continue
            }

            // Mark as sent
            guard let zohoInvoiceId = zohoInvoice.invoiceId else {
                result.recordSkip()
                continue
            }

            do {
                try await zohoAPI.markInvoiceAsSent(zohoInvoiceId, invoiceNumber: invoiceNumber)
                if !dryRun {
                    print("  [MARKED SENT] Invoice \(invoiceNumber) (FB status: \(fbInvoice.v3Status ?? "unknown"))")
                }
                result.recordSuccess()
            } catch {
                result.recordFailure(entity: invoiceNumber, error: error.localizedDescription)
                print("  [ERROR] Could not mark \(invoiceNumber) as sent: \(error.localizedDescription)")
            }
        }

        if alreadySentCount > 0 {
            print("  (\(alreadySentCount) invoices already had non-draft status)")
        }
        if notFoundCount > 0 {
            print("  (\(notFoundCount) FreshBooks invoices not found in Zoho)")
        }
        result.printSummary(entityType: "Invoice Status Updates")
    }

    /// Migrate attachments/receipts for existing expenses.
    /// Matches FB expenses to Zoho expenses by date + amount + description.
    func migrateExpenseAttachments() async throws {
        print("Migrating expense attachments...")

        // Fetch all FreshBooks expenses
        print("Fetching expenses from FreshBooks...")
        let fbExpenses = try await freshBooksAPI.fetchExpenses()
        let expensesWithReceipts = fbExpenses.filter { $0.hasReceipt == true && ($0.visState == 0 || $0.visState == nil) }
        print("Found \(expensesWithReceipts.count) expenses with receipts in FreshBooks")

        if expensesWithReceipts.isEmpty {
            print("No expenses with receipts to migrate.")
            return
        }

        // Fetch all Zoho expenses
        print("Fetching expenses from Zoho...")
        let zohoExpenses = try await zohoAPI.fetchExpenses()
        print("Found \(zohoExpenses.count) expenses in Zoho")

        // Build lookup for Zoho expenses by date + amount + description
        // Key format: "date|amount|description"
        var zohoByKey: [String: ZBExpense] = [:]
        for expense in zohoExpenses {
            guard let date = expense.date,
                  let amount = expense.total else { continue }
            let desc = expense.description?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = "\(date)|\(String(format: "%.2f", amount))|\(desc)"
            zohoByKey[key] = expense
        }

        var result = MigrationResult()
        var matchedCount = 0
        var noMatchCount = 0

        for fbExpense in expensesWithReceipts {
            let fbDate = fbExpense.date ?? ""
            let fbAmount = Double(fbExpense.amount?.amount ?? "0") ?? 0
            let fbDesc = (fbExpense.notes ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(fbDate)|\(String(format: "%.2f", fbAmount))|\(fbDesc)"

            // Find matching Zoho expense
            guard let zohoExpense = zohoByKey[key],
                  let zohoExpenseId = zohoExpense.expenseId else {
                noMatchCount += 1
                if verbose {
                    print("  [NO MATCH] FB expense \(fbExpense.id) on \(fbDate) for $\(String(format: "%.2f", fbAmount))")
                }
                result.recordSkip()
                continue
            }

            matchedCount += 1

            if dryRun {
                print("  [DRY RUN] Would migrate attachment for expense \(fbExpense.id) -> Zoho \(zohoExpenseId)")
                result.recordSuccess()
                continue
            }

            // Migrate the attachment
            await migrateExpenseAttachment(
                fbExpenseId: fbExpense.id,
                zohoExpenseId: zohoExpenseId,
                expenseDesc: fbExpense.notes ?? String(fbExpense.id)
            )
            result.recordSuccess()
        }

        print("\nMatched \(matchedCount) expenses, \(noMatchCount) could not be matched")
        result.printSummary(entityType: "Expense Attachments")
    }
}
