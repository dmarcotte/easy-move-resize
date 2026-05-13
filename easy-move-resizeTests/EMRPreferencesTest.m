#import <XCTest/XCTest.h>
#import "EMRPreferences.h"

@interface EMRPreferencesTest : XCTestCase

@end

@implementation EMRPreferencesTest {
    NSString *testDefaultsName;
    NSUserDefaults *testDefaults;
    EMRPreferences *preferences;
}

- (void)setUp {
    [super setUp];
    NSString *uuid = [[NSUUID UUID] UUIDString];
    testDefaultsName = [@"org.dmarcotte.Easy-Move-Resize." stringByAppendingString:uuid];
    testDefaults = [[NSUserDefaults alloc] initWithSuiteName:testDefaultsName];
    preferences = [[EMRPreferences alloc] initWithUserDefaults:testDefaults];
}

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:testDefaultsName];
    [super tearDown];
}

#pragma mark - Helper: create preferences with pre-existing v1 data (simulates upgrade)

- (EMRPreferences *)createV1PreferencesWithModifiers:(NSString *)flags middleClick:(BOOL)middleClick {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *suiteName = [@"org.dmarcotte.Easy-Move-Resize.v1." stringByAppendingString:uuid];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];

    // Write v1-style preferences (no version key, no resize-specific keys)
    [defaults setObject:flags forKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    [defaults setBool:middleClick forKey:SHOULD_MIDDLE_CLICK_RESIZE];
    [defaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];

    // Constructing EMRPreferences triggers migration
    EMRPreferences *prefs = [[EMRPreferences alloc] initWithUserDefaults:defaults];
    return prefs;
}

#pragma mark - Existing test (move modifier reset)

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

#pragma mark - Resize modifier flags

- (void)testResizeModifierDefaults {
    [preferences setToDefaults];
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];
    NSSet *expectedSet = [NSSet setWithArray:@[@"CTRL", @"CMD"]];
    XCTAssertEqualObjects(resizeFlags, expectedSet, "Resize modifiers should default to CMD+CTRL");
}

- (void)testSetResizeModifierKey {
    [preferences setToDefaults];

    [preferences setResizeModifierKey:ALT_KEY enabled:YES];
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];
    XCTAssertTrue([resizeFlags containsObject:ALT_KEY], "ALT should be enabled after setting it");
    XCTAssertTrue([resizeFlags containsObject:CMD_KEY], "CMD should still be enabled");
    XCTAssertTrue([resizeFlags containsObject:CTRL_KEY], "CTRL should still be enabled");

    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    resizeFlags = [preferences getResizeFlagStringSet];
    XCTAssertFalse([resizeFlags containsObject:CTRL_KEY], "CTRL should be disabled after removing it");
    XCTAssertTrue([resizeFlags containsObject:ALT_KEY], "ALT should still be enabled");
    XCTAssertTrue([resizeFlags containsObject:CMD_KEY], "CMD should still be enabled");
}

- (void)testResizeModifierFlagsReturnsCorrectBitmask {
    [preferences setToDefaults];
    int flags = [preferences resizeModifierFlags];
    int expected = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    XCTAssertEqual(flags, expected, "Default resize modifier flags should be CMD|CTRL");

    // Change resize to ALT only
    [preferences setResizeModifierKey:CMD_KEY enabled:NO];
    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    [preferences setResizeModifierKey:ALT_KEY enabled:YES];
    flags = [preferences resizeModifierFlags];
    XCTAssertEqual(flags, (int)kCGEventFlagMaskAlternate, "Resize flags should be ALT only");
}

- (void)testMoveAndResizeModifiersAreIndependent {
    [preferences setToDefaults];

    // Change move to CMD only
    [preferences setModifierKey:CTRL_KEY enabled:NO];
    // Change resize to ALT+CMD
    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    [preferences setResizeModifierKey:ALT_KEY enabled:YES];

    NSSet *moveFlags = [preferences getFlagStringSet];
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];

    XCTAssertEqualObjects(moveFlags, [NSSet setWithArray:@[CMD_KEY]], "Move should be CMD only");
    NSSet *expectedResize = [NSSet setWithArray:@[CMD_KEY, ALT_KEY]];
    XCTAssertEqualObjects(resizeFlags, expectedResize, "Resize should be CMD+ALT");
}

#pragma mark - Mouse button preferences

- (void)testMouseButtonDefaults {
    [preferences setToDefaults];
    XCTAssertEqual([preferences moveMouseButton], EMRMouseButtonLeft, "Move mouse button should default to Left");
    XCTAssertEqual([preferences resizeMouseButton], EMRMouseButtonRight, "Resize mouse button should default to Right");
}

- (void)testSetMoveMouseButton {
    [preferences setToDefaults];
    [preferences setMoveMouseButton:EMRMouseButtonMiddle];
    XCTAssertEqual([preferences moveMouseButton], EMRMouseButtonMiddle, "Move mouse button should be Middle after setting");
}

- (void)testSetResizeMouseButton {
    [preferences setToDefaults];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    XCTAssertEqual([preferences resizeMouseButton], EMRMouseButtonLeft, "Resize mouse button should be Left after setting");
}

- (void)testResizeMouseButtonDefaultsToRightWhenUnset {
    // Fresh defaults with no resize mouse button key set — should return Right
    // setUp already creates a fresh preferences with setToDefaults called,
    // but let's test the nil-key path explicitly
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *suiteName = [@"org.dmarcotte.Easy-Move-Resize.niltest." stringByAppendingString:uuid];
    NSUserDefaults *freshDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    // setToDefaults will be called by init since ModifierFlags is nil
    EMRPreferences *freshPrefs = [[EMRPreferences alloc] initWithUserDefaults:freshDefaults];
    XCTAssertEqual([freshPrefs resizeMouseButton], EMRMouseButtonRight, "Resize should default to Right");
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:suiteName];
}

#pragma mark - Conflict detection

- (void)testNoConflictWithDefaultSettings {
    [preferences setToDefaults];
    XCTAssertFalse([preferences hasConflictingConfig], "Default settings should not conflict (different mouse buttons)");
}

- (void)testConflictWhenSameButtonAndSameModifiers {
    [preferences setToDefaults];
    // Set both to left-click with same modifiers
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    XCTAssertTrue([preferences hasConflictingConfig], "Same button + same modifiers should conflict");
}

- (void)testNoConflictWhenSameButtonDifferentModifiers {
    [preferences setToDefaults];
    // Both left-click, but different modifiers
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    [preferences setResizeModifierKey:ALT_KEY enabled:YES];
    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    XCTAssertFalse([preferences hasConflictingConfig], "Same button but different modifiers should not conflict");
}

- (void)testNoConflictWhenDifferentButtonSameModifiers {
    [preferences setToDefaults];
    // Same modifiers, but different buttons
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonRight];
    XCTAssertFalse([preferences hasConflictingConfig], "Different buttons with same modifiers should not conflict");
}

#pragma mark - Preference migration from v1

- (void)testMigrationCopiesModifierFlagsToResize {
    EMRPreferences *migrated = [self createV1PreferencesWithModifiers:@"CMD,ALT" middleClick:NO];
    NSSet *resizeFlags = [migrated getResizeFlagStringSet];
    NSSet *expected = [NSSet setWithArray:@[CMD_KEY, ALT_KEY]];
    XCTAssertEqualObjects(resizeFlags, expected, "Migration should copy move modifiers to resize modifiers");
}

- (void)testMigrationMiddleClickToResizeMouseButton {
    EMRPreferences *migrated = [self createV1PreferencesWithModifiers:@"CMD,CTRL" middleClick:YES];
    XCTAssertEqual([migrated resizeMouseButton], EMRMouseButtonMiddle,
                   "Migration should set resize mouse button to Middle when MiddleClickResize was ON");
}

- (void)testMigrationNoMiddleClickKeepsDefaultRight {
    EMRPreferences *migrated = [self createV1PreferencesWithModifiers:@"CMD,CTRL" middleClick:NO];
    XCTAssertEqual([migrated resizeMouseButton], EMRMouseButtonRight,
                   "Migration without MiddleClickResize should keep resize button as Right (default)");
}

- (void)testMigrationRunsOnlyOnce {
    // Create v1 prefs, triggering migration
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *suiteName = [@"org.dmarcotte.Easy-Move-Resize.migrateonce." stringByAppendingString:uuid];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    [defaults setObject:@"CMD,ALT" forKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    [defaults setBool:YES forKey:SHOULD_MIDDLE_CLICK_RESIZE];
    [defaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];

    // First init triggers migration
    EMRPreferences *prefs1 = [[EMRPreferences alloc] initWithUserDefaults:defaults];
    XCTAssertEqual([prefs1 resizeMouseButton], EMRMouseButtonMiddle);

    // Now change resize mouse button to Left
    [prefs1 setResizeMouseButton:EMRMouseButtonLeft];
    XCTAssertEqual([prefs1 resizeMouseButton], EMRMouseButtonLeft);

    // Re-init — migration should NOT run again (version is already 2)
    EMRPreferences *prefs2 = [[EMRPreferences alloc] initWithUserDefaults:defaults];
    XCTAssertEqual([prefs2 resizeMouseButton], EMRMouseButtonLeft,
                   "Second init should not re-run migration and overwrite user's choice");

    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:suiteName];
}

#pragma mark - setToDefaults comprehensive

- (void)testSetToDefaultsResetsAllFields {
    [preferences setToDefaults];

    // Modify everything
    [preferences setModifierKey:ALT_KEY enabled:YES];
    [preferences setResizeModifierKey:SHIFT_KEY enabled:YES];
    [preferences setMoveMouseButton:EMRMouseButtonMiddle];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    [preferences setShouldBringWindowToFront:YES];
    [preferences setResizeOnly:YES];

    // Reset
    [preferences setToDefaults];

    NSSet *moveFlags = [preferences getFlagStringSet];
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];
    NSSet *expectedModifiers = [NSSet setWithArray:@[CMD_KEY, CTRL_KEY]];

    XCTAssertEqualObjects(moveFlags, expectedModifiers, "Move modifiers should reset to CMD+CTRL");
    XCTAssertEqualObjects(resizeFlags, expectedModifiers, "Resize modifiers should reset to CMD+CTRL");
    XCTAssertEqual([preferences moveMouseButton], EMRMouseButtonLeft, "Move button should reset to Left");
    XCTAssertEqual([preferences resizeMouseButton], EMRMouseButtonRight, "Resize button should reset to Right");
    XCTAssertFalse([preferences shouldBringWindowToFront], "Bring to front should reset to NO");
    XCTAssertFalse([preferences resizeOnly], "Resize only should reset to NO");
    XCTAssertFalse([preferences hasConflictingConfig], "Defaults should not conflict");
}

#pragma mark - Edge cases

- (void)testAllModifiersUncheckedReturnsZeroFlags {
    [preferences setToDefaults];
    [preferences setResizeModifierKey:CMD_KEY enabled:NO];
    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    XCTAssertEqual([preferences resizeModifierFlags], 0, "All modifiers unchecked should return 0");
}

- (void)testAllMoveModifiersUncheckedReturnsZeroFlags {
    [preferences setToDefaults];
    [preferences setModifierKey:CMD_KEY enabled:NO];
    [preferences setModifierKey:CTRL_KEY enabled:NO];
    XCTAssertEqual([preferences modifierFlags], 0, "All move modifiers unchecked should return 0");
}

- (void)testConflictWithAllModifiersUnchecked {
    [preferences setToDefaults];
    // Both operations: left-click, no modifiers
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    [preferences setModifierKey:CMD_KEY enabled:NO];
    [preferences setModifierKey:CTRL_KEY enabled:NO];
    [preferences setResizeModifierKey:CMD_KEY enabled:NO];
    [preferences setResizeModifierKey:CTRL_KEY enabled:NO];
    XCTAssertTrue([preferences hasConflictingConfig], "Same button + same (empty) modifiers should conflict");
}

@end
