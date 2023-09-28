#import <Cocoa/Cocoa.h>

// 100hz: refresh every 10ms. Seems like a reasonable default value.
static const double kMoveFilterInterval = 0.01;
static const double kResizeFilterInterval = 0.01;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
    NSRunningApplication *lastApp;
}

- (int)modifierFlags;

- (void)initMenuItems;
- (IBAction)modifierToggle:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;
- (IBAction)toggleBringWindowToFront:(id)sender;
- (IBAction)disableLastApp:(id)sender;
- (IBAction)enableDisabledApp:(id)sender;

@property (weak) IBOutlet NSMenuItem *altMenu;
@property (weak) IBOutlet NSMenuItem *cmdMenu;
@property (weak) IBOutlet NSMenuItem *ctrlMenu;
@property (weak) IBOutlet NSMenuItem *shiftMenu;
@property (weak) IBOutlet NSMenuItem *fnMenu;
@property (weak) IBOutlet NSMenuItem *disabledMenu;
@property (weak) IBOutlet NSMenuItem *bringWindowFrontMenu;
@property (weak) IBOutlet NSMenuItem *middleClickResizeMenu;
@property (weak) IBOutlet NSMenuItem *resizeOnlyMenu;
@property (weak) IBOutlet NSMenuItem *disabledAppsMenu;
@property (weak) IBOutlet NSMenuItem *lastAppMenu;
@property (nonatomic) BOOL sessionActive;

@end
