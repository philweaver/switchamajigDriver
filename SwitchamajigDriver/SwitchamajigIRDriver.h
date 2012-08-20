//
//  SwitchamajigIRDriver.h
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/17/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigDriver.h"
#import "GCDAsyncSocket.h"

@interface SwitchamajigIRDeviceDriver () {
}
@end

@interface SwitchamajigIRDeviceListener () <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser *netServiceBrowser;
    NSURLConnection *puckStatusConnection;
    NSNetService *retainedNetService;
    NSString *hostName;
    NSMutableData *puckRequestData;
}

@end

@interface SimulatedSwitchamajigIR : NSObject {
    GCDAsyncSocket *listenSocket;
    GCDAsyncSocket *connectedSocket;
}
- (void) announcePresenceToListener:(SwitchamajigIRDeviceListener*)listener withHostName:(NSString *)hostname;
- (void) startListening;
@property int port;
@property NSString *deviceName;
@end