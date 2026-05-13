// Preferences can alternativevly be managed from the Terminal:
//   Read:
//     `defaults read org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Write:
//     `defaults write org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Note that deleting this preference or writing invalid keys may cause trouble and require that
//     you choose "Reset to Defaults from the app menu.
#ifndef EMRPreferences_h
#define EMRPreferences_h

#define SHOULD_BRING_WINDOW_TO_FRONT @"BringToFront"
#define SHOULD_MIDDLE_CLICK_RESIZE @"MiddleClickResize" // deprecated — used only for migration
#define RESIZE_ONLY @"ResizeOnly"
#define MODIFIER_FLAGS_DEFAULTS_KEY @"ModifierFlags"
#define RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY @"ResizeModifierFlags"
#define MOVE_MOUSE_BUTTON @"MoveMouseButton"
#define RESIZE_MOUSE_BUTTON @"ResizeMouseButton"
#define PREFERENCES_VERSION_KEY @"PreferencesVersion"
#define DISABLED_APPS_DEFAULTS_KEY @"DisabledApps"
#define CTRL_KEY @"CTRL"
#define SHIFT_KEY @"SHIFT"
#define CAPS_KEY @"CAPS" // CAPS lock
#define ALT_KEY @"ALT" // Alternate or Option key
#define CMD_KEY @"CMD"
#define FN_KEY @"FN"

// Mouse button values
enum {
    EMRMouseButtonLeft = 0,
    EMRMouseButtonRight = 1,
    EMRMouseButtonMiddle = 2
};

@interface EMRPreferences : NSObject {

}

@property (nonatomic) BOOL shouldBringWindowToFront;
@property (nonatomic) BOOL resizeOnly;

// Initialize an EMRPreferences, persisting settings to the given userDefaults
- (id)initWithUserDefaults:(NSUserDefaults *)defaults;

// Get the move modifier flags from preferences
- (int) modifierFlags;

// Set or unset the given move modifier key
- (void) setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;

// returns a set of the currently persisted move key constants
- (NSSet*) getFlagStringSet;

// Get the resize modifier flags from preferences
- (int) resizeModifierFlags;

// Set or unset the given resize modifier key
- (void) setResizeModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;

// returns a set of the currently persisted resize key constants
- (NSSet*) getResizeFlagStringSet;

// Mouse button preferences (EMRMouseButtonLeft/Right/Middle)
- (int) moveMouseButton;
- (void) setMoveMouseButton:(int)button;
- (int) resizeMouseButton;
- (void) setResizeMouseButton:(int)button;

// Returns YES if move and resize have identical button + modifier config
- (BOOL) hasConflictingConfig;

// returns a dict of disabled apps
- (NSDictionary*) getDisabledApps;

// add or remove an app from the disabled apps list
- (void) setDisabledForApp:(NSString*)bundleIdentifier withLocalizedName:(NSString*)localizedName disabled:(BOOL)disabled;

// reset preferences to the defaults
- (void)setToDefaults;

@end

#endif /* EMRPreferences_h */
