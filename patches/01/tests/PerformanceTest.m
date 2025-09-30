// Performance benchmarks for User-Agent generation
@interface UserAgentPerformanceTests : XCTestCase
@end

@implementation UserAgentPerformanceTests

- (void)testUserAgentGenerationPerformance {
    [self measureBlock:^{
        for (int i = 0; i < 10000; i++) {
            NSString *userAgent = [DynamicUserAgent generateUserAgentForRequest:nil 
                                                                   privacyLevel:PrivacyLevelBalanced];
        }
    }];
    
    // Benchmark should show minimal performance impact (<1ms per generation)
}

- (void)testEntropyCalculationPerformance {
    NSString *sampleUA = @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/22A123 Safari/604.1";
    
    [self measureBlock:^{
        for (int i = 0; i < 50000; i++) {
            double entropy = [UserAgentEntropyReduction calculateEntropy:sampleUA];
        }
    }];
}

@end
