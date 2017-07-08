//
//  EMRPreferences.h
//  easy-move-resize
//
//  Created by Rajpaul Bagga on 2016-01-21.
//
// Preferences can be stored manually by running from Terminal a command like:
// defaults write org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL


#ifndef EMRPreferences_h
#define EMRPreferences_h

#define MODIFIER_FLAGS_DEFAULTS_KEY @"ModifierFlags"
#define USE_MOUSE_MOVE_DEFAULTS_KEY @"UseMouseMove"
#define CTRL_KEY @"CTRL"
#define SHIFT_KEY @"SHIFT"
#define CAPS_KEY @"CAPS" // CAPS lock
#define ALT_KEY @"ALT" // Alternate or Option key
#define CMD_KEY @"CMD"

@interface EMRPreferences : NSObject {
    
}

// Get the modifier flags from the standard preferences
+ (int) modifierFlags;
+ (BOOL) useMouseMove;
// Store a modifier flag string in the preferences. (e.g. "CTRL,CMD"
+ (void) setModifierFlagString:(NSString*)flagString;
+ (void) setUseMouseMove:(BOOL)enabled;

+ (void) setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;
+ (NSSet*) getFlagStringSet;

+ (void) removeDefaults;

@end

#endif /* EMRPreferences_h */
