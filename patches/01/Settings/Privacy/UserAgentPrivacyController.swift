import UIKit
import PrivacySettingsFramework

class UserAgentPrivacyController: UITableViewController {
    
    enum PrivacyLevel: Int, CaseIterable {
        case minimal = 0      // Mask build only
        case balanced = 1     // Group versions
        case maximum = 2      // Generic UA
        
        var displayName: String {
            switch self {
            case .minimal: return "Minimal Protection"
            case .balanced: return "Balanced Protection"
            case .maximum: return "Maximum Protection"
            }
        }
        
        var description: String {
            switch self {
            case .minimal: 
                return "Hides specific build numbers while preserving iOS version information for compatibility"
            case .balanced: 
                return "Groups iOS versions (e.g., 18.x) and uses generic build identifiers"
            case .maximum: 
                return "Uses standardized User-Agent with minimal system information"
            }
        }
    }
    
    @IBOutlet weak var privacyLevelSegmentedControl: UISegmentedControl!
    @IBOutlet weak var perAppControlSwitch: UISwitch!
    @IBOutlet weak var developerOverrideSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPrivacyControls()
        loadCurrentSettings()
    }
    
    private func setupPrivacyControls() {
        // Configure segmented control for privacy levels
        privacyLevelSegmentedControl.removeAllSegments()
        for (index, level) in PrivacyLevel.allCases.enumerated() {
            privacyLevelSegmentedControl.insertSegment(
                withTitle: level.displayName, 
                at: index, 
                animated: false
            )
        }
        
        privacyLevelSegmentedControl.addTarget(
            self, 
            action: #selector(privacyLevelChanged(_:)), 
            for: .valueChanged
        )
    }
    
    @objc private func privacyLevelChanged(_ sender: UISegmentedControl) {
        let selectedLevel = PrivacyLevel(rawValue: sender.selectedSegmentIndex) ?? .balanced
        UserAgentPrivacyManager.shared.setGlobalPrivacyLevel(selectedLevel)
        updateDescriptionText(for: selectedLevel)
    }
}
