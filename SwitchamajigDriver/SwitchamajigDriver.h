//
//  SwitchamajigDriver.h
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../../KissXML/KissXML/DDXMLDocument.h"
const NSString *SwitchamajigDriverErrorDomain;
// Error codes
#define SJDriverErrorUnknownCommand 100
#define SJDriverErrorBadArguments 101
#define SJDriverErrorNullSocket 1000
#define SJDriverErrorConfigProblem 1001
#define SJDriverErrorIR 2000
#define SJDriverErrorIRDatabase 2001

/*------------------------------------------------------------------------------------------------------------
 Switchamajig Driver
  
 The driver consist of two parts: the driver and the listener. The listener listens for Switchamajig devices
 on the network, and the driver talks to them.
 
 Both the driver and the listener use delegates. The listener calls its delegate when it finds a device to
 talk to, and the driver calls its delegate with connection status information.
 
 The driver also allows commands to be sent to the Switchamajig device. These are specified as XML.
 
 The XML commands supported depend on the type of device:
 Switchamajig Controller - Basic Operation
 turnSwitchesOn - Closes selected relays
    <turnSwitchesOn>1 4 5</turnSwitchesOn> - Closes relays for ports 1, 4, and 5. Ports are numbered 1-6.
 turnSwitchesOff - Opens selected relays
    <turnSwitchesOff>2</turnSwitchesOff> - Opens relay for port 2.

 Switchamajig Controller - Special Commands
 setDeviceName - Set the friendly name for the device
    <setDeviceName>California</setDeviceName> - Sets the device's friendly name to 'California'
 configureDeviceNetworking - Change the networking settings. Note that the Switchamajig Controller reboots
    after you change its network settings. It then tries to join the new network. If that network is different
    from the iPad's, the iPad will lose contact with it.
    <configureDeviceNetworking ssid="newSSID" channel="3" passphrase="newPassprase"></configureDeviceNetworking>
 
 Switchamajig IR - Basic Operation
 docommand - Send one or more IR commands
    <docommand key="0" repeat="1" seq="0" command="AnyString" ir_data="irCommands" ch="0"></docommand>
        key: Reserved for future use. Set to 0.
        repeat: The number of times to send out the command sequence.
        seq: Reserved for future use. Set to 0.
        ir_data: A string from the IR database or from learning an IR command. Commands may be concatenated 
                 together and separated by a space.
        ch: Reserved for future use. Set to 0.
 
 Note that there is no way to configure the networking settings of the Switchamajig IR. Its networking is 
 configured over USB using a program available on switchamjig.com.
 
 The Switchamjig IR driver also supports commands to interrogate the database of IR codes and to learn a new code.
 Learning is started with - (void) startIRLearning; the response is returned to the delegate, which must
 implement additional methods to be a SwitchamajigIRDeviceDriverDelegate.
 
 The IR database returns arrays of strings for the brands, devices, and code sets for the IR codes. It returns
 a string when provided with a valid brand, device, and code set.
 ------------------------------------------------------------------------------------------------------------*/
@protocol SwitchamajigDeviceDriverDelegate <NSObject>
@required
- (void) SwitchamajigDeviceDriverConnected:(id)deviceDriver;
- (void) SwitchamajigDeviceDriverDisconnected:(id)deviceDriver withError:(NSError*)error;
@end

@protocol SwitchamajigDeviceListenerDelegate <NSObject> 
- (void) SwitchamajigDeviceListenerFoundDevice:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname;
- (void) SwitchamajigDeviceListenerHandleError:(id)listener theError:(NSError*)error;
- (void) SwitchamajigDeviceListenerHandleBatteryWarning:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname;
@end

@interface SwitchamajigDriver : NSObject
@property (nonatomic) id <SwitchamajigDeviceDriverDelegate> delegate;
- (id) initWithHostname:(NSString *)hostName;
- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode error:(NSError **)error;
@end

@interface SwitchamajigListener : NSObject
@property (nonatomic) id <SwitchamajigDeviceListenerDelegate> delegate;
- (id) initWithDelegate:(id)delegate_init;

@end

@interface SwitchamajigControllerDeviceDriver : SwitchamajigDriver {
}
@property BOOL useUDP;

@end

@protocol SwitchamajigIRDeviceDriverDelegate <SwitchamajigDeviceDriverDelegate>
@optional
- (void) SwitchamajigIRDeviceDriverDelegateDidReceiveLearnedIRCommand:(id)deviceDriver irCommand:(NSString *)irCommand;
- (void) SwitchamajigIRDeviceDriverDelegateErrorOnLearnIR:(id) deviceDriver error:(NSError *)error;
@end

@interface SwitchamajigIRDeviceDriver : SwitchamajigDriver {
}
- (void) startIRLearning;
+ (void) loadIRCodeDatabase:(NSString *)path error:(NSError **)error;
+ (NSString *) irCodeForFunction:(NSString *)function inCodeSet:(NSString*) codeSet onDevice:(NSString *)device forBrand:(NSString *)brand;
+ (NSArray *) getIRDatabaseBrands;
+ (NSArray *) getIRDatabaseDevicesForBrand:(NSString *)brand;
+ (NSArray *) getIRDatabaseCodeSetsOnDevice:(NSString *)device forBrand:(NSString *)brand;
+ (NSArray *) getIRDatabaseFunctionsInCodeSet:(NSString *)codeSet onDevice:(NSString *)device forBrand:(NSString *)brand;
+ (NSArray *) getIRDatabaseDevices;
+ (NSArray *) getIRDatabaseBrandsForDevice:(NSString *)device;
@end

@interface SwitchamajigControllerDeviceListener : SwitchamajigListener {

}
@end

@interface SwitchamajigIRDeviceListener : SwitchamajigListener {
    
}

@end
