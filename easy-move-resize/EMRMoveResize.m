#import "EMRMoveResize.h"

@implementation EMRMoveResize
@synthesize eventTap = _eventTap;
@synthesize resizeSection = _resizeSection;
@synthesize window = _window;
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

- (AXUIElementRef)window {
    return _window;
}

- (void)setWindow:(AXUIElementRef)window {
    if (_window != nil) CFRelease(_window);
    if (window != nil) CFRetain(window);
    _window = window;
}

- (void)dealloc {
    if (_window != nil) CFRelease(_window);
}

@end
