//
//  EMRPreferences.m
//  easy-move-resize
//
//  Created by Rajpaul Bagga on 2016-01-21.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "EMRPreferences.h"

#define DEFAULT_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl

@implementation EMRPreferences

+ (int)modifierFlags {
    int modifierFlags = 0;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *modifierFlagString = [defaults stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        return DEFAULT_MODIFIER_FLAGS;
    }
    
    modifierFlags = [self flagsFromFlagString:modifierFlagString];
    
    return modifierFlags;
}

+ (void)setModifierFlagString:(NSString *)flagString {
    flagString = [[flagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    [[NSUserDefaults standardUserDefaults] setObject:flagString forKey:MODIFIER_FLAGS_DEFAULTS_KEY];
}


+ (void)setModifierKey:(NSString *)singleFlagString enabled:(BOOL)enabled {
    singleFlagString = [singleFlagString uppercaseString];
    NSString *modifierFlagString = [[NSUserDefaults standardUserDefaults] stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        // No prior value set. Set if enabled.
        if (enabled) {
            [self setModifierFlagString:singleFlagString];
            return;
        }
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

+ (NSSet*)getFlagStringSet {
    NSString *modifierFlagString = [[NSUserDefaults standardUserDefaults] stringForKey:MODIFIER_FLAGS_DEFAULTS_KEY];
    if (modifierFlagString == nil) {
        return [NSSet setWithObjects:CTRL_KEY, CMD_KEY, nil];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:modifierFlagString];
    return flagSet;
}

// --------------------------------------------------------------------
// Private methods

+ (NSMutableSet*)createSetFromFlagString:(NSString*)modifierFlagString {
    modifierFlagString = [[modifierFlagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    if ([modifierFlagString length] == 0) {
        return [[NSMutableSet alloc] initWithCapacity:0];
    }
    NSArray *flagList = [modifierFlagString componentsSeparatedByString:@","];
    NSMutableSet *flagSet = [[NSMutableSet alloc] initWithArray:flagList];
    return flagSet;
}


+ (int)flagsFromFlagString:(NSString*)modifierFlagString {
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
@end

