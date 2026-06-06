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
    NSSet *flagStringSet = [preferences getFlagStringSet];
    NSSet *expectedSet = [NSSet setWithArray:@[@"CTRL", @"CMD"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the expected defaults");

    [preferences setModifierKey:@"CTRL" enabled:NO];
    flagStringSet = [preferences getFlagStringSet];
    expectedSet = [NSSet setWithArray:@[@"CMD"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the modified defaults");

    [preferences setToDefaults];
    flagStringSet = [preferences getFlagStringSet];
    expectedSet = [NSSet setWithArray:@[@"CMD", @"CTRL"]];
    XCTAssertEqualObjects(flagStringSet, expectedSet, "Should contain the restored defaults");
}

- (void)testResizeFromNearestCorner {
    [preferences setToDefaults];
    XCTAssertFalse([preferences resizeFromNearestCorner], "Should default to disabled");

    [preferences setResizeFromNearestCorner:YES];
    XCTAssertTrue([preferences resizeFromNearestCorner], "Should persist the enabled setting");

    [preferences setToDefaults];
    XCTAssertFalse([preferences resizeFromNearestCorner], "Should be disabled after reset");
}

@end
