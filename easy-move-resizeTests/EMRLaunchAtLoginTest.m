#import <XCTest/XCTest.h>
#import "EMRLaunchAtLogin.h"

// Only the OS boundary is replaced; the real setting controls the menu and
// decides which registration operation to perform.
@interface EMRTestLoginItemService : NSObject <EMRLoginItemService>
@property SMAppServiceStatus status;
@property SMAppServiceStatus statusAfterRegistration;
@property (strong) NSError *operationError;
@property BOOL approvalRequiredOnFailure;
@property NSUInteger registrations;
@property NSUInteger unregistrations;
@end

@implementation EMRTestLoginItemService
- (BOOL)registerAndReturnError:(NSError **)error {
    self.registrations++;
    if (self.operationError) {
        if (self.approvalRequiredOnFailure) {
            self.status = SMAppServiceStatusRequiresApproval;
        }
        if (error) *error = self.operationError;
        return NO;
    }
    self.status = self.statusAfterRegistration;
    return YES;
}

- (BOOL)unregisterAndReturnError:(NSError **)error {
    self.unregistrations++;
    if (self.operationError) {
        if (error) *error = self.operationError;
        return NO;
    }
    self.status = SMAppServiceStatusNotRegistered;
    return YES;
}
@end

@interface EMRLaunchAtLoginTest : XCTestCase
@end

@implementation EMRLaunchAtLoginTest {
    EMRTestLoginItemService *service;
    EMRLaunchAtLogin *setting;
    NSMenuItem *menuItem;
}

- (void)setUp {
    [super setUp];
    service = [[EMRTestLoginItemService alloc] init];
    service.status = SMAppServiceStatusNotRegistered;
    service.statusAfterRegistration = SMAppServiceStatusEnabled;
    setting = [[EMRLaunchAtLogin alloc] initWithService:service];
    menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
}

- (void)testToggleEnablesAndDisablesAutomaticLaunch {
    XCTAssertTrue([setting toggleAndReturnError:NULL]);
    [setting updateMenuItem:menuItem];
    XCTAssertFalse(menuItem.hidden);
    XCTAssertEqual(menuItem.state, NSControlStateValueOn);
    XCTAssertEqualObjects(menuItem.title, @"Launch at Login");
    XCTAssertEqual(service.registrations, 1u);
    XCTAssertEqual(service.unregistrations, 0u);

    XCTAssertTrue([setting toggleAndReturnError:NULL]);
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOff);
    XCTAssertEqual(service.registrations, 1u);
    XCTAssertEqual(service.unregistrations, 1u);
}

- (void)testPendingApprovalCanBeCancelled {
    service.statusAfterRegistration = SMAppServiceStatusRequiresApproval;
    XCTAssertTrue([setting toggleAndReturnError:NULL]);
    [setting updateMenuItem:menuItem];
    XCTAssertTrue(setting.requiresApproval);
    XCTAssertEqual(menuItem.state, NSControlStateValueMixed);
    XCTAssertEqualObjects(menuItem.title, @"Launch at Login (Approval Required)");

    XCTAssertTrue([setting toggleAndReturnError:NULL]);
    [setting updateMenuItem:menuItem];
    XCTAssertFalse(setting.requiresApproval);
    XCTAssertEqual(menuItem.state, NSControlStateValueOff);
    XCTAssertEqualObjects(menuItem.title, @"Launch at Login");
    XCTAssertEqual(service.unregistrations, 1u);
}

- (void)testMenuReflectsChangesMadeOutsideTheApp {
    service.status = SMAppServiceStatusEnabled;
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOn);

    service.status = SMAppServiceStatusRequiresApproval;
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueMixed);
    XCTAssertTrue(setting.requiresApproval);

    service.status = SMAppServiceStatusNotRegistered;
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOff);
    XCTAssertFalse(setting.requiresApproval);
    XCTAssertEqualObjects(menuItem.title, @"Launch at Login");
    XCTAssertEqual(service.registrations, 0u);
    XCTAssertEqual(service.unregistrations, 0u);
}

- (void)testRegistrationFailureKeepsTheMenuOffAndReturnsTheError {
    service.operationError = [NSError errorWithDomain:@"TestLoginService" code:1 userInfo:nil];
    NSError *error = nil;
    XCTAssertFalse([setting toggleAndReturnError:&error]);
    XCTAssertEqualObjects(error, service.operationError);
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOff);
    XCTAssertEqual(service.registrations, 1u);
}

- (void)testUnregistrationFailureKeepsTheMenuOnAndReturnsTheError {
    service.status = SMAppServiceStatusEnabled;
    service.operationError = [NSError errorWithDomain:@"TestLoginService" code:2 userInfo:nil];
    NSError *error = nil;
    XCTAssertFalse([setting toggleAndReturnError:&error]);
    XCTAssertEqualObjects(error, service.operationError);
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOn);
    XCTAssertEqual(service.unregistrations, 1u);
}

- (void)testUnavailableServiceHidesTheOption {
    setting = [[EMRLaunchAtLogin alloc] initWithService:nil];
    [setting updateMenuItem:menuItem];
    XCTAssertTrue(menuItem.hidden);
    XCTAssertFalse(setting.requiresApproval);
    NSError *error = nil;
    XCTAssertFalse([setting toggleAndReturnError:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSFeatureUnsupportedError);
}

- (void)testDeniedRegistrationOffersApprovalAndCanBeCancelled {
    service.operationError = [NSError errorWithDomain:@"TestLoginService" code:3 userInfo:nil];
    service.approvalRequiredOnFailure = YES;
    NSAlert *alert = [setting toggleWithAlert];
    XCTAssertNotNil(alert);
    XCTAssertEqualObjects(alert.messageText, @"Approve Launch at Login");
    XCTAssertEqualObjects(alert.buttons.firstObject.title, @"Open System Settings");
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueMixed);
    XCTAssertTrue(setting.requiresApproval);

    service.operationError = nil;
    XCTAssertNil([setting toggleWithAlert]);
    [setting updateMenuItem:menuItem];
    XCTAssertEqual(menuItem.state, NSControlStateValueOff);
    XCTAssertEqual(service.registrations, 1u);
    XCTAssertEqual(service.unregistrations, 1u);
}

- (void)testFailureWithoutPendingApprovalShowsTheError {
    service.operationError = [NSError errorWithDomain:@"TestLoginService" code:4 userInfo:nil];
    NSAlert *alert = [setting toggleWithAlert];
    XCTAssertNotNil(alert);
    XCTAssertEqualObjects(alert.messageText, @"Couldn’t Change Launch at Login");
    XCTAssertEqualObjects(alert.informativeText, service.operationError.localizedDescription);
}

- (void)testFailedCancellationShowsTheErrorInsteadOfRequestingApproval {
    service.status = SMAppServiceStatusRequiresApproval;
    service.operationError = [NSError errorWithDomain:@"TestLoginService" code:5 userInfo:nil];
    NSAlert *alert = [setting toggleWithAlert];
    XCTAssertEqualObjects(alert.messageText, @"Couldn’t Change Launch at Login");
    XCTAssertEqualObjects(alert.informativeText, service.operationError.localizedDescription);
    XCTAssertEqual(service.registrations, 0u);
    XCTAssertEqual(service.unregistrations, 1u);
}

@end
