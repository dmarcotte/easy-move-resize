// Standalone checks for EMRCopyWindowAtPoint. Run with scripts/test-window-lookup.sh.
// AX elements are faked with NSDictionaries and the window list is simulated, so no
// real windows are read or moved. Only window lookup is exercised here.
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <assert.h>

static NSDictionary *hitElement;           // result of the AX hit test (nil = hit test fails)
static NSArray *screenWindows;             // simulated CGWindowList, front to back
static NSDictionary *applicationWindows;   // pid -> AXWindows

static CFTypeID TestElementTypeID(void) { return CFDictionaryGetTypeID(); }
static AXError TestGetPid(AXUIElementRef element, pid_t *pid) {
    *pid = [((__bridge NSDictionary *)element)[@"pid"] intValue];
    return kAXErrorSuccess;
}
static AXUIElementRef TestCreateSystemWide(void) { return (AXUIElementRef)CFBridgingRetain(@{}); }
static AXUIElementRef TestCreateApp(pid_t pid) {
    return (AXUIElementRef)CFBridgingRetain(@{@"pid": @(pid),
        (__bridge NSString *)kAXWindowsAttribute: applicationWindows[@(pid)] ?: @[]});
}
static AXError TestHit(AXUIElementRef system, float x, float y, AXUIElementRef *result) {
    *result = hitElement ? (AXUIElementRef)CFBridgingRetain(hitElement) : NULL;
    return hitElement ? kAXErrorSuccess : kAXErrorNotImplemented;
}
static AXError TestCopy(AXUIElementRef element, CFStringRef attribute, CFTypeRef *result) {
    id value = ((__bridge NSDictionary *)element)[(__bridge NSString *)attribute];
    *result = value ? CFBridgingRetain(value) : NULL;
    return value ? kAXErrorSuccess : kAXErrorAttributeUnsupported;
}
static CFArrayRef TestWindowList(CGWindowListOption options, CGWindowID relativeTo) {
    return (CFArrayRef)CFBridgingRetain(screenWindows ?: @[]);
}
#define AXUIElementGetTypeID TestElementTypeID
#define AXUIElementGetPid TestGetPid
#define AXUIElementCreateSystemWide TestCreateSystemWide
#define AXUIElementCreateApplication TestCreateApp
#define AXUIElementCopyElementAtPosition TestHit
#define AXUIElementCopyAttributeValue TestCopy
#define CGWindowListCopyWindowInfo TestWindowList
#import "../easy-move-resize/EMRAppDelegate.m"

static NSDictionary *Window(pid_t pid, CGRect frame) {
    CGPoint origin = frame.origin;
    CGSize size = frame.size;
    return @{@"pid": @(pid), (__bridge NSString *)kAXRoleAttribute: (__bridge NSString *)kAXWindowRole,
             (__bridge NSString *)kAXPositionAttribute: CFBridgingRelease(AXValueCreate(kAXValueCGPointType, &origin)),
             (__bridge NSString *)kAXSizeAttribute: CFBridgingRelease(AXValueCreate(kAXValueCGSizeType, &size))};
}
static NSDictionary *CGWindow(pid_t pid, int layer, CGRect frame) {
    return @{(__bridge NSString *)kCGWindowOwnerPID: @(pid), (__bridge NSString *)kCGWindowLayer: @(layer),
             (__bridge NSString *)kCGWindowBounds: CFBridgingRelease(CGRectCreateDictionaryRepresentation(frame))};
}
static NSDictionary *Lookup(void) {
    return CFBridgingRelease(EMRCopyWindowAtPoint(CGPointMake(30, 40)));
}

int main(void) {
    @autoreleasepool {
        // The Dock exception checks the owner's bundle ID, so use the real Dock's PID.
        pid_t dockPid = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dock"]
            .firstObject.processIdentifier;
        assert(dockPid > 0 && "run these checks in a logged-in session with the Dock running");
        int dockLayer = CGWindowLevelForKey(kCGDockWindowLevelKey);
        CGRect frame = CGRectMake(10, 20, 300, 200);
        NSDictionary *window = Window(42, frame);
        NSDictionary *qtAppElement = @{@"pid": @42}; // hit element with no window ancestor
        NSDictionary *dockElement = @{@"pid": @(dockPid)};
        NSDictionary *dockBacking = CGWindow(dockPid, dockLayer, CGRectMake(0, 0, 1920, 1080));

        // Direct AX paths: hit element is the window, has AXWindow, or an ancestor has it.
        hitElement = window;
        assert([Lookup() isEqual:window]);
        hitElement = @{@"pid": @42, (__bridge NSString *)kAXWindowAttribute: window};
        assert([Lookup() isEqual:window]);
        hitElement = @{@"pid": @42, (__bridge NSString *)kAXParentAttribute: @{(__bridge NSString *)kAXParentAttribute: window}};
        assert([Lookup() isEqual:window]);

        // Parent traversal is bounded (also guards against cyclic hierarchies).
        NSDictionary *deep = window;
        for (int i = 0; i < 12; ++i) deep = @{(__bridge NSString *)kAXParentAttribute: deep};
        hitElement = deep;
        assert(!Lookup());

        // Fallback (WeChat/Telegram blank area): the full-screen Dock backing window is
        // skipped and the app's AX window is matched by frame, not just by being first.
        screenWindows = @[dockBacking, CGWindow(42, 0, frame)];
        applicationWindows = @{@42: @[Window(42, CGRectMake(500, 20, 300, 200)), window]};
        hitElement = qtAppElement;
        assert([Lookup() isEqual:window]);
        hitElement = nil; // hit test fails entirely
        assert([Lookup() isEqual:window]);

        // Clicking the Dock (or any other app's element) never moves the window behind it.
        hitElement = dockElement;
        assert(!Lookup());

        // Any other window in front of the normal window blocks the fallback, whether the
        // overlay's hit test fails or the overlay belongs to the same app.
        applicationWindows = @{@42: @[window]};
        screenWindows = @[CGWindow(99, 101, frame), CGWindow(42, 0, frame)];
        hitElement = nil;
        assert(!Lookup());
        screenWindows = @[CGWindow(42, 101, frame), CGWindow(42, 0, frame)];
        hitElement = qtAppElement;
        assert(!Lookup());
        screenWindows = @[CGWindow(dockPid, 101, frame), CGWindow(42, 0, frame)]; // e.g. a Dock menu
        hitElement = nil;
        assert(!Lookup());

        // Ambiguous or mismatched frames cancel.
        screenWindows = @[CGWindow(42, 0, frame)];
        hitElement = qtAppElement;
        applicationWindows = @{@42: @[window, Window(42, frame)]};
        assert(!Lookup());
        applicationWindows = @{@42: @[Window(42, CGRectMake(10, 20, 400, 200))]};
        assert(!Lookup());

        puts("Window lookup checks passed.");
    }
    return 0;
}
