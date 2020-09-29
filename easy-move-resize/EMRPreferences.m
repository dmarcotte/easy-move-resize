#import "EMRPreferences.h"

#define DEFAULT_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl

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
    }
    return self;
}

- (int)modifierFlags {
    int modifierFlags = 0;
    
    NSString *modifierFlagString = [userDefaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        return DEFAULT_MODIFIER_FLAGS;
    }
    
    modifierFlags = [self flagsFromFlagString:modifierFlagString];
    
    return modifierFlags;
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

- (void)setToDefaults {
    [self setModifierFlagString:[@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","]];
    [userDefaults setBool:NO forKey:SHOULD_BRING_WINDOW_TO_FRONT];
    [userDefaults setBool:NO forKey:SHOULD_MIDDLE_CLICK_RESIZE];
    [userDefaults setBool:NO forKey:SHOULD_BE_DISABLED];
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
    
    return modifierFlags;
}

-(BOOL)shouldBringWindowToFront {
    return [userDefaults boolForKey:SHOULD_BRING_WINDOW_TO_FRONT];
}
-(void)setShouldBringWindowToFront:(BOOL)bringToFront {
    [userDefaults setBool:bringToFront forKey:SHOULD_BRING_WINDOW_TO_FRONT];
}

-(BOOL)shouldMiddleClickResize {
    return [userDefaults boolForKey:SHOULD_MIDDLE_CLICK_RESIZE];
}
-(void)setShouldMiddleClickResize:(BOOL)middleClickResize {
    [userDefaults setBool:middleClickResize forKey:SHOULD_MIDDLE_CLICK_RESIZE];
}

-(BOOL)shouldBeDisabled {
    return [userDefaults boolForKey:SHOULD_BE_DISABLED];
}
-(void)setShouldBeDisabled:(BOOL)disabled {
    [userDefaults setBool:disabled forKey:SHOULD_BE_DISABLED];
}
@end

