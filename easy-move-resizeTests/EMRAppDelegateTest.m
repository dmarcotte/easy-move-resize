#import <XCTest/XCTest.h>
#import "EMRAppDelegate.h"
#import "EMRPreferences.h"
#import "EMRMoveResize.h"

// The callback is a C function with external linkage in EMRAppDelegate.m
extern CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

// Expose refreshCachedPreferences and private ivars for testing via category
@interface EMRAppDelegate (Testing)
- (void)refreshCachedPreferences;
- (BOOL)resizeOnly;
@end

@interface EMRAppDelegateTest : XCTestCase

@end

@implementation EMRAppDelegateTest {
    EMRAppDelegate *delegate;
}

- (void)setUp {
    [super setUp];
    delegate = [[EMRAppDelegate alloc] init];
    // Reset EMRMoveResize singleton state
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:0];
    [mr setIsResizing:NO];
    [mr setWindow:nil];
}

#pragma mark - Helper: set cached ivars directly via KVC

- (void)setCachedMoveModifiers:(int)flags {
    [delegate setValue:@(flags) forKey:@"keyModifierFlags"];
}
- (void)setCachedResizeModifiers:(int)flags {
    [delegate setValue:@(flags) forKey:@"resizeKeyModifierFlags"];
}
- (void)setCachedMoveButton:(int)btn {
    [delegate setValue:@(btn) forKey:@"cachedMoveMouseButton"];
}
- (void)setCachedResizeButton:(int)btn {
    [delegate setValue:@(btn) forKey:@"cachedResizeMouseButton"];
}
- (void)setCachedHasConflict:(BOOL)conflict {
    [delegate setValue:@(conflict) forKey:@"cachedHasConflict"];
}

#pragma mark - Helper: create a CGEvent with specific type and modifier flags

- (CGEventRef)createMouseEvent:(CGEventType)type flags:(CGEventFlags)flags {
    // Create a mouse event at position (100, 100)
    CGPoint location = CGPointMake(100, 100);

    // Map CGEventType to CGMouseButton
    CGMouseButton button = kCGMouseButtonLeft;
    if (type == kCGEventRightMouseDown || type == kCGEventRightMouseDragged || type == kCGEventRightMouseUp) {
        button = kCGMouseButtonRight;
    } else if (type == kCGEventOtherMouseDown || type == kCGEventOtherMouseDragged || type == kCGEventOtherMouseUp) {
        button = kCGMouseButtonCenter;
    }

    CGEventRef event = CGEventCreateMouseEvent(NULL, type, location, button);
    if (event && flags != 0) {
        CGEventSetFlags(event, flags);
    }
    return event;
}

#pragma mark - refreshCachedPreferences

- (void)testRefreshCachedPreferencesUpdatesAccessors {
    // The delegate uses the "userPrefs" suite which may have leftover state.
    // Reset to known defaults first, then verify cache sync.
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ModifierFlags"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:EMRMouseButtonLeft forKey:@"MoveMouseButton"];
    [prefs setInteger:EMRMouseButtonRight forKey:@"ResizeMouseButton"];

    [delegate refreshCachedPreferences];

    int expectedFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    XCTAssertEqual([delegate modifierFlags], expectedFlags, "Cached move modifiers should match preferences");
    XCTAssertEqual([delegate resizeModifierFlags], expectedFlags, "Cached resize modifiers should match preferences");
    XCTAssertEqual([delegate moveMouseButton], EMRMouseButtonLeft, "Cached move button should match preferences");
    XCTAssertEqual([delegate resizeMouseButton], EMRMouseButtonRight, "Cached resize button should match preferences");

    // Now change preferences and refresh — verify update
    [prefs setObject:@"CMD,ALT" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:EMRMouseButtonMiddle forKey:@"ResizeMouseButton"];

    [delegate refreshCachedPreferences];

    int expectedResizeFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    XCTAssertEqual([delegate resizeModifierFlags], expectedResizeFlags, "Cached resize modifiers should update after preference change");
    XCTAssertEqual([delegate resizeMouseButton], EMRMouseButtonMiddle, "Cached resize button should update after preference change");

    // Restore defaults to not pollute other tests
    [prefs setObject:@"CTRL,CMD" forKey:@"ModifierFlags"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:EMRMouseButtonLeft forKey:@"MoveMouseButton"];
    [prefs setInteger:EMRMouseButtonRight forKey:@"ResizeMouseButton"];
}

#pragma mark - Accessor methods return cached ivars

- (void)testModifierFlagsReturnsCachedValue {
    [self setCachedMoveModifiers:42];
    XCTAssertEqual([delegate modifierFlags], 42);
}

- (void)testResizeModifierFlagsReturnsCachedValue {
    [self setCachedResizeModifiers:99];
    XCTAssertEqual([delegate resizeModifierFlags], 99);
}

- (void)testMoveMouseButtonReturnsCachedValue {
    [self setCachedMoveButton:EMRMouseButtonMiddle];
    XCTAssertEqual([delegate moveMouseButton], EMRMouseButtonMiddle);
}

- (void)testResizeMouseButtonReturnsCachedValue {
    [self setCachedResizeButton:EMRMouseButtonLeft];
    XCTAssertEqual([delegate resizeMouseButton], EMRMouseButtonLeft);
}

#pragma mark - Callback: session inactive passes through

- (void)testCallbackPassesThroughWhenSessionInactive {
    [delegate setSessionActive:NO];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown
                                        flags:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when session is inactive");
    CFRelease(event);
}

#pragma mark - Callback: both modifiers zero → early return

- (void)testCallbackPassesThroughWhenBothModifiersZero {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:0];
    [self setCachedResizeModifiers:0];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when both modifier sets are zero");
    CFRelease(event);
}

#pragma mark - Callback: wrong modifiers → pass through

- (void)testCallbackPassesThroughWithWrongModifiers {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Send left-click with only Shift — matches neither move nor resize
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:kCGEventFlagMaskShift];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through with non-matching modifiers");
    CFRelease(event);
}

#pragma mark - Callback: wrong button → pass through

- (void)testCallbackPassesThroughWithWrongButton {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Send middle-click with correct modifiers — neither move (Left) nor resize (Right)
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventOtherMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventOtherMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when button doesn't match move or resize");
    CFRelease(event);
}

#pragma mark - Callback: extra modifiers → pass through

- (void)testCallbackPassesThroughWithExtraModifiers {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonLeft];

    // Send left-click with Cmd+Ctrl+Alt — has extras for both sets
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when extra modifiers are held for both sets");
    CFRelease(event);
}

#pragma mark - Callback: resizeOnly suppresses move

- (void)testCallbackPassesThroughMoveWhenResizeOnly {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Set resizeOnly via preferences (the callback reads it via [ourDelegate resizeOnly])
    // The delegate's init creates its own preferences, so we need to use KVC or the accessor
    // Actually, resizeOnly is read from preferences, not cached. Let me check...
    // The callback calls: bool resizeOnly = [ourDelegate resizeOnly];
    // which calls: [preferences resizeOnly] which reads from NSUserDefaults "userPrefs"

    // We can use the delegate's own preferences by writing to the "userPrefs" suite
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
    [prefs setBool:YES forKey:@"ResizeOnly"];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Move event should pass through when resizeOnly is ON");

    // Clean up
    [prefs setBool:NO forKey:@"ResizeOnly"];
    CFRelease(event);
}

#pragma mark - Callback: mouse-up clears tracking and isResizing

- (void)testMouseUpClearsTrackingAndIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Simulate an active tracking session (as if mouse-down already happened)
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];

    XCTAssertTrue([mr tracking] > 0, "Precondition: tracking should be active");
    XCTAssertTrue([mr isResizing], "Precondition: isResizing should be YES");

    // Send mouse-up (left button) — the button/modifiers don't need to match for up events
    // as long as tracking > 0
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);

    XCTAssertTrue(result == NULL, "Mouse-up during tracking should be handled (return NULL)");
    XCTAssertEqual([mr tracking], 0, "tracking should be cleared after mouse-up");
    XCTAssertFalse([mr isResizing], "isResizing should be NO after mouse-up");
    CFRelease(event);
}

- (void)testRightMouseUpClearsTrackingAndIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];

    CGEventRef event = [self createMouseEvent:kCGEventRightMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventRightMouseUp, event, (__bridge void *)delegate);

    XCTAssertTrue(result == NULL, "Right mouse-up during tracking should be handled");
    XCTAssertEqual([mr tracking], 0);
    XCTAssertFalse([mr isResizing]);
    CFRelease(event);
}

#pragma mark - Callback: mouse-up with no active tracking → pass through

- (void)testMouseUpWithNoTrackingPassesThrough {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:0]; // No active tracking

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Mouse-up with no active tracking should pass through");
    CFRelease(event);
}

#pragma mark - Callback: unrecognized event type → pass through

- (void)testCallbackPassesThroughUnrecognizedEventType {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Create a scroll wheel event (not handled by the callback)
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1, 1);
    CGEventRef result = myCGEventCallback(NULL, kCGEventScrollWheel, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Scroll wheel events should pass through");
    CFRelease(event);
}

// Note: kCGEventTapDisabledByTimeout handling cannot be tested without a real event tap,
// as the callback calls CGEventTapEnable([EMRMoveResize instance].eventTap, true)
// which crashes on a NULL event tap reference.

#pragma mark - Callback: conflict resolution (both match → resize wins)

- (void)testConflictResolutionResizeWins {
    [delegate setSessionActive:YES];
    // Configure: same button (Left) + same modifiers for both operations
    int flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    [self setCachedMoveModifiers:flags];
    [self setCachedResizeModifiers:flags];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonLeft];
    [self setCachedHasConflict:YES];

    // Send mouse-down with matching modifiers.
    // Both move and resize match → conflict resolution should pick resize.
    // The callback enters the resize path (isForResize=YES), which tries to get window size
    // via AX. In test environment with no real window, the AX size query fails and the callback
    // clears tracking+isResizing and returns NULL.
    //
    // Key verification: if move had been chosen instead, the callback would NOT enter the
    // resize size-query path, so tracking would remain active and isResizing would be NO.
    // By checking that tracking is 0 (resize path's AX failure cleanup ran), we confirm
    // the callback chose the resize path, proving conflict resolution chose resize.
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    EMRMoveResize *mr = [EMRMoveResize instance];
    // The resize path was entered (AX size query ran and failed, clearing tracking)
    // If move had been chosen, tracking would still be > 0 (move path doesn't query size)
    XCTAssertTrue(result == NULL, "Conflicting event should be consumed (not passed through)");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure should have cleared tracking, confirming resize was chosen over move");

    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: independent modifier matching

- (void)testMoveModifiersMatchResizeModifiersDont {
    [delegate setSessionActive:YES];
    // Move: Cmd+Ctrl on Left, Resize: Cmd+Alt on Left
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonLeft];

    // Send left-click with Cmd+Ctrl — should match move only
    CGEventFlags moveFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:moveFlags];
    myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    EMRMoveResize *mr = [EMRMoveResize instance];
    // Move matched, resize didn't → isResizing should be NO
    XCTAssertFalse([mr isResizing], "Move modifiers should match but resize should not — isResizing should be NO");

    [mr setTracking:0];
    [mr setIsResizing:NO];
    CFRelease(event);
}

- (void)testResizeModifiersMatchMoveModifiersDont {
    [delegate setSessionActive:YES];
    // Move: Cmd+Ctrl on Left, Resize: Cmd+Alt on Left
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonLeft];

    // Send left-click with Cmd+Alt — should match resize only.
    // In test env: resize path enters AX size query which fails on NULL window,
    // clearing tracking to 0 and returning NULL. This confirms the resize path was chosen.
    // (If move had been chosen, tracking would remain > 0 since move doesn't query size.)
    CGEventFlags resizeFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:resizeFlags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    EMRMoveResize *mr = [EMRMoveResize instance];
    XCTAssertTrue(result == NULL, "Resize-matching event should be consumed (not passed through)");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure clears tracking, confirming resize was chosen");

    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: drag during active tracking respects isResizing

- (void)testDragDuringMoveTrackingDoesNotSetIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Simulate active move tracking
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:NO];
    [mr setWndPosition:NSMakePoint(100, 100)];

    // Send drag event — during active tracking, the drag handler should fire
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDragged flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDragged, event, (__bridge void *)delegate);

    // Drag during move tracking: isResizing should still be NO
    XCTAssertFalse([mr isResizing], "isResizing should remain NO during move drag");
    // The drag was handled (but AX calls to move window may fail in test — that's OK)
    // If window is nil, the AX call is a no-op but doesn't crash
    XCTAssertTrue(result == NULL, "Drag during active tracking should be handled (return NULL)");

    [mr setTracking:0];
    CFRelease(event);
}

- (void)testDragDuringResizeTrackingKeepsIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonRight];

    // Simulate active resize tracking
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];
    [mr setWndPosition:NSMakePoint(100, 100)];
    [mr setWndSize:NSMakeSize(400, 300)];
    struct ResizeSection section = { .xResizeDirection = right, .yResizeDirection = bottom };
    [mr setResizeSection:section];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventRightMouseDragged flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventRightMouseDragged, event, (__bridge void *)delegate);

    XCTAssertTrue([mr isResizing], "isResizing should remain YES during resize drag");
    XCTAssertTrue(result == NULL, "Drag during active tracking should be handled");

    [mr setTracking:0];
    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: different button configurations

- (void)testMiddleClickResizeConfiguration {
    [delegate setSessionActive:YES];
    int flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    [self setCachedMoveModifiers:flags];
    [self setCachedResizeModifiers:flags];
    [self setCachedMoveButton:EMRMouseButtonLeft];
    [self setCachedResizeButton:EMRMouseButtonMiddle]; // Middle-click resize

    // Left-click should match move, not resize
    CGEventRef leftEvent = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    myCGEventCallback(NULL, kCGEventLeftMouseDown, leftEvent, (__bridge void *)delegate);

    EMRMoveResize *mr = [EMRMoveResize instance];
    XCTAssertFalse([mr isResizing], "Left-click should match move (not resize) when resize is middle-click");

    [mr setTracking:0];
    [mr setIsResizing:NO];

    // Middle-click should match resize.
    // The resize path enters AX size query which fails in test env, clearing tracking.
    // We confirm the resize path was chosen by checking return value is NULL and tracking == 0.
    CGEventRef middleEvent = [self createMouseEvent:kCGEventOtherMouseDown flags:flags];
    CGEventRef middleResult = myCGEventCallback(NULL, kCGEventOtherMouseDown, middleEvent, (__bridge void *)delegate);

    XCTAssertTrue(middleResult == NULL, "Middle-click resize event should be consumed");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure clears tracking, confirming middle-click matched resize");

    [mr setIsResizing:NO];
    CFRelease(leftEvent);
    CFRelease(middleEvent);
}

@end
