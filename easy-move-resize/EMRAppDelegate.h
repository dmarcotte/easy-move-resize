#import <Cocoa/Cocoa.h>

// these intervals feel good in experimentation, but maybe in the future we can measure how long
// the move and resize increments are actually taking and adjust them dynamically for each move/resize?
static const double kMoveFilterInterval = 0.01;
static const double kResizeFilterInterval = 0.02;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
}

- (int)modifierFlags;

- (IBAction)toggleDisabled:(id)sender;
- (IBAction)showPreferences:(id)sender;

@property (weak) IBOutlet NSMenuItem *disabledMenu;

@end
