#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"
#import "EMRPreferences.h"

static BOOL EMRGetValue(AXUIElementRef element, CFStringRef attribute, AXValueType type, void *result) {
    CFTypeRef value = NULL;
    BOOL ok = AXUIElementCopyAttributeValue(element, attribute, &value) == kAXErrorSuccess && value
        && CFGetTypeID(value) == AXValueGetTypeID() && AXValueGetValue(value, type, result);
    if (value) CFRelease(value);
    return ok;
}

// Returns the single AX window of `pid` whose frame matches `frame`, or NULL if none or ambiguous.
static AXUIElementRef EMRCopyAXWindowWithFrame(pid_t pid, CGRect frame) {
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    CFTypeRef windows = NULL;
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, &windows);
    CFRelease(app);
    AXUIElementRef result = NULL;
    if (windows && CFGetTypeID(windows) == CFArrayGetTypeID()) {
        for (id entry in (__bridge NSArray *)windows) {
            AXUIElementRef window = (__bridge AXUIElementRef)entry;
            CGPoint origin;
            CGSize size;
            if (CFGetTypeID(window) != AXUIElementGetTypeID()
                || !EMRGetValue(window, kAXPositionAttribute, kAXValueCGPointType, &origin)
                || !EMRGetValue(window, kAXSizeAttribute, kAXValueCGSizeType, &size)
                || fabs(origin.x - frame.origin.x) > 2 || fabs(origin.y - frame.origin.y) > 2
                || fabs(size.width - frame.size.width) > 2 || fabs(size.height - frame.size.height) > 2) continue;
            if (result) { // Several windows share this frame; picking one would be a guess.
                CFRelease(result);
                result = NULL;
                break;
            }
            result = (AXUIElementRef)CFRetain(window);
        }
    }
    if (windows) CFRelease(windows);
    return result;
}

// Fallback for apps (e.g. WeChat, Telegram) whose clicked element has no window ancestor:
// take the topmost window under the pointer and, if it is a normal window, match it to its
// owner's AX windows. Any other window in front (menus, panels, notifications) cancels, so
// a window behind an overlay is never moved. The one exception is the Dock's backing
// window, which can span the whole screen without covering anything; clicks on actual Dock
// icons are still rejected because the hit-tested element then belongs to the Dock, and a
// window from a different app than the hit-tested element is never accepted.
static AXUIElementRef EMRCopyWindowFromList(CGPoint point, pid_t hitPid) {
    CFArrayRef list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                                                 kCGNullWindowID);
    if (!list) return NULL;
    AXUIElementRef result = NULL;
    for (NSDictionary *info in (__bridge NSArray *)list) {
        NSDictionary *boundsInfo = info[(__bridge NSString *)kCGWindowBounds];
        CGRect bounds;
        NSNumber *alpha = info[(__bridge NSString *)kCGWindowAlpha];
        if (!boundsInfo || !CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsInfo, &bounds)
            || !CGRectContainsPoint(bounds, point) || (alpha && alpha.doubleValue <= 0)) continue;
        int layer = [info[(__bridge NSString *)kCGWindowLayer] intValue];
        pid_t pid = [info[(__bridge NSString *)kCGWindowOwnerPID] intValue];
        if (layer == CGWindowLevelForKey(kCGDockWindowLevelKey)
            && [[NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier
                isEqualToString:@"com.apple.dock"]) continue;
        if (layer == 0 && (hitPid == 0 || pid == hitPid)) result = EMRCopyAXWindowWithFrame(pid, bounds);
        NSLog(@"[EMR] window list fallback: hit pid=%d, window pid=%d, layer=%d, matched=%d",
              hitPid, pid, layer, result != NULL);
        break;
    }
    CFRelease(list);
    return result;
}

// Returns an owned reference to the window under `point`, or NULL.
static AXUIElementRef EMRCopyWindowAtPoint(CGPoint point) {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(systemWide, point.x, point.y, &element);
    CFRelease(systemWide);
    pid_t hitPid = 0;
    if (error == kAXErrorSuccess && element) {
        AXUIElementGetPid(element, &hitPid);
        // Walk up the tree: the element itself, its AXWindow, or an ancestor's. Bounded
        // in case an app exposes a cyclic hierarchy.
        AXUIElementRef current = (AXUIElementRef)CFRetain(element);
        for (int depth = 0; current && depth < 10; ++depth) {
            CFTypeRef role = NULL, window = NULL, parent = NULL;
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute, &role);
            BOOL isWindow = role && CFEqual(role, kAXWindowRole);
            if (role) CFRelease(role);
            if (isWindow) window = CFRetain(current);
            else AXUIElementCopyAttributeValue(current, kAXWindowAttribute, &window);
            if (window && CFGetTypeID(window) == AXUIElementGetTypeID()) {
                CFRelease(current);
                CFRelease(element);
                return (AXUIElementRef)window;
            }
            if (window) CFRelease(window);
            AXUIElementCopyAttributeValue(current, kAXParentAttribute, &parent);
            CFRelease(current);
            current = parent && CFGetTypeID(parent) == AXUIElementGetTypeID() ? (AXUIElementRef)parent : NULL;
            if (parent && !current) CFRelease(parent);
        }
        if (current) CFRelease(current);
        CFRelease(element);
    }
    return EMRCopyWindowFromList(point, hitPid);
}

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

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {

    EMRAppDelegate *ourDelegate = (__bridge EMRAppDelegate*)refcon;
    int keyModifierFlags = [ourDelegate modifierFlags];
    bool shouldMiddleClickResize = [ourDelegate shouldMiddleClickResize];
    bool resizeOnly = [ourDelegate resizeOnly];
    CGEventType resizeModifierDown = kCGEventRightMouseDown;
    CGEventType resizeModifierDragged = kCGEventRightMouseDragged;
    CGEventType resizeModifierUp = kCGEventRightMouseUp;
    bool handled = NO;

    if (![ourDelegate sessionActive]) {
        return event;
    }

    if (keyModifierFlags == 0) {
        // No modifier keys set. Disable behaviour.
        return event;
    }
    
    if (shouldMiddleClickResize){
        resizeModifierDown = kCGEventOtherMouseDown;
        resizeModifierDragged = kCGEventOtherMouseDragged;
        resizeModifierUp = kCGEventOtherMouseUp;
    }
    
    EMRMoveResize* moveResize = [EMRMoveResize instance];

    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        // need to re-enable our eventTap (We got disabled.  Usually happens on a slow resizing app)
        CGEventTapEnable([moveResize eventTap], true);
        return event;
    }
    
    CGEventFlags flags = CGEventGetFlags(event);
    if ((flags & (keyModifierFlags)) != (keyModifierFlags)) {
        // didn't find our expected modifiers; this event isn't for us
        return event;
    }

    int ignoredKeysMask = (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn) ^ keyModifierFlags;
    
    if (flags & ignoredKeysMask) {
        // also ignore this event if we've got extra modifiers (i.e. holding down Cmd+Ctrl+Alt should not invoke our action)
        return event;
    }

    if ((type == kCGEventLeftMouseDown && !resizeOnly)
            || type == resizeModifierDown) {
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:0];

        // If no window (or its position) can be found, let the click through untouched.
        AXUIElementRef _clickedWindow = EMRCopyWindowAtPoint(mouseLocation);
        NSPoint cTopLeft;
        if (!_clickedWindow || !EMRGetValue(_clickedWindow, kAXPositionAttribute, kAXValueCGPointType, &cTopLeft)) {
            NSLog(@"[EMR] no movable window under pointer; passing click through");
            if (_clickedWindow) CFRelease(_clickedWindow);
            return event;
        }
        [moveResize setTracking:CACurrentMediaTime()];

        pid_t PID;
        NSRunningApplication* app = nil;
        if(!AXUIElementGetPid(_clickedWindow, &PID)) {
            app = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
            if ([app bundleIdentifier] && [[ourDelegate getDisabledApps] objectForKey:[app bundleIdentifier]] != nil) {
                [moveResize setTracking:0];
                CFRelease(_clickedWindow);
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

        cTopLeft.x = (int) cTopLeft.x;
        cTopLeft.y = (int) cTopLeft.y;

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWindow:_clickedWindow];
        if (_clickedWindow != nil) CFRelease(_clickedWindow);
        handled = YES;
    }

    if (type == kCGEventLeftMouseDragged
            && [moveResize tracking] > 0) {
        AXUIElementRef _clickedWindow = [moveResize window];
        double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSPoint thePoint;
        thePoint.x = cTopLeft.x + deltaX;
        thePoint.y = cTopLeft.y + deltaY;
        [moveResize setWndPosition:thePoint];
        CFTypeRef _position;

        // actually applying the change is expensive, so only do it every kMoveFilterInterval seconds
        if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.moveFilterInterval) {
            _position = (CFTypeRef) (AXValueCreate(kAXValueCGPointType, (const void *) &thePoint));
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef) NSAccessibilityPositionAttribute, (CFTypeRef *) _position);
            if (_position != NULL) CFRelease(_position);
            [moveResize setTracking:CACurrentMediaTime()];
        }
        handled = YES;
    }

    if (type == resizeModifierDown) {
        AXUIElementRef _clickedWindow = [moveResize window];

        // on resizeModifierDown click, record which direction we should resize in on the drag
        struct ResizeSection resizeSection;

        CGPoint clickPoint = CGEventGetLocation(event);

        NSPoint cTopLeft = [moveResize wndPosition];

        clickPoint.x -= cTopLeft.x;
        clickPoint.y -= cTopLeft.y;

        CFTypeRef _cSize;
        NSSize cSize;
        if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
                || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
            NSLog(@"ERROR: Could not decode size");
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
        } else  if (clickPoint.y > 2*wndSize.height/3) {
            resizeSection.yResizeDirection = top;
        } else {
            resizeSection.yResizeDirection = noY;
        }

        [moveResize setWndSize:wndSize];
        [moveResize setResizeSection:resizeSection];
        handled = YES;
    }

    if (type == resizeModifierDragged
            && [moveResize tracking] > 0) {
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
                // nothing to do
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
                // nothing to do
                break;
            default:
                [NSException raise:@"Unknown yResizeSection" format:@"No case for %d", resizeSection.yResizeDirection];
        }

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWndSize:wndSize];

        // actually applying the change is expensive, so only do it every kResizeFilterInterval events
        if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.resizeFilterInterval) {
            // only make a call to update the position if we need to
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
        handled = YES;
    }

    if ((type == kCGEventLeftMouseUp || type == resizeModifierUp)
        && [moveResize tracking] > 0) {
        [moveResize setTracking:0];
        handled = YES;
    }
    
    if (handled) {
        return NULL;
    }
    else {
        return event;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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
        // don't have permission to do our thing right now... AXIsProcessTrustedWithOptions prompted the user to fix
        // this, so hopefully on next launch we'll be good to go
        NSLog(@"Missing permissions");
        exit(1);
    }
    
    [self initMenuItems];

    // Retrieve the Key press modifier flags to activate move/resize actions.
    keyModifierFlags = [preferences modifierFlags];
    
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

- (void)initMenuItems {
    [_altMenu setState:0];
    [_cmdMenu setState:0];
    [_ctrlMenu setState:0];
    [_shiftMenu setState:0];
    [_fnMenu setState:0];
    [_disabledMenu setState:0];
    [_bringWindowFrontMenu setState:0];
    [_middleClickResizeMenu setState:0];

    bool shouldBringWindowToFront = [preferences shouldBringWindowToFront];
    bool shouldMiddleClickResize = [preferences shouldMiddleClickResize];
    bool resizeOnly = [preferences resizeOnly];

    if(shouldBringWindowToFront){
        [_bringWindowFrontMenu setState:1];
    }
    if(shouldMiddleClickResize){
        [_middleClickResizeMenu setState:1];
    }
    if(resizeOnly){
        [_resizeOnlyMenu setState:1];
    }
    
    NSSet* flags = [preferences getFlagStringSet];
    if ([flags containsObject:ALT_KEY]) {
        [_altMenu setState:1];
    }
    if ([flags containsObject:CMD_KEY]) {
        [_cmdMenu setState:1];
    }
    if ([flags containsObject:CTRL_KEY]) {
        [_ctrlMenu setState:1];
    }
    if ([flags containsObject:SHIFT_KEY]) {
        [_shiftMenu setState:1];
    }
    if ([flags containsObject:FN_KEY]) {
        [_fnMenu setState:1];
    }
}

- (IBAction)modifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setModifierKey:[menu title] enabled:newState];
    keyModifierFlags = [preferences modifierFlags];
}

- (IBAction)resetToDefaults:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    [preferences setToDefaults];
    [self initMenuItems];
    [self setMenusEnabled:YES];
    [self enableRunLoopSource:moveResize];
    keyModifierFlags = [preferences modifierFlags];
}

- (IBAction)toggleBringWindowToFront:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldBringWindowToFront:newState];
}

- (IBAction)toggleMiddleClickResize:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldMiddleClickResize:newState];
}

- (IBAction)toggleDisabled:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    if ([_disabledMenu state] == 0) {
        // We are enabled, disable
        [_disabledMenu setState:YES];
        [self setMenusEnabled:NO];
        [self disableRunLoopSource:moveResize];
    }
    else {
        // We are disabled, enable
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

- (int)modifierFlags {
    return keyModifierFlags;
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
-(BOOL)shouldMiddleClickResize {
    return [preferences shouldMiddleClickResize];
}
-(BOOL)resizeOnly {
    return [preferences resizeOnly];
}

- (void)setMenusEnabled:(BOOL)enabled {
    [_altMenu setEnabled:enabled];
    [_cmdMenu setEnabled:enabled];
    [_ctrlMenu setEnabled:enabled];
    [_shiftMenu setEnabled:enabled];
    [_fnMenu setEnabled:enabled];
    [_bringWindowFrontMenu setEnabled:enabled];
    [_middleClickResizeMenu setEnabled:enabled];
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
