//
//  SwitchamajigDriver.h
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../../KissXML/KissXML/DDXMLDocument.h"

@protocol SwitchamajigDeviceDriverDelegate <NSObject> 
- (void) SwitchamajigDeviceDriverConnected:(id)deviceDriver;
- (void) SwitchamajigDeviceDriverDisconnected:(id)deviceDriver withError:(NSError*)error;
@end

@protocol SwitchamajigDeviceListenerDelegate <NSObject> 
- (void) SwitchamajigDeviceListenerFoundDevice:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname;
- (void) SwitchamajigDeviceListenerHandleError:(id)listener theError:(NSError*)error;
- (void) SwitchamajigDeviceListenerHandleBatteryWarning:(id)listener hostname:(NSString*)hostname friendlyname:(NSString*)friendlyname;
@end

@interface SwitchamajigDriver : NSObject
- (id) initWithHostname:(NSString *)hostName;
- (void) setDelegate:(id)delegate;
- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode;
@end

@interface SwitchamajigListener : NSObject
- (id) initWithDelegate:(id)delegate_init;

@end

@interface SwitchamajigControllerDeviceDriver : SwitchamajigDriver {
}

@end

@interface SwitchamajigControllerDeviceListener : SwitchamajigListener {

}

@end
