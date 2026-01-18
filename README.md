# FreshBooks to Zoho Books Migration Tool

> ⚠️ **DISCLAIMER**: This software is provided "as is", without warranty of any kind, express or implied. Use at your own risk. The author(s) are not responsible for any data loss, corruption, or damage that may result from using this tool. **Always back up your data before running any migration.** Test thoroughly with `--dry-run` first and verify results in a sandbox environment when possible.
>
> 🤖 This tool was written with the assistance of [Claude](https://claude.ai) (Anthropic's Opus 4.5).

---

A command-line application written in Swift to migrate data from FreshBooks to Zoho Books.

## Data Migrated

- **Expense Categories** → Chart of Accounts
- **Taxes** → Tax Rates
- **Items/Products** → Items
- **Clients** → Contacts (Customers)
- **Vendors** → Contacts (Vendors)
- **Invoices** → Invoices
- **Expenses** → Expenses
- **Payments** → Customer Payments

## Prerequisites

- Swift 5.9 or later
- macOS 12.0 or later
- FreshBooks OAuth application credentials
- Zoho Books OAuth application credentials

## Setup

### 1. Create FreshBooks OAuth Application

1. Go to [FreshBooks Developer Portal](https://my.freshbooks.com/#/developer)
2. Create a new application
3. Note your Client ID and Client Secret
4. Set up OAuth flow to get access and refresh tokens
5. Find your Account ID in FreshBooks settings

### 2. Create Zoho Books OAuth Application

1. Go to [Zoho API Console](https://api-console.zoho.com/)
2. Create a new Self Client or Server-based Application
3. Add scopes:
   - `ZohoBooks.contacts.CREATE`
   - `ZohoBooks.invoices.CREATE`
   - `ZohoBooks.expenses.CREATE`
   - `ZohoBooks.accountants.CREATE`
   - `ZohoBooks.settings.READ`
   - `ZohoBooks.settings.CREATE`
   - `ZohoBooks.items.CREATE`
   - `ZohoBooks.customerpayments.CREATE`
4. Generate access and refresh tokens
5. Find your Organization ID in Zoho Books Settings → Organization Profile

### 3. Configure the Application

Copy the example config and fill in your credentials:

```bash
cp config.example.json config.json
```

Edit `config.json` with your credentials:

```json
{
  "freshbooks": {
    "clientId": "your-freshbooks-client-id",
    "clientSecret": "your-freshbooks-client-secret",
    "accessToken": "your-access-token",
    "refreshToken": "your-refresh-token",
    "accountId": "your-account-id"
  },
  "zoho": {
    "clientId": "your-zoho-client-id",
    "clientSecret": "your-zoho-client-secret",
    "accessToken": "your-access-token",
    "refreshToken": "your-refresh-token",
    "organizationId": "your-organization-id",
    "region": "com"
  }
}
```

**Zoho Regions:**
- `com` - United States
- `eu` - Europe
- `in` - India
- `au` - Australia

## Build

```bash
swift build
```

For a release build:

```bash
swift build -c release
```

## Editing in Xcode

```bash
open Package.swift
```

This project can only be built on macOS devices.
It will not compile when an iOS device is selected.

## Usage

### Migrate All Data

```bash
swift run ZohoMigration migrate all
```

### Migrate Specific Entities

```bash
# Migrate only customers
swift run ZohoMigration migrate customers

# Migrate only vendors
swift run ZohoMigration migrate vendors

# Migrate only invoices
swift run ZohoMigration migrate invoices

# Migrate only expenses
swift run ZohoMigration migrate expenses

# Migrate only expense categories to chart of accounts
swift run ZohoMigration migrate categories

# Migrate only items/products
swift run ZohoMigration migrate items

# Migrate only tax rates
swift run ZohoMigration migrate taxes

# Migrate only customer payments
swift run ZohoMigration migrate payments
```

### Options

```bash
# Use a different config file
swift run ZohoMigration migrate all --config /path/to/config.json

# Dry run (validate without making changes)
swift run ZohoMigration migrate all --dry-run

# Verbose output
swift run ZohoMigration migrate all --verbose

# Combine options
swift run ZohoMigration migrate all --config ./my-config.json --dry-run --verbose
```

### Help

```bash
swift run ZohoMigration --help
swift run ZohoMigration migrate --help
swift run ZohoMigration migrate all --help
```

## Migration Order

When running `migrate all`, entities are migrated in this order:

1. **Categories** → Chart of Accounts (needed for expense account mapping)
2. **Taxes** → Tax Rates (needed for item tax associations)
3. **Items/Products** → Items (uses tax ID mapping)
4. **Customers** (needed for invoice and payment customer mapping)
5. **Vendors**
6. **Invoices** (uses customer ID mapping)
7. **Expenses** (uses account, vendor, and customer ID mappings)
8. **Payments** (uses customer and invoice ID mappings)

## Rate Limiting

Zoho Books has a rate limit of 100 requests per minute. The tool automatically:
- Tracks request timestamps
- Pauses when approaching the limit
- Displays progress during waits

## Error Handling

- Failed entities are logged but don't stop the migration
- Summary shows success/failure counts at the end
- Use `--verbose` for detailed error messages
- Archived/deleted entities (visState != 0) are skipped

## Token Refresh

The tool automatically refreshes OAuth tokens when they expire (401 response).

## Notes

- The tool maps FreshBooks IDs to Zoho IDs during migration
- Invoice migration requires customer mapping to exist
- Expense migration requires account mapping to exist
- Payment migration requires customer mapping to exist (and optionally invoice mapping)
- Item migration can optionally use tax ID mapping for tax associations
- Run categories migration before expenses if migrating separately
- Run customers migration before invoices if migrating separately
- Run taxes migration before items if you want tax associations
- Run customers and invoices before payments if migrating separately
