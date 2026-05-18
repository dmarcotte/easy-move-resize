#import <Foundation/Foundation.h>
#import <CoreVideo/CVDisplayLink.h>
#import <os/lock.h>

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

typedef enum {
    EMROperationNone,
    EMROperationMove,
    EMROperationResize
} EMROperationType;

typedef struct {
    NSPoint              position;
    NSSize               size;
    EMROperationType     operation;
    struct ResizeSection  resizeSection;
    BOOL                 dirty;
    AXUIElementRef       window;
} EMRDisplayState;

@interface EMRMoveResize : NSObject {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
    struct ResizeSection _resizeSection;
    AXUIElementRef _window;
    CFTimeInterval _tracking;
    NSPoint _wndPosition;
    NSSize _wndSize;

    CVDisplayLinkRef _displayLink;
    os_unfair_lock _displayStateLock;
    EMRDisplayState _displayState;
}

+ (id) instance;

@property CFMachPortRef eventTap;
@property CFRunLoopSourceRef runLoopSource;
@property struct ResizeSection resizeSection;
@property AXUIElementRef window;
@property CFTimeInterval tracking;
@property NSPoint wndPosition;
@property NSSize wndSize;

- (void)setupDisplayLink;
- (void)startDisplayLink;
- (void)stopDisplayLink;
- (void)updatePosition:(NSPoint)position;
- (void)updatePositionAndSize:(NSPoint)position size:(NSSize)size resizeSection:(struct ResizeSection)resizeSection;
- (void)applyPendingChanges;

@end
