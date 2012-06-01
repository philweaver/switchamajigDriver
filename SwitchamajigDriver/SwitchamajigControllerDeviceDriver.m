//
//  SwitchamajigControllerDeviceDriver.m
//  SwitchControl
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigControllerDeviceDriver.h"
#import "GCDAsyncSocket.h"

@implementation SwitchamajigControllerDeviceDriver

@synthesize hostName;
@synthesize friendlyName;

#define ROVING_PORTNUM 2000
#define MAX_SWITCH_NUMBER 6

- (id) initWithHostname:(NSString *)newHostName {
    self = [super init];
    [self setHostName:newHostName];
    return self;
}

- (void) setDelegate:(id)newDelegate {
    delegate = newDelegate;
    // Send packet to turn switches off
    switchState = 0;
    [self sendSwitchState];
}

// Send command specified in XML
- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode {
    NSError *xmlError=nil;
    NSArray *switchOnNodes = [xmlCommandNode nodesForXPath:@".//turnSwitchesOn" error:&xmlError];
    NSArray *switchOffNodes = [xmlCommandNode nodesForXPath:@".//turnSwitchesOff" error:&xmlError];
    //NSArray *sequenceNodes = [xmlCommandNode nodesForXPath:@".//switchsequence" error:&xmlError];
    if([switchOnNodes count]) {
        DDXMLNode *switchOnNode = [switchOnNodes objectAtIndex:0];
        NSString *switchOnString = [switchOnNode stringValue];
        NSScanner *switchOnScan = [[NSScanner alloc] initWithString:switchOnString];
        int switchNumber;
        while([switchOnScan scanInt:&switchNumber]) {
            if((switchNumber > 0) && (switchNumber <= MAX_SWITCH_NUMBER)) {
                switchState |= 1 << (switchNumber-1);
            }
        }
    }
           
    if([switchOffNodes count]) {
        DDXMLNode *switchOffNode = [switchOffNodes objectAtIndex:0];
        NSString *switchOffString = [switchOffNode stringValue];
        NSScanner *switchOffScan = [[NSScanner alloc] initWithString:switchOffString];
        int switchNumber;
        while([switchOffScan scanInt:&switchNumber]) {
            if((switchNumber > 0) && (switchNumber <= MAX_SWITCH_NUMBER)) {
                switchState &= ~(1 << (switchNumber-1));
            }
        }
    }
    [self sendSwitchState];
}

#define SWITCHAMAJIG_PACKET_LENGTH 8
#define SWITCHAMAJIG_PACKET_BYTE_0 255
#define SWITCHAMAJIG_CMD_SET_RELAY 0
#define SWITCHAMAJIG_TIMEOUT 5
- (void) sendSwitchState {
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
	asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
    NSError *error = nil;
    if (![asyncSocket connectToHost:hostName onPort:ROVING_PORTNUM error:&error])
    {
        NSLog(@"Error connecting: %@", error);
    }
    unsigned char packet[SWITCHAMAJIG_PACKET_LENGTH];
    memset(packet, 0, sizeof(packet));
    packet[0] = SWITCHAMAJIG_PACKET_BYTE_0;
    packet[1] = SWITCHAMAJIG_CMD_SET_RELAY;
    packet[2] = switchState & 0x0f;
    packet[3] = (switchState >> 4) & 0x0f;
    [asyncSocket writeData:[NSData dataWithBytes:packet length:SWITCHAMAJIG_PACKET_LENGTH] withTimeout:SWITCHAMAJIG_TIMEOUT tag:0];
    [asyncSocket disconnectAfterWriting];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);
}

- (void)socketDidConnectToHost:(GCDAsyncSocket *)sock port:(UInt16)port
{
	NSLog(@"socketDidConnect to port %d", port);
}

@end

@implementation SimulatedSwitchamajigController

@synthesize connectedSocket;

- (void) startListening {
    switchState = 0;
    // Listen to Switchamajig port number
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![listenSocket acceptOnPort:ROVING_PORTNUM error:&error])
    {
        NSLog(@"Error trying to listen: %@", error);
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    [self setConnectedSocket:newSocket];
    [newSocket readDataToLength:SWITCHAMAJIG_PACKET_LENGTH withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    const unsigned char *packet = [data bytes];
    if((packet[0] == SWITCHAMAJIG_PACKET_BYTE_0) && (packet[1] == SWITCHAMAJIG_CMD_SET_RELAY))  {
        int newSwitchState = packet[2] & 0x0f;
        newSwitchState |= (packet[3] & 0x0f) << 4;
        switchState = newSwitchState;
    }
}

- (int) getSwitchState {
    return switchState;
}

- (void) stopListening {
    [listenSocket disconnect];
    [connectedSocket disconnect];
}

@end