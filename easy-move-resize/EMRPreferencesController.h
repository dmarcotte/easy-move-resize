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

@property (weak) IBOutlet NSButton *altButton;
@property (weak) IBOutlet NSButton *commandButton;
@property (weak) IBOutlet NSButton *controlButton;
@property (weak) IBOutlet NSButton *fnButton;
@property (weak) IBOutlet NSButton *shiftButton;

@end

NS_ASSUME_NONNULL_END
