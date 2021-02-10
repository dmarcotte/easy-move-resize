#import <Cocoa/Cocoa.h>

// these intervals feel good in experimentation, but maybe in the future we can measure how long
// the move and resize increments are actually taking and adjust them dynamically for each move/resize?
static const double kMoveFilterInterval = 0.02;
static const double kResizeFilterInterval = 0.04;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
}

- (int)modifierFlags;

- (void)initMenuItems;
- (IBAction)modifierToggle:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;
- (IBAction)toggleBringWindowToFront:(id)sender;

@property (weak) IBOutlet NSMenuItem *altMenu;
@property (weak) IBOutlet NSMenuItem *cmdMenu;
@property (weak) IBOutlet NSMenuItem *ctrlMenu;
@property (weak) IBOutlet NSMenuItem *shiftMenu;
@property (weak) IBOutlet NSMenuItem *disabledMenu;
@property (weak) IBOutlet NSMenuItem *bringWindowFrontMenu;
@property (weak) IBOutlet NSMenuItem *middleClickResizeMenu;
@property (nonatomic) BOOL sessionActive;

@end
