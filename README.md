# FreshBooks to Zoho Books Migration Tool

> ⚠️ **DISCLAIMER**: This software is provided "as is", without warranty of any kind, express or implied. Use at your own risk. The author(s) are not responsible for any data loss, corruption, or damage that may result from using this tool. **Always back up your data before running any migration.** Test thoroughly with `--dry-run` first and verify results in a sandbox environment when possible.
>
> 🤖 This tool was written with the assistance of [Claude](https://claude.ai) (Anthropic's Opus 4.5).

---

A command-line application written in Swift to migrate data from FreshBooks to Zoho Books.

## Data Migrated

- **Expense Categories** → Chart of Accounts
- **Items/Products** → Items *(optional, skipped by default)*
- **Clients** → Contacts (Customers)
- **Vendors** → Contacts (Vendors)
- **Invoices** → Invoices (line items created inline)
- **Expenses** → Expenses
- **Payments** → Customer Payments

**Note:** Taxes are not migrated. Zoho Books creates default tax rates during onboarding (e.g., "RI Sales Tax"). Use existing Zoho taxes directly.

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

### Sample Command
This is the actual command I used in prod

```bash
swift run ZohoMigration migrate all --use-config-mapping --verbose 2>&1 | tee actual-run-output-3.txt
```

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

# Migrate only customer payments
swift run ZohoMigration migrate payments
```

### Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Validate and preview changes without making any actual API calls to Zoho |
| `--verbose` | Enable detailed output showing each entity being processed |
| `--config <path>` | Use a custom config file (default: `./config.json`) |
| `--use-config-mapping` | Use hierarchical category mapping from config instead of direct 1:1 FreshBooks category migration. Creates parent/child accounts in Zoho based on the `categoryMapping.categories` structure in config.json |
| `--include-items` | Include items/products in the migration. **Skipped by default** because FreshBooks items are often one-off service descriptions that don't need to be catalog items in Zoho. Invoice line items are created inline with name, description, rate, and quantity - no catalog item reference required. |

```bash
# Dry run (validate without making changes)
swift run ZohoMigration migrate all --dry-run

# Verbose output
swift run ZohoMigration migrate all --verbose

# Use hierarchical category mapping from config
swift run ZohoMigration migrate all --use-config-mapping

# Include items migration (usually not needed)
swift run ZohoMigration migrate all --include-items

# Use a different config file
swift run ZohoMigration migrate all --config /path/to/config.json

# Combine options
swift run ZohoMigration migrate all --dry-run --verbose --use-config-mapping
```

### Refresh OAuth Tokens

Use the `auth` command to get new OAuth tokens when they expire:

```bash
# Refresh FreshBooks tokens
swift run ZohoMigration auth freshbooks

# Refresh Zoho tokens
swift run ZohoMigration auth zoho

# Use custom redirect URI if needed
swift run ZohoMigration auth freshbooks --redirect-uri "https://your-uri.com/callback"
```

The command will guide you through the OAuth flow and automatically update your `config.json` with the new tokens.

### Help

```bash
swift run ZohoMigration --help
swift run ZohoMigration migrate --help
swift run ZohoMigration migrate all --help
```

## Migration Order

When running `migrate all`, entities are migrated in this order:

1. **Categories** → Chart of Accounts (needed for expense account mapping)
2. **Items/Products** → Items *(skipped by default, use `--include-items` to enable)*
3. **Customers** (needed for invoice and payment customer mapping)
4. **Vendors**
5. **Invoices** (uses customer ID mapping; line items created inline)
6. **Expenses** (uses account, vendor, and customer ID mappings)
7. **Payments** (uses customer and invoice ID mappings)

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
- Run categories migration before expenses if migrating separately
- Run customers migration before invoices if migrating separately
- Run customers and invoices before payments if migrating separately
- **On-the-fly vendor creation**: During expense migration, if an expense references a vendor by name that doesn't exist in Zoho, it will be created automatically. Existing vendors are cached at the start to avoid duplicates.
- Invoice terms (payment terms like "Net 30") are mapped from FreshBooks to Zoho
