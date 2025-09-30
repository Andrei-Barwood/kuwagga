import Foundation
import CryptoKit

public class DynamicUserAgent {
    private static let shared = DynamicUserAgent()
    
    // Rotate User-Agent components periodically
    private let rotationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var lastRotation: Date = Date.distantPast
    
    private struct UAComponents {
        let baseVersion: String      // e.g., "18.x"
        let webkitVersion: String    // Standardized
        let deviceClass: String      // iPhone/iPad only
        let capabilities: [String]   // Feature-based
    }
    
    public func generateUserAgent(for request: URLRequest, 
                                 privacyLevel: PrivacyLevel) -> String {
        
        let components = getRotatedComponents()
        
        switch privacyLevel {
        case .minimal:
            return buildMinimalUA(components: components)
        case .balanced:
            return buildBalancedUA(components: components)
        case .maximum:
            return buildGenericUA()
        }
    }
    
    private func getRotatedComponents() -> UAComponents {
        if Date().timeIntervalSince(lastRotation) > rotationInterval {
            rotateComponents()
        }
        
        return currentComponents
    }
    
    private func rotateComponents() {
        // Rotate non-identifying components to reduce tracking
        let variations = [
            "Mozilla/5.0",
            "Mozilla/5.0 (compatible)",
        ]
        
        currentComponents = UAComponents(
            baseVersion: getiOSBaseVersion(),
            webkitVersion: "605.1.15", // Standardized
            deviceClass: getDeviceClass(),
            capabilities: getAvailableCapabilities()
        )
        
        lastRotation = Date()
    }
    
    private var currentComponents: UAComponents = UAComponents(
        baseVersion: "18.x",
        webkitVersion: "605.1.15",
        deviceClass: "Mobile",
        capabilities: []
    )
}
