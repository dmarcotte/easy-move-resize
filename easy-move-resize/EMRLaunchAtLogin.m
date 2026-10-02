#import "EMRLaunchAtLogin.h"

@implementation EMRLaunchAtLogin {
    id<EMRLoginItemService> service;
}

- (instancetype)init {
    if (@available(macOS 13.0, *)) {
        // SMAppService provides the protocol's methods and status property.
        return [self initWithService:(id<EMRLoginItemService>)[SMAppService mainAppService]];
    }
    return [self initWithService:nil];
}

- (instancetype)initWithService:(id<EMRLoginItemService>)loginItemService {
    self = [super init];
    if (self) {
        service = loginItemService;
    }
    return self;
}

- (BOOL)requiresApproval {
    return service != nil && service.status == SMAppServiceStatusRequiresApproval;
}

- (void)updateMenuItem:(NSMenuItem *)menuItem {
    menuItem.hidden = service == nil;
    menuItem.title = @"Launch at Login";
    menuItem.state = NSControlStateValueOff;
    if (service != nil) {
        SMAppServiceStatus status = service.status;
        if (status == SMAppServiceStatusEnabled) {
            menuItem.state = NSControlStateValueOn;
        } else if (status == SMAppServiceStatusRequiresApproval) {
            menuItem.title = @"Launch at Login (Approval Required)";
            menuItem.state = NSControlStateValueMixed;
        }
    }
}

- (BOOL)toggleAndReturnError:(NSError **)error {
    if (service == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSFeatureUnsupportedError userInfo:nil];
        }
        return NO;
    }
    SMAppServiceStatus status = service.status;
    if (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval) {
        return [service unregisterAndReturnError:error];
    }
    return [service registerAndReturnError:error];
}

- (NSAlert *)toggleWithAlert {
    BOOL disabling = service != nil
            && (service.status == SMAppServiceStatusEnabled || self.requiresApproval);
    NSError *error = nil;
    BOOL success = [self toggleAndReturnError:&error];
    // Registration can fail because consent is absent while still leaving
    // the service registered and waiting for approval.
    if (!disabling && self.requiresApproval) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Approve Launch at Login";
        alert.informativeText = @"Allow Easy Move+Resize in System Settings → General → Login Items to launch it automatically when you log in. To cancel automatic launching, click Launch at Login again.";
        [alert addButtonWithTitle:@"Open System Settings"];
        [alert addButtonWithTitle:@"Later"];
        return alert;
    }
    if (!success) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Couldn’t Change Launch at Login";
        alert.informativeText = error.localizedDescription
                ?: @"Please try again or manage the app in System Settings → General → Login Items.";
        return alert;
    }
    return nil;
}

@end
