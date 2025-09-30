// Test suite for User-Agent privacy features
class UserAgentPrivacyTests: XCTestCase {
    
    func testBuildVersionMasking() {
        let originalUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/22A123 Safari/604.1"
        
        let maskedUA = UserAgentHelper.sanitizedUserAgentWithBuildMasking(originalUA)
        
        XCTAssertFalse(maskedUA.contains("22A123"), "Build number should be masked")
        XCTAssertTrue(maskedUA.contains("Mobile/WebKit"), "Should contain generic build identifier")
        XCTAssertTrue(maskedUA.contains("iPhone OS 18_0"), "iOS version should be preserved")
    }
    
    func testEntropyReduction() {
        let highEntropyUA = generateHighEntropyUserAgent()
        let reducedUA = UserAgentEntropyReduction().reduceEntropy(highEntropyUA)
        
        let originalEntropy = calculateEntropy(highEntropyUA)
        let reducedEntropy = calculateEntropy(reducedUA)
        
        XCTAssertLessThanOrEqual(reducedEntropy, 8.5, "Entropy should be reduced to acceptable levels")
        XCTAssertLessThan(reducedEntropy, originalEntropy, "Entropy should be reduced")
    }
    
    func testPrivacyBudgetSystem() {
        let budgetManager = PrivacyBudgetManager()
        let testDomain = "example.com"
        
        // First access should be allowed
        XCTAssertTrue(budgetManager.canRevealInformation(for: testDomain, entropyCost: 3.0))
        
        // Consume budget
        budgetManager.consumeBudget(for: testDomain, entropyCost: 3.0)
        
        // High entropy request should be denied
        XCTAssertFalse(budgetManager.canRevealInformation(for: testDomain, entropyCost: 5.0))
    }
}
