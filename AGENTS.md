# AI Agent Guide for FreshbooksZohoMigratorCLI

This document helps AI assistants understand the project architecture and make consistent updates.

## Project Overview

A Swift CLI tool that migrates data from FreshBooks to Zoho Books. Uses async/await, actors for thread-safe API access, and a mapper pattern for data transformation.

## Directory Structure

```
Sources/ZohoMigration/
├── main.swift                    # CLI entry point (ArgumentParser)
├── Config/
│   └── Configuration.swift       # JSON config loading, OAuth credentials
├── API/
│   ├── FreshBooksAPI.swift       # Actor - fetches from FreshBooks (read-only)
│   ├── ZohoAPI.swift             # Actor - creates in Zoho Books
│   └── OAuthHelper.swift         # Actor - token management for both APIs
├── Migration/
│   └── MigrationService.swift    # Orchestrates migrations, maintains ID mappings
├── Mappers/
│   └── *Mapper.swift             # Stateless transformation functions
└── Models/
    ├── FreshBooks/
    │   └── FB*.swift             # Source models with response wrappers
    └── Zoho/
        └── ZB*.swift             # Target models with create request variants
```

## Adding a New Entity Type

Follow these steps to add support for migrating a new entity (e.g., "Widget"):

### 1. Create FreshBooks Model (`Models/FreshBooks/FBWidget.swift`)

```swift
import Foundation

struct FBWidgetResponse: Codable {
    let response: FBWidgetResponseBody
}

struct FBWidgetResponseBody: Codable {
    let result: FBWidgetResult
}

struct FBWidgetResult: Codable {
    let widgets: [FBWidget]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case widgets
        case page, pages
        case perPage = "per_page"
        case total
    }
}

struct FBWidget: Codable, Identifiable {
    let id: Int
    let name: String?
    let visState: Int?  // 0 = active, non-zero = archived/deleted

    enum CodingKeys: String, CodingKey {
        case id, name
        case visState = "vis_state"
    }

    var displayName: String {
        name ?? "Widget \(id)"
    }
}
```

### 2. Create Zoho Model (`Models/Zoho/ZBWidget.swift`)

```swift
import Foundation

struct ZBWidgetResponse: Codable {
    let code: Int
    let message: String
    let widget: ZBWidget?
}

struct ZBWidget: Codable {
    var widgetId: String?
    var name: String

    enum CodingKeys: String, CodingKey {
        case widgetId = "widget_id"
        case name
    }
}

struct ZBWidgetCreateRequest: Codable {
    var name: String

    enum CodingKeys: String, CodingKey {
        case name
    }
}
```

### 3. Create Mapper (`Mappers/WidgetMapper.swift`)

```swift
import Foundation

struct WidgetMapper {
    static func map(_ widget: FBWidget) -> ZBWidgetCreateRequest {
        ZBWidgetCreateRequest(
            name: widget.name ?? "Widget \(widget.id)"
        )
    }
}
```

### 4. Add Fetch Method to FreshBooksAPI.swift

```swift
func fetchWidgets() async throws -> [FBWidget] {
    let endpoint = "/accounting/account/\(accountId)/widgets/widgets"
    // ... pagination pattern (copy from existing methods)
}
```

### 5. Add Create Method to ZohoAPI.swift

```swift
func createWidget(_ widget: ZBWidgetCreateRequest) async throws -> ZBWidget? {
    if dryRun {
        print("  [DRY RUN] Would create widget: \(widget.name)")
        return nil
    }
    // ... POST to /widgets endpoint (copy pattern from existing methods)
}
```

### 6. Add Migration Method to MigrationService.swift

1. Add ID mapping property: `private var widgetIdMapping: [Int: String] = [:]`
2. Add to `migrateAll()` in correct dependency order
3. Add `migrateWidgets()` method following existing patterns

### 7. Add CLI Command to main.swift

1. Add `Widgets.self` to subcommands array in `Migrate` struct
2. Add new command struct (see existing commands like `Customers`, `Invoices`, `Payments`):

```swift
struct Widgets: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Migrate widgets"
    )
    @OptionGroup var options: MigrationOptions
    func run() async throws {
        let service = try createMigrationService(options: options)
        try await service.migrateWidgets()
    }
}
```

### 8. Update README.md

- Add to "Data Migrated" list
- Add to "Migrate Specific Entities" examples
- Update "Migration Order" section
- Add any required Zoho OAuth scopes

## CLI Commands

The tool has two main command groups:
- **`migrate`**: Migration commands (`migrate all`, `migrate customers`, etc.)
- **`auth`**: OAuth token refresh commands (`auth freshbooks`, `auth zoho`)

The `Auth` command in `main.swift` handles interactive OAuth flows and auto-updates `config.json`.

## Key Patterns

### FreshBooks Response Wrapper Pattern
FreshBooks nests data: `response.result.{entities}`. Always create three structs:
- `FB{Entity}Response` → `FB{Entity}ResponseBody` → `FB{Entity}Result`

### Zoho Response Pattern
Zoho returns `code` (0 = success) and `message`. Create:
- `ZB{Entity}Response` (for API responses)
- `ZB{Entity}` (the entity itself)
- `ZB{Entity}CreateRequest` (subset of fields for creation)

### visState Filtering
FreshBooks uses `visState` to track deleted/archived items:
- `visState == 0` or `visState == nil` → active (migrate)
- `visState != 0` → skip

### ID Mappings
MigrationService maintains `[Int: String]` dictionaries mapping FreshBooks IDs to Zoho IDs. Use these when entities have dependencies (e.g., invoices need customer IDs).

### Mapper Dependencies
If a mapper needs ID mappings, pass them as parameters:
```swift
static func map(_ entity: FBEntity, customerIdMapping: [Int: String]) -> ZBEntityCreateRequest?
```
Return `nil` if required mapping is missing.

### On-the-Fly Entity Creation
For entities that reference other entities by name (not ID), use the on-the-fly creation pattern:
1. At migration start, fetch existing Zoho entities and build a name→ID cache
2. During migration, check if referenced entity exists in cache
3. If not, create it in Zoho and add to cache
4. Use the cached/new ID for the dependent entity

Example: Expense migration creates vendors on-the-fly when they don't exist (see `MigrationService.migrateExpenses()`).

## API Endpoints

### FreshBooks
- Base: `https://api.freshbooks.com`
- Pattern: `/accounting/account/{accountId}/{resource}/{resource}`
- Auth: `Bearer {token}` header
- Pagination: `?page=N&per_page=100`

### Zoho Books
- Base: Region-dependent (see `ZohoConfig.baseURL`)
- Pattern: `/books/v3/{resource}?organization_id={orgId}`
- Auth: `Zoho-oauthtoken {token}` header
- Rate limit: 100 requests/minute (auto-handled)

## Common Zoho Endpoints
- Contacts: `/contacts`
- Invoices: `/invoices`
- Expenses: `/expenses`
- Items: `/items`
- Taxes: `/settings/taxes`
- Payments: `/customerpayments`
- Chart of Accounts: `/chartofaccounts`

## Testing Changes

```bash
# Build
swift build

# Dry run (validates without making changes)
swift run ZohoMigration migrate all --dry-run --verbose

# Run specific migration
swift run ZohoMigration migrate widgets --dry-run
```
