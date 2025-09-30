@implementation UserAgentHelper (PrivacyEnhancements)

+ (NSString *)sanitizedUserAgentWithBuildMasking:(NSString *)originalUserAgent {
    // Phase 1: Simple build version masking
    NSError *error = nil;
    NSRegularExpression *buildRegex = [NSRegularExpression 
        regularExpressionWithPattern:@"Mobile/[A-Z0-9]+" 
        options:0 
        error:&error];
    
    if (error) {
        // Fallback to original if regex fails
        return originalUserAgent;
    }
    
    // Replace with generic identifier
    NSString *maskedUserAgent = [buildRegex 
        stringByReplacingMatchesInString:originalUserAgent
        options:0
        range:NSMakeRange(0, [originalUserAgent length])
        withTemplate:@"Mobile/WebKit"];
    
    return maskedUserAgent;
}

+ (NSString *)adaptiveUserAgentWithPrivacyLevel:(PrivacyLevel)level 
                               originalUserAgent:(NSString *)originalUA {
    switch (level) {
        case PrivacyLevelMinimal:
            return [self sanitizedUserAgentWithBuildMasking:originalUA];
        case PrivacyLevelBalanced:
            return [self versionGroupedUserAgent:originalUA];
        case PrivacyLevelMaximum:
            return [self genericUserAgent];
    }
}

@end
