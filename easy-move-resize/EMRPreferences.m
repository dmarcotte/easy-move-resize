#import "EMRPreferences.h"

#define DEFAULT_CLICK_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl


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
        for (NSString *key in @[MODIFIER_CLICK_FLAGS_DEFAULTS_KEY, MODIFIER_HOVER_MOVE_FLAGS_DEFAULTS_KEY, MODIFIER_HOVER_RESIZE_FLAGS_DEFAULTS_KEY]) {
            NSString *modifierFlagString = [userDefaults stringForKey:key];
            if (modifierFlagString == nil) {
                // ensure our defaults are initialized
                [self setToDefaultsForKey:key];
            }
        }
    }
    return self;
}

- (NSString *)keyForFlagSet:(ModifierFlags)flagSet {
    switch (flagSet) {
        case click:
            return MODIFIER_CLICK_FLAGS_DEFAULTS_KEY;
            break;

        case hoverMove:
            return MODIFIER_HOVER_MOVE_FLAGS_DEFAULTS_KEY;
            break;

        case hoverResize:
            return MODIFIER_HOVER_RESIZE_FLAGS_DEFAULTS_KEY;
            break;

        default:
            // must not reach this
            assert(false);
            break;
    }
}

- (NSArray *)modifierDefaultsForKey:(NSString *)key {
    NSDictionary* modifierDefaults = @{
                                       MODIFIER_CLICK_FLAGS_DEFAULTS_KEY: @[CTRL_KEY, CMD_KEY],
                                       MODIFIER_HOVER_MOVE_FLAGS_DEFAULTS_KEY: @[CTRL_KEY, ALT_KEY],
                                       MODIFIER_HOVER_RESIZE_FLAGS_DEFAULTS_KEY: @[CTRL_KEY, ALT_KEY, CMD_KEY]
                                       };
    return modifierDefaults[key];
}

- (NSString *)flagStringForFlags:(NSArray *)flags {
    return [flags componentsJoinedByString:@","];
}

- (int)modifierFlagsForFlagSet:(ModifierFlags)flagSet {
    NSString *key = [self keyForFlagSet:flagSet];
    int modifierFlags = 0;

    NSString *modifierFlagString = [userDefaults stringForKey:key];
    if (modifierFlagString == nil) {
        NSArray *defaults = [self modifierDefaultsForKey:key];
        modifierFlagString = [self flagStringForFlags:defaults];
    }

    modifierFlags = [self flagsFromFlagString:modifierFlagString];

    return modifierFlags;
}

- (void)setModifierFlagString:(NSString *)flagString forKey:(NSString *)key {
    flagString = [[flagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    [userDefaults setObject:flagString forKey:key];
}


- (void) setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled flagSet:(ModifierFlags)flagSet {
    singleFlagString = [singleFlagString uppercaseString];
    NSString *key = [self keyForFlagSet:flagSet];
    NSString *modifierFlagString = [userDefaults stringForKey:key];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaultsForKey:key];
    }
    NSMutableSet *flags = [self createSetFromFlagString:modifierFlagString];
    if (enabled) {
        [flags addObject:singleFlagString];
    }
    else {
        [flags removeObject:singleFlagString];
    }
    [self setModifierFlagString:[[flags allObjects] componentsJoinedByString:@","] forKey:key];
}



- (NSSet*)getFlagStringSetForFlagSet:(ModifierFlags)flagSet {
    NSString *key = [self keyForFlagSet:flagSet];
    NSString *modifierFlagString = [userDefaults stringForKey:key];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaultsForKey:key];
    }
    NSMutableSet *flags = [self createSetFromFlagString:modifierFlagString];
    return flags;
}

//- (NSSet*)getClickFlagStringSet {
//    return [self getFlagStringSetForFlagSet:click];
//}
//
//- (NSSet*) getHoverMoveFlagStringSet {
//    return [self getFlagStringSetForFlagSet:hoverMove];
//}
//
//- (NSSet*) getHoverResizeFlagStringSet {
//    return [self getFlagStringSetForFlagSet:hoverResize];
//}


- (void)setToDefaultsForKey:(NSString *)key {
    NSArray *flags = [self modifierDefaultsForKey:key];
    NSString *flagString = [self flagStringForFlags:flags];
    [self setModifierFlagString:flagString forKey:key];
}

- (void)setToDefaults {
    for (NSString *key in @[MODIFIER_CLICK_FLAGS_DEFAULTS_KEY, MODIFIER_HOVER_MOVE_FLAGS_DEFAULTS_KEY, MODIFIER_HOVER_RESIZE_FLAGS_DEFAULTS_KEY]) {
        [self setToDefaultsForKey:key];
    }
}


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
@end

