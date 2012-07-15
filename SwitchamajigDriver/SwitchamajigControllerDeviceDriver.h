//
//  SwitchamajigControllerDeviceDriver.h
//  SwitchControl
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwitchamajigDriver.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"


@interface SwitchamajigControllerDeviceDriver () {
    id <SwitchamajigDeviceDriverDelegate> delegate;
    int switchState;
    GCDAsyncSocket *asyncSocket;
    NSLock *networkLock;
}

- (void) sendSwitchState;

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, strong) NSString *friendlyName;
@end


@interface SwitchamajigControllerDeviceListener () {
    id <SwitchamajigDeviceListenerDelegate> delegate;
}

@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;

@end


@interface SimulatedSwitchamajigController : NSObject <NSStreamDelegate> {
    NSInputStream *inputStream;
    GCDAsyncSocket *listenSocket;
    int switchState;
}
- (void) startListening;
- (void) stopListening;
- (int) getSwitchState;
- (void) sendHeartbeat:(char *)friendlyName batteryVoltageInmV:(int)batteryVoltageInmV;

@property (strong) GCDAsyncSocket *connectedSocket;
@property (strong) GCDAsyncUdpSocket *sendSocket;
@end