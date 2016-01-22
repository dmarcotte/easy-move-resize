#import <Cocoa/Cocoa.h>

static const int kMoveFilterInterval = 2;
static const int kResizeFilterInterval = 4;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
}

- (int)modifierFlags;
- (BOOL)disabled;

- (void)initModifierMenuItems;
- (IBAction)modifierToggle:(id)sender;
- (IBAction)resetModifiersToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;

@property (weak) IBOutlet NSMenuItem *altMenu;
@property (weak) IBOutlet NSMenuItem *cmdMenu;
@property (weak) IBOutlet NSMenuItem *ctrlMenu;
@property (weak) IBOutlet NSMenuItem *shiftMenu;
@property (weak) IBOutlet NSMenuItem *disabledMenu;

@end
