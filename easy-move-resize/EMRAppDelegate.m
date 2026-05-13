#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"
#import "EMRPreferences.h"

#define ALL_MODIFIERS (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | \
    kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | \
    kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn)

/* Return the minimum refresh interval (1/refresh rate) across all screens. If the user
 * is on a version of MacOS < 12.0 then 60hz refresh rate is assumed. */
float getMinRefreshInterval(void) {
    float minInterval = 1.0 / 60;
    for (unsigned i=0; i<NSScreen.screens.count; ++i) {
        if (@available(macOS 12.0, *)) {
            minInterval = MIN(minInterval, NSScreen.screens[i].minimumRefreshInterval);
        }
    }
    return minInterval;
}

@implementation EMRAppDelegate {
    EMRPreferences *preferences;
}

- (id) init  {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
        preferences = [[EMRPreferences alloc] initWithUserDefaults:userDefaults];

        // Window move and resize based on minimum refresh interval across all screens
        const float refreshRate = getMinRefreshInterval();
        self.moveFilterInterval = refreshRate;
        self.resizeFilterInterval = refreshRate;
    }
    return self;
}

- (void)refreshCachedPreferences {
    keyModifierFlags = [preferences modifierFlags];
    resizeKeyModifierFlags = [preferences resizeModifierFlags];
    cachedMoveMouseButton = [preferences moveMouseButton];
    cachedResizeMouseButton = [preferences resizeMouseButton];
    cachedHasConflict = [preferences hasConflictingConfig];
}

#pragma mark - Event callback

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {

    EMRAppDelegate *ourDelegate = (__bridge EMRAppDelegate*)refcon;

    // Re-enable tap if it was disabled (usually happens on a slow resizing app)
    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        EMRMoveResize* mr = [EMRMoveResize instance];
        CGEventTapEnable([mr eventTap], true);
        return event;
    }

    if (![ourDelegate sessionActive]) {
        return event;
    }

    // Read cached preference values (ivars, not NSUserDefaults)
    int moveModifiers = ourDelegate->keyModifierFlags;
    int resizeModifiers = ourDelegate->resizeKeyModifierFlags;
    int moveBtn = ourDelegate->cachedMoveMouseButton;
    int resizeBtn = ourDelegate->cachedResizeMouseButton;
    bool resizeOnly = [ourDelegate resizeOnly];

    // Both modifier sets are zero — nothing to do
    if (moveModifiers == 0 && resizeModifiers == 0) {
        return event;
    }

    CGEventFlags flags = CGEventGetFlags(event);
    EMRMoveResize *moveResize = [EMRMoveResize instance];

    // Check if flags match each modifier set with no extra modifiers
    BOOL moveModifiersMatch = NO;
    BOOL resizeModifiersMatch = NO;

    if (moveModifiers != 0 && (flags & moveModifiers) == (CGEventFlags)moveModifiers) {
        int moveIgnored = ALL_MODIFIERS ^ moveModifiers;
        moveModifiersMatch = !(flags & moveIgnored);
    }
    if (resizeModifiers != 0 && (flags & resizeModifiers) == (CGEventFlags)resizeModifiers) {
        int resizeIgnored = ALL_MODIFIERS ^ resizeModifiers;
        resizeModifiersMatch = !(flags & resizeIgnored);
    }

    // Map CGEvent type to button number and event phase
    int eventButton = -1;
    BOOL isDown = NO, isDrag = NO, isUp = NO;
    switch (type) {
        case kCGEventLeftMouseDown:     eventButton = 0; isDown = YES; break;
        case kCGEventRightMouseDown:    eventButton = 1; isDown = YES; break;
        case kCGEventOtherMouseDown:    eventButton = 2; isDown = YES; break;
        case kCGEventLeftMouseDragged:  eventButton = 0; isDrag = YES; break;
        case kCGEventRightMouseDragged: eventButton = 1; isDrag = YES; break;
        case kCGEventOtherMouseDragged: eventButton = 2; isDrag = YES; break;
        case kCGEventLeftMouseUp:       eventButton = 0; isUp = YES; break;
        case kCGEventRightMouseUp:      eventButton = 1; isUp = YES; break;
        case kCGEventOtherMouseUp:      eventButton = 2; isUp = YES; break;
        default: return event;
    }

    // Determine if this event matches move, resize, or neither
    BOOL isForMove = (eventButton == moveBtn && moveModifiersMatch && !resizeOnly);
    BOOL isForResize = (eventButton == resizeBtn && resizeModifiersMatch);

    // Conflict resolution: if both match, prefer resize
    if (isForMove && isForResize) {
        isForMove = NO;
    }

    // If neither matches and we're not in an active drag, this event isn't for us
    if (!isForMove && !isForResize && !([moveResize tracking] > 0)) {
        return event;
    }

    BOOL handled = NO;

    // --- MOUSE DOWN: capture window, set isResizing, compute resize direction ---
    if (isDown && (isForMove || isForResize)) {
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:CACurrentMediaTime()];
        [moveResize setIsResizing:isForResize];

        AXUIElementRef _systemWideElement;
        AXUIElementRef _clickedWindow = NULL;
        _systemWideElement = AXUIElementCreateSystemWide();

        AXUIElementRef _element;
        if ((AXUIElementCopyElementAtPosition(_systemWideElement, (float) mouseLocation.x, (float) mouseLocation.y, &_element) == kAXErrorSuccess) && _element) {
            CFTypeRef _role;
            if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &_role) == kAXErrorSuccess) {
                if ([(__bridge NSString *)_role isEqualToString:NSAccessibilityWindowRole]) {
                    _clickedWindow = _element;
                }
                if (_role != NULL) CFRelease(_role);
            }
            CFTypeRef _window;
            if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityWindowAttribute, &_window) == kAXErrorSuccess) {
                if (_element != NULL) CFRelease(_element);
                _clickedWindow = (AXUIElementRef)_window;
            }
        }
        CFRelease(_systemWideElement);

        pid_t PID;
        NSRunningApplication* app;
        if(!AXUIElementGetPid(_clickedWindow, &PID)) {
            app = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
            if ([[ourDelegate getDisabledApps] objectForKey:[app bundleIdentifier]] != nil) {
                [moveResize setTracking:0];
                [moveResize setIsResizing:NO];
                return event;
            }
            [ourDelegate setMostRecentApp:app];
        }

        if([ourDelegate shouldBringWindowToFront]){
            if (app != nil) {
                [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            }
            AXUIElementPerformAction(_clickedWindow, kAXRaiseAction);
        }

        CFTypeRef _cPosition = nil;
        NSPoint cTopLeft;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, &_cPosition) == kAXErrorSuccess) {
            if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
                NSLog(@"ERROR: Could not decode position");
                cTopLeft = NSMakePoint(0, 0);
            }
            CFRelease(_cPosition);
        }

        cTopLeft.x = (int) cTopLeft.x;
        cTopLeft.y = (int) cTopLeft.y;

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWindow:_clickedWindow];
        if (_clickedWindow != nil) CFRelease(_clickedWindow);

        // If this is a resize, compute resize direction from click position in window thirds
        if (isForResize) {
            AXUIElementRef _resizeWindow = [moveResize window];
            struct ResizeSection resizeSection;

            CGPoint clickPoint = mouseLocation;
            clickPoint.x -= cTopLeft.x;
            clickPoint.y -= cTopLeft.y;

            CFTypeRef _cSize;
            NSSize cSize;
            if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_resizeWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
                    || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
                NSLog(@"ERROR: Could not decode size");
                [moveResize setTracking:0];
                [moveResize setIsResizing:NO];
                return NULL;
            }
            CFRelease(_cSize);

            NSSize wndSize = cSize;

            if (clickPoint.x < wndSize.width/3) {
                resizeSection.xResizeDirection = left;
            } else if (clickPoint.x > 2*wndSize.width/3) {
                resizeSection.xResizeDirection = right;
            } else {
                resizeSection.xResizeDirection = noX;
            }

            if (clickPoint.y < wndSize.height/3) {
                resizeSection.yResizeDirection = bottom;
            } else if (clickPoint.y > 2*wndSize.height/3) {
                resizeSection.yResizeDirection = top;
            } else {
                resizeSection.yResizeDirection = noY;
            }

            [moveResize setWndSize:wndSize];
            [moveResize setResizeSection:resizeSection];
        }

        handled = YES;
    }

    // --- MOUSE DRAG: move or resize based on isResizing ---
    if (isDrag && [moveResize tracking] > 0) {
        if ([moveResize isResizing]) {
            // Resize drag
            AXUIElementRef _clickedWindow = [moveResize window];
            struct ResizeSection resizeSection = [moveResize resizeSection];
            int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSSize wndSize = [moveResize wndSize];

            switch (resizeSection.xResizeDirection) {
                case right:
                    wndSize.width += deltaX;
                    break;
                case left:
                    wndSize.width -= deltaX;
                    cTopLeft.x += deltaX;
                    break;
                case noX:
                    break;
                default:
                    [NSException raise:@"Unknown xResizeSection" format:@"No case for %d", resizeSection.xResizeDirection];
            }

            switch (resizeSection.yResizeDirection) {
                case top:
                    wndSize.height += deltaY;
                    break;
                case bottom:
                    wndSize.height -= deltaY;
                    cTopLeft.y += deltaY;
                    break;
                case noY:
                    break;
                default:
                    [NSException raise:@"Unknown yResizeSection" format:@"No case for %d", resizeSection.yResizeDirection];
            }

            [moveResize setWndPosition:cTopLeft];
            [moveResize setWndSize:wndSize];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.resizeFilterInterval) {
                if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                    CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                    AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                    CFRelease(_position);
                }

                CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
                AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
                CFRelease(_size);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        } else {
            // Move drag
            AXUIElementRef _clickedWindow = [moveResize window];
            double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSPoint thePoint;
            thePoint.x = cTopLeft.x + deltaX;
            thePoint.y = cTopLeft.y + deltaY;
            [moveResize setWndPosition:thePoint];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.moveFilterInterval) {
                CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
                AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                if (_position != NULL) CFRelease(_position);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        }
        handled = YES;
    }

    // --- MOUSE UP: clear tracking ---
    if (isUp && [moveResize tracking] > 0) {
        [moveResize setTracking:0];
        [moveResize setIsResizing:NO];
        handled = YES;
    }

    return handled ? NULL : event;
}

#pragma mark - Application lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Skip the entire accessibility check when running under XCTest.
    // AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt triggers
    // a system modal dialog, which blocks the test runner.
    if (NSClassFromString(@"XCTestCase") != nil) {
        return;
    }

    const void * keys[] = { kAXTrustedCheckOptionPrompt };
    const void * values[] = { kCFBooleanTrue };

    CFDictionaryRef options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    if (!AXIsProcessTrustedWithOptions(options)) {
        NSLog(@"Missing permissions");
        exit(1);
    }

    [self buildMenu];
    [self refreshCachedPreferences];

    CFRunLoopSourceRef runLoopSource;

    CGEventMask eventMask = CGEventMaskBit( kCGEventLeftMouseDown )
                    | CGEventMaskBit( kCGEventRightMouseDown )
                    | CGEventMaskBit( kCGEventOtherMouseDown )
                    | CGEventMaskBit( kCGEventLeftMouseDragged )
                    | CGEventMaskBit( kCGEventRightMouseDragged )
                    | CGEventMaskBit( kCGEventOtherMouseDragged )
                    | CGEventMaskBit( kCGEventLeftMouseUp )
                    | CGEventMaskBit( kCGEventRightMouseUp )
                    | CGEventMaskBit( kCGEventOtherMouseUp )
    ;

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);

    EMRMoveResize *moveResize = [EMRMoveResize instance];
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];
    CFRelease(runLoopSource);

    _sessionActive = true;
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameActive:)
            name:NSWorkspaceSessionDidBecomeActiveNotification
            object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameInactive:)
            name:NSWorkspaceSessionDidResignActiveNotification
            object:nil];

    [self reconstructDisabledAppsSubmenu];
}

- (void)becameActive:(NSNotification*) notification {
    _sessionActive = true;
}

- (void)becameInactive:(NSNotification*) notification {
    _sessionActive = false;
}

-(void)awakeFromNib{
    NSImage *icon = [NSImage imageNamed:@"MenuIcon"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:icon];
    [statusMenu setAutoenablesItems:NO];
    [[statusMenu itemAtIndex:0] setEnabled:NO];
}

- (void)enableRunLoopSource:(EMRMoveResize*)moveResize {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
    CGEventTapEnable([moveResize eventTap], true);
}

- (void)disableRunLoopSource:(EMRMoveResize*)moveResize {
    CGEventTapEnable([moveResize eventTap], false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
}

#pragma mark - Menu construction (programmatic)

- (NSMenuItem *)createModifierItem:(NSString *)title action:(SEL)action state:(BOOL)on {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    [item setTarget:self];
    [item setState:on ? NSControlStateValueOn : NSControlStateValueOff];
    return item;
}

- (NSMenuItem *)createMouseButtonSubmenu:(NSString *)label
                            leftItem:(NSMenuItem **)outLeft
                           rightItem:(NSMenuItem **)outRight
                          middleItem:(NSMenuItem **)outMiddle
                              action:(SEL)action
                       selectedButton:(int)selected {
    NSMenu *sub = [[NSMenu alloc] init];
    NSMenuItem *leftItem = [[NSMenuItem alloc] initWithTitle:@"Left" action:action keyEquivalent:@""];
    [leftItem setTarget:self];
    [leftItem setTag:EMRMouseButtonLeft];
    [leftItem setState:(selected == EMRMouseButtonLeft) ? NSControlStateValueOn : NSControlStateValueOff];
    [sub addItem:leftItem];

    NSMenuItem *rightItem = [[NSMenuItem alloc] initWithTitle:@"Right" action:action keyEquivalent:@""];
    [rightItem setTarget:self];
    [rightItem setTag:EMRMouseButtonRight];
    [rightItem setState:(selected == EMRMouseButtonRight) ? NSControlStateValueOn : NSControlStateValueOff];
    [sub addItem:rightItem];

    NSMenuItem *middleItem = [[NSMenuItem alloc] initWithTitle:@"Middle" action:action keyEquivalent:@""];
    [middleItem setTarget:self];
    [middleItem setTag:EMRMouseButtonMiddle];
    [middleItem setState:(selected == EMRMouseButtonMiddle) ? NSControlStateValueOn : NSControlStateValueOff];
    [sub addItem:middleItem];

    *outLeft = leftItem;
    *outRight = rightItem;
    *outMiddle = middleItem;

    NSMenuItem *container = [[NSMenuItem alloc] initWithTitle:label action:nil keyEquivalent:@""];
    [container setSubmenu:sub];
    return container;
}

- (void)buildMenu {
    // XIB provides: [0] "Easy Move+Resize" (title), [1] "Disabled", [2] separator,
    //               [3] "Bring Window to Front", [4] "Resize only", ...
    // We insert programmatic Move/Resize sections at index 3 (before "Bring Window to Front").
    NSInteger insertIdx = 3;

    // --- Move section ---
    NSSet *moveFlags = [preferences getFlagStringSet];
    BOOL moveResizeOnly = [preferences resizeOnly];

    NSMenuItem *moveHeader = [[NSMenuItem alloc] initWithTitle:@"Move:" action:nil keyEquivalent:@""];
    [moveHeader setEnabled:NO];
    [statusMenu insertItem:moveHeader atIndex:insertIdx++];

    moveAltMenu = [self createModifierItem:ALT_KEY action:@selector(modifierToggle:) state:[moveFlags containsObject:ALT_KEY]];
    [moveAltMenu setIndentationLevel:1];
    [statusMenu insertItem:moveAltMenu atIndex:insertIdx++];

    moveCmdMenu = [self createModifierItem:CMD_KEY action:@selector(modifierToggle:) state:[moveFlags containsObject:CMD_KEY]];
    [moveCmdMenu setIndentationLevel:1];
    [statusMenu insertItem:moveCmdMenu atIndex:insertIdx++];

    moveCtrlMenu = [self createModifierItem:CTRL_KEY action:@selector(modifierToggle:) state:[moveFlags containsObject:CTRL_KEY]];
    [moveCtrlMenu setIndentationLevel:1];
    [statusMenu insertItem:moveCtrlMenu atIndex:insertIdx++];

    moveShiftMenu = [self createModifierItem:SHIFT_KEY action:@selector(modifierToggle:) state:[moveFlags containsObject:SHIFT_KEY]];
    [moveShiftMenu setIndentationLevel:1];
    [statusMenu insertItem:moveShiftMenu atIndex:insertIdx++];

    moveFnMenu = [self createModifierItem:FN_KEY action:@selector(modifierToggle:) state:[moveFlags containsObject:FN_KEY]];
    [moveFnMenu setIndentationLevel:1];
    [statusMenu insertItem:moveFnMenu atIndex:insertIdx++];

    int moveBtn = [preferences moveMouseButton];
    NSMenuItem *tmpLeft, *tmpRight, *tmpMiddle;
    NSMenuItem *moveBtnContainer = [self createMouseButtonSubmenu:@"Mouse Button"
                                                        leftItem:&tmpLeft
                                                       rightItem:&tmpRight
                                                      middleItem:&tmpMiddle
                                                          action:@selector(setMoveMouseButton:)
                                                   selectedButton:moveBtn];
    moveMouseButtonLeftMenu = tmpLeft;
    moveMouseButtonRightMenu = tmpRight;
    moveMouseButtonMiddleMenu = tmpMiddle;
    [moveBtnContainer setIndentationLevel:1];
    [statusMenu insertItem:moveBtnContainer atIndex:insertIdx++];

    // Separator between Move and Resize
    [statusMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIdx++];

    // --- Resize section ---
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];

    NSMenuItem *resizeHeader = [[NSMenuItem alloc] initWithTitle:@"Resize:" action:nil keyEquivalent:@""];
    [resizeHeader setEnabled:NO];
    [statusMenu insertItem:resizeHeader atIndex:insertIdx++];

    resizeAltMenu = [self createModifierItem:ALT_KEY action:@selector(resizeModifierToggle:) state:[resizeFlags containsObject:ALT_KEY]];
    [resizeAltMenu setIndentationLevel:1];
    [statusMenu insertItem:resizeAltMenu atIndex:insertIdx++];

    resizeCmdMenu = [self createModifierItem:CMD_KEY action:@selector(resizeModifierToggle:) state:[resizeFlags containsObject:CMD_KEY]];
    [resizeCmdMenu setIndentationLevel:1];
    [statusMenu insertItem:resizeCmdMenu atIndex:insertIdx++];

    resizeCtrlMenu = [self createModifierItem:CTRL_KEY action:@selector(resizeModifierToggle:) state:[resizeFlags containsObject:CTRL_KEY]];
    [resizeCtrlMenu setIndentationLevel:1];
    [statusMenu insertItem:resizeCtrlMenu atIndex:insertIdx++];

    resizeShiftMenu = [self createModifierItem:SHIFT_KEY action:@selector(resizeModifierToggle:) state:[resizeFlags containsObject:SHIFT_KEY]];
    [resizeShiftMenu setIndentationLevel:1];
    [statusMenu insertItem:resizeShiftMenu atIndex:insertIdx++];

    resizeFnMenu = [self createModifierItem:FN_KEY action:@selector(resizeModifierToggle:) state:[resizeFlags containsObject:FN_KEY]];
    [resizeFnMenu setIndentationLevel:1];
    [statusMenu insertItem:resizeFnMenu atIndex:insertIdx++];

    int resizeBtn = [preferences resizeMouseButton];
    NSMenuItem *tmpLeft2, *tmpRight2, *tmpMiddle2;
    NSMenuItem *resizeBtnContainer = [self createMouseButtonSubmenu:@"Mouse Button"
                                                           leftItem:&tmpLeft2
                                                          rightItem:&tmpRight2
                                                         middleItem:&tmpMiddle2
                                                             action:@selector(setResizeMouseButton:)
                                                      selectedButton:resizeBtn];
    resizeMouseButtonLeftMenu = tmpLeft2;
    resizeMouseButtonRightMenu = tmpRight2;
    resizeMouseButtonMiddleMenu = tmpMiddle2;
    [resizeBtnContainer setIndentationLevel:1];
    [statusMenu insertItem:resizeBtnContainer atIndex:insertIdx++];

    // Conflict warning (hidden by default, shown when config conflicts)
    conflictWarningMenu = [[NSMenuItem alloc] initWithTitle:@"\u26A0\uFE0F Move and Resize have identical settings" action:nil keyEquivalent:@""];
    [conflictWarningMenu setEnabled:NO];
    [conflictWarningMenu setHidden:YES];
    [statusMenu insertItem:conflictWarningMenu atIndex:insertIdx++];

    // Separator before "Bring Window to Front"
    [statusMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIdx++];

    // --- Non-programmatic items (from XIB) follow: Bring Window to Front, Resize only, etc. ---
    // Set their initial states
    [_disabledMenu setState:NSControlStateValueOff];
    [_bringWindowFrontMenu setState:[preferences shouldBringWindowToFront] ? NSControlStateValueOn : NSControlStateValueOff];
    [_resizeOnlyMenu setState:moveResizeOnly ? NSControlStateValueOn : NSControlStateValueOff];

    // Grey out Move section when resizeOnly is on
    [self updateMoveMenuEnabled:!moveResizeOnly];

    // Update conflict warning visibility
    [self updateConflictWarning];
}

- (void)updateMoveMenuEnabled:(BOOL)enabled {
    [moveAltMenu setEnabled:enabled];
    [moveCmdMenu setEnabled:enabled];
    [moveCtrlMenu setEnabled:enabled];
    [moveShiftMenu setEnabled:enabled];
    [moveFnMenu setEnabled:enabled];
    // Mouse button submenu parent
    NSMenuItem *moveBtnParent = [moveMouseButtonLeftMenu parentItem];
    if (moveBtnParent == nil) {
        // Find parent by traversing — the submenu container is the item whose submenu contains our items
        for (NSInteger i = 0; i < [statusMenu numberOfItems]; i++) {
            NSMenuItem *item = [statusMenu itemAtIndex:i];
            if ([[item submenu] indexOfItem:moveMouseButtonLeftMenu] != -1) {
                moveBtnParent = item;
                break;
            }
        }
    }
    [moveBtnParent setEnabled:enabled];
}

- (void)updateConflictWarning {
    BOOL conflict = [preferences hasConflictingConfig];
    [conflictWarningMenu setHidden:!conflict];
}

- (void)updateMouseButtonRadioState:(int)selectedButton
                               left:(NSMenuItem *)leftItem
                              right:(NSMenuItem *)rightItem
                             middle:(NSMenuItem *)middleItem {
    [leftItem setState:(selectedButton == EMRMouseButtonLeft) ? NSControlStateValueOn : NSControlStateValueOff];
    [rightItem setState:(selectedButton == EMRMouseButtonRight) ? NSControlStateValueOn : NSControlStateValueOff];
    [middleItem setState:(selectedButton == EMRMouseButtonMiddle) ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)syncMenuStatesFromPreferences {
    // Move modifier checkmarks
    NSSet *moveFlags = [preferences getFlagStringSet];
    [moveAltMenu setState:[moveFlags containsObject:ALT_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [moveCmdMenu setState:[moveFlags containsObject:CMD_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [moveCtrlMenu setState:[moveFlags containsObject:CTRL_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [moveShiftMenu setState:[moveFlags containsObject:SHIFT_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [moveFnMenu setState:[moveFlags containsObject:FN_KEY] ? NSControlStateValueOn : NSControlStateValueOff];

    // Resize modifier checkmarks
    NSSet *resizeFlags = [preferences getResizeFlagStringSet];
    [resizeAltMenu setState:[resizeFlags containsObject:ALT_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [resizeCmdMenu setState:[resizeFlags containsObject:CMD_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [resizeCtrlMenu setState:[resizeFlags containsObject:CTRL_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [resizeShiftMenu setState:[resizeFlags containsObject:SHIFT_KEY] ? NSControlStateValueOn : NSControlStateValueOff];
    [resizeFnMenu setState:[resizeFlags containsObject:FN_KEY] ? NSControlStateValueOn : NSControlStateValueOff];

    // Mouse button radio states
    [self updateMouseButtonRadioState:[preferences moveMouseButton]
                                 left:moveMouseButtonLeftMenu right:moveMouseButtonRightMenu middle:moveMouseButtonMiddleMenu];
    [self updateMouseButtonRadioState:[preferences resizeMouseButton]
                                 left:resizeMouseButtonLeftMenu right:resizeMouseButtonRightMenu middle:resizeMouseButtonMiddleMenu];

    // Other toggles
    [_bringWindowFrontMenu setState:[preferences shouldBringWindowToFront] ? NSControlStateValueOn : NSControlStateValueOff];
    [_resizeOnlyMenu setState:[preferences resizeOnly] ? NSControlStateValueOn : NSControlStateValueOff];
    [_disabledMenu setState:NSControlStateValueOff];

    // Resize-only greys out Move section
    [self updateMoveMenuEnabled:![preferences resizeOnly]];

    // Conflict warning
    [self updateConflictWarning];
}

#pragma mark - IBActions

- (IBAction)modifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setModifierKey:[menu title] enabled:newState];
    [self refreshCachedPreferences];
    [self updateConflictWarning];
}

- (IBAction)resizeModifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setResizeModifierKey:[menu title] enabled:newState];
    [self refreshCachedPreferences];
    [self updateConflictWarning];
}

- (IBAction)resetToDefaults:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    [preferences setToDefaults];
    [self syncMenuStatesFromPreferences];
    [self setMenusEnabled:YES];
    [self enableRunLoopSource:moveResize];
    [self refreshCachedPreferences];
}

- (IBAction)toggleBringWindowToFront:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldBringWindowToFront:newState];
}


- (IBAction)toggleDisabled:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    if ([_disabledMenu state] == 0) {
        [_disabledMenu setState:YES];
        [self setMenusEnabled:NO];
        [self disableRunLoopSource:moveResize];
    }
    else {
        [_disabledMenu setState:NO];
        [self setMenusEnabled:YES];
        [self enableRunLoopSource:moveResize];
    }
}

- (IBAction)toggleResizeOnly:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setResizeOnly:newState];
    [self updateMoveMenuEnabled:!newState];
}

- (IBAction)setMoveMouseButton:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    int button = (int)[menu tag];
    [preferences setMoveMouseButton:button];
    [self updateMouseButtonRadioState:button left:moveMouseButtonLeftMenu right:moveMouseButtonRightMenu middle:moveMouseButtonMiddleMenu];
    [self refreshCachedPreferences];
    [self updateConflictWarning];
}

- (IBAction)setResizeMouseButton:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    int button = (int)[menu tag];
    [preferences setResizeMouseButton:button];
    [self updateMouseButtonRadioState:button left:resizeMouseButtonLeftMenu right:resizeMouseButtonRightMenu middle:resizeMouseButtonMiddleMenu];
    [self refreshCachedPreferences];
    [self updateConflictWarning];
}

- (IBAction)disableLastApp:(id)sender {
    [preferences setDisabledForApp:[lastApp bundleIdentifier] withLocalizedName:[lastApp localizedName] disabled:YES];
    [_lastAppMenu setEnabled:FALSE];
    [self reconstructDisabledAppsSubmenu];
}

- (IBAction)enableDisabledApp:(id)sender {
    NSString *bundleId = [sender representedObject];
    [preferences setDisabledForApp:bundleId withLocalizedName:nil disabled:NO];
    if (lastApp != nil && [[lastApp bundleIdentifier] isEqualToString:bundleId]) {
        [_lastAppMenu setEnabled:YES];
    }
    [self reconstructDisabledAppsSubmenu];
}

#pragma mark - Accessor methods

- (int)modifierFlags {
    return keyModifierFlags;
}
- (int)resizeModifierFlags {
    return resizeKeyModifierFlags;
}
- (int)moveMouseButton {
    return cachedMoveMouseButton;
}
- (int)resizeMouseButton {
    return cachedResizeMouseButton;
}
- (void) setMostRecentApp:(NSRunningApplication*)app {
    lastApp = app;
    [_lastAppMenu setTitle:[NSString stringWithFormat:@"Disable for %@", [app localizedName]]];
    [_lastAppMenu setEnabled:YES];
}
- (NSDictionary*) getDisabledApps {
    return [preferences getDisabledApps];
}
-(BOOL)shouldBringWindowToFront {
    return [preferences shouldBringWindowToFront];
}
-(BOOL)resizeOnly {
    return [preferences resizeOnly];
}

- (void)setMenusEnabled:(BOOL)enabled {
    // Move section
    [moveAltMenu setEnabled:enabled];
    [moveCmdMenu setEnabled:enabled];
    [moveCtrlMenu setEnabled:enabled];
    [moveShiftMenu setEnabled:enabled];
    [moveFnMenu setEnabled:enabled];

    // Resize section
    [resizeAltMenu setEnabled:enabled];
    [resizeCmdMenu setEnabled:enabled];
    [resizeCtrlMenu setEnabled:enabled];
    [resizeShiftMenu setEnabled:enabled];
    [resizeFnMenu setEnabled:enabled];

    // Other items
    [_bringWindowFrontMenu setEnabled:enabled];
    [_resizeOnlyMenu setEnabled:enabled];

    // When re-enabling, respect resizeOnly state for Move section
    if (enabled && [preferences resizeOnly]) {
        [self updateMoveMenuEnabled:NO];
    }
}

- (void)reconstructDisabledAppsSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    NSDictionary *disabledApps = [self getDisabledApps];
    for (id bundleIdentifier in disabledApps) {
        NSMenuItem *item = [submenu addItemWithTitle:[disabledApps objectForKey:bundleIdentifier] action:@selector(enableDisabledApp:) keyEquivalent:@""];
        [item setRepresentedObject:bundleIdentifier];
    }
    [_disabledAppsMenu setSubmenu:submenu];
    [_disabledAppsMenu setEnabled:([disabledApps count] > 0)];
}

@end
