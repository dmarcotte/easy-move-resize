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

@end
