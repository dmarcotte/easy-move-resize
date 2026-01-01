#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

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

typedef NS_ENUM(NSInteger, EMRTileZone) {
    EMRTileZoneNone = 0,
    EMRTileZoneLeftHalf,
    EMRTileZoneRightHalf,
    EMRTileZoneMaximize,
    EMRTileZoneTopLeftQuarter,
    EMRTileZoneTopRightQuarter,
    EMRTileZoneBottomLeftQuarter,
    EMRTileZoneBottomRightQuarter
};

@interface EMRMoveResize : NSObject {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
    struct ResizeSection _resizeSection;
    AXUIElementRef _window;
    CFTimeInterval _tracking;
    NSPoint _wndPosition;
    NSSize _wndSize;
    EMRTileZone _currentTileZone;
    NSWindow *_tilePreviewWindow;
    NSRect _preTileFrame;
    BOOL _isWindowTiled;
}

+ (id) instance;

@property CFMachPortRef eventTap;
@property CFRunLoopSourceRef runLoopSource;
@property struct ResizeSection resizeSection;
@property AXUIElementRef window;
@property CFTimeInterval tracking;
@property NSPoint wndPosition;
@property NSSize wndSize;
@property EMRTileZone currentTileZone;
@property (strong) NSWindow *tilePreviewWindow;
@property NSRect preTileFrame;
@property BOOL isWindowTiled;

@end
