#import <Cocoa/Cocoa.h>

static const int kMoveFilterInterval = 2;
static const int kResizeFilterInterval = 4;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
}

- (void)initModifierMenuItems;
- (IBAction)modifierToggle:(id)sender;
- (IBAction)resetModifiersToDefaults:(id)sender;

@property (weak) IBOutlet NSMenuItem *altMenu;
@property (weak) IBOutlet NSMenuItem *cmdMenu;
@property (weak) IBOutlet NSMenuItem *ctrlMenu;
@property (weak) IBOutlet NSMenuItem *shiftMenu;

@end
