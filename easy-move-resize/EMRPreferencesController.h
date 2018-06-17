//
//  EMRPreferencesController.h
//  easy-move-resize
//
//  Created by Sven A. Schmidt on 13/06/2018.
//  Copyright © 2018 Daniel Marcotte. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EMRPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMRPreferencesController : NSWindowController {
    EMRPreferences *_prefs;
}

@property EMRPreferences *prefs;

@property (weak) IBOutlet NSButton *altClickButton;
@property (weak) IBOutlet NSButton *commandClickButton;
@property (weak) IBOutlet NSButton *controlClickButton;
@property (weak) IBOutlet NSButton *fnClickButton;
@property (weak) IBOutlet NSButton *shiftClickButton;

@property (weak) IBOutlet NSButton *altHoverMoveButton;
@property (weak) IBOutlet NSButton *commandHoverMoveButton;
@property (weak) IBOutlet NSButton *controlHoverMoveButton;
@property (weak) IBOutlet NSButton *fnHoverMoveButton;
@property (weak) IBOutlet NSButton *shiftHoverMoveButton;

@property (weak) IBOutlet NSButton *altHoverResizeButton;
@property (weak) IBOutlet NSButton *commandHoverResizeButton;
@property (weak) IBOutlet NSButton *controlHoverResizeButton;
@property (weak) IBOutlet NSButton *fnHoverResizeButton;
@property (weak) IBOutlet NSButton *shiftHoverResizeButton;


@property (weak) IBOutlet NSButton *clickModeButton;
@property (weak) IBOutlet NSButton *hoverModeButton;

- (IBAction)modifierClicked:(NSButton *)sender;

- (IBAction)clickModeClicked:(id)sender;
- (IBAction)hoverModeClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
