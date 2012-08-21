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
@end

@interface SwitchamajigControllerDeviceListener : SwitchamajigListener {

}
@end

@interface SwitchamajigIRDeviceListener : SwitchamajigListener {
    
}

@end
