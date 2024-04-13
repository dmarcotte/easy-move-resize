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
#define SHOULD_MIDDLE_CLICK_RESIZE @"MiddleClickResize"
#define RESIZE_ONLY @"ResizeOnly"
#define MODIFIER_FLAGS_DEFAULTS_KEY @"ModifierFlags"
#define DISABLED_APPS_DEFAULTS_KEY @"DisabledApps"
#define CTRL_KEY @"CTRL"
#define SHIFT_KEY @"SHIFT"
#define CAPS_KEY @"CAPS" // CAPS lock
#define ALT_KEY @"ALT" // Alternate or Option key
#define CMD_KEY @"CMD"
#define FN_KEY @"FN"

@interface EMRPreferences : NSObject {
}

@property (nonatomic) BOOL shouldBringWindowToFront;
@property (nonatomic) BOOL shouldMiddleClickResize;
@property (nonatomic) BOOL resizeOnly;

// Initialize an EMRPreferences, persisting settings to the given userDefaults
- (id)initWithUserDefaults:(NSUserDefaults *)defaults;

// Get the modifier flags from the standard preferences
- (int)modifierFlags;

// Set or unset the given modifier key in the preferences
- (void)setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;

// returns a set of the currently persisted key constants
- (NSSet*)getFlagStringSet;

// returns a dict of disabled apps
- (NSDictionary*)getDisabledApps;

// add or remove an app from the disabled apps list
- (void)setDisabledForApp:(NSString*)bundleIdentifier withLocalizedName:(NSString*)localizedName disabled:(BOOL)disabled;

// reset preferences to the defaults
- (void)setToDefaults;

@end

#endif /* EMRPreferences_h */
