#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

// The OS service is injected so tests can exercise the setting without
// registering the test runner as a login item.
@protocol EMRLoginItemService <NSObject>
@property (readonly) SMAppServiceStatus status;
- (BOOL)registerAndReturnError:(NSError **)error;
- (BOOL)unregisterAndReturnError:(NSError **)error;
@end

@interface EMRLaunchAtLogin : NSObject
- (instancetype)initWithService:(id<EMRLoginItemService>)service;
- (void)updateMenuItem:(NSMenuItem *)menuItem;
- (BOOL)toggleAndReturnError:(NSError **)error;
- (NSAlert *)toggleWithAlert;
@property (readonly) BOOL requiresApproval;
@end
