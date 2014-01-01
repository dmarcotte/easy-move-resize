#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"

@implementation EMRAppDelegate

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void __unused *refcon) {

    EMRMoveResize* moveResize = [EMRMoveResize instance];

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        // need to re-enable our eventTap (We got disabled.  Usually happens on a slow resizing app)
        CGEventTapEnable([moveResize eventTap], true);
        NSLog(@"Re-enabling...");
        return event;
    }

    CGEventFlags flags = CGEventGetFlags(event);

    if ((flags & (kCGEventFlagMaskCommand | kCGEventFlagMaskControl)) != (kCGEventFlagMaskCommand | kCGEventFlagMaskControl)) {
        // didn't find our Cmd+Ctrl modifiers; this event isn't for us
        return event;
    }

    if (flags & (kCGEventFlagMaskShift | kCGEventFlagMaskAlternate | kCGEventFlagMaskAlphaShift)) {
        // also ignore this event if we've got extra modifiers (i.e. holding down Cmd+Ctrl+Alt should not invoke our action)
        return event;
    }

    if (type == kCGEventLeftMouseDown
            || type == kCGEventRightMouseDown) {
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:1];

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

        CFTypeRef _cPosition;
        NSPoint cTopLeft;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, &_cPosition) == kAXErrorSuccess) {
            if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
                NSLog(@"ERROR: Could not decode position");
                cTopLeft = NSMakePoint(0, 0);
            }
        }
        cTopLeft.x = (int) cTopLeft.x;
        cTopLeft.y = (int) cTopLeft.y;

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWindow:_clickedWindow];
    }

    if (type == kCGEventLeftMouseDragged
            && [moveResize tracking] > 0) {
        [moveResize setTracking:[moveResize tracking] + 1];
        AXUIElementRef _clickedWindow = [moveResize window];
        double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSPoint thePoint;
        thePoint.x = cTopLeft.x + deltaX;
        thePoint.y = cTopLeft.y + deltaY;
        [moveResize setWndPosition:thePoint];
        CFTypeRef _position;

        // actually applying the change is expensive, so only do it every kMoveFilterInterval events
        if ([moveResize tracking] % kMoveFilterInterval == 0) {
            _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
            if (AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position) != kAXErrorSuccess) {
                if (_position != NULL) CFRelease(_position);
            }
            if (_position != NULL) CFRelease(_position);
        }
    }

    if (type == kCGEventRightMouseDown) {
        [moveResize setTracking:true];
        AXUIElementRef _clickedWindow = [moveResize window];

        // on right click, record which direction we should resize in on the drag
        struct ResizeSection resizeSection;

        CGPoint clickPoint = CGEventGetLocation(event);

        NSPoint cTopLeft = [moveResize wndPosition];

        clickPoint.x -= cTopLeft.x;
        clickPoint.y -= cTopLeft.y;

        CFTypeRef _cSize;
        NSSize cSize;
        if (!AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess
                || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
            NSLog(@"ERROR: Could not decode size");
            return NULL;
        }

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
    }

    if (type == kCGEventRightMouseDragged
            && [moveResize tracking] > 0) {
        [moveResize setTracking:[moveResize tracking] + 1];

        AXUIElementRef _clickedWindow = [moveResize window];
        struct ResizeSection resizeSection = [moveResize resizeSection];
        int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);
        CFTypeRef _size;
        CFTypeRef _position;

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
        if ([moveResize tracking] % kResizeFilterInterval == 0) {
            // only make a call to update the position if we need to
            if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
            }

            _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
            AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
        }
    }

    if (type == kCGEventLeftMouseUp
            || type == kCGEventRightMouseUp) {
        [moveResize setTracking:0];
    }

    // we took ownership of this event, don't pass it along
    return NULL;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (!AXAPIEnabled()) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Cannot start Easy Move+Resize!\n\nTo fix this problem, please select\n\"Enable access for assistive devices\" in\nSystem Preferences -> Accessibility"];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        exit(1);
    }

    CFRunLoopSourceRef runLoopSource;

    CGEventMask eventMask = CGEventMaskBit( kCGEventLeftMouseDown )
                    | CGEventMaskBit( kCGEventLeftMouseDragged )
                    | CGEventMaskBit( kCGEventRightMouseDown )
                    | CGEventMaskBit( kCGEventRightMouseDragged )
                    | CGEventMaskBit( kCGEventLeftMouseUp )
                    | CGEventMaskBit( kCGEventRightMouseUp )
    ;

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
            NULL);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    EMRMoveResize *moveResize = [EMRMoveResize instance];
    [moveResize setEventTap:eventTap];
    CGEventTapEnable([moveResize eventTap], true);
}

-(void)awakeFromNib{
    NSImage *icon = [NSImage imageNamed:@"MenuIcon"];
    NSImage *altIcon = [NSImage imageNamed:@"MenuIconHighlight"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:icon];
    [statusItem setAlternateImage:altIcon];
    [statusItem setHighlightMode:YES];
}

@end
