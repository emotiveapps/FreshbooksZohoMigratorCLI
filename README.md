# FreshBooks to Zoho Books Migration Tool

## Author's Reflection

I wrote this tool in a day using Claude's Opus 4.5 model to accelerate my work.
Unlike most code samples I've shared, I spent very little time on the architecture or code reviewing the AI's work. One exception was debugging: there were a few bugs that even Opus 4.5 couldn't fix, so I examined the code and suggested a possible cause. In each case, the LLM was able to fix the bug once I'd proposed a (creative) theory. I think coming up with the out of box thinking necessary for this creativity is still a bit beyond what the LLM can accomplish.

I judged the app by its results. 

This took many iterations to:
 (a) fix bugs,
 (b) add requirements, such as migrating expense receipt PDFs/JPGs, and 
 (c) identify fields in FreshBooks that were not mapped correctly to Zoho Books (i.e. due to decoding errors, encoding errors, or the LLM misunderstanding the requirements) 
 
Actual #s: 21 dry-run migrations and 12 actual migrations. Thankfully Zoho Books' UI makes it super fast to delete records so I could wipe out invoices, payments, expenses, etc. before each new iteration.

### Why did it take so many iterations? Would it have been faster if I had prepared a complex prompt with all the known requirements?

This is a really interesting question.
First off, I didn't know all the requirements in advance. That would have required reading lots of API documentation for both FreshBooks and Zoho Books.  

**To further this experiment, I asked the AI as follows:**

> Thank you. Here's a reflection question. Please take your time to think it over. Could I have built
  this app faster than the full-day it took (the LLM estimates 10 hours; I guessed 12 hours 😇) if I had written a complex
  prompt with all the requirements in advance? Or would this have been too much context and not worked?

> As an experiment, please write out a complex prompt for me defining all the requirements. I will then
  feed that into a new incognito session of Opus 4.5 and see how much of this app it is able to produce
  in a single response.

**Opus 4.5's response is worth the time to read in full:**

> This is a fascinating question about AI-assisted development methodology. Let me think through it carefully,
> then write that comprehensive prompt.
>
> My honest assessment:
>
> A complex upfront prompt could probably produce 60-70% of a working solution in one shot, but there are
> fundamental challenges:
>
> 1. You didn't know all requirements upfront - Discovering that vendor names weren't mapping, that receipt
> attachments were needed, that terms needed special handling - these emerged from seeing actual migration
> results.
> 2. API structure details are hard to specify - FreshBooks' nested response.result.{entity} pattern, Zoho's
> code: 0 success pattern, the specific field names like vis_state vs visState - these require either reading
> extensive documentation or trial-and-error.
> 3. The "creative debugging" problem - You noted that even Opus 4.5 needed you to propose theories for
> certain bugs. A prompt can't anticipate bugs that stem from subtle data edge cases.
> 4. Time redistribution, not elimination - An upfront approach requires reading all API docs first. The total
> time might be similar, just front-loaded differently.
>
> That said, let me explore your codebase more thoroughly to write the most complete prompt possible.

➡️ Please see `comprehensive-prompt.md` for the resulting prompt.

### The next experiment: Replicate a working app from a comprehensive prompt.

Then I created a new folder `FreshbooksZohoMigratorFullPromptExperimentCLI` (yes, Swift engineers give things _really_ long names 🤣)

I added the full prompt suggested by Claude’s Opus 4.5 as the AGENTS.md file.

Created a new git repo to track progress. It has just the one AGENTS.md file and a .gitignore.

**Then I "checked my assumptions":**

> Do you have the ability to have an incognito or temporary Claude Code session with me, with no access to context from anything I've done
  previously?

**Claude's response:**

> ⏺ Each Claude Code conversation is already isolated by default. I don't have access to previous conversations or sessions you've had - this conversation started fresh with no memory of past interactions.
>
> The only context I have access to right now is:
> - What you write in this current conversation
> - Files in your current working directory (/Users/andrewash/Development/experiments/FreshbooksZohoMigratorFullPromptExperimentCLI)
> - Git status and history for this repo
> - Basic environment info (OS, date, etc.)
>
> So in that sense, every session is already "incognito" from previous sessions. If you want to start completely fresh within a session, you can simply start a new conversation.

**My next prompt:**

> Please review the AGENTS.MD file in this directory. Then work for as long as needed, and as many iterations as needed, without asking
  me any questions, to produce that goal. I'm testing whether if I'd taken the time to write as full a prompt as the one you see here,
  whether it would have produced the full app that it took me 12 hours to write yesterday with Claude's Opus 4.5 model, but in a short Q&A
  Socratic method style of LLM/human pair coding. Keep track of how long it takes you, and report the results. Also when complete, assess how
  well it works. You will not have access to the API keys, so you won't be able to perform trial & error testing. 

**The Result**

❓ TBD ❓ 

It's still working 😄
I'll post an update with the results later this long weekend.

## Design Principles

1. open-source - from the beginning I wanted to make this tool accessible to anyone who should want to experiment with it.
2. confidential - anything unique to the user, such as bank account names, a custom chart of accounts, customer names, and of course, auth tokens, is stored in `config.json`, which is in `.gitignore`.   
3. idempotent - repeated runs of this tool should not cause duplicates or errors (*⚠️ I haven't tested this in every possible permutation. See disclaimer below.*)
4. pick & choose - migrate only one data-type, or perform a full migration. It's up to you.
5. bonus goal: complete - I hoped that the tool would migrate all my data, including receipts on expenses (i.e. attachments). In fact, no part of the migration was fixed manually after it was done.

---
**LLM Authorship Begins Here**
ℹ️ Everything above this point was written by the author, by hand. Most of the rest was written by the LLM, with my guidance. 
--- 

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
