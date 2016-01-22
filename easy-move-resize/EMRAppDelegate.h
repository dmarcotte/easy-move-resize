#import <Cocoa/Cocoa.h>

static const int kMoveFilterInterval = 2;
static const int kResizeFilterInterval = 4;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
}

@end
