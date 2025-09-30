//
// UserAgentEntropyReduction.h
// WebKit
//
// Privacy-focused User-Agent entropy reduction and fingerprinting prevention
// Copyright (C) 2025 Snocomm. All rights reserved.
//

#ifndef UserAgentEntropyReduction_h
#define UserAgentEntropyReduction_h

#include <string>
#include <vector>
#include <unordered_map>
#include <memory>

namespace WebCore {

// Forward declarations
class UserAgentComponents;
class PrivacyBudgetManager;

/**
 * @brief Enumeration defining privacy levels for User-Agent entropy reduction
 */
enum class PrivacyLevel : uint8_t {
    Minimal = 0,    // Basic build number masking only
    Balanced = 1,   // Version grouping and entropy reduction
    Maximum = 2     // Generic User-Agent with minimal information
};

/**
 * @brief Structure representing entropy analysis results
 */
struct EntropyAnalysis {
    double totalEntropy;
    double buildNumberEntropy;
    double versionEntropy;
    double deviceModelEntropy;
    double webkitVersionEntropy;
    bool exceedsThreshold;
    std::vector<std::string> highEntropyComponents;
};

/**
 * @brief Configuration options for entropy reduction
 */
struct EntropyReductionConfig {
    double maxEntropyBits = 8.5;           // Maximum allowed entropy in bits
    bool enableVersionGrouping = true;      // Group iOS versions (e.g., 18.x)
    bool enableBuildMasking = true;        // Mask specific build numbers
    bool enableDeviceGeneralization = true; // Use generic device identifiers
    bool enableRotation = false;           // Rotate UA components periodically
    uint32_t rotationIntervalHours = 24;   // Rotation interval in hours
};

/**
 * @brief Main class for User-Agent entropy reduction and privacy protection
 */
class UserAgentEntropyReduction {
public:
    /**
     * @brief Get the singleton instance of UserAgentEntropyReduction
     * @return Reference to the singleton instance
     */
    static UserAgentEntropyReduction& getInstance();
    
    /**
     * @brief Initialize the entropy reduction system with configuration
     * @param config Configuration parameters for entropy reduction
     */
    void initialize(const EntropyReductionConfig& config);
    
    /**
     * @brief Reduce entropy in a User-Agent string based on privacy level
     * @param originalUserAgent The original User-Agent string
     * @param privacyLevel The desired privacy level
     * @param domain Optional domain for privacy budget calculations
     * @return Privacy-enhanced User-Agent string
     */
    std::string reduceEntropy(const std::string& originalUserAgent, 
                             PrivacyLevel privacyLevel,
                             const std::string& domain = "");
    
    /**
     * @brief Calculate entropy value of a User-Agent string
     * @param userAgent The User-Agent string to analyze
     * @return EntropyAnalysis structure with detailed entropy information
     */
    EntropyAnalysis calculateEntropy(const std::string& userAgent) const;
    
    /**
     * @brief Check if a User-Agent string exceeds entropy threshold
     * @param userAgent The User-Agent string to check
     * @return True if entropy exceeds configured threshold
     */
    bool exceedsEntropyThreshold(const std::string& userAgent) const;
    
    /**
     * @brief Generate a privacy-compliant User-Agent for given parameters
     * @param deviceType Device type (iPhone, iPad, etc.)
     * @param iOSMajorVersion Major iOS version number
     * @param privacyLevel Desired privacy level
     * @return Generated User-Agent string
     */
    std::string generatePrivacyCompliantUserAgent(const std::string& deviceType,
                                                 int iOSMajorVersion,
                                                 PrivacyLevel privacyLevel) const;
    
    /**
     * @brief Set custom entropy weights for different UA components
     * @param component Component name (e.g., "build_number", "ios_version")
     * @param weight Entropy weight value
     */
    void setEntropyWeight(const std::string& component, double weight);
    
    /**
     * @brief Get current entropy weight for a component
     * @param component Component name
     * @return Current entropy weight
     */
    double getEntropyWeight(const std::string& component) const;
    
    /**
     * @brief Enable or disable User-Agent component rotation
     * @param enabled True to enable rotation
     * @param intervalHours Rotation interval in hours
     */
    void setRotationPolicy(bool enabled, uint32_t intervalHours = 24);
    
    /**
     * @brief Manually trigger User-Agent component rotation
     */
    void rotateComponents();
    
    /**
     * @brief Register a privacy budget manager for domain-based entropy control
     * @param budgetManager Shared pointer to privacy budget manager
     */
    void setPrivacyBudgetManager(std::shared_ptr<PrivacyBudgetManager> budgetManager);
    
    /**
     * @brief Get statistics about entropy reduction effectiveness
     * @return Map of statistics (requests processed, entropy reduced, etc.)
     */
    std::unordered_map<std::string, uint64_t> getStatistics() const;
    
    /**
     * @brief Reset all statistics counters
     */
    void resetStatistics();
    
    /**
     * @brief Parse User-Agent string into structured components
     * @param userAgent The User-Agent string to parse
     * @return Parsed components structure
     */
    std::unique_ptr<UserAgentComponents> parseUserAgent(const std::string& userAgent) const;
    
    /**
     * @brief Validate that a User-Agent string meets privacy requirements
     * @param userAgent The User-Agent string to validate
     * @param privacyLevel Required privacy level
     * @return True if User-Agent meets privacy requirements
     */
    bool validatePrivacyCompliance(const std::string& userAgent, 
                                  PrivacyLevel privacyLevel) const;

private:
    // Private constructor for singleton pattern
    UserAgentEntropyReduction();
    
    // Private destructor
    ~UserAgentEntropyReduction();
    
    // Delete copy constructor and assignment operator
    UserAgentEntropyReduction(const UserAgentEntropyReduction&) = delete;
    UserAgentEntropyReduction& operator=(const UserAgentEntropyReduction&) = delete;
    
    // Internal helper methods
    std::string maskBuildNumber(const std::string& userAgent) const;
    std::string generalizeVersion(const std::string& userAgent) const;
    std::string generalizeDevice(const std::string& userAgent) const;
    std::string applyRotation(const std::string& userAgent) const;
    
    bool containsBuildNumber(const std::string& userAgent) const;
    bool containsSpecificVersion(const std::string& userAgent) const;
    bool containsSpecificDevice(const std::string& userAgent) const;
    
    double calculateComponentEntropy(const std::string& component, 
                                   const std::string& userAgent) const;
    
    // Internal data members
    EntropyReductionConfig m_config;
    std::unordered_map<std::string, double> m_entropyWeights;
    std::shared_ptr<PrivacyBudgetManager> m_budgetManager;
    
    // Statistics tracking
    mutable uint64_t m_requestsProcessed;
    mutable uint64_t m_entropyReduced;
    mutable uint64_t m_privacyViolationsBlocked;
    
    // Rotation state
    std::chrono::time_point<std::chrono::system_clock> m_lastRotation;
    std::unordered_map<std::string, std::string> m_rotatedComponents;
    
    // Thread safety
    mutable std::mutex m_mutex;
};

/**
 * @brief Structure representing parsed User-Agent components
 */
class UserAgentComponents {
public:
    std::string mozilla;           // Mozilla identifier
    std::string platform;          // Platform (iPhone, iPad, etc.)
    std::string osVersion;         // Operating system version
    std::string webkitVersion;     // WebKit version
    std::string browserVersion;    // Browser version
    std::string buildNumber;       // Build number (if present)
    std::string deviceModel;       // Device model (if present)
    
    /**
     * @brief Reconstruct User-Agent string from components
     * @return Reconstructed User-Agent string
     */
    std::string reconstruct() const;
    
    /**
     * @brief Check if components contain high-entropy information
     * @return True if high-entropy information is present
     */
    bool containsHighEntropyInfo() const;
    
    /**
     * @brief Apply privacy filtering to components
     * @param privacyLevel Privacy level to apply
     */
    void applyPrivacyFiltering(PrivacyLevel privacyLevel);
};

/**
 * @brief Utility functions for User-Agent entropy analysis
 */
namespace UserAgentUtils {
    /**
     * @brief Calculate information entropy of a string
     * @param data Input string
     * @return Entropy value in bits
     */
    double calculateInformationEntropy(const std::string& data);
    
    /**
     * @brief Extract iOS version from User-Agent string
     * @param userAgent User-Agent string
     * @return iOS version string or empty if not found
     */
    std::string extractiOSVersion(const std::string& userAgent);
    
    /**
     * @brief Extract build number from User-Agent string
     * @param userAgent User-Agent string
     * @return Build number string or empty if not found
     */
    std::string extractBuildNumber(const std::string& userAgent);
    
    /**
     * @brief Check if User-Agent represents an iOS device
     * @param userAgent User-Agent string
     * @return True if iOS device is detected
     */
    bool isiOSUserAgent(const std::string& userAgent);
}

} // namespace WebCore

#endif // UserAgentEntropyReduction_h
