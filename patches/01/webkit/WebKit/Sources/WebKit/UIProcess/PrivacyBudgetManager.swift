public class PrivacyBudgetManager {
    private static let shared = PrivacyBudgetManager()
    
    private struct SiteBudget {
        let domain: String
        var remainingBits: Double
        var lastAccess: Date
        var accessCount: Int
    }
    
    private var siteBudgets: [String: SiteBudget] = [:]
    private let dailyBudget: Double = 5.0 // bits of entropy per day per site
    
    public func canRevealInformation(for domain: String, 
                                   entropyCost: Double) -> Bool {
        
        let budget = getBudgetForDomain(domain)
        return budget.remainingBits >= entropyCost
    }
    
    public func consumeBudget(for domain: String, 
                            entropyCost: Double) {
        guard var budget = siteBudgets[domain] else { return }
        
        budget.remainingBits -= entropyCost
        budget.accessCount += 1
        budget.lastAccess = Date()
        
        siteBudgets[domain] = budget
    }
    
    private func getBudgetForDomain(_ domain: String) -> SiteBudget {
        if let existing = siteBudgets[domain] {
            // Refresh budget if it's a new day
            if Calendar.current.isDateInToday(existing.lastAccess) == false {
                siteBudgets[domain] = SiteBudget(
                    domain: domain,
                    remainingBits: dailyBudget,
                    lastAccess: Date(),
                    accessCount: 0
                )
                return siteBudgets[domain]!
            }
            return existing
        } else {
            let newBudget = SiteBudget(
                domain: domain,
                remainingBits: dailyBudget,
                lastAccess: Date(),
                accessCount: 0
            )
            siteBudgets[domain] = newBudget
            return newBudget
        }
    }
}
