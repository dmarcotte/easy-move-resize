// Preferences can alternativevly be managed from the Terminal:
//   Read:
//     `defaults write org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Write:
//     `defaults write org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Note that deleting this preference or writing invalid keys may cause trouble and require that
//     you choose "Reset to Defaults from the app menu.
#ifndef EMRPreferences_h
#define EMRPreferences_h

#define MODIFIER_CLICK_FLAGS_DEFAULTS_KEY @"ModifierFlags"
#define MODIFIER_HOVER_MOVE_FLAGS_DEFAULTS_KEY @"HoverMoveModifierFlags"
#define MODIFIER_HOVER_RESIZE_FLAGS_DEFAULTS_KEY @"HoverResizeModifierFlags"
#define EMR_MODE_DEFAULTS_KEY @"EMRMode"
#define CTRL_KEY @"CTRL"
#define SHIFT_KEY @"SHIFT"
#define CAPS_KEY @"CAPS" // CAPS lock
#define ALT_KEY @"ALT" // Alternate or Option key
#define CMD_KEY @"CMD"
#define FN_KEY @"FN"


typedef enum : NSUInteger {
    clickMode,
    hoverMode
} EMRMode;


typedef enum : NSUInteger {
    clickFlags,
    hoverMoveFlags,
    hoverResizeFlags,
} FlagSet;

@interface EMRPreferences : NSObject {
    
}

// Initialize an EMRPreferences, persisting settings to the given userDefaults
- (id)initWithUserDefaults:(NSUserDefaults *)defaults;

// Get the modifier flags from the standard preferences for a given set
- (int)modifierFlagsForFlagSet:(FlagSet)flagSet;

// Set or unset the given modifier key in the preferences
- (void) setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled flagSet:(FlagSet)flagSet;

// returns a set of the currently persisted key constants
- (NSSet*) getFlagStringSetForFlagSet:(FlagSet)flagSet;

// returns EMR mode - click or hover
- (EMRMode)mode;

// set EMR mode
- (void)setMode:(EMRMode)mode;

// reset preferences to the defaults
- (void)setToDefaults;

@end

#endif /* EMRPreferences_h */
