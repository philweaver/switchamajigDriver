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

// Includes for socket
#import "sys/socket.h"
#import "netinet/in.h"
#import "netdb.h"
#import "sys/unistd.h"
#import "sys/fcntl.h"
#import "sys/poll.h"
#import "arpa/inet.h"
#import "errno.h"
#import "socket_switchamajig1_cfg.hpp"

@implementation SwitchamajigControllerDeviceDriver

@synthesize hostName;
@synthesize friendlyName;
@synthesize useUDP;
#define ROVING_PORTNUM 2000
#define ROVING_LISTENPORT 55555
#define MAX_SWITCH_NUMBER 6

- (id) initWithHostname:(NSString *)newHostName {
    self = [super init];
    [self setHostName:newHostName];
    networkLock = [[NSLock alloc] init];
    return self;
}

- (void) setDelegate:(id)newDelegate {
    delegate = newDelegate;
    // Send packet to turn switches off
    switchState = 0;
    [self sendSwitchState];
}

// Send command specified in XML
- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode error:(NSError *__autoreleasing *)error{
    NSString *command = [xmlCommandNode name];
    if([command isEqualToString:@"turnSwitchesOn"]) {
        NSString *switchOnString = [xmlCommandNode stringValue];
        NSScanner *switchOnScan = [[NSScanner alloc] initWithString:switchOnString];
        int switchNumber;
        while([switchOnScan scanInt:&switchNumber]) {
            if((switchNumber > 0) && (switchNumber <= MAX_SWITCH_NUMBER)) {
                switchState |= 1 << (switchNumber-1);
            }
        }
        [self sendSwitchState];
    } else if([command isEqualToString:@"turnSwitchesOff"]) {
        NSString *switchOffString = [xmlCommandNode stringValue];
        NSScanner *switchOffScan = [[NSScanner alloc] initWithString:switchOffString];
        int switchNumber;
        while([switchOffScan scanInt:&switchNumber]) {
            if((switchNumber > 0) && (switchNumber <= MAX_SWITCH_NUMBER)) {
                switchState &= ~(1 << (switchNumber-1));
            }
        }
        [self sendSwitchState];
    } else if ([command isEqualToString:@"setDeviceName"]) {
        NSString *newName = [xmlCommandNode stringValue];
        int socket = switchamajig1_open_socket([[self hostName] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        if(!socket) {
            NSLog(@"setDeviceName: null socket");
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorNullSocket userInfo:nil];
            return;
        }
        bool status = switchamajig1_enter_command_mode(socket);
        if(status)
            status = switchamajig1_set_name(socket, [newName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        if(status)
            status = switchamajig1_save(socket);
        if(!status) {
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorConfigProblem userInfo:nil];
            NSLog(@"Error executing setDeviceName");
        }
        switchamajig1_close_socket(socket);
    } else if ([command isEqualToString:@"configureDeviceNetworking"]) {
        DDXMLNode *ssidNode = [(DDXMLElement *)xmlCommandNode attributeForName:@"ssid"];
        if(!ssidNode){
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorBadArguments userInfo:nil];
            NSLog(@"configureDeviceNetworking: no ssid");
            return;
        }
        NSString *ssid = [ssidNode stringValue];

        DDXMLNode *chanNode = [(DDXMLElement *)xmlCommandNode attributeForName:@"channel"];
        if(!chanNode){
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorBadArguments userInfo:nil];
            NSLog(@"configureDeviceNetworking: no channel node");
            return;
        }
        NSString *chanString = [chanNode stringValue];
        NSScanner *chanScan = [[NSScanner alloc] initWithString:chanString];
        int channel;
        if(![chanScan scanInt:&channel]) {
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorBadArguments userInfo:nil];
            NSLog(@"configureDeviceNetworking: no channel");
            return;
        }

        DDXMLNode *passphraseNode = [(DDXMLElement *)xmlCommandNode attributeForName:@"passphrase"];
        if(!passphraseNode){
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorBadArguments userInfo:nil];
            NSLog(@"configureDeviceNetworking: no passphrase");
            return;
        }
        NSString *passphrase = [passphraseNode stringValue];
        
        int socket = switchamajig1_open_socket([[self hostName] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        if(!socket) {
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorNullSocket userInfo:nil];
            NSLog(@"configureDeviceNetworking: null socket");
            return;
        }
        bool status = switchamajig1_enter_command_mode(socket);
        struct switchamajig1_network_info newInfo;
        newInfo.channel = channel;
        NSString *ssidWithDollars = [ssid stringByReplacingOccurrencesOfString:@" " withString:@"$"];
        strncpy(newInfo.ssid, [ssidWithDollars UTF8String], sizeof(newInfo.ssid));
        NSString *phraseWithDollars = [passphrase stringByReplacingOccurrencesOfString:@" " withString:@"$"];
        if(![phraseWithDollars length])
            strncpy(newInfo.passphrase, "none", sizeof(newInfo.passphrase));
        else
            strncpy(newInfo.passphrase, [phraseWithDollars cStringUsingEncoding:NSUTF8StringEncoding], sizeof(newInfo.passphrase));
        if(status)
            status = switchamajig1_set_netinfo(socket, &newInfo);
        if(status)
            status = switchamajig1_save(socket);
        if(status)
            status = switchamajig1_exit_command_mode(socket);
        if(status)
            status = switchamajig1_write_eeprom(socket, 0, 0);
        if(status)
            status = switchamajig1_reset(socket);
        if(!status) {
            *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorConfigProblem userInfo:nil];
        }
        switchamajig1_close_socket(socket);
    } else {
        *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorUnknownCommand userInfo:nil];
    }
}

#define SWITCHAMAJIG_PACKET_LENGTH 8
#define SWITCHAMAJIG_PACKET_BYTE_0 255
#define SWITCHAMAJIG_CMD_SET_RELAY 0
#define SWITCHAMAJIG_TIMEOUT 5

- (void) sendSwitchState {
    [networkLock lock];
    unsigned char packet[SWITCHAMAJIG_PACKET_LENGTH];
    memset(packet, 0, sizeof(packet));
    packet[0] = SWITCHAMAJIG_PACKET_BYTE_0;
    packet[1] = SWITCHAMAJIG_CMD_SET_RELAY;
    packet[2] = switchState & 0x0f;
    packet[3] = (switchState >> 4) & 0x0f;

    if([self useUDP]) {
        // Create UDP socket
        int server_socket = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if(server_socket <= 0) {
            NSLog(@"SwitchamajigControllerDeviceDriver: sendSwitchState: unable to open UDP socket");
            [networkLock unlock];
            return;
        }
        char on = 1;
        setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
        // Set timeout on all operations to 1 second
        struct timeval tv;
        tv.tv_sec = 1;
        tv.tv_usec = 0;
        setsockopt(server_socket, SOL_SOCKET, SO_SNDTIMEO, (void *)&tv, sizeof(tv));
        setsockopt(server_socket, SOL_SOCKET, SO_RCVTIMEO, (void *)&tv, sizeof(tv));
        char ip_addr_string[2*INET6_ADDRSTRLEN];
        [hostName getCString:ip_addr_string maxLength:sizeof(ip_addr_string) encoding:[NSString defaultCStringEncoding]];
        struct hostent *host = gethostbyname(ip_addr_string);
        if(!host) {
            NSLog(@"SwitchamajigControllerDeviceDriver: sendSwitchState: unable to resolve host");
            close(server_socket);
            [networkLock unlock];
            return;
        }
        struct sockaddr_in sin;
        memcpy(&sin.sin_addr.s_addr, host->h_addr, host->h_length);
        sin.sin_family = AF_INET;
        sin.sin_port = htons(ROVING_PORTNUM);
        // Prevent signals; we'll handle error messages instead
        int on2;
        setsockopt(server_socket, SOL_SOCKET, SO_NOSIGPIPE, &on2, sizeof(on2));
        if(sendto(server_socket, packet, sizeof(packet), 0, (struct sockaddr*) &sin, sizeof(sin)) < 0) {
            NSLog(@"SwitchamajigControllerDeviceDriver: sendSwitchState: unable to sendto UDP socket");
        }
        close(server_socket);
        
    } else {
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
        NSError *error = nil;
        if (![asyncSocket connectToHost:hostName onPort:ROVING_PORTNUM error:&error])
        {
            [delegate SwitchamajigDeviceDriverDisconnected:self withError:error];
            NSLog(@"Error connecting: %@", error);
            [networkLock unlock];
            return;
        }
        [asyncSocket writeData:[NSData dataWithBytes:packet length:SWITCHAMAJIG_PACKET_LENGTH] withTimeout:SWITCHAMAJIG_TIMEOUT tag:0];
        [asyncSocket disconnectAfterWriting];
    }
    [networkLock unlock];
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
    [[self udpSocket] setIPv4Enabled:YES];
    [[self udpSocket] setIPv6Enabled:NO];
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
    // Listen to Switchamajig TCP port number
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![listenSocket acceptOnPort:ROVING_PORTNUM error:&error])
    {
        NSLog(@"Error trying to listen: %@", error);
    }
    
    // Also listen as UDP
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
	udpListenSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
    [udpListenSocket setIPv4Enabled:YES];
    [udpListenSocket setIPv6Enabled:NO];
    if(![udpListenSocket bindToPort:ROVING_PORTNUM error:&error]) {
        NSLog(@"SimulatedSwitchamajigController: startListening: bindToPort failed: %@", error);
    } else {
        if(![udpListenSocket beginReceiving:&error]) {
            NSLog(@"SimulatedSwitchamajigController: startListening: beginReceiving failed: %@", error);
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    [self setConnectedSocket:newSocket];
    [newSocket readDataToLength:SWITCHAMAJIG_PACKET_LENGTH withTimeout:-1 tag:0];
    NSLog(@"SimulatedSwitchamajigController: accepted new socket");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    const unsigned char *packet = [data bytes];
    int datalen = [data length];
    lastPacketWasUDP = false;
    if(datalen != 8) {
        NSLog(@"Simulated Switchamajig Controller received packet of %d bytes. Ignoring.", datalen);
    }
    if((packet[0] == SWITCHAMAJIG_PACKET_BYTE_0) && (packet[1] == SWITCHAMAJIG_CMD_SET_RELAY))  {
        int newSwitchState = packet[2] & 0x0f;
        newSwitchState |= (packet[3] & 0x0f) << 4;
        switchState = newSwitchState;
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    const unsigned char *packet = [data bytes];
    int datalen = [data length];
    lastPacketWasUDP = true;
    if(datalen != 8) {
        NSLog(@"Simulated Switchamajig Controller received UDP packet of %d bytes. Ignoring.", datalen);
    }
    if((packet[0] == SWITCHAMAJIG_PACKET_BYTE_0) && (packet[1] == SWITCHAMAJIG_CMD_SET_RELAY))  {
        int newSwitchState = packet[2] & 0x0f;
        newSwitchState |= (packet[3] & 0x0f) << 4;
        switchState = newSwitchState;
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
}

- (int) getSwitchState {
    return switchState;
}

- (bool) wasLastPacketUDP {
    return lastPacketWasUDP;
}

- (void) stopListening {
    [udpListenSocket setDelegate:nil];
    [udpListenSocket close];
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