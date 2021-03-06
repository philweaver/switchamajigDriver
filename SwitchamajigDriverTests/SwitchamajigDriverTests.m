/*
Copyright 2014 PAW Solutions LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

#import "SwitchamajigDriverTests.h"
#import "SwitchamajigControllerDeviceDriver.h"
#import "SwitchamajigIRDriver.h"
#import "SwitchamajigInsteonDriver.h"

@implementation SwitchamajigDriverTests

#define RUN_ALL_TESTS 1
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
// OPTIONAL IR DELEGATE
NSString *lastLearnedIRCommand;
bool learningIRError;
- (void) SwitchamajigIRDeviceDriverDelegateDidReceiveLearnedIRCommand:(id)deviceDriver irCommand:(NSString *)irCommand {
    lastLearnedIRCommand = irCommand;
}
- (void) SwitchamajigIRDeviceDriverDelegateErrorOnLearnIR:(id) deviceDriver error:(NSError *)error {
    learningIRError = true;
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
    [irDevice returnValidPuckStatus];
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
    [irDevice2 returnValidPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit2"), @"Did not get Unit2. Instead got %s", lastFriendlyName);
    // Complete the second puck status request
    [irDevice3 returnValidPuckStatus];
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
    [irDevice5 returnValidPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit5"), @"Did not get Unit5. Instead got %s", lastFriendlyName);
    // Complete the first puck status request
    [irDevice4 returnValidPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "Unit4"), @"Did not get Unit4. Instead got %s", lastFriendlyName);
    
    STAssertFalse(listenerErrorReceieved, @"Received unexpected listener error.");
    
}

- (void)test006IRDriverBasicOperation
{
    SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25010];
    [irDevice startListening];
    SwitchamajigIRDeviceDriver *driver = [[SwitchamajigIRDeviceDriver alloc] initWithHostname:@"localhost:25010"];
    [driver setDelegate:self];
    
    // Send a do command
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <docommand key=\"hoopy\" repeat=\"0\" seq=\"0\" command=\"frood\" ir_data=\"shrubbery\" ch=\"0\"></docommand>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for do command: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    //NSLog(@"commandNodeString = %@", [commandNode XMLString]);
    [driver issueCommandFromXMLNode:commandNode error:&err];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    // Check that the command was received by the simulated device
    NSString *lastIRCommand = [irDevice lastCommand];
    STAssertTrue([lastIRCommand isEqualToString:@"<docommand key=\"hoopy\" repeat=\"0\" seq=\"0\" command=\"frood\" ir_data=\"shrubbery\" ch=\"0\"></docommand>"], @"Failed to send docommand. Current lastIRCommand = %@", lastIRCommand);
}

- (void)test007IRDriverLearning
{
    SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25011];
    [irDevice startListening];
    SwitchamajigIRDeviceDriver *driver = [[SwitchamajigIRDeviceDriver alloc] initWithHostname:@"localhost:25011"];
    [driver setDelegate:self];
    learningIRError = false;
    [driver startIRLearning];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    int numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 1), @"IR count request wrong (is %d).", numIRLearningRequests);
    [irDevice returnIRLearningCommand:@"L123 4567"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue([lastLearnedIRCommand isEqualToString:@"L123 4567"], @"IR command wrong (is %@).", lastLearnedIRCommand);
    STAssertFalse(learningIRError, @"Got unexpected learning IR error");
    [driver startIRLearning];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 2), @"IR count request wrong (is %d).", numIRLearningRequests);
    [irDevice returnIRLearningErrorWithReasonCode:5];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(learningIRError, @"Failed to get IR error.");
    // Verify that we retry if we get a quick timeout
    learningIRError = false;
    [driver startIRLearning];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 3), @"IR count request wrong (is %d).", numIRLearningRequests);
    [irDevice returnIRLearningErrorWithReasonCode:6];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertFalse(learningIRError, @"Got error on quick timeout.");
    numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 4), @"IR count request wrong - should have retried on timeout (is %d).", numIRLearningRequests);
    // On the second timeout, we should report an error
    [irDevice returnIRLearningErrorWithReasonCode:6];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(learningIRError, @"Failed to get IR error on second timeout.");
    // Check for a real timeout as well
    learningIRError = false;
    [driver startIRLearning];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
    numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 5), @"IR count request wrong (is %d).", numIRLearningRequests);
    [irDevice returnIRLearningErrorWithReasonCode:6];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(learningIRError, @"Did not get error on real timeout.");
    numIRLearningRequests = [irDevice getIRLearnRequestCount];
    STAssertTrue((numIRLearningRequests == 5), @"IR count request wrong after real timeout (is %d).", numIRLearningRequests);
}

- (void)test008IRDriverErrors {
    disconnectedCallbackCalled = false;
    SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25012];
    [irDevice startListening];
    SwitchamajigIRDeviceDriver *driver = [[SwitchamajigIRDeviceDriver alloc] initWithHostname:@"255.255.255.255"];
    [driver setDelegate:self];
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <docommand key=\"hoopy\" repeat=\"0\" seq=\"0\" command=\"frood\" ir_data=\"shrubbery\" ch=\"0\"></docommand>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for docommand: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode error:&err];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    //STAssertTrue(disconnectedCallbackCalled, @"No disconnect callback on bad hostname.");
    
    // Now connect properly
    connectedCallbackCalled = false;
    driver = [[SwitchamajigIRDeviceDriver alloc] initWithHostname:@"localhost:25012"];
    [driver setDelegate:self];
    [driver issueCommandFromXMLNode:commandNode error:&err];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(connectedCallbackCalled, @"Did not receive connect callback.");
    // Than shut down controller
    [irDevice stopListening];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    disconnectedCallbackCalled = false;
    connectedCallbackCalled = false;
    // Send command
    [driver issueCommandFromXMLNode:commandNode error:&err];
    // Wait for command
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    //STAssertTrue(disconnectedCallbackCalled, @"No disconnect with error on do command after ir device shut down.");
    disconnectedCallbackCalled = false;
    [driver startIRLearning];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertFalse(connectedCallbackCalled, @"Received connect callback after ir device shut down.");
    //STAssertTrue(disconnectedCallbackCalled, @"No disconnect with error on learn IR after ir device shut down.");
}
- (void)test009IRListenerErrors {
    // Basic test with a single unit
    listenerErrorReceieved = false;
    SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25013];
    [irDevice setDeviceName:@"FunkyAT"];
    [irDevice resetPuckRequestCount];
    SwitchamajigIRDeviceListener *listener = [[SwitchamajigIRDeviceListener alloc] initWithDelegate:self];
    [irDevice startListening];
    [irDevice announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    int numPuckRequests = [irDevice getPuckRequestCount];
    STAssertTrue((numPuckRequests == 1), @"Device should have received one puck status request, but count is %d.", numPuckRequests);
    [irDevice returnPuckStatusWithNoOEMKey];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(strcmp(lastFriendlyName, "FunkyAT"), @"Registered an IR with no oem key");
    [irDevice announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    [irDevice returnPuckStatusWithInvalidOEMKey];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(strcmp(lastFriendlyName, "FunkyAT"), @"Registered an IR with an invalid oem key");
    [irDevice announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    [irDevice returnValidPuckStatus];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(!strcmp(lastFriendlyName, "FunkyAT"), @"Did not get FunkyAT. Instead got %s. May not have properly checked listener errors", lastFriendlyName);
    
}
- (void)test100IRDatabase {
    NSError *error;
    NSArray *brandsWithDatabaseUninitialized = [SwitchamajigIRDeviceDriver getIRDatabaseBrands];
    STAssertNil(brandsWithDatabaseUninitialized, @"Uninitialized database should return nil");
    NSString *irDatabasePath = [[NSBundle bundleForClass:[self class]]pathForResource:@"IRDB" ofType:@"sqlite"];
    NSLog(@"Database path = %@", irDatabasePath);
    [SwitchamajigIRDeviceDriver loadIRCodeDatabase:irDatabasePath error:&error];
    STAssertNil(error, @"Error loading IR database: %@", error);
    NSArray *brands = [SwitchamajigIRDeviceDriver getIRDatabaseBrands];
    STAssertTrue([brands count] == 638, @"Expected 638 brands in database. Got %d", [brands count]);
    STAssertTrue([brands containsObject:@"Sony"], @"Sony not in brands");
    NSArray *SonyDevices = [SwitchamajigIRDeviceDriver getIRDatabaseDevicesForBrand:@"Sony"];
    STAssertTrue([SonyDevices count] == 25, @"Expected 25 devices in database for Sony. Got %d", [SonyDevices count]);
    STAssertTrue([SonyDevices containsObject:@"TV"], @"TV not in Sony devices");
    NSArray *SonyTVCodeSets = [SwitchamajigIRDeviceDriver getIRDatabaseCodeSetsOnDevice:@"TV" forBrand:@"Sony"];
    STAssertTrue([SonyTVCodeSets count] == 5, @"Expected 5 code sets for Sony TV. Got %d", [SonyTVCodeSets count]);
    STAssertTrue([SonyTVCodeSets containsObject:@"All Models All Types"], @"'All Models All Types' not in Sony TV code sets. First object is %@", [SonyTVCodeSets objectAtIndex:0]);
    NSArray *SonyTVAllModelsFunctions = [SwitchamajigIRDeviceDriver getIRDatabaseFunctionsInCodeSet:@"All Models All Types" onDevice:@"TV" forBrand:@"Sony"];
    STAssertTrue([SonyTVAllModelsFunctions count] == 133, @"Expected 5 functions for Sony TV All Models All Types. Got %d", [SonyTVAllModelsFunctions count]);
    STAssertTrue([SonyTVAllModelsFunctions containsObject:@"VOLUME UP"], @"'VOLUME UP' not in functions for Sony TV all models all types. First object is %@", [SonyTVAllModelsFunctions objectAtIndex:0]);
    char irCommandBytes[800], expectedBytes[800];
    NSString *irCommand = [SwitchamajigIRDeviceDriver irCodeForFunction:@"VOLUME UP" inCodeSet:@"UEI Setup Code 0000" onDevice:@"TV" forBrand:@"Sony"];
    [irCommand getCString:irCommandBytes maxLength:sizeof(irCommandBytes) encoding:NSUTF8StringEncoding];
    STAssertTrue([irCommand isEqualToString:@"UT00006"], @"Command not what was expected. Got %@", irCommand);
    // Command that has hex code
    irCommand = [SwitchamajigIRDeviceDriver irCodeForFunction:@"NETFLIX" inCodeSet:@"All Models All Types" onDevice:@"TV" forBrand:@"Sony"];
    [irCommand getCString:irCommandBytes maxLength:sizeof(irCommandBytes) encoding:NSUTF8StringEncoding];
    NSString *expectedString = @"P7b64 79c4 fdf5 7f78 c44c ae1c f80d be9a 1b8a 7f35 1f7f e938 c9f8 d9c2 7dc6 c15a ea40 2b72 7e29 2850 eda3 49a7 74c3 0311 9045 0825 f4bb 54ac a2f1 718b 5008 bc94  ";
    [expectedString getCString:expectedBytes maxLength:sizeof(expectedBytes) encoding:NSUTF8StringEncoding];
    STAssertTrue([irCommand isEqualToString:expectedString], @"Command wrong. Expected %@ Got %@", expectedString, irCommand);
    NSArray *devices = [SwitchamajigIRDeviceDriver getIRDatabaseDevices];
    STAssertTrue([devices count] == 43, @"Expected 43 devices in database. Got %d", [devices count]);
    STAssertTrue([devices containsObject:@"TV"], @"TV not in devices");
    NSArray *tvBrands = [SwitchamajigIRDeviceDriver getIRDatabaseBrandsForDevice:@"TV"];
    STAssertTrue([tvBrands count] == 176, @"Expected 176 tv brands in database. Got %d", [tvBrands count]);
    STAssertTrue([tvBrands containsObject:@"Panasonic"], @"Panasonic not listed as TV brand");
}
#endif

- (void)test050InsteonListener {
    // Basic test with a single unit
    listenerErrorReceieved = false;
    /*SimulatedSwitchamajigIR *irDevice = [[SimulatedSwitchamajigIR alloc] init];
    [irDevice setPort:25000];
    [irDevice setDeviceName:@"Roger the shrubber"];
    [irDevice resetPuckRequestCount];*/
    lastFriendlyName[0] = 0;
    static SwitchamajigInsteonDeviceListener *listener;
    listener = [[SwitchamajigInsteonDeviceListener alloc] initWithDelegate:self];
    //[irDevice startListening];
    //[irDevice announcePresenceToListener:listener withHostName:@"localhost"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    //int numPuckRequests = [irDevice getPuckRequestCount];
    //STAssertTrue((numPuckRequests == 1), @"Device should have received one puck status request, but count is %d.", numPuckRequests);
    //[irDevice returnValidPuckStatus];
    //[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    STAssertTrue(strlen(lastFriendlyName), @"Did not get callback from Insteon Listener. Is a unit plugged in?");
    
}

- (void)test051InsteonDriverBasicOperation {
    // Basic test with a single unit
    SimulatedInsteonDevice *insteon = [[SimulatedInsteonDevice alloc] init];
    [insteon startListeningOnPort:25105];
    SwitchamajigInsteonDeviceDriver *driver = [[SwitchamajigInsteonDeviceDriver alloc] initWithHostname:@"localhost:25105"];
    NSError *err;
    DDXMLDocument *xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <insteon_send><username>admin</username><password>shadow</password><dst_addr>20B300</dst_addr><command>OFF</command></insteon_send>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for send command: %@", err);
    }
    DDXMLNode *commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode error:&err];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    STAssertTrue([[NSPredicate predicateWithFormat:@"SELF contains \"GET /3?026220B3000F13ff=I=3\""] evaluateWithObject:insteon->lastIssuedCommand], @"Wrong received command. Got %@", insteon->lastIssuedCommand);
    
    xmlCommandDoc = [[DDXMLDocument alloc] initWithXMLString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r <insteon_send><username>admin</username><password>shadow</password><dst_addr>123456</dst_addr><level>128</level><command>ON</command></insteon_send>" options:0 error:&err];
    if(!xmlCommandDoc) {
        NSLog(@"Failed to create xml doc for send command: %@", err);
    }
    commandNode = [[xmlCommandDoc children] objectAtIndex:0];
    [driver issueCommandFromXMLNode:commandNode error:&err];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    
    STAssertTrue([[NSPredicate predicateWithFormat:@"SELF contains \"GET /3?02621234560F1180=I=3\""] evaluateWithObject:insteon->lastIssuedCommand], @"Wrong received command. Got %@", insteon->lastIssuedCommand);
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
