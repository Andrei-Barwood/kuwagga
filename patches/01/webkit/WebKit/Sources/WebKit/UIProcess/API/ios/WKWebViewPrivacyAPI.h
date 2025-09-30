@interface WKWebView (PrivacyAPI)

// Modern feature detection API (replaces User-Agent parsing)
- (void)evaluateDeviceCapabilities:(void (^)(NSDictionary<NSString *, NSNumber *> *capabilities))completionHandler;

// Version compatibility checking
- (void)checkiOSVersionCompatibility:(NSString *)requiredVersion 
                   completionHandler:(void (^)(BOOL isCompatible, NSString *availableFeatures))completionHandler;

// Privacy-aware analytics
- (NSDictionary<NSString *, id> *)privacyCompliantAnalyticsData;

@end
