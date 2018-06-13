//
//  EMRPreferencesController.m
//  easy-move-resize
//
//  Created by Sven A. Schmidt on 13/06/2018.
//  Copyright © 2018 Daniel Marcotte. All rights reserved.
//

#import "EMRPreferencesController.h"

@interface EMRPreferencesController ()

@end

@implementation EMRPreferencesController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if (_prefs) {
        _altButton.state = NSOffState;
        _commandButton.state = NSOffState;
        _controlButton.state = NSOffState;
        _fnButton.state = NSOffState;
        _shiftButton.state = NSOffState;

        NSSet* flags = [_prefs getFlagStringSet];
        if ([flags containsObject:ALT_KEY]) {
            _altButton.state = NSOnState;
        }
        if ([flags containsObject:CMD_KEY]) {
            _commandButton.state = NSOnState;
        }
        if ([flags containsObject:CTRL_KEY]) {
            _controlButton.state = NSOnState;
        }
        if ([flags containsObject:FN_KEY]) {
            _fnButton.state = NSOnState;
        }
        if ([flags containsObject:SHIFT_KEY]) {
            _shiftButton.state = NSOnState;
        }

    }
}

@end
