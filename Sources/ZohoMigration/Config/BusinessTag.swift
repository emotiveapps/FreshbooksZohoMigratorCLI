import Foundation

/// Represents which business line an expense belongs to
enum BusinessLine: Equatable, Hashable {
    case primary(String)    // e.g., "Emotive Apps (EA)"
    case secondary(String)  // e.g., "Lucky Frog Bricks (LF)"

    var name: String {
        switch self {
        case .primary(let name), .secondary(let name):
            return name
        }
    }
}

/// Helper for business line tagging operations
struct BusinessTagHelper {
    let config: BusinessTagConfig
    let startDate: Date?

    init(config: BusinessTagConfig) {
        self.config = config
        self.startDate = Self.parseDate(config.secondaryStartDate)
    }

    /// Determine the appropriate business line for an expense
    func determineBusinessLine(date: String?, description: String?) -> BusinessLine {
        // Parse the expense date
        guard let dateString = date,
              let expenseDate = Self.parseDate(dateString),
              let cutoffDate = startDate else {
            // If no date or can't parse, default to primary
            return .primary(config.primaryTag)
        }

        // Before cutoff date, everything is primary business
        if expenseDate < cutoffDate {
            return .primary(config.primaryTag)
        }

        // From cutoff date onwards, check for secondary business keywords
        if let desc = description?.lowercased() {
            for keyword in config.secondaryKeywords {
                if desc.contains(keyword.lowercased()) {
                    return .secondary(config.secondaryTag)
                }
            }
        }

        // Default to primary
        return .primary(config.primaryTag)
    }

    /// Parse a date string in YYYY-MM-DD format
    private static func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}
