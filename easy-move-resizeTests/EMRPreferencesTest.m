#import <XCTest/XCTest.h>
#import "EMRPreferences.h"

@interface EMRPreferencesTest : XCTestCase

@end

@implementation EMRPreferencesTest {
    NSString *testDefaultsName;
    EMRPreferences *preferences;
}

- (void)setUp {
    [super setUp];
    NSString *uuid = [[NSUUID UUID] UUIDString];
    testDefaultsName = [@"org.dmarcotte.Easy-Move-Resize." stringByAppendingString:uuid];
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:testDefaultsName];
    preferences = [[EMRPreferences alloc] initWithUserDefaults:userDefaults];
}

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:testDefaultsName];
    [super tearDown];
}

- (void)testResetPreferences {
    [preferences setToDefaults];
    NSSet *flagStringSet = [preferences getFlagStringSetForFlagSet:click];
    NSSet *expectedSet = [NSSet setWithArray:@[@"CTRL", @"CMD"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the expected defaults");

    [preferences setModifierKey:@"CTRL" enabled:NO flagSet:click];
    flagStringSet = [preferences getFlagStringSetForFlagSet:click];
    expectedSet = [NSSet setWithArray:@[@"CMD"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the modified defaults");

    [preferences setToDefaults];
    flagStringSet = [preferences getFlagStringSetForFlagSet:click];
    expectedSet = [NSSet setWithArray:@[@"CMD", @"CTRL"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the restored defaults");
}

@end
