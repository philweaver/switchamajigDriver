//
//  SwitchamajigInsteonDriver.h
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/13/13.
//  Copyright (c) 2013 PAW Solutions. All rights reserved.
//

#import "SwitchamajigDriver.h"
#import "GCDAsyncSocket.h"

@interface SwitchamajigInsteonDeviceDriver() <NSURLConnectionDelegate> {
    NSURLConnection *connection;
}
@property (nonatomic, strong) NSString *hostName;

@end

@interface SwitchamajigInsteonDeviceListener() <NSURLConnectionDelegate> {
    
}

@end

@interface SimulatedInsteonDevice : NSObject {
    GCDAsyncSocket *listenSocket;
    GCDAsyncSocket *connectedSocket;
@public
    NSString *lastIssuedCommand;
}
- (void) startListeningOnPort:(int)portNum;
- (void) stopListening;
@end