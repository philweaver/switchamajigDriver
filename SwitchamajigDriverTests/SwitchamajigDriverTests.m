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

// SWITCHAMAJIG DRIVER DELEGATE
bool connectedCallbackCalled, disconnectedCallbackCalled;
- (void) SwitchamajigDeviceDriverConnected:(id)deviceDriver {
    connectedCallbackCalled = true;
}
- (void) SwitchamajigDeviceDriverDisconnected:(id)deviceDriver withError:(NSError*)error {
    disconnectedCallbackCalled = true;
}


- (void)test001DriverBasicOperationTCP
{
    connectedCallbackCalled = false;
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    [controller startListening];
    SwitchamajigControllerDeviceDriver *driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"localhost"];
    [driver setDelegate:self];
    // Wait to allow connections to happen
    NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    // Make sure we got callback
    STAssertTrue(connectedCallbackCalled, @"Did not receive connect callback.");
    // It should have set the switch state to 0
    STAssertTrue(([controller getSwitchState] == 0x00), @"Failed to initialize switches.");
    STAssertFalse([controller wasLastPacketUDP], @"Got UDP packet during TCP test (init)");
    // Turn on all switches
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOn> 1 2 3 4 5 6 </turnSwitchesOn>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOn: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    // Wait for command
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    // Confirm that command worked
    int switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x3f), @"Failed to set switches. State=%d", switchState);
    STAssertFalse([controller wasLastPacketUDP], @"Got UDP packet during TCP test (3f)");
    // Turn a few switches off
    xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOff> 2 4 5 </turnSwitchesOff>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOff: %@", err);
    }
    commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x25), @"Failed to set switches. State=%d", switchState);
    STAssertFalse([controller wasLastPacketUDP], @"Got UDP packet during TCP test (25)");
    [controller stopListening];
}

- (void)test002DriverBasicOperationUDP
{
    connectedCallbackCalled = false;
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    [controller startListening];
    SwitchamajigControllerDeviceDriver *driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"localhost"];
    [driver setUseUDP:YES];
    [driver setDelegate:self];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    // It should have set the switch state to 0
    STAssertTrue(([controller getSwitchState] == 0x00), @"Failed to initialize switches.");
    STAssertTrue([controller wasLastPacketUDP], @"Didn't receive UDP packet (init)");
    // Turn on all switches
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOn> 1 2 3 4 5 6 </turnSwitchesOn>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOn: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    // Confirm that command worked
    int switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x3f), @"Failed to set switches. State=%d", switchState);
    STAssertTrue([controller wasLastPacketUDP], @"Didn't receive UDP packet (3f)");
    // Turn a few switches off
    xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOff> 2 4 5 </turnSwitchesOff>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOff: %@", err);
    }
    commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x25), @"Failed to set switches. State=%d", switchState);
    STAssertTrue([controller wasLastPacketUDP], @"Didn't receive UDP packet (25)");
    [controller stopListening];
}

bool batteryWarning;
char lastFriendlyName[255];
bool listenerErrorReceieved;
- (void) SwitchamajigDeviceListenerFoundDevice:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname {
    strcpy(lastFriendlyName, [friendlyname cStringUsingEncoding:NSASCIIStringEncoding]);
    
}
- (void) SwitchamajigDeviceListenerHandleError:(id)listener theError:(NSError*)error {
    listenerErrorReceieved = true;
    NSLog(@"SwitchamajigDeviceListenerHandleError: %@", error); 
}
- (void) SwitchamajigDeviceListenerHandleBatteryWarning:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname {
    batteryWarning = true;
    
}

- (void) test003ListenerBasicOperation {
    listenerErrorReceieved = false;
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    SwitchamajigControllerDeviceListener *listener = [[SwitchamajigControllerDeviceListener alloc] initWithDelegate:self];
    listener = listener; // Quiet warning
    batteryWarning = false;
    [controller sendHeartbeat:"testName1" batteryVoltageInmV:2500];
    NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertTrue(!strcmp(lastFriendlyName, "testName1"), @"Did not get testName1");
    STAssertFalse(batteryWarning, @"Got erroneous battery warning");
    
    [controller sendHeartbeat:"testName2" batteryVoltageInmV:1000];
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertTrue(!strcmp(lastFriendlyName, "testName2"), @"Did not get testName1");
    STAssertTrue(batteryWarning, @"Did not receive battery warning");
    STAssertFalse(listenerErrorReceieved, @"Received unexpected listener error.");
}

- (void) test004DriverAndListenerErrors {
    disconnectedCallbackCalled = false;
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    [controller startListening];
    SwitchamajigControllerDeviceDriver *driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"255.255.255.255"];
    [driver setDelegate:self];
    NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertTrue(disconnectedCallbackCalled, @"No disconnect callback on bad hostname.");
    
    // Now connect properly
    connectedCallbackCalled = false;
    driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"localhost"];
    [driver setDelegate:self];
    // Wait to allow connections to happen
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertTrue(connectedCallbackCalled, @"Did not receive connect callback.");
    // Than shut down controller
    [controller stopListening];
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    disconnectedCallbackCalled = false;
    connectedCallbackCalled = false;
   // Send command
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <turnSwitchesOn> 1 2 3 4 5 6 </turnSwitchesOn>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for turnSwitchesOn: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    // Wait for command
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertFalse(connectedCallbackCalled, @"Received connect callback after controller shut down.");
    STAssertTrue(disconnectedCallbackCalled, @"No disconnect with error after controller shut down.");
   
    listenerErrorReceieved = false;
    // Create two listeners. The second one should generate errors
    SwitchamajigControllerDeviceListener *listener1 = [[SwitchamajigControllerDeviceListener alloc] initWithDelegate:self];
    listener1 = listener1; // Quiet warning
    SwitchamajigControllerDeviceListener *listener2 = [[SwitchamajigControllerDeviceListener alloc] initWithDelegate:self];
    listener2 = listener2; // Quiet warning
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    STAssertTrue(listenerErrorReceieved, @"Should receive error when two listeners conflict.");
}
@end
