#import "EMRPreferences.h"

#define DEFAULT_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl
#define DEFAULT_RESIZE_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl
#define CURRENT_PREFERENCES_VERSION 2

@implementation EMRPreferences {
@private
    NSUserDefaults *userDefaults;
}

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Must initialize with a NSUserDefaults pointer in -initWithUserDefaults"
                                 userInfo:nil];
    return nil;
}

- (id)initWithUserDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        userDefaults = defaults;
        NSString *modifierFlagString = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
        if (modifierFlagString == nil) {
            // ensure our defaults are initialized
            [self setToDefaults];
        }
        else {
            // disabledApps was added in an update, need to set if the app has been updated
            NSDictionary *disabledApps = [userDefaults dictionaryForKey:DISABLED_APPS_DEFAULTS_KEY];
            if (disabledApps == nil) {
                [userDefaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];
            }

            // Version-gated migration from v1 preferences
            NSInteger version = [userDefaults integerForKey:PREFERENCES_VERSION_KEY];
            if (version < CURRENT_PREFERENCES_VERSION) {
                // Migrate MiddleClickResize → ResizeMouseButton
                if ([userDefaults boolForKey:SHOULD_MIDDLE_CLICK_RESIZE]) {
                    [userDefaults setInteger:EMRMouseButtonMiddle forKey:RESIZE_MOUSE_BUTTON];
                }
                // Copy existing ModifierFlags as resize modifiers (preserves current behavior
                // where both operations use the same modifier set)
                NSString *existingFlags = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
                if (existingFlags != nil) {
                    [userDefaults setObject:existingFlags forKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
                }
                [userDefaults setInteger:CURRENT_PREFERENCES_VERSION forKey:PREFERENCES_VERSION_KEY];
            }
        }
    }
    return self;
}

#pragma mark - Move modifier flags

- (int)modifierFlags {
    NSString *modifierFlagString = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        return DEFAULT_MODIFIER_FLAGS;
    }
    return [self flagsFromFlagString:modifierFlagString];
}

- (void)setModifierFlagString:(NSString *)flagString {
    flagString = [[flagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    [userDefaults setObject:flagString forKey:MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setModifierKey:(NSString *)singleFlagString enabled:(BOOL)enabled {
    singleFlagString = [singleFlagString uppercaseString];
    NSString *modifierFlagString = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:modifierFlagString];
    if (enabled) {
        [flagSet addObject:singleFlagString];
    }
    else {
        [flagSet removeObject:singleFlagString];
    }
    [self setModifierFlagString:[[flagSet allObjects] componentsJoinedByString:@","]];
}

- (NSSet*)getFlagStringSet {
    NSString *modifierFlagString = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:modifierFlagString];
    return flagSet;
}

#pragma mark - Resize modifier flags

- (int)resizeModifierFlags {
    NSString *flagString = [userDefaults stringForKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
    if (flagString == nil) {
        return DEFAULT_RESIZE_MODIFIER_FLAGS;
    }
    return [self flagsFromFlagString:flagString];
}

- (void)setResizeModifierFlagString:(NSString *)flagString {
    flagString = [[flagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    [userDefaults setObject:flagString forKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setResizeModifierKey:(NSString *)singleFlagString enabled:(BOOL)enabled {
    singleFlagString = [singleFlagString uppercaseString];
    NSString *flagString = [userDefaults stringForKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
    if (flagString == nil) {
        NSLog(@"Unexpected null for resize modifier flags");
        flagString = [@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:flagString];
    if (enabled) {
        [flagSet addObject:singleFlagString];
    }
    else {
        [flagSet removeObject:singleFlagString];
    }
    [self setResizeModifierFlagString:[[flagSet allObjects] componentsJoinedByString:@","]];
}

- (NSSet*)getResizeFlagStringSet {
    NSString *flagString = [userDefaults stringForKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
    if (flagString == nil) {
        NSLog(@"Unexpected null for resize modifier flags");
        flagString = [@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","];
    }
    return [self createSetFromFlagString:flagString];
}

#pragma mark - Mouse button preferences

- (int)moveMouseButton {
    // Default: Left (0). NSUserDefaults returns 0 for unset integer keys,
    // which conveniently matches EMRMouseButtonLeft.
    return (int)[userDefaults integerForKey:MOVE_MOUSE_BUTTON];
}

- (void)setMoveMouseButton:(int)button {
    [userDefaults setInteger:button forKey:MOVE_MOUSE_BUTTON];
}

- (int)resizeMouseButton {
    // Default: Right (1). We can't rely on 0-default here, so check if key exists.
    if ([userDefaults objectForKey:RESIZE_MOUSE_BUTTON] == nil) {
        return EMRMouseButtonRight;
    }
    return (int)[userDefaults integerForKey:RESIZE_MOUSE_BUTTON];
}

- (void)setResizeMouseButton:(int)button {
    [userDefaults setInteger:button forKey:RESIZE_MOUSE_BUTTON];
}

#pragma mark - Conflict validation

- (BOOL)hasConflictingConfig {
    if ([self moveMouseButton] != [self resizeMouseButton]) return NO;
    return [self modifierFlags] == [self resizeModifierFlags];
}

#pragma mark - Disabled apps

- (NSDictionary*) getDisabledApps {
    return [userDefaults dictionaryForKey:DISABLED_APPS_DEFAULTS_KEY];
}

- (void) setDisabledForApp:(NSString*)bundleIdentifier withLocalizedName:(NSString*)localizedName disabled:(BOOL)disabled {    NSMutableDictionary *disabledApps = [[self getDisabledApps] mutableCopy];
    if (disabled) {
        [disabledApps setObject:localizedName forKey:bundleIdentifier];
    }
    else {
        [disabledApps removeObjectForKey:bundleIdentifier];
    }
    [userDefaults setObject:disabledApps forKey:DISABLED_APPS_DEFAULTS_KEY];
}

#pragma mark - Defaults

- (void)setToDefaults {
    [self setModifierFlagString:[@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","]];
    [self setResizeModifierFlagString:[@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","]];
    [userDefaults setBool:NO forKey:SHOULD_BRING_WINDOW_TO_FRONT];
    [userDefaults setBool:NO forKey:RESIZE_ONLY];
    [userDefaults setInteger:EMRMouseButtonLeft forKey:MOVE_MOUSE_BUTTON];
    [userDefaults setInteger:EMRMouseButtonRight forKey:RESIZE_MOUSE_BUTTON];
    [userDefaults setInteger:CURRENT_PREFERENCES_VERSION forKey:PREFERENCES_VERSION_KEY];
    [userDefaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];
}

#pragma mark - Flag string utilities

- (NSMutableSet*)createSetFromFlagString:(NSString*)modifierFlagString {
    modifierFlagString = [[modifierFlagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    if ([modifierFlagString length] == 0) {
        return [[NSMutableSet alloc] initWithCapacity:0];
    }
    NSArray *flagList = [modifierFlagString componentsSeparatedByString:@","];
    NSMutableSet *flagSet = [[NSMutableSet alloc] initWithArray:flagList];
    return flagSet;
}

- (int)flagsFromFlagString:(NSString*)modifierFlagString {
    int modifierFlags = 0;
    if (modifierFlagString == nil || [modifierFlagString length] == 0) {
        return 0;
    }
    NSSet *flagList = [self createSetFromFlagString:modifierFlagString];

    if ([flagList containsObject:CTRL_KEY]) {
        modifierFlags |= kCGEventFlagMaskControl;
    }
    if ([flagList containsObject:SHIFT_KEY]) {
        modifierFlags |= kCGEventFlagMaskShift;
    }
    if ([flagList containsObject:CAPS_KEY]) {
        modifierFlags |= kCGEventFlagMaskAlphaShift;
    }
    if ([flagList containsObject:ALT_KEY]) {
        modifierFlags |= kCGEventFlagMaskAlternate;
    }
    if ([flagList containsObject:CMD_KEY]) {
        modifierFlags |= kCGEventFlagMaskCommand;
    }
    if ([flagList containsObject:FN_KEY]) {
        modifierFlags |= kCGEventFlagMaskSecondaryFn;
    }

    return modifierFlags;
}

#pragma mark - Boolean preferences

-(BOOL)shouldBringWindowToFront {
    return [userDefaults boolForKey:SHOULD_BRING_WINDOW_TO_FRONT];
}
-(void)setShouldBringWindowToFront:(BOOL)bringToFront {
    [userDefaults setBool:bringToFront forKey:SHOULD_BRING_WINDOW_TO_FRONT];
}

-(BOOL)resizeOnly {
    return [userDefaults boolForKey:RESIZE_ONLY];
}
-(void)setResizeOnly:(BOOL)resizeOnly {
    [userDefaults setBool:resizeOnly forKey:RESIZE_ONLY];
}

@end
