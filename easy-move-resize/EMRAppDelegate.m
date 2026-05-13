#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"
#import "EMRPreferences.h"

static const CGFloat kEdgeThreshold = 10.0;
static const CGFloat kCornerThreshold = 50.0;

EMRTileZone detectTileZone(CGPoint mouseLocation) {
    NSScreen *screen = nil;
    for (NSScreen *s in [NSScreen screens]) {
        if (NSPointInRect(NSPointFromCGPoint(mouseLocation), s.frame)) {
            screen = s;
            break;
        }
    }
    if (!screen) {
        screen = [NSScreen mainScreen];
    }
    
    NSRect frame = screen.frame;
    
    CGFloat screenLeft = frame.origin.x;
    CGFloat screenRight = frame.origin.x + frame.size.width;
    CGFloat screenTop = frame.origin.y + frame.size.height;
    
    BOOL nearLeft = mouseLocation.x <= screenLeft + kEdgeThreshold;
    BOOL nearRight = mouseLocation.x >= screenRight - kEdgeThreshold;
    BOOL nearTop = mouseLocation.y <= frame.origin.y + kEdgeThreshold;
    
    BOOL inTopCornerZone = mouseLocation.y <= frame.origin.y + kCornerThreshold;
    BOOL inBottomCornerZone = mouseLocation.y >= screenTop - kCornerThreshold - 25;
    
    if (nearTop && !nearLeft && !nearRight) {
        return EMRTileZoneMaximize;
    }
    if (nearLeft && inTopCornerZone) {
        return EMRTileZoneTopLeftQuarter;
    }
    if (nearRight && inTopCornerZone) {
        return EMRTileZoneTopRightQuarter;
    }
    if (nearLeft && inBottomCornerZone) {
        return EMRTileZoneBottomLeftQuarter;
    }
    if (nearRight && inBottomCornerZone) {
        return EMRTileZoneBottomRightQuarter;
    }
    if (nearLeft) {
        return EMRTileZoneLeftHalf;
    }
    if (nearRight) {
        return EMRTileZoneRightHalf;
    }
    
    return EMRTileZoneNone;
}

NSRect getTileFrame(EMRTileZone zone, CGPoint mouseLocation) {
    NSScreen *screen = nil;
    for (NSScreen *s in [NSScreen screens]) {
        if (NSPointInRect(NSPointFromCGPoint(mouseLocation), s.frame)) {
            screen = s;
            break;
        }
    }
    if (!screen) {
        screen = [NSScreen mainScreen];
    }
    
    NSRect visibleFrame = screen.visibleFrame;
    CGFloat halfWidth = visibleFrame.size.width / 2;
    CGFloat halfHeight = visibleFrame.size.height / 2;
    
    switch (zone) {
        case EMRTileZoneLeftHalf:
            return NSMakeRect(visibleFrame.origin.x, visibleFrame.origin.y,
                            halfWidth, visibleFrame.size.height);
        case EMRTileZoneRightHalf:
            return NSMakeRect(visibleFrame.origin.x + halfWidth, visibleFrame.origin.y,
                            halfWidth, visibleFrame.size.height);
        case EMRTileZoneMaximize:
            return visibleFrame;
        case EMRTileZoneTopLeftQuarter:
            return NSMakeRect(visibleFrame.origin.x, visibleFrame.origin.y + halfHeight,
                            halfWidth, halfHeight);
        case EMRTileZoneTopRightQuarter:
            return NSMakeRect(visibleFrame.origin.x + halfWidth, visibleFrame.origin.y + halfHeight,
                            halfWidth, halfHeight);
        case EMRTileZoneBottomLeftQuarter:
            return NSMakeRect(visibleFrame.origin.x, visibleFrame.origin.y,
                            halfWidth, halfHeight);
        case EMRTileZoneBottomRightQuarter:
            return NSMakeRect(visibleFrame.origin.x + halfWidth, visibleFrame.origin.y,
                            halfWidth, halfHeight);
        case EMRTileZoneNone:
        default:
            return NSZeroRect;
    }
}

NSRect convertToScreenCoordinates(NSRect rect) {
    NSRect mainScreenFrame = [[NSScreen mainScreen] frame];
    CGFloat mainScreenHeight = mainScreenFrame.size.height;
    return NSMakeRect(rect.origin.x,
                     mainScreenHeight - rect.origin.y - rect.size.height,
                     rect.size.width,
                     rect.size.height);
}

void showTilePreview(EMRMoveResize *moveResize, EMRTileZone zone, CGPoint mouseLocation) {
    if (zone == EMRTileZoneNone) {
        if ([moveResize tilePreviewWindow]) {
            [[moveResize tilePreviewWindow] orderOut:nil];
        }
        return;
    }
    
    NSRect tileFrame = getTileFrame(zone, mouseLocation);
    if (NSIsEmptyRect(tileFrame)) {
        return;
    }
    
    NSWindow *previewWindow = [moveResize tilePreviewWindow];
    if (!previewWindow) {
        previewWindow = [[NSWindow alloc] initWithContentRect:tileFrame
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        [previewWindow setBackgroundColor:[[NSColor systemBlueColor] colorWithAlphaComponent:0.2]];
        [previewWindow setOpaque:NO];
        [previewWindow setLevel:NSFloatingWindowLevel];
        [previewWindow setIgnoresMouseEvents:YES];
        [previewWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary];
        [moveResize setTilePreviewWindow:previewWindow];
    }
    
    [previewWindow setFrame:tileFrame display:YES];
    [previewWindow orderFront:nil];
}

void hideTilePreview(EMRMoveResize *moveResize) {
    if ([moveResize tilePreviewWindow]) {
        [[moveResize tilePreviewWindow] orderOut:nil];
    }
    [moveResize setCurrentTileZone:EMRTileZoneNone];
}

void applyTileZone(EMRMoveResize *moveResize, EMRTileZone zone, CGPoint mouseLocation) {
    if (zone == EMRTileZoneNone) {
        return;
    }
    
    AXUIElementRef window = [moveResize window];
    if (!window) {
        return;
    }
    
    NSRect tileFrame = getTileFrame(zone, mouseLocation);
    if (NSIsEmptyRect(tileFrame)) {
        return;
    }
    
    if (![moveResize isWindowTiled]) {
        NSPoint currentPos = [moveResize wndPosition];
        CFTypeRef sizeRef = nil;
        CGSize currentSize;
        if (AXUIElementCopyAttributeValue(window, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &sizeRef) == kAXErrorSuccess) {
            AXValueGetValue(sizeRef, kAXValueCGSizeType, &currentSize);
            CFRelease(sizeRef);
        } else {
            currentSize = CGSizeMake(800, 600);
        }
        
        NSRect preTileFrame = NSMakeRect(currentPos.x, currentPos.y, currentSize.width, currentSize.height);
        [moveResize setPreTileFrame:preTileFrame];
    }
    
    NSRect screenCoordFrame = convertToScreenCoordinates(tileFrame);
    
    CGPoint position = CGPointMake(screenCoordFrame.origin.x, screenCoordFrame.origin.y);
    CGSize size = CGSizeMake(screenCoordFrame.size.width, screenCoordFrame.size.height);
    
    CFTypeRef positionRef = AXValueCreate(kAXValueCGPointType, &position);
    CFTypeRef sizeRef = AXValueCreate(kAXValueCGSizeType, &size);
    
    AXUIElementSetAttributeValue(window, (__bridge CFStringRef)NSAccessibilityPositionAttribute, positionRef);
    AXUIElementSetAttributeValue(window, (__bridge CFStringRef)NSAccessibilitySizeAttribute, sizeRef);
    
    CFRelease(positionRef);
    CFRelease(sizeRef);
    
    [moveResize setIsWindowTiled:YES];
}

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
        [moveResize setTracking:CACurrentMediaTime()];

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
        handled = YES;
    }

    if (type == kCGEventLeftMouseDragged
            && [moveResize tracking] > 0) {
        AXUIElementRef _clickedWindow = [moveResize window];
        double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);
        
        if ([moveResize isWindowTiled] && [ourDelegate edgeTilingEnabled]) {
            NSRect preTileFrame = [moveResize preTileFrame];
            CGPoint mouseLocation = CGEventGetLocation(event);
            NSPoint tiledPos = [moveResize wndPosition];
            
            CFTypeRef tiledSizeRef = nil;
            CGSize tiledSize;
            if (AXUIElementCopyAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &tiledSizeRef) == kAXErrorSuccess) {
                AXValueGetValue(tiledSizeRef, kAXValueCGSizeType, &tiledSize);
                CFRelease(tiledSizeRef);
            } else {
                tiledSize = CGSizeMake(preTileFrame.size.width, preTileFrame.size.height);
            }
            
            CGFloat relativeX = (mouseLocation.x - tiledPos.x) / tiledSize.width;
            CGFloat relativeY = (mouseLocation.y - tiledPos.y) / tiledSize.height;
            
            CGSize originalSize = CGSizeMake(preTileFrame.size.width, preTileFrame.size.height);
            CFTypeRef sizeRef = AXValueCreate(kAXValueCGSizeType, &originalSize);
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, sizeRef);
            CFRelease(sizeRef);
            
            CGFloat newX = mouseLocation.x - (relativeX * preTileFrame.size.width);
            CGFloat newY = mouseLocation.y - (relativeY * preTileFrame.size.height);
            CGPoint newPosition = CGPointMake(newX, newY);
            CFTypeRef posRef = AXValueCreate(kAXValueCGPointType, &newPosition);
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, posRef);
            CFRelease(posRef);
            
            [moveResize setWndPosition:NSMakePoint(newX, newY)];
            [moveResize setIsWindowTiled:NO];
            [moveResize setPreTileFrame:NSZeroRect];
        }

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
        
        if ([ourDelegate edgeTilingEnabled]) {
            CGPoint mouseLocation = CGEventGetLocation(event);
            EMRTileZone zone = detectTileZone(mouseLocation);
            [moveResize setCurrentTileZone:zone];
            showTilePreview(moveResize, zone, mouseLocation);
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
        
        if (type == kCGEventLeftMouseUp && [ourDelegate edgeTilingEnabled]) {
            CGPoint mouseLocation = CGEventGetLocation(event);
            EMRTileZone zone = [moveResize currentTileZone];
            if (zone != EMRTileZoneNone) {
                applyTileZone(moveResize, zone, mouseLocation);
            }
            hideTilePreview(moveResize);
        }
        
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
    [_edgeTilingMenu setState:0];

    bool shouldBringWindowToFront = [preferences shouldBringWindowToFront];
    bool shouldMiddleClickResize = [preferences shouldMiddleClickResize];
    bool resizeOnly = [preferences resizeOnly];
    bool edgeTilingEnabled = [preferences edgeTilingEnabled];

    if(shouldBringWindowToFront){
        [_bringWindowFrontMenu setState:1];
    }
    if(shouldMiddleClickResize){
        [_middleClickResizeMenu setState:1];
    }
    if(resizeOnly){
        [_resizeOnlyMenu setState:1];
    }
    if(edgeTilingEnabled){
        [_edgeTilingMenu setState:1];
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

- (IBAction)toggleEdgeTiling:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setEdgeTilingEnabled:newState];
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
-(BOOL)edgeTilingEnabled {
    return [preferences edgeTilingEnabled];
}

- (void)setMenusEnabled:(BOOL)enabled {
    [_altMenu setEnabled:enabled];
    [_cmdMenu setEnabled:enabled];
    [_ctrlMenu setEnabled:enabled];
    [_shiftMenu setEnabled:enabled];
    [_fnMenu setEnabled:enabled];
    [_bringWindowFrontMenu setEnabled:enabled];
    [_middleClickResizeMenu setEnabled:enabled];
    [_edgeTilingMenu setEnabled:enabled];
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
