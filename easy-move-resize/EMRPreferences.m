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


// Private methods


+ (int)flagsFromFlagString:(NSString*)modifierFlagString {
    int modifierFlags = 0;
    if (modifierFlagString == nil || [modifierFlagString length] == 0) {
        return 0;
    }
    modifierFlagString = [[modifierFlagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    NSArray *flagList = [modifierFlagString componentsSeparatedByString:@","];
    
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

