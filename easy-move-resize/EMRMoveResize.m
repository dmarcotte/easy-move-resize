#import "EMRMoveResize.h"

static BOOL enhancedUserInterfaceIsEnabled(AXUIElementRef application) {
    CFTypeRef value = nil;
    AXError error = AXUIElementCopyAttributeValue(application,
                                                   CFSTR("AXEnhancedUserInterface"),
                                                   &value);
    BOOL isEnabled = error == kAXErrorSuccess
        && value != nil
        && CFGetTypeID(value) == CFBooleanGetTypeID()
        && CFBooleanGetValue(value);

    if (value != nil) CFRelease(value);
    return isEnabled;
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
    _enhancedUserInterfaceApplication = nil;
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

- (void)temporarilyDisableEnhancedUserInterfaceForApplication:(AXUIElementRef)application {
    [self restoreEnhancedUserInterface];

    if (application == nil || !enhancedUserInterfaceIsEnabled(application)) return;

    _enhancedUserInterfaceApplication = application;
    CFRetain(_enhancedUserInterfaceApplication);
    AXUIElementSetAttributeValue(application,
                                 CFSTR("AXEnhancedUserInterface"),
                                 kCFBooleanFalse);
}

- (void)restoreEnhancedUserInterface {
    if (_enhancedUserInterfaceApplication == nil) return;

    AXUIElementSetAttributeValue(_enhancedUserInterfaceApplication,
                                 CFSTR("AXEnhancedUserInterface"),
                                 kCFBooleanTrue);

    CFRelease(_enhancedUserInterfaceApplication);
    _enhancedUserInterfaceApplication = nil;
}

- (void)dealloc {
    [self restoreEnhancedUserInterface];
    if (_window != nil) CFRelease(_window);
}

@end
