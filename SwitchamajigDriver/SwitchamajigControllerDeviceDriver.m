//
//  SwitchamajigControllerDeviceDriver.m
//  SwitchControl
//
//  Created by Phil Weaver on 5/27/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigControllerDeviceDriver.h"
#import "GCDAsyncSocket.h"
#include <stdlib.h>

@implementation SwitchamajigControllerDeviceDriver

@synthesize hostName;
@synthesize friendlyName;

#define ROVING_PORTNUM 2000
#define ROVING_LISTENPORT 55555
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
        [delegate SwitchamajigDeviceDriverDisconnected:self withError:error];
        NSLog(@"Error connecting: %@", error);
        return;
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
    if(err) {
        NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);
        [delegate SwitchamajigDeviceDriverDisconnected:self withError:err];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    [delegate SwitchamajigDeviceDriverConnected:self];
	//NSLog(@"socketDidConnect to port %d", port);
}

@end

@implementation SwitchamajigControllerDeviceListener

@synthesize udpSocket;

- (id) initWithDelegate:(id)delegate_init {
    self = [super init];
    delegate = delegate_init;
    // Set up UDP socket
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
	[self setUdpSocket:[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:mainQueue]];
    NSError *error;
    if(![[self udpSocket] bindToPort:ROVING_LISTENPORT error:&error]) {
        NSLog(@"SwitchamajigControllerDeviceListener: initWithDelegate: bindToPort failed: %@", error);
        [delegate SwitchamajigDeviceListenerHandleError:self theError:error];
    } else {
        if(![[self udpSocket] beginReceiving:&error]) {
            NSLog(@"SwitchamajigControllerDeviceListener: initWithDelegate: beginReceiving failed: %@", error);
            [delegate SwitchamajigDeviceListenerHandleError:self theError:error];
        }
    }
    
    return self;
}

#define EXPECTED_PACKET_SIZE 110
#define DEVICE_STRING_OFFSET 60
#define BATTERY_VOLTAGE_OFFSET 14
#define BATTERY_VOLTAGE_WARN_LIMIT 2000

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    const unsigned char *packet = [data bytes];
    if([data length] == EXPECTED_PACKET_SIZE) {
        // Get the IP address in string format
        NSString *hostname = [GCDAsyncUdpSocket hostFromAddress:address];
        NSLog(@"Switchamajig found with hostname %@", hostname);
        //printf("Received: %s from %s\n", buffer+DEVICE_STRING_OFFSET, ip_addr_string);
        NSString *switchName = [NSString stringWithCString:(char*)packet+DEVICE_STRING_OFFSET encoding:NSASCIIStringEncoding];
        int batteryVoltage = ((unsigned char)packet[BATTERY_VOLTAGE_OFFSET]) * 256 + ((unsigned char)packet[BATTERY_VOLTAGE_OFFSET + 1]);
        if(batteryVoltage < BATTERY_VOLTAGE_WARN_LIMIT) {
            [delegate SwitchamajigDeviceListenerHandleBatteryWarning:self hostname:hostname friendlyname:switchName];
        }
        [delegate SwitchamajigDeviceListenerFoundDevice:self hostname:hostname friendlyname:switchName];
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    if(error != nil) {
        NSLog(@"SwitchamajigControllerDeviceListener: udpSocketDidClose: %@", error);
        [delegate SwitchamajigDeviceListenerHandleError:self theError:error];
    }
}

@end

@implementation SimulatedSwitchamajigController

@synthesize connectedSocket;
@synthesize sendSocket;

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
    [listenSocket setDelegate:nil];
    [listenSocket disconnect];
    [connectedSocket setDelegate:nil];
    [connectedSocket disconnect];
}

- (void) sendHeartbeat:(char *)friendlyName batteryVoltageInmV:(int)batteryVoltageInmV {
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
	[self setSendSocket:[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:mainQueue]];
    unsigned char packet[EXPECTED_PACKET_SIZE];
    memset(packet, 0, sizeof(packet));
    strncpy((char*)packet+DEVICE_STRING_OFFSET, friendlyName, (EXPECTED_PACKET_SIZE-DEVICE_STRING_OFFSET));
    packet[BATTERY_VOLTAGE_OFFSET] = (unsigned char) (batteryVoltageInmV >> 8);
    packet[BATTERY_VOLTAGE_OFFSET+1] = (unsigned char) batteryVoltageInmV;
    [[self sendSocket] sendData:[NSData dataWithBytes:packet length:sizeof(packet)] toHost:@"localhost" port:ROVING_LISTENPORT withTimeout:1.0 tag:0];
    [[self sendSocket] closeAfterSending];
}

@end