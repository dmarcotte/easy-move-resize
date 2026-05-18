#import "EMRMoveResize.h"

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                     const CVTimeStamp *inNow,
                                     const CVTimeStamp *inOutputTime,
                                     CVOptionFlags flagsIn,
                                     CVOptionFlags *flagsOut,
                                     void *displayLinkContext) {
    EMRMoveResize *moveResize = (__bridge EMRMoveResize *)displayLinkContext;
    [moveResize applyPendingChanges];
    return kCVReturnSuccess;
}

@implementation EMRMoveResize
@synthesize eventTap = _eventTap;
@synthesize resizeSection = _resizeSection;
@synthesize tracking = _tracking;
@synthesize wndPosition = _wndPosition;
@synthesize wndSize = _wndSize;

+ (EMRMoveResize*)instance {
    static EMRMoveResize *instance = nil;

    if (instance == nil) {
        instance = [[EMRMoveResize alloc] init];
    }

    return instance;
}

- init {
    _window = nil;
    _runLoopSource = nil;
    _displayLink = NULL;
    _displayStateLock = OS_UNFAIR_LOCK_INIT;
    memset(&_displayState, 0, sizeof(_displayState));
    return self;
}

- (AXUIElementRef)window {
    return _window;
}

- (void)setWindow:(AXUIElementRef)window {
    if (_window != nil) CFRelease(_window);
    if (window != nil) CFRetain(window);
    _window = window;
}

- (CFRunLoopSourceRef) runLoopSource {
    return _runLoopSource;
}

- (void)setRunLoopSource:(CFRunLoopSourceRef)runLoopSource {
    if (_runLoopSource != nil) CFRelease(_runLoopSource);
    if (runLoopSource != nil) CFRetain(runLoopSource);
    _runLoopSource = runLoopSource;
}

- (void)setupDisplayLink {
    if (_displayLink != NULL) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, &displayLinkCallback, (__bridge void *)self);
    CVDisplayLinkStart(_displayLink);
}

- (void)startDisplayLink {
    os_unfair_lock_lock(&_displayStateLock);
    _displayState.dirty = NO;
    _displayState.window = _window;
    os_unfair_lock_unlock(&_displayStateLock);
}

- (void)stopDisplayLink {
    os_unfair_lock_lock(&_displayStateLock);
    _displayState.dirty = NO;
    _displayState.window = NULL;
    os_unfair_lock_unlock(&_displayStateLock);
}

- (void)updatePosition:(NSPoint)position {
    os_unfair_lock_lock(&_displayStateLock);
    _displayState.position = position;
    _displayState.operation = EMROperationMove;
    _displayState.dirty = YES;
    os_unfair_lock_unlock(&_displayStateLock);
}

- (void)updatePositionAndSize:(NSPoint)position size:(NSSize)size resizeSection:(struct ResizeSection)resizeSection {
    os_unfair_lock_lock(&_displayStateLock);
    _displayState.position = position;
    _displayState.size = size;
    _displayState.resizeSection = resizeSection;
    _displayState.operation = EMROperationResize;
    _displayState.dirty = YES;
    os_unfair_lock_unlock(&_displayStateLock);
}

- (void)applyPendingChanges {
    os_unfair_lock_lock(&_displayStateLock);
    EMRDisplayState snapshot = _displayState;
    _displayState.dirty = NO;
    os_unfair_lock_unlock(&_displayStateLock);

    if (!snapshot.dirty || snapshot.window == NULL) {
        return;
    }

    if (snapshot.operation == EMROperationMove) {
        CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&snapshot.position));
        AXUIElementSetAttributeValue(snapshot.window, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
        if (_position != NULL) CFRelease(_position);
    } else if (snapshot.operation == EMROperationResize) {
        if (snapshot.resizeSection.xResizeDirection == left || snapshot.resizeSection.yResizeDirection == bottom) {
            CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&snapshot.position));
            AXUIElementSetAttributeValue(snapshot.window, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
            CFRelease(_position);
        }

        CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&snapshot.size));
        AXUIElementSetAttributeValue(snapshot.window, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
        CFRelease(_size);
    }
}

- (void)dealloc {
    if (_displayLink != NULL) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
    if (_window != nil) CFRelease(_window);
}

@end
