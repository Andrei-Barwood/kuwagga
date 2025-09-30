@implementation WKWebView (PrivacyAPI)

- (void)evaluateDeviceCapabilities:(void (^)(NSDictionary<NSString *, NSNumber *> *))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *capabilities = [NSMutableDictionary dictionary];
        
        // Safe capability detection without exposing specific versions
        capabilities[@"supportsWebGL2"] = @([self supportsWebGL2]);
        capabilities[@"supportsWebRTC"] = @([self supportsWebRTC]);
        capabilities[@"supportsServiceWorkers"] = @([self supportsServiceWorkers]);
        capabilities[@"maxTouchPoints"] = @([UIScreen mainScreen].maximumTouchPoints);
        capabilities[@"devicePixelRatio"] = @([UIScreen mainScreen].scale);
        
        // iOS generation without specific version
        capabilities[@"iOSGeneration"] = @([self getiOSGeneration]);
        
        completionHandler([capabilities copy]);
    });
}

- (NSInteger)getiOSGeneration {
    // Return iOS generation (17, 18, 19) instead of specific version
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return version.majorVersion;
}

@end
