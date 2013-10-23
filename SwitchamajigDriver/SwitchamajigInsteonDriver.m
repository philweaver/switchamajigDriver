//
//  SwitchamajigInsteonDriver.m
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/13/13.
//  Copyright (c) 2013 PAW Solutions. All rights reserved.
//

#import "SwitchamajigInsteonDriver.h"
#import "SJAugmentedNSURLConnection.h"
#define SWITCHAMAJIG_TIMEOUT 15

@implementation SwitchamajigInsteonDeviceDriver
@synthesize hostName;

- (id) initWithHostname:(NSString *)newHostName {
    self = [super init];
    [self setHostName:newHostName];
    return self;
}

- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode error:(NSError *__autoreleasing *)err {
    NSString *command = [xmlCommandNode name];
    if([command isEqualToString:@"insteon_send"]) {
        // Extract username, password, dst_addr, cmd, and (optionally) level
        NSArray *dst_addrs = [xmlCommandNode nodesForXPath:@".//dst_addr" error:err];
        if([dst_addrs count] < 1) {
            NSLog(@"Can't find dst_addr. Count = %d. Node string = %@", [dst_addrs count], [xmlCommandNode XMLString]);
            return;
        }
        DDXMLNode *dst_addrNode = [dst_addrs objectAtIndex:0];
        NSString *dst_addr = [dst_addrNode stringValue];
        if(dst_addr == nil) {
            NSLog(@"performActionSequence: dst_addr is nil. Node string = %@", [xmlCommandNode XMLString]);
            return;
        }
        
        NSArray *usernames = [xmlCommandNode nodesForXPath:@".//username" error:err];
        if([usernames count] < 1) {
            NSLog(@"Can't find username. Count = %d. Node string = %@", [usernames count], [xmlCommandNode XMLString]);
            return;
        }
        DDXMLNode *usernameNode = [usernames objectAtIndex:0];
        NSString *username = [usernameNode stringValue];
        if(username == nil) {
            NSLog(@"performActionSequence: username is nil. Node string = %@", [xmlCommandNode XMLString]);
            return;
        }

        NSArray *passwords = [xmlCommandNode nodesForXPath:@".//password" error:err];
        if([dst_addrs count] < 1) {
            NSLog(@"Can't find password. Count = %d. Node string = %@", [passwords count], [xmlCommandNode XMLString]);
            return;
        }
        DDXMLNode *passwordNode = [passwords objectAtIndex:0];
        NSString *password = [passwordNode stringValue];
        if(password == nil) {
            NSLog(@"performActionSequence: password is nil. Node string = %@", [xmlCommandNode XMLString]);
            return;
        }

        NSArray *commands = [xmlCommandNode nodesForXPath:@".//command" error:err];
        if([commands count] < 1) {
            NSLog(@"Can't find command. Count = %d. Node string = %@", [commands count], [xmlCommandNode XMLString]);
            return;
        }
        DDXMLNode *commandNode = [commands objectAtIndex:0];
        NSString *commandInString = [commandNode stringValue];
        NSString *commandOutString = nil;
        if([commandInString isEqualToString:@"ON"])
            commandOutString = @"11"; // Hex code for 'on'
        if([commandInString isEqualToString:@"OFF"])
            commandOutString = @"13"; // Hex code for 'off'
        if(commandOutString == nil) {
            NSLog(@"SwitchamajigInsteonDriver: unrecognized command: %@", commandInString);
            return;
        }
        int level = 255;
        NSArray *levels = [xmlCommandNode nodesForXPath:@".//level" error:err];
        if([levels count] >= 1) {
            DDXMLNode *levelNode = [levels objectAtIndex:0];
            NSString *levelString = [levelNode stringValue];
            NSScanner *levelScan = [[NSScanner alloc] initWithString:levelString];
            [levelScan scanInt:&level];
        }
        
        if(dst_addr == nil) {
            NSLog(@"performActionSequence: dst_addr is nil. Node string = %@", [xmlCommandNode XMLString]);
            return;
        }
        NSString *requestString = [NSString stringWithFormat:@"http://%@:%@@%@/3?0262%@0F%@%02x=I=3", username, password, hostName, dst_addr, commandOutString, level];
        NSLog(@"SwitchamajigInsteonDeviceDriver: Sending %@", requestString);
        NSMutableURLRequest *commandRequest=[[NSMutableURLRequest alloc] init];
        [commandRequest setURL:[NSURL URLWithString:requestString]];
        [commandRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        [commandRequest setTimeoutInterval:SWITCHAMAJIG_TIMEOUT];
        [commandRequest setHTTPMethod:@"GET"];
        connection = [[NSURLConnection alloc] initWithRequest:commandRequest delegate:self startImmediately:YES];
    }
    if([command isEqualToString:@"insteon_link"]) {
        // Get optional group
        int group = 167; // Good as any number
        NSArray *groups = [xmlCommandNode nodesForXPath:@".//group" error:err];
        if([groups count] >= 1) {
            DDXMLNode *groupNode = [groups objectAtIndex:0];
            NSString *groupString = [groupNode stringValue];
            NSScanner *groupScan = [[NSScanner alloc] initWithString:groupString];
            [groupScan scanInt:&group];
        }
        NSString *requestString = [NSString stringWithFormat:@"%@/0?09%d=I=0", hostName, group];
        NSMutableURLRequest *commandRequest=[[NSMutableURLRequest alloc] init];
        [commandRequest setURL:[NSURL URLWithString:requestString]];
        [commandRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        [commandRequest setTimeoutInterval:SWITCHAMAJIG_TIMEOUT];
        [commandRequest setHTTPMethod:@"GET"];
        connection = [[NSURLConnection alloc] initWithRequest:commandRequest delegate:self startImmediately:YES];
    }
}

// NSURLConnection Delegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    return;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"SwitchamajigInsteonDriver: received %d bytes: %@", [data length], response);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
}

@end

@implementation SwitchamajigInsteonDeviceListener
- (id) initWithDelegate:(id)delegate_init andURL:(NSURL *)url {
    self = [super init];
    if(self) {
        [super setDelegate:delegate_init];
        // Request the address of the insteon hub from Insteon's website
        NSURLRequest *insteonAddressRequest=[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
        SJAugmentedNSURLConnection *insteonAddressConnectionAug = [[SJAugmentedNSURLConnection alloc] initWithRequest:insteonAddressRequest delegate:self];
        if(!insteonAddressConnectionAug) {
            NSLog(@"SwitchamajigInsteonDeviceListener: netServiceDidResolveAddress: connection failed\n");
            return self;
        }
        [insteonAddressConnectionAug setSJData:[NSMutableData data]];
    }
    return self;
    
}
// Init with default URL
- (id) initWithDelegate:(id <SwitchamajigDeviceListenerDelegate>)delegate_init {
    return [self initWithDelegate:delegate_init andURL:[NSURL URLWithString:@"http://connect.insteon.com/getinfo.asp"]];
}


// NSURLConnection Delegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    SJAugmentedNSURLConnection *augConnection = (SJAugmentedNSURLConnection *)connection;
    [[augConnection SJData] setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    SJAugmentedNSURLConnection *augConnection = (SJAugmentedNSURLConnection *)connection;
    [[augConnection SJData] appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // Log error
    NSLog(@"SwitchamajigInsteonDeviceListener: connection didFailWithError - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
    SJAugmentedNSURLConnection *connection = (SJAugmentedNSURLConnection *)conn;
    NSLog(@"SwitchamajigInsteonDeviceListener: connectionDidFinishLoading. Received %d bytes of data",[[connection SJData] length]);
    NSString *httpResponse = [[NSString alloc] initWithData:[connection SJData] encoding:NSUTF8StringEncoding];
    NSLog(@"Received %@\n", httpResponse);
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Click on the Link Below to access SmartLinc.*?http:\\/\\/([\\d\\.:]*)" options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    if(error) {
        NSLog(@"SwitchamajigInsteonDeviceListener: error creating regex: %@", error);
        return;
    }
    NSTextCheckingResult *match = [regex firstMatchInString:httpResponse options:0 range:NSMakeRange(0, [httpResponse length])];
    if (!NSEqualRanges([match range], NSMakeRange(NSNotFound, 0))) {
        NSString *hostname = [httpResponse substringWithRange:[match rangeAtIndex:1]];
        NSLog(@"Hostname is %@\n", hostname);
        [[self delegate] SwitchamajigDeviceListenerFoundDevice:self hostname:[connection SJHostName] friendlyname:@"Insteon"];
    } else {
        NSLog(@"No match");
    }
}

@end
/*
@interface SimulatedInsteonDevice : NSObject {
    GCDAsyncSocket *listenSocket;
    GCDAsyncSocket *connectedSocket;
@public
    NSString *lastUserName;
    NSString *lastPassword;
    NSString *lastIssuedCommand;
}*/

@implementation SimulatedInsteonDevice

- (void) startListeningOnPort:(int)portNum {
    // Listen to Switchamajig TCP port number
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![listenSocket acceptOnPort:portNum error:&error])
    {
        NSLog(@"SimulatedInsteonDevice: startListening: Error trying to listen: %@", error);
    }
}

- (void) stopListening {
    [connectedSocket disconnect];
    [listenSocket disconnect];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    connectedSocket = newSocket;
    [newSocket readDataWithTimeout:-1 tag:0];
    //NSLog(@"SimulatedSwitchamajigController: accepted new socket");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog(@"Simulated Switchamajig Controller received packet of %d bytes.", [data length]);
    lastIssuedCommand = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"SimulatedInsteonDevice: didReadData. Received %@", lastIssuedCommand);
    // Keep reading
    [sock readDataWithTimeout:-1 tag:0];
}

@end