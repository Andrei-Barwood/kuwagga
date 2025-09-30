import Foundation

public class UserAgentPrivacyManager {
    public static let shared = UserAgentPrivacyManager()
    
    private let userDefaults = UserDefaults(suiteName: "com.apple.privacy.useragent")!
    private let perAppSettingsKey = "PerAppUserAgentSettings"
    private let globalPrivacyLevelKey = "GlobalUserAgentPrivacyLevel"
    
    public struct AppPrivacySettings {
        let bundleIdentifier: String
        let privacyLevel: PrivacyLevel
        let allowVersionDisclosure: Bool
        let customUserAgent: String?
    }
    
    public func setPrivacyLevel(for bundleID: String, level: PrivacyLevel) {
        var settings = getPerAppSettings()
        settings[bundleID] = AppPrivacySettings(
            bundleIdentifier: bundleID,
            privacyLevel: level,
            allowVersionDisclosure: level != .maximum,
            customUserAgent: nil
        )
        savePerAppSettings(settings)
        notifyWebKitOfSettingsChange()
    }
    
    public func getEffectivePrivacyLevel(for bundleID: String) -> PrivacyLevel {
        let perAppSettings = getPerAppSettings()
        
        if let appSettings = perAppSettings[bundleID] {
            return appSettings.privacyLevel
        }
        
        return getGlobalPrivacyLevel()
    }
    
    private func notifyWebKitOfSettingsChange() {
        NotificationCenter.default.post(
            name: .userAgentPrivacySettingsChanged,
            object: nil
        )
    }
}

extension Notification.Name {
    static let userAgentPrivacySettingsChanged = Notification.Name("UserAgentPrivacySettingsChanged")
}
