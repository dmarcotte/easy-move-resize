#import <XCTest/XCTest.h>
#import "EMRMoveResize.h"

@interface EMRMoveResizeTest : XCTestCase

@end

@implementation EMRMoveResizeTest

- (void)setUp {
    [super setUp];
    // Reset state before each test
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:0];
    [mr setIsResizing:NO];
    [mr setWindow:nil];
}

#pragma mark - Singleton

- (void)testInstanceReturnsSameObject {
    EMRMoveResize *a = [EMRMoveResize instance];
    EMRMoveResize *b = [EMRMoveResize instance];
    XCTAssertEqual(a, b, "instance should return the same singleton object");
}

- (void)testInstanceIsNotNil {
    XCTAssertNotNil([EMRMoveResize instance], "instance should never return nil");
}

#pragma mark - isResizing property

- (void)testIsResizingDefaultsToNO {
    EMRMoveResize *mr = [EMRMoveResize instance];
    XCTAssertFalse([mr isResizing], "isResizing should default to NO after reset");
}

- (void)testSetIsResizingToYES {
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setIsResizing:YES];
    XCTAssertTrue([mr isResizing], "isResizing should be YES after setting to YES");
}

- (void)testSetIsResizingBackToNO {
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setIsResizing:YES];
    [mr setIsResizing:NO];
    XCTAssertFalse([mr isResizing], "isResizing should be NO after setting back to NO");
}

#pragma mark - tracking property

- (void)testTrackingDefaultsToZero {
    EMRMoveResize *mr = [EMRMoveResize instance];
    XCTAssertEqual([mr tracking], 0, "tracking should be 0 after reset");
}

- (void)testSetTracking {
    EMRMoveResize *mr = [EMRMoveResize instance];
    CFTimeInterval now = CACurrentMediaTime();
    [mr setTracking:now];
    XCTAssertEqual([mr tracking], now, "tracking should store the time value");
}

- (void)testClearTracking {
    EMRMoveResize *mr = [EMRMoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setTracking:0];
    XCTAssertEqual([mr tracking], 0, "tracking should be 0 after clearing");
}

#pragma mark - resizeSection struct

- (void)testResizeSectionStorage {
    EMRMoveResize *mr = [EMRMoveResize instance];
    struct ResizeSection section;
    section.xResizeDirection = left;
    section.yResizeDirection = top;
    [mr setResizeSection:section];

    struct ResizeSection retrieved = [mr resizeSection];
    XCTAssertEqual(retrieved.xResizeDirection, left, "xResizeDirection should be left");
    XCTAssertEqual(retrieved.yResizeDirection, top, "yResizeDirection should be top");
}

- (void)testResizeSectionAllDirections {
    EMRMoveResize *mr = [EMRMoveResize instance];

    // Test right + bottom
    struct ResizeSection section1 = { .xResizeDirection = right, .yResizeDirection = bottom };
    [mr setResizeSection:section1];
    struct ResizeSection r1 = [mr resizeSection];
    XCTAssertEqual(r1.xResizeDirection, right);
    XCTAssertEqual(r1.yResizeDirection, bottom);

    // Test noX + noY (center of window)
    struct ResizeSection section2 = { .xResizeDirection = noX, .yResizeDirection = noY };
    [mr setResizeSection:section2];
    struct ResizeSection r2 = [mr resizeSection];
    XCTAssertEqual(r2.xResizeDirection, noX);
    XCTAssertEqual(r2.yResizeDirection, noY);
}

#pragma mark - wndPosition and wndSize

- (void)testWndPositionStorage {
    EMRMoveResize *mr = [EMRMoveResize instance];
    NSPoint pos = NSMakePoint(100.0, 200.0);
    [mr setWndPosition:pos];
    NSPoint retrieved = [mr wndPosition];
    XCTAssertEqual(retrieved.x, 100.0);
    XCTAssertEqual(retrieved.y, 200.0);
}

- (void)testWndSizeStorage {
    EMRMoveResize *mr = [EMRMoveResize instance];
    NSSize size = NSMakeSize(800.0, 600.0);
    [mr setWndSize:size];
    NSSize retrieved = [mr wndSize];
    XCTAssertEqual(retrieved.width, 800.0);
    XCTAssertEqual(retrieved.height, 600.0);
}

#pragma mark - State lifecycle (simulating down → drag → up)

- (void)testStateLifecycleMoveOperation {
    EMRMoveResize *mr = [EMRMoveResize instance];

    // Simulate mouse down for move
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:NO];
    XCTAssertTrue([mr tracking] > 0, "tracking should be active");
    XCTAssertFalse([mr isResizing], "should not be resizing for a move");

    // Simulate mouse up
    [mr setTracking:0];
    [mr setIsResizing:NO];
    XCTAssertEqual([mr tracking], 0, "tracking should be cleared");
    XCTAssertFalse([mr isResizing], "isResizing should be NO after up");
}

- (void)testStateLifecycleResizeOperation {
    EMRMoveResize *mr = [EMRMoveResize instance];

    // Simulate mouse down for resize
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];
    struct ResizeSection section = { .xResizeDirection = right, .yResizeDirection = bottom };
    [mr setResizeSection:section];
    [mr setWndPosition:NSMakePoint(50, 50)];
    [mr setWndSize:NSMakeSize(400, 300)];

    XCTAssertTrue([mr tracking] > 0);
    XCTAssertTrue([mr isResizing]);
    XCTAssertEqual([mr resizeSection].xResizeDirection, right);
    XCTAssertEqual([mr wndSize].width, 400.0);

    // Simulate mouse up
    [mr setTracking:0];
    [mr setIsResizing:NO];
    XCTAssertEqual([mr tracking], 0);
    XCTAssertFalse([mr isResizing]);
}

@end
