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
        // FIXME: handle click vs hover mode radio button

        _altHoverMoveButton.state = NSOffState;
        _commandHoverMoveButton.state = NSOffState;
        _controlHoverMoveButton.state = NSOffState;
        _fnHoverMoveButton.state = NSOffState;
        _shiftHoverMoveButton.state = NSOffState;

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:click];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altClickButton,
                                           CMD_KEY: _commandClickButton,
                                           CTRL_KEY: _controlClickButton,
                                           FN_KEY: _fnClickButton,
                                           SHIFT_KEY: _shiftClickButton
                                  };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:hoverMove];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altHoverMoveButton,
                                           CMD_KEY: _commandHoverMoveButton,
                                           CTRL_KEY: _controlHoverMoveButton,
                                           FN_KEY: _fnHoverMoveButton,
                                           SHIFT_KEY: _shiftHoverMoveButton
                                           };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

        {
            NSSet* flags = [_prefs getFlagStringSetForFlagSet:hoverResize];
            NSDictionary *keyButtonMap = @{
                                           ALT_KEY: _altHoverMoveButton,
                                           CMD_KEY: _commandHoverResizeButton,
                                           CTRL_KEY: _controlHoverResizeButton,
                                           FN_KEY: _fnHoverResizeButton,
                                           SHIFT_KEY: _shiftHoverResizeButton
                                           };
            for (NSString *key in keyButtonMap) {
                NSButton *button = keyButtonMap[key];
                button.state = [flags containsObject:key] ? NSOnState : NSOffState;
            }
        }

    }
}

@end
