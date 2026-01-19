# Task: Build a FreshBooks to Zoho Books Migration CLI Tool

Build a Swift command-line application that migrates data from FreshBooks to Zoho Books. Use Swift 5.9+, async/await, actors for thread-safe API access, and ArgumentParser for CLI.

## Project Structure

```
Sources/ZohoMigration/
├── main.swift                    # CLI entry point (ArgumentParser)
├── Config/
│   └── Configuration.swift       # JSON config loading
├── API/
│   ├── FreshBooksAPI.swift       # Actor - fetches from FreshBooks
│   ├── ZohoAPI.swift             # Actor - creates in Zoho Books
│   └── OAuthHelper.swift         # Token refresh for both APIs
├── Migration/
│   └── MigrationService.swift    # Orchestrates migrations, ID mappings
├── Mappers/
│   └── *Mapper.swift             # Stateless transformation functions
└── Models/
    ├── FreshBooks/FB*.swift      # Source models
    └── Zoho/ZB*.swift            # Target models
```

## Entities to Migrate (in dependency order)

1. **Expense Categories** → Zoho Chart of Accounts
2. **Items/Products** → Zoho Items (optional, skip by default)
3. **Customers** (FreshBooks Clients) → Zoho Contacts (type: "customer")
4. **Vendors** → Zoho Contacts (type: "vendor")
5. **Invoices** → Zoho Invoices (line items inline, no catalog reference needed)
6. **Expenses** → Zoho Expenses (with receipt attachments)
7. **Payments** → Zoho Customer Payments

## API Details

### FreshBooks API
- Base URL: `https://api.freshbooks.com`
- Auth Header: `Authorization: Bearer {token}`
- Endpoint pattern: `/accounting/account/{accountId}/{resource}/{resource}`
- Pagination: `?page=N&per_page=100`
- Response structure (IMPORTANT - triple nested):
```json
{
  "response": {
    "result": {
      "clients": [...],
      "page": 1,
      "pages": 5,
      "per_page": 100,
      "total": 450
    }
  }
}
```

### Zoho Books API
- Base URL varies by region:
  - US: `https://www.zohoapis.com/books/v3`
  - EU: `https://www.zohoapis.eu/books/v3`
  - IN: `https://www.zohoapis.in/books/v3`
  - AU: `https://www.zohoapis.com.au/books/v3`
- Auth Header: `Authorization: Zoho-oauthtoken {token}`
- All endpoints need: `?organization_id={orgId}`
- Rate limit: **100 requests per minute** (must implement tracking/waiting)
- Success response: `{ "code": 0, "message": "success", "entity": {...} }`
- Error response: `{ "code": non-zero, "message": "error description" }`

### Key Zoho Endpoints
- Contacts: POST `/contacts`
- Invoices: POST `/invoices`, POST `/invoices/{id}/status/sent`
- Expenses: POST `/expenses`, POST `/expenses/{id}/receipt`
- Items: POST `/items`
- Chart of Accounts: POST `/chartofaccounts`, GET `/chartofaccounts`
- Customer Payments: POST `/customerpayments`
- Taxes: GET `/settings/taxes`

## Field Mappings

### Customer (FBClient → ZBContact)
```
FreshBooks Field          → Zoho Field
----------------------------------------
organization OR           → contact_name (required)
  fname + " " + lname OR
  "Unknown Client " + id
organization              → company_name
email                     → contact_persons[0].email
fname                     → contact_persons[0].first_name
lname                     → contact_persons[0].last_name
bus_phone OR home_phone   → contact_persons[0].phone
mob_phone                 → contact_persons[0].mobile
p_street + "\n" + p_street2 → billing_address.address
p_city                    → billing_address.city
p_province                → billing_address.state
p_code                    → billing_address.zip
p_country                 → billing_address.country
(same pattern for shipping: s_street, s_city, etc.)
currency_code             → currency_code
note                      → notes
vat_number                → tax_id
(hardcode)                → contact_type: "customer"
(hardcode)                → contact_persons[0].is_primary_contact: true
```

### Vendor (FBVendor → ZBContact)
```
vendor_name OR            → contact_name
  "Vendor " + id
vendor_name               → company_name
primary_contact_email     → contact_persons[0].email
primary_contact_first_name→ contact_persons[0].first_name
primary_contact_last_name → contact_persons[0].last_name
phone                     → contact_persons[0].phone
street + "\n" + street2   → billing_address.address
city                      → billing_address.city
province                  → billing_address.state
postal_code               → billing_address.zip
country                   → billing_address.country
currency_code             → currency_code
note                      → notes
website                   → website
tax_id                    → tax_id
(hardcode)                → contact_type: "vendor"
```

### Invoice (FBInvoice → ZBInvoice)
```
(lookup via customerIdMapping) → customer_id (required)
invoice_number            → invoice_number
po_number                 → reference_number
create_date               → date
due_date                  → due_date
currency_code             → currency_code
notes                     → notes
(hardcode)                → is_inclusive_tax: false

Line Items (FBInvoiceLine → line_items[]):
name OR "Item"            → name
description               → description
unit_cost.amount (parse)  → rate (Double)
qty OR 1                  → quantity
tax_name1 (if taxAmount1 > 0) → tax_id (lookup from Zoho taxes)
(if no tax)               → tax_exemption_id (lookup "service" exemption)
```

**Invoice Status Logic:**
- Create invoice first (will be DRAFT)
- If FreshBooks `v3_status` != "draft" OR numeric `status` indicates sent:
  - Call POST `/invoices/{id}/status/sent` to mark as sent

### Expense (FBExpense → ZBExpense)
```
category_id               → account_id (via accountIdMapping, required)
date OR today             → date
amount.amount (parse)     → amount (Double)
notes                     → description
vendor (name string)      → vendor_id (lookup or CREATE on-the-fly)
client_id                 → customer_id (optional, for billable)
account_name              → paid_through_account_id (via paidThroughMapping)
tax_name1                 → tax_id (lookup)
billable                  → is_billable
transaction_id            → reference_number
```

**On-the-fly Vendor Creation:**
During expense migration, if `vendor` field has a name but no matching vendor exists:
1. Check vendor name cache (built at start from existing Zoho vendors)
2. If not found, create new vendor with just the name
3. Add to cache
4. Use new vendor_id for expense

### Payment (FBPayment → ZBPayment)
```
client_id                 → customer_id (via customerIdMapping, required)
date                      → date
amount.amount (parse)     → amount (Double)
invoice_id                → invoices[0].invoice_id (optional, via invoiceIdMapping)
                          → invoices[0].amount_applied (full amount if linked)
gateway OR type           → payment_mode (mapped - see below)
transaction_id OR order_id→ reference_number
note                      → description
(lookup via depositAccountMapping) → account_id (deposit account)
```

**Payment Mode Mapping:**
```
stripe, square, 2checkout → "credit_card"
paypal                    → "paypal"
wechat, ach, bank transfer→ "bank_transfer"
check, cheque             → "check"
cash                      → "cash"
(default)                 → "other"
```

### Category (FBCategory → ZBAccount)

**Direct Mode (default):**
```
category_name             → account_name
category_id (as string)   → account_code
is_cogs                   → account_type: "cost_of_goods_sold" or "expense"
(hardcode)                → description: "Imported from FreshBooks"
```

**Hierarchical Mode (--use-config-mapping):**
- Read category hierarchy from config
- Create parent accounts first, then children
- Map FreshBooks category names to Zoho names via config mapping
- Unknown categories fall back to default

## Configuration File (config.json)

```json
{
  "freshbooks": {
    "clientId": "...",
    "clientSecret": "...",
    "accessToken": "...",
    "refreshToken": "...",
    "accountId": "..."
  },
  "zoho": {
    "clientId": "...",
    "clientSecret": "...",
    "accessToken": "...",
    "refreshToken": "...",
    "organizationId": "...",
    "region": "com"
  },
  "categoryMapping": {
    "categories": [
      { "name": "Marketing", "children": ["Advertising", "Design"] },
      { "name": "Travel", "children": ["Lodging", "Transportation"] }
    ],
    "mapping": {
      "FB Category Name": "Zoho Category Name"
    }
  },
  "paidThroughMapping": {
    "Old Card Name": "New Card Name"
  },
  "depositAccountMapping": {
    "stripe": "Checking",
    "paypal": "PayPal",
    "check": "Checking",
    "default": "Checking"
  },
  "manualCustomerMapping": {
    "12345": "Customer Name for archived FB client"
  }
}
```

## CLI Commands

```bash
# Main migration commands
zoho-migration migrate all [OPTIONS]
zoho-migration migrate customers
zoho-migration migrate vendors
zoho-migration migrate invoices
zoho-migration migrate expenses
zoho-migration migrate categories
zoho-migration migrate items
zoho-migration migrate payments

# Auth commands
zoho-migration auth freshbooks [--redirect-uri URL]
zoho-migration auth zoho [--redirect-uri URL]
```

**Options:**
- `--dry-run`: Fetch data but don't create anything in Zoho (print "[DRY RUN] Would create...")
- `--verbose`: Print each entity being processed
- `--config <path>`: Custom config file path (default: ./config.json)
- `--use-config-mapping`: Use hierarchical category mapping from config
- `--include-items`: Include items migration (skipped by default)
- `--include-attachments`: Download/upload expense receipts

## Critical Implementation Details

### 1. FreshBooks visState Filtering
FreshBooks uses `vis_state` to track deleted/archived records:
- `vis_state == 0` or `nil` → active, migrate it
- `vis_state != 0` → archived/deleted, SKIP IT

### 2. Rate Limiting (CRITICAL)
```swift
actor ZohoAPI {
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 100

    private func checkRateLimit() async {
        // Remove timestamps older than 60 seconds
        let cutoff = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > cutoff }

        if requestTimestamps.count >= maxRequestsPerMinute {
            let oldestInWindow = requestTimestamps.first!
            let waitTime = oldestInWindow.addingTimeInterval(60).timeIntervalSinceNow
            if waitTime > 0 {
                print("Rate limit approaching, waiting \(Int(waitTime))s...")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        requestTimestamps.append(Date())
    }
}
```

### 3. OAuth Token Refresh
On 401 response:
1. Call token refresh endpoint with refresh_token
2. Update in-memory token
3. Update config.json file
4. Retry original request

**FreshBooks Token Refresh:**
```
POST https://api.freshbooks.com/auth/oauth/token
{
  "grant_type": "refresh_token",
  "client_id": "...",
  "client_secret": "...",
  "refresh_token": "..."
}
```

**Zoho Token Refresh:**
```
POST https://accounts.zoho.{region}/oauth/v2/token
grant_type=refresh_token&client_id=...&client_secret=...&refresh_token=...
```

### 4. ID Mappings
Maintain these during migration:
```swift
private var customerIdMapping: [Int: String] = [:]  // FB clientId → Zoho contactId
private var vendorIdMapping: [Int: String] = [:]
private var accountIdMapping: [Int: String] = [:]   // FB categoryId → Zoho accountId
private var invoiceIdMapping: [Int: String] = [:]
private var itemIdMapping: [Int: String] = [:]
```

### 5. Duplicate Detection
Before creating, check if entity already exists in Zoho:
- Customers/Vendors: lookup by name (case-insensitive)
- Invoices: lookup by invoice_number
- Categories: lookup by account_name
- Items: lookup by name

If found, reuse existing ID, don't create duplicate.

### 6. Error Handling
- Failed entities should be logged but NOT stop migration
- Print summary at end: Succeeded: X, Failed: Y, Skipped: Z
- Show first 10 errors with details

### 7. Pagination
FreshBooks returns paginated results. Loop until `page >= pages`:
```swift
var allEntities: [Entity] = []
var page = 1
while true {
    let response = try await fetch(page: page)
    allEntities.append(contentsOf: response.result.entities)
    if page >= response.result.pages { break }
    page += 1
}
```

### 8. Money Parsing
FreshBooks stores money as:
```json
{ "amount": "123.45", "code": "USD" }
```
Parse `amount` string to Double for Zoho.

## Auth Command Flow

Interactive OAuth flow:
1. Print authorization URL for user to open in browser
2. User authorizes and gets redirected to localhost with `?code=...`
3. User pastes the code
4. Exchange code for tokens
5. Save tokens to config.json
6. Print success message

## Expected Output Examples

**Verbose migration:**
```
Migrating customers...
  [CREATE] Customer: Acme Corp
  [EXISTS] Customer: Beta Inc (using existing ID: 12345)
  [SKIP] Customer: Old Client (archived)
Customers: Succeeded: 45, Failed: 2, Skipped: 8

Migrating invoices...
  [CREATE] Invoice: INV-001 for customer Acme Corp
  ...
```

**Dry run:**
```
[DRY RUN] Would create customer: Acme Corp
[DRY RUN] Would create invoice: INV-001
```

**Rate limiting:**
```
Rate limit approaching (98/100 requests), waiting 45s...
```

## Receipt/Attachment Migration

For expenses with receipts:
1. FreshBooks provides attachment info with `jwt` token for download
2. Download file using JWT-authenticated URL
3. Upload to Zoho via POST `/expenses/{id}/receipt` (multipart/form-data)

Match existing Zoho expenses to FreshBooks by: date + amount + description (case-insensitive).

---

Build this complete migration tool following Swift best practices, using actors for thread safety, proper error handling, and clean separation of concerns between API clients, mappers, and the migration service.
