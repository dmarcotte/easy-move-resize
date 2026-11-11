#import <Foundation/Foundation.h>

enum ResizeDirectionX {
    right,
    left,
    noX
};

enum ResizeSectionY {
    top,
    bottom,
    noY
};

struct ResizeSection {
    enum ResizeDirectionX xResizeDirection;
    enum ResizeSectionY yResizeDirection;
};

@interface EMRMoveResize : NSObject {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
    struct ResizeSection _resizeSection;
    AXUIElementRef _window;
    CFTimeInterval _tracking;
    NSPoint _wndPosition;
    NSSize _wndSize;
    CGEventRef _pendingMouseDown;
    CGPoint _mouseDownLocation;
    BOOL _dragStarted;
}

+ (id) instance;

@property CFMachPortRef eventTap;
@property CFRunLoopSourceRef runLoopSource;
@property struct ResizeSection resizeSection;
@property AXUIElementRef window;
@property CFTimeInterval tracking;
@property NSPoint wndPosition;
@property NSSize wndSize;
// Pass Through Clicks: copy of the held-back mouse-down, replayed if the button is released without dragging
@property CGEventRef pendingMouseDown;
@property CGPoint mouseDownLocation;
@property BOOL dragStarted;

@end
