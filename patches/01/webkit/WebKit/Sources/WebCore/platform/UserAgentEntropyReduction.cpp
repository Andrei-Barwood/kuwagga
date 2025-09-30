#include "UserAgentEntropyReduction.h"
#include <random>
#include <unordered_map>

class UserAgentEntropyReduction {
private:
    static constexpr double MAX_ENTROPY_BITS = 8.5; // Industry standard
    std::unordered_map<std::string, double> entropyWeights;
    
public:
    UserAgentEntropyReduction() {
        // Initialize entropy weights for different UA components
        entropyWeights["ios_version"] = 3.2;
        entropyWeights["build_number"] = 6.8;  // High entropy!
        entropyWeights["device_model"] = 4.1;
        entropyWeights["webkit_version"] = 2.3;
    }
    
    std::string reduceEntropy(const std::string& originalUA) {
        double currentEntropy = calculateEntropy(originalUA);
        
        if (currentEntropy <= MAX_ENTROPY_BITS) {
            return originalUA;
        }
        
        return applyEntropyReduction(originalUA, currentEntropy);
    }
    
private:
    double calculateEntropy(const std::string& userAgent) {
        double totalEntropy = 0.0;
        
        // Parse UA components and calculate entropy
        if (containsBuildNumber(userAgent)) {
            totalEntropy += entropyWeights["build_number"];
        }
        
        if (containsSpecificVersion(userAgent)) {
            totalEntropy += entropyWeights["ios_version"];
        }
        
        return totalEntropy;
    }
    
    std::string applyEntropyReduction(const std::string& ua, double currentEntropy) {
        std::string reducedUA = ua;
        double targetReduction = currentEntropy - MAX_ENTROPY_BITS;
        
        // Remove highest entropy components first
        if (targetReduction >= entropyWeights["build_number"]) {
            reducedUA = removeBuildNumber(reducedUA);
            targetReduction -= entropyWeights["build_number"];
        }
        
        if (targetReduction >= entropyWeights["ios_version"]) {
            reducedUA = generalizeVersion(reducedUA);
            targetReduction -= entropyWeights["ios_version"];
        }
        
        return reducedUA;
    }
};
