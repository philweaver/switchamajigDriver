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

@interface SJAugmentedNSURLConnection : NSURLConnection {
    
}
@property NSString *SJHostName;
@property NSMutableData *SJData;
@end

@implementation SJAugmentedNSURLConnection
@synthesize SJHostName;
@synthesize SJData;

@end


@implementation SwitchamajigIRDeviceDriver
@synthesize hostName;

- (id) initWithHostname:(NSString *)newHostName {
    self = [super init];
    [self setHostName:newHostName];
    return self;
}

- (void) issueCommandFromXMLNode:(DDXMLNode*) xmlCommandNode error:(NSError *__autoreleasing *)error {
    NSString *commandString = [NSString stringWithFormat:@"http://%@/docmnd.xml", [self hostName]];
    NSMutableURLRequest *commandRequest=[[NSMutableURLRequest alloc] init];
    [commandRequest setURL:[NSURL URLWithString:commandString]];
    [commandRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [commandRequest setTimeoutInterval:SWITCHAMAJIG_TIMEOUT];
    [commandRequest setHTTPMethod:@"POST"];
    NSString *commandXMLString = [xmlCommandNode XMLString];
    //NSLog(@"commandXMLString = %@", commandXMLString);
    [commandRequest setHTTPBody:[commandXMLString dataUsingEncoding:NSUTF8StringEncoding]];
    SJAugmentedNSURLConnection *connection = [[SJAugmentedNSURLConnection alloc] initWithRequest:commandRequest delegate:self];
    [connection setSJData:[NSMutableData data]];
}

- (void) startIRLearning {
    NSString *learnIRRequestString = [NSString stringWithFormat:@"http://%@/learnIR.xml", [self hostName]];
    NSURLRequest *learnIRRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:learnIRRequestString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:SWITCHAMAJIG_TIMEOUT];
    SJAugmentedNSURLConnection *connection = [[SJAugmentedNSURLConnection alloc] initWithRequest:learnIRRequest delegate:self];
    [connection setSJData:[NSMutableData data]];
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
    NSLog(@"SwitchamajigIRDeviceListener: connection didFailWithError - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    [[self delegate] SwitchamajigDeviceDriverDisconnected:self withError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
    //NSLog(@"SwitchamajigIRDeviceDriver: connectionDidFinishLoading. Received %d bytes of data",[puckRequestData length]);
    SJAugmentedNSURLConnection *connection = (SJAugmentedNSURLConnection *)conn;
    NSError *error;
    DDXMLDocument *deviceResponse = [[DDXMLDocument alloc] initWithData:[connection SJData] options:0 error:&error];
    
    if(error) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: xml document error %@", error);
        return;
    }
    NSArray *learnIRNodes = [deviceResponse nodesForXPath:@".//learnIRResponse" error:&error];
    if(error) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error getting name: %@", error);
        return;
    }
    DDXMLNode *irNode;
    for (irNode in learnIRNodes){
        NSError *statusError, *learnDataError;
        NSArray *statusNodes = [irNode nodesForXPath:@".//status" error:&statusError];
        NSArray *learnedDataNodes = [irNode nodesForXPath:@".//learnedData" error:&learnDataError];
        if(statusError || learnDataError || ([statusNodes count] != 1) || ([learnedDataNodes count] != 1)) {
            NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error parsing ir status %@ %@ %d %d", statusError, learnDataError, [statusNodes count], [learnedDataNodes count]);
            return;
        }
        DDXMLElement *statusElement = (DDXMLElement *)[statusNodes objectAtIndex:0];
        DDXMLElement *learnedDataElement = (DDXMLElement *)[learnedDataNodes objectAtIndex:0];
        DDXMLNode *messageNumAttribute = [statusElement attributeForName:@"messageNum"];
        DDXMLNode *reasonCodeAttribute = [statusElement attributeForName:@"reasonCode"];
        DDXMLNode *learnedDataAttribute = [learnedDataElement attributeForName:@"data"];
        if(!messageNumAttribute || !reasonCodeAttribute || !learnedDataAttribute) {
            NSLog(@"Unable to parse ir status elements. Response = %@ and %@", [statusElement XMLString], [learnedDataElement XMLString]);
            return;
        }
        //NSString *messageNumString = [messageNumAttribute stringValue];
        NSString *reasonCodeString = [reasonCodeAttribute stringValue];
        NSString *learnedDataString = [learnedDataAttribute stringValue];
        NSScanner *reasonCodeScan = [[NSScanner alloc] initWithString:reasonCodeString];
        int reasonCode;
        bool reasonCodeOK = [reasonCodeScan scanInt:&reasonCode];
        if(!reasonCodeOK) {
            NSLog(@"Unable to extract integer reason code from %@", reasonCodeString);
            return;
        }
        if(reasonCode) {
            // This is an actual error from the device. Report it.
            if([[self delegate] respondsToSelector:@selector(SwitchamajigIRDeviceDriverDelegateErrorOnLearnIR:error:)]) {
                NSError *irError = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorIR userInfo:nil];
                id<SwitchamajigIRDeviceDriverDelegate> theDelegate = (id<SwitchamajigIRDeviceDriverDelegate>)[self delegate];
                [theDelegate SwitchamajigIRDeviceDriverDelegateErrorOnLearnIR:self error:irError];
            }
        }
        // Reason code is OK. Return the IR command
        if([[self delegate] respondsToSelector:@selector(SwitchamajigIRDeviceDriverDelegateDidReceiveLearnedIRCommand:irCommand:)]) {
            id<SwitchamajigIRDeviceDriverDelegate> theDelegate = (id<SwitchamajigIRDeviceDriverDelegate>)[self delegate];
            [theDelegate SwitchamajigIRDeviceDriverDelegateDidReceiveLearnedIRCommand:self irCommand:learnedDataString];
        }
    }
}

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
    //retainedNetService = netService; // Prevent netService from disappearing
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
    NSString *hostName = [NSString stringWithFormat:@"%@:%d", [sender hostName], [sender port]];
    //NSLog(@"hostname %@", hostName);
    NSString *puckStatusRequestString = [NSString stringWithFormat:@"http://%@:%d/puckStatus.xml", [sender hostName], [sender port]];
    NSURLRequest *puckStatusRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:puckStatusRequestString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:SWITCHAMAJIG_TIMEOUT];
    SJAugmentedNSURLConnection *puckStatusConnectionAug = [[SJAugmentedNSURLConnection alloc] initWithRequest:puckStatusRequest delegate:self];
    if(!puckStatusConnectionAug) {
        NSLog(@"SwitchamajigIRDeviceListener: netServiceDidResolveAddress: connection failed\n");
        return;
    }
    [puckStatusConnectionAug setSJHostName:hostName];
    [puckStatusConnectionAug setSJData:[NSMutableData data]];
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
    NSLog(@"SwitchamajigIRDeviceListener: connection didFailWithError - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
    //NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading. Received %d bytes of data",[puckRequestData length]);
    SJAugmentedNSURLConnection *connection = (SJAugmentedNSURLConnection *)conn;
    NSError *error;
    DDXMLDocument *puckResponse = [[DDXMLDocument alloc] initWithData:[connection SJData] options:0 error:&error];

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
        [[self delegate] SwitchamajigDeviceListenerFoundDevice:self hostname:[connection SJHostName] friendlyname:friendlyName];
    }
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
    //NSLog(@"SimulatedSwitchamajigController: accepted new socket");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog(@"Simulated Switchamajig Controller received packet of %d bytes.", [data length]);
    NSString *readString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"SimulatedSwitchamajigIR: didReadData. Received %@", readString);
    BOOL isPuckStatus = [[NSPredicate predicateWithFormat:@"SELF contains \"GET /puckStatus.xml\""] evaluateWithObject:readString];
    if(isPuckStatus) {
        numPuckStatusRequests++;
    }
    BOOL isDoCommand = [[NSPredicate predicateWithFormat:@"SELF contains \"<docommand\""] evaluateWithObject:readString];
    if(isDoCommand) {
        NSRange commandRange = [readString rangeOfString:@"<docommand"];
        lastCommandReceived = [readString substringFromIndex:commandRange.location];
    }
    BOOL islearnIR = [[NSPredicate predicateWithFormat:@"SELF contains \"GET /learnIR\""] evaluateWithObject:readString];
    if(islearnIR) {
        numIRLearnRequests++;
    }
    // Keep reading
    [sock readDataWithTimeout:-1 tag:0];
}

- (void) returnPuckStatus {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <puckdata> <name>%@</name> </puckdata>", [self deviceName]];
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
    //NSLog(@"header = %@", header);
    //NSLog(@"response = %@", response);
    [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];    
}
- (void) returnIRLearningCommand:(NSString*)command {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <learnIRResponse> <status messageNum=\"77\" reasonCode=\"0\" /> <learnedData data=\"%@\"/> </learnIRResponse>", command];
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
    //NSLog(@"header = %@", header);
    //NSLog(@"response = %@", response);
    [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void) returnIRLearningError {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <learnIRResponse> <status messageNum=\"77\" reasonCode=\"1\" /> <learnedData data=\"none\"/> </learnIRResponse>"];
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
    //NSLog(@"header = %@", header);
    //NSLog(@"response = %@", response);
    [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}


- (void) resetPuckRequestCount {
    numPuckStatusRequests = 0;
}
- (int) getPuckRequestCount {
    return numPuckStatusRequests;
}
- (void) resetIRLearnRequestCount {
    numIRLearnRequests = 0;
}
- (int) getIRLearnRequestCount {
    return numIRLearnRequests;
}
- (NSString *) lastCommand {
    return lastCommandReceived;
}
@end

