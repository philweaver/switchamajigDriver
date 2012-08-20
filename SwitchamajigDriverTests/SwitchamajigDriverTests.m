//
//  SwitchamajigDriverTests.m
//  SwitchamajigDriverTests
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigDriverTests.h"
#import "SwitchamajigControllerDeviceDriver.h"
#import "SwitchamajigIRDriver.h"
@implementation SwitchamajigDriverTests

#define RUN_ALL_TESTS 0
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

// SwitchamajigDeviceListenerDelegate
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


#if RUN_ALL_TESTS
- (void)test001ControllerDriverBasicOperationTCP
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
    [driver issueCommandFromXMLNode:commandNode error:&err];
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
    [driver issueCommandFromXMLNode:commandNode error:&err];
    oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
    [[NSRunLoop currentRunLoop] runUntilDate:oneSecondFromNow];
    switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x25), @"Failed to set switches. State=%d", switchState);
    STAssertFalse([controller wasLastPacketUDP], @"Got UDP packet during TCP test (25)");
    [controller stopListening];
}

- (void)test002ControllerDriverBasicOperationUDP
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
    [driver issueCommandFromXMLNode:commandNode error:&err];
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
    [driver issueCommandFromXMLNode:commandNode error:&err];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    switchState = [controller getSwitchState];
    STAssertTrue((switchState == 0x25), @"Failed to set switches. State=%d", switchState);
    STAssertTrue([controller wasLastPacketUDP], @"Didn't receive UDP packet (25)");
    [controller stopListening];
}

- (void) test003ControllerListenerBasicOperation {
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

- (void) test004ControllerDriverAndListenerErrors {
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
    [driver issueCommandFromXMLNode:commandNode error:&err];
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
#endif

- (void) test005IRListenerBasicOperation {
    // Basic test with a single unit
    listenerErrorReceieved = false;
    SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25000];
    [irDevice setDeviceName:@"Roger the shrubber"];
    [irDevice resetPuckRequestCount];
    SwitchamajigIRDeviceListener *listener = [[SwitchamajigIRDeviceListener alloc] initWithDelegate:self];
    [irDevice startListening];
    [irDevice announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    int numPuckRequests = [irDevice getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device should have received one puck status request, but count is %d.", numPuckRequests);
    [irDevice returnPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Roger the shrubber"), @"Did not get Roger the shrubber. Instead got %s", lastFriendlyName);
    
    // Test to force race condition with two units
    SimulatedSwitchamajigIR *irDevice2 = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice2 setPort:25001];
    [irDevice2 setDeviceName:@"Unit2"];
    [irDevice2 resetPuckRequestCount];
    SimulatedSwitchamajigIR *irDevice3 = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice3 setPort:25002];
    [irDevice3 setDeviceName:@"Unit3"];
    [irDevice3 resetPuckRequestCount];
    [irDevice2 startListening];
    [irDevice3 startListening];
    [irDevice2 announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numPuckRequests = [irDevice2 getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device2 should have received one puck status request, but count is %d.", numPuckRequests);
    // While this request is in flight, have a second unit get discovered
    [irDevice3 announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numPuckRequests = [irDevice3 getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device2 should have received one puck status request, but count is %d.", numPuckRequests);
    // Complete the first puck status request
    [irDevice2 returnPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit2"), @"Did not get Unit2. Instead got %s", lastFriendlyName);
    // Complete the second puck status request
    [irDevice3 returnPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit3"), @"Did not get Unit3. Instead got %s", lastFriendlyName);
    
    // Repeat the sequence again, but complete the second request first
    SimulatedSwitchamajigIR *irDevice4 = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice4 setPort:25003];
    [irDevice4 setDeviceName:@"Unit4"];
    [irDevice4 resetPuckRequestCount];
    SimulatedSwitchamajigIR *irDevice5 = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice5 setPort:25004];
    [irDevice5 setDeviceName:@"Unit5"];
    [irDevice5 resetPuckRequestCount];
    [irDevice4 startListening];
    [irDevice5 startListening];
    [irDevice4 announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numPuckRequests = [irDevice4 getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device2 should have received one puck status request, but count is %d.", numPuckRequests);
    // While this request is in flight, have a second unit get discovered
    [irDevice5 announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numPuckRequests = [irDevice5 getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device2 should have received one puck status request, but count is %d.", numPuckRequests);
    // Complete the second puck status request
    [irDevice5 returnPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit5"), @"Did not get Unit5. Instead got %s", lastFriendlyName);
    // Complete the first puck status request
    [irDevice4 returnPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit4"), @"Did not get Unit4. Instead got %s", lastFriendlyName);
    
    STAssertFalse(listenerErrorReceieved, @"Received unexpected listener error.");
    
}


#if 0
// This test doesn't pass because th driver is synchronous and the controller is asynchronous and the
// controller isn't serviced fast enough
- (void) test005ConfigureSettings {
    SimulatedSwitchamajigController *controller = [SimulatedSwitchamajigController alloc];
    [controller startListening];
    SwitchamajigControllerDeviceDriver *driver = [[SwitchamajigControllerDeviceDriver alloc] initWithHostname:@"localhost"];
    [driver setUseUDP:YES]; // Doesn't really matter; config must use TCP
    [driver setDelegate:self];
    // Send command to set controller name
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <setDeviceName>abcdefg</setDeviceName>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for setDeviceName: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    STAssertTrue([controller->deviceName isEqualToString:@"abcdefg"], @"Failed to set device name. Name is %@ not abcdefg", controller->deviceName);
    
    // Send command to set networking info
    xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <configureDeviceNetworking ssid=\"newssid\" channel=\"3\" passphrase=\"newpassphrase\"></configureDeviceNetworking>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for configureDeviceNetworking: %@", err);
    }
    [driver issueCommandFromXMLNode:commandNode];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    STAssertTrue([controller->ssidName isEqualToString:@"newssid"], @"Failed to set ssid. Name is %@ not newssid", controller->ssidName);
    STAssertTrue(controller->wifiChannel == 3, @"Failed to set wifi channel. Name is %d not 3", controller->wifiChannel);
    STAssertTrue([controller->wifiPassphrase isEqualToString:@"newpassphrase"], @"Failed to set ssid. Name is %@ not newpassphrase", controller-> wifiPassphrase);
}
#endif
@end
