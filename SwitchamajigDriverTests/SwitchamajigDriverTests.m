//
//  SwitchamajigDriverTests.m
//  SwitchamajigDriverTests
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigDriverTests.h"
#import "SwitchamajigControllerDeviceDriver.h"
@implementation SwitchamajigDriverTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testBasicOperation
{
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    [controller startListening];
    SwitchamajigControllerDeviceDriver *driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"localhost"];
    [driver setDelegate:self];
    // Wait to allow connections to happen
    NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    // It should have set the switch state to 0
    STAssertTrue(([controller getSwitchState] == 0x00), @"Failed to initialize switches.");
    // Turn on all switches
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOn> 1 2 3 4 5 6 </turnSwitchesOn>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOn: %@", err);
    }
    [driver issueCommandFromXMLNode:xmlCommandDoc];
    // Wait for command
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    // Confirm that command worked
    int switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x3f), @"Failed to set switches. State=%d", switchState);
    // Turn a few switches off
    xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOff> 2 4 5 </turnSwitchesOff>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOff: %@", err);
    }
    [driver issueCommandFromXMLNode:xmlCommandDoc];
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x25), @"Failed to set switches. State=%d", switchState);

}

@end
