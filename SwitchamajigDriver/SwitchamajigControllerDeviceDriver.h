//
//  SwitchamajigControllerDeviceDriver.h
//  SwitchControl
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwitchamajigDriver.h"
#import "../../KissXML/KissXML/DDXMLDocument.h"
#import "GCDAsyncSocket.h"
enum SwitchamajigDeviceDriverNotification {
    SWITCHAMAJIG_AVAILABLE = 1,
    SWITCHAMAJIG_UNAVAILABLE = 2
    };

@protocol SwitchamajigDeviceDriverDelegate <NSObject> 
- (void) switchamajigDeviceDriverHandleEvents:(id)deviceDriver notification:(enum SwitchamajigDeviceDriverNotification)notification;
@end

@interface SwitchamajigControllerDeviceDriver : SwitchamajigDriver {
    id <SwitchamajigDeviceDriverDelegate> delegate;
    int switchState;
    GCDAsyncSocket *asyncSocket;
    
}

- (id) initWithHostname:(NSString *)hostName;
- (void) setDelegate:(id)delegate;
- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode;
- (void) sendSwitchState;

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, strong) NSString *friendlyName;
@end

@interface SimulatedSwitchamajigController : NSObject <NSStreamDelegate> {
    NSInputStream *inputStream;
    GCDAsyncSocket *listenSocket;
    int switchState;
}
- (void) startListening;
- (void) stopListening;
- (int) getSwitchState;

@property (strong) GCDAsyncSocket *connectedSocket;
@end