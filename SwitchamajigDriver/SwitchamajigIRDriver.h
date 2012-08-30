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
@property (nonatomic, strong) NSString *hostName;
@end

@interface SwitchamajigIRDeviceListener () <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser *netServiceBrowser;
    NSMutableArray *netServices;
}

@end

@interface SimulatedSwitchamajigIR : NSObject {
    GCDAsyncSocket *listenSocket;
    GCDAsyncSocket *connectedSocket;
    int numPuckStatusRequests;
    int numIRLearnRequests;
    NSString *lastCommandReceived;
}
- (void) announcePresenceToListener:(SwitchamajigIRDeviceListener*)listener withHostName:(NSString *)hostname;
- (void) startListening;
- (void) stopListening;
- (void) returnPuckStatus;
- (void) resetPuckRequestCount;
- (int) getPuckRequestCount;
- (void) resetIRLearnRequestCount;
- (int) getIRLearnRequestCount;
- (NSString *) lastCommand;
- (void) returnIRLearningCommand:(NSString*)command;
- (void) returnIRLearningError;
@property int port;
@property NSString *deviceName;
@end