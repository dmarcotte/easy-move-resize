#import <Cocoa/Cocoa.h>

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    int keyModifierFlags;
    int resizeKeyModifierFlags;
    int cachedMoveMouseButton;
    int cachedResizeMouseButton;
    BOOL cachedHasConflict;
    NSRunningApplication *lastApp;

    // Programmatic menu items — Move section
    NSMenuItem *moveAltMenu;
    NSMenuItem *moveCmdMenu;
    NSMenuItem *moveCtrlMenu;
    NSMenuItem *moveShiftMenu;
    NSMenuItem *moveFnMenu;
    NSMenuItem *moveMouseButtonLeftMenu;
    NSMenuItem *moveMouseButtonRightMenu;
    NSMenuItem *moveMouseButtonMiddleMenu;

    // Programmatic menu items — Resize section
    NSMenuItem *resizeAltMenu;
    NSMenuItem *resizeCmdMenu;
    NSMenuItem *resizeCtrlMenu;
    NSMenuItem *resizeShiftMenu;
    NSMenuItem *resizeFnMenu;
    NSMenuItem *resizeMouseButtonLeftMenu;
    NSMenuItem *resizeMouseButtonRightMenu;
    NSMenuItem *resizeMouseButtonMiddleMenu;

    // Programmatic menu items — other
    NSMenuItem *conflictWarningMenu;
}

- (int)modifierFlags;
- (int)resizeModifierFlags;
- (int)moveMouseButton;
- (int)resizeMouseButton;

- (IBAction)modifierToggle:(id)sender;
- (IBAction)resizeModifierToggle:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;
- (IBAction)toggleBringWindowToFront:(id)sender;
- (IBAction)toggleResizeOnly:(id)sender;
- (IBAction)setMoveMouseButton:(id)sender;
- (IBAction)setResizeMouseButton:(id)sender;
- (IBAction)disableLastApp:(id)sender;
- (IBAction)enableDisabledApp:(id)sender;

// XIB-wired outlets — kept for items that remain in the XIB
@property (weak) IBOutlet NSMenuItem *disabledMenu;
@property (weak) IBOutlet NSMenuItem *bringWindowFrontMenu;
@property (weak) IBOutlet NSMenuItem *resizeOnlyMenu;
@property (weak) IBOutlet NSMenuItem *disabledAppsMenu;
@property (weak) IBOutlet NSMenuItem *lastAppMenu;
@property (nonatomic) BOOL sessionActive;
@property float moveFilterInterval;
@property float resizeFilterInterval;

@end
