//
//  SwitchamajigIRDriver.m
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/17/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigIRDriver.h"
#import "arpa/inet.h"

#define SQ_PORTNUM 80
#define SWITCHAMAJIG_TIMEOUT 5

@implementation SwitchamajigIRDeviceDriver
@end

@implementation SwitchamajigIRDeviceListener

- (id) initWithDelegate:(id <SwitchamajigDeviceListenerDelegate>)delegate_init {
    self = [super init];
    if(self) {
        [super setDelegate:delegate_init];
        // Create browser to listen for Bonjour services
        netServiceBrowser = [[NSNetServiceBrowser alloc] init];
        [netServiceBrowser setDelegate:self];
        [netServiceBrowser searchForServicesOfType:@"_sqp._tcp." inDomain:@""];
    }
    return self;
}

// NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
    NSLog(@"didFindDomain: %@\n", domainName);
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"didFindService %@\n", [netService hostName]);
    [netService setDelegate:self];
    retainedNetService = netService; // Prevent netService from disappearing
    [netService resolveWithTimeout:0];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didNotSearch:(NSDictionary *)errorInfo {
    NSLog(@"didNotSearch: %@ %@\n", [errorInfo objectForKey:NSNetServicesErrorCode], [errorInfo objectForKey:NSNetServicesErrorDomain]);
    
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
    printf("didRemoveDomain\n");
    
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    printf("didRemoveService\n");
    
}
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser {
    printf("netServiceBrowserDidStopSearch\n");
    
}
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser {
    printf("netServiceBrowserWillSearch\n");
    
}
// NSNetServiceDelegate
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    NSLog(@"didNotPublish\n");
}
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict{
    NSLog(@"didNotResolve\n");
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data{
    NSLog(@"didUpdateTXTRecordData\n");
}

- (void)netServiceDidPublish:(NSNetService *)sender{
    NSLog(@"netServiceDidPublish\n");
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    // We've found a candidate for a Switchamajig IR. Send it a "puckstatus" request. We'll know from
    // the response if this is a true IR unit
    hostName = [sender hostName];
    NSLog(@"port %d", [sender port]);
    NSString *puckStatusRequestString = [NSString stringWithFormat:@"http://%@:%d/puckStatus.xml", [sender hostName], [sender port]];
    NSURLRequest *puckStatusRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:puckStatusRequestString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:SWITCHAMAJIG_TIMEOUT];
    puckStatusConnection = [[NSURLConnection alloc] initWithRequest:puckStatusRequest delegate:self];
    if(!puckStatusConnection) {
        NSLog(@"SwitchamajigIRDeviceListener: netServiceDidResolveAddress: connection failed\n");
        return;
    }
    puckRequestData = [NSMutableData data];
}

- (void)netServiceDidStop:(NSNetService *)sender{
    NSLog(@"netServiceDidStop\n");
}

- (void)netServiceWillPublish:(NSNetService *)sender{
    NSLog(@"netServiceWillPublish\n");
}

- (void)netServiceWillResolve:(NSNetService *)sender{
    NSLog(@"netServiceWillResolve\n");
}

// NSURLConnection Delegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [puckRequestData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [puckRequestData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // Release the connection
    puckStatusConnection = nil;
    puckRequestData = nil;
    // Log error
    NSLog(@"SwitchamajigIRDeviceListener: connection didFailWithError - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading. Received %d bytes of data",[puckRequestData length]);

    NSError *error;
    DDXMLDocument *puckResponse = [[DDXMLDocument alloc] initWithData:puckRequestData options:0 error:&error];

    if(error) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: xml document error %@", error);
        return;
    }
    NSArray *nameNodes = [puckResponse nodesForXPath:@".//puckdata/name" error:&error];
    if(error) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error getting name: %@", error);
        return;
    }
    if([nameNodes count]) {
        NSString *friendlyNameRaw = [[nameNodes objectAtIndex:0] stringValue];
        NSLog(@"Found unit with name %@", friendlyNameRaw);
        // Cover up SQ Blaster stuff
        NSString *friendlyName = [friendlyNameRaw stringByReplacingOccurrencesOfString:@"sq-blaster" withString:@"SwitchamajigIR"];
        [[self delegate] SwitchamajigDeviceListenerFoundDevice:self hostname:hostName friendlyname:friendlyName];
        
    }
    puckRequestData = nil;
    puckStatusConnection = nil;
}

@end

@interface mockNetService : NSNetService {
    NSString *hostname;
}
- (void) setHostName:(NSString *)newHostName;
- (NSString *) hostName;
@end

@implementation mockNetService
- (void) setHostName:(NSString *)newHostName {
    hostname = newHostName;
}
- (NSString *) hostName {
    return hostname;
}
@end

@implementation SimulatedSwitchamajigIR
@synthesize port;

- (void) announcePresenceToListener:(SwitchamajigIRDeviceListener*)listener withHostName:(NSString *)hostname {
    mockNetService *netService = [[mockNetService alloc] initWithDomain:@"" type:@"" name:hostname port:[self port]];
    [netService setHostName:hostname];
    [listener netServiceDidResolveAddress:netService];
}

- (void) startListening {
    // Listen to Switchamajig TCP port number
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![listenSocket acceptOnPort:[self port] error:&error])
    {
        NSLog(@"SimulatedSwitchamajigIR: startListening: Error trying to listen: %@", error);
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    connectedSocket = newSocket;
    [newSocket readDataWithTimeout:-1 tag:0];
    NSLog(@"SimulatedSwitchamajigController: accepted new socket");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    int datalen = [data length];
    NSLog(@"Simulated Switchamajig Controller received packet of %d bytes.", datalen);
    NSString *readString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"SimulatedSwitchamajigIR: didReadData. Received %@", readString);
    BOOL isPuckStatus = [[NSPredicate predicateWithFormat:@"SELF contains \"GET /puckStatus.xml\""] evaluateWithObject:readString];
    if(isPuckStatus) {
        NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <puckdata> <name>%@</name> </puckdata>", [self deviceName]];
        NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
        NSLog(@"header = %@", header);
        NSLog(@"response = %@", response);
        [sock writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        [sock writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    }
}


@end

