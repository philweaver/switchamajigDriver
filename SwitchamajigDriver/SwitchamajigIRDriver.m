//
//  SwitchamajigIRDriver.m
//  SwitchamajigDriver
//
//  Created by Phil Weaver on 8/17/12.
//  Copyright (c) 2012 PAW Solutions. All rights reserved.
//

#import "SwitchamajigIRDriver.h"
#import "arpa/inet.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "sha1.h"
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

// The IR database is megabytes in size, so we can't have one for every instance of an IR device
static FMDatabase *irDatabase;

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
    SJAugmentedNSURLConnection *connection = [[SJAugmentedNSURLConnection alloc] initWithRequest:commandRequest delegate:self startImmediately:NO];
    [connection setSJData:[NSMutableData data]];
    if(!connection) {
        NSLog(@"SwitchamajigIRDeviceDriver: issueCommandFromXMLNode: connection is null");
    }
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [connection setSJData:[NSMutableData data]];
    [connection start];
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
    NSLog(@"SwitchamajigIRDeviceDriver: connection didFailWithError - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    //[[self delegate] SwitchamajigDeviceDriverDisconnected:self withError:error];
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
    [[self delegate] SwitchamajigDeviceDriverConnected:self];
}

// IR Database support
// Lock used to make database accesses thread-safe
NSLock *irDatabaseLock = nil;
void beginIRDatabaseThreadsafe() {
    if(!irDatabaseLock)
        irDatabaseLock = [[NSLock alloc] init];
    [irDatabaseLock lock];
}

void endIRDatabaseThreadsafe() {
    [irDatabaseLock unlock];
}
+ (void) loadIRCodeDatabase:(NSString *)path error:(NSError **)error {
    beginIRDatabaseThreadsafe();
    irDatabase = [FMDatabase databaseWithPath:path];
    if(!irDatabase) {
        *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorIRDatabase userInfo:nil];
        endIRDatabaseThreadsafe();
        return;
    }
    if(![irDatabase open]){
        *error = [NSError errorWithDomain:(NSString*)SwitchamajigDriverErrorDomain code:SJDriverErrorIRDatabase userInfo:nil];
        endIRDatabaseThreadsafe();
        return;
    }
    endIRDatabaseThreadsafe();
}

+ (NSString *) getBrandIdForBrand:(NSString*)brand {
    NSString *query = [NSString stringWithFormat:@"select brandid from m_brands where brandname=\"%@\"", brand];
    FMResultSet *brandListing = [irDatabase executeQuery:query];
    if(![brandListing next]) {
        return nil;
    }
    NSString *brandIDString = [brandListing stringForColumn:@"brandid"];
    if(!brandIDString) {
        NSLog(@"getIRDatabaseDevicesForBrand: Failed to get brandid for brand %@.", brand);
        return nil;
    }
    return brandIDString;
}

+ (NSString *) getDeviceIdForDevice:(NSString*)device {
    NSString *query = [NSString stringWithFormat:@"select typeID from m_deviceTypes where typename=\"%@\"", device];
    FMResultSet *deviceListing = [irDatabase executeQuery:query];
    if(![deviceListing next]) {
        return nil;
    }
    NSString *deviceIDString = [deviceListing stringForColumn:@"typeID"];
    if(!deviceIDString) {
        NSLog(@"getDeviceIdForDevice: Failed to get typeID for type %@.", device);
        return nil;
    }
    return deviceIDString;
}

+ (NSString *) getCodeSetIdForCodeSet:(NSString*)codeSet onDevice:(NSString *)device forBrand:(NSString *)brand {
    NSString *brandIDString = [SwitchamajigIRDeviceDriver getBrandIdForBrand:brand];
    if(!brandIDString) {
        return nil;
    }
    NSString *deviceIDString = [SwitchamajigIRDeviceDriver getDeviceIdForDevice:device];
    if(!deviceIDString) {
        return nil;
    }
    NSString *query = [NSString stringWithFormat:@"select setofcodesid from m_setofcodes where brandid=\"%@\" and typeID=\"%@\" and controltype=\"IR\" and modelname=\"%@\"", brandIDString, deviceIDString, codeSet];
    FMResultSet *deviceListing = [irDatabase executeQuery:query];
    if(![deviceListing next]) {
        return nil;
    }
    NSString *codeSetIDString = [deviceListing stringForColumn:@"setofcodesid"];
    if(!codeSetIDString) {
        NSLog(@"codeSetIDString: Failed to get ID for type %@.", codeSet);
        return nil;
    }
    return codeSetIDString;
}

+ (NSArray *) getIRDatabaseBrands {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *brands = [[NSMutableArray alloc] initWithCapacity:100];
    FMResultSet *queryResults = [irDatabase executeQuery:@"select brandid,brandname,SQSource from m_brands order by brandname"];
    while([queryResults next]) {
        NSString *brandName = [queryResults stringForColumn:@"brandname"];
        [brands addObject:brandName];
    }
    endIRDatabaseThreadsafe();
    return brands;
}
+ (NSArray *) getIRDatabaseDevicesForBrand:(NSString *)brand {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *brandIDString = [SwitchamajigIRDeviceDriver getBrandIdForBrand:brand];
    if(!brandIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *devices = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *query = [NSString stringWithFormat:@"select distinct m_deviceTypes.typename from m_setofcodes,m_devicetypes where m_setofcodes.brandid=\"%@\" and m_setofcodes.typeid=m_devicetypes.typeid order by typename", brandIDString];
    FMResultSet *queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *deviceName = [queryResults stringForColumn:@"typename"];
        [devices addObject:deviceName];
    }
    endIRDatabaseThreadsafe();
    return devices;
}

+ (NSArray *) getIRDatabaseCodeSetsOnDevice:(NSString *)device forBrand:(NSString *)brand {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *brandIDString = [SwitchamajigIRDeviceDriver getBrandIdForBrand:brand];
    if(!brandIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *deviceIDString = [SwitchamajigIRDeviceDriver getDeviceIdForDevice:device];
    if(!deviceIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *codeSets = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *query = [NSString stringWithFormat:@"select modelname from m_setofcodes where typeid=\"%@\" and brandid=\"%@\" and controltype=\"IR\"", deviceIDString, brandIDString];
    FMResultSet *queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *codeSet = [queryResults stringForColumn:@"modelname"];
        [codeSets addObject:codeSet];
    }
    endIRDatabaseThreadsafe();
    return codeSets;
}

+ (NSArray *) getIRDatabaseFunctionsInCodeSet:(NSString *)codeSet onDevice:(NSString *)device forBrand:(NSString *)brand {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *codeSetString = [SwitchamajigIRDeviceDriver getCodeSetIdForCodeSet:codeSet onDevice:device forBrand:brand];
    if(!codeSetString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *functions = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *query = [NSString stringWithFormat:@"select distinct upper(functionname) from m_codelink where setofcodesid=\"%@\"", codeSetString];
    FMResultSet *queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *functionName = [queryResults stringForColumn:@"upper(functionname)"];
        [functions addObject:functionName];
    }
    endIRDatabaseThreadsafe();
    return functions;
}

+ (NSString *) irCodeForFunction:(NSString *)function inCodeSet:(NSString*) codeSet onDevice:(NSString *)device forBrand:(NSString *)brand {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *brandIDString = [SwitchamajigIRDeviceDriver getBrandIdForBrand:brand];
    if(!brandIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *deviceIDString = [SwitchamajigIRDeviceDriver getDeviceIdForDevice:device];
    if(!deviceIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *codeSetString = [SwitchamajigIRDeviceDriver getCodeSetIdForCodeSet:codeSet onDevice:device forBrand:brand];
    if(!codeSetString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    // First query: look for a UEI code
    NSString *query = [NSString stringWithFormat:@"select ueisetupcode,m_codes.ircode from m_codes,m_codelink,m_setofcodes where m_setofcodes.brandid=\"%@\" and m_setofcodes.typeid=\"%@\" and m_setofcodes.modelname=\"%@\" and upper(m_codelink.functionname)=\"%@\" and m_codes.codeid=m_codelink.codeid and m_codelink.setofcodesid=m_setofcodes.setofcodesid and m_setofcodes.controltype=\"IR\" and m_codes.sqsource=\"U\"", brandIDString, deviceIDString, codeSet, function];
    FMResultSet *queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *ueiSetupCode = [queryResults stringForColumn:@"ueisetupcode"];
        NSString *ueiFunctionNumber = [queryResults stringForColumn:@"ircode"];
        NSString *irCode = [NSString stringWithFormat:@"UT%@%@", ueiSetupCode, ueiFunctionNumber];
        if(ueiSetupCode && ueiFunctionNumber) {
            endIRDatabaseThreadsafe();
            return irCode;
        }
    }
    // If we didn't return, look for hex codes
    query = [NSString stringWithFormat:@"select m_codes.ircode from m_codes,m_codelink,m_setofcodes where m_setofcodes.brandid=\"%@\" and m_setofcodes.typeid=\"%@\" and m_setofcodes.modelname=\"%@\" and upper(m_codelink.functionname)=\"%@\" and m_codes.codeid=m_codelink.codeid and m_codelink.setofcodesid=m_setofcodes.setofcodesid and m_setofcodes.controltype=\"IR\" and m_codes.sqsource=\"O\"", brandIDString, deviceIDString, codeSet, function];
    queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *irCode = [queryResults stringForColumn:@"ircode"];
        if(irCode) {
            endIRDatabaseThreadsafe();
            return irCode;
        }
    }
    endIRDatabaseThreadsafe();
    return nil;
}

+ (NSArray *) getIRDatabaseDevices {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *devices = [[NSMutableArray alloc] initWithCapacity:100];
    FMResultSet *queryResults = [irDatabase executeQuery:@"select distinct m_devicetypes.typename,m_setofcodes.typeid from m_devicetypes,m_setofcodes where m_devicetypes.typeid==m_setofcodes.typeid and m_setofcodes.controltype=\"IR\""];
    while([queryResults next]) {
        NSString *deviceName = [queryResults stringForColumn:@"typename"];
        [devices addObject:deviceName];
    }
    endIRDatabaseThreadsafe();
    return devices;    
}

+ (NSArray *) getIRDatabaseBrandsForDevice:(NSString *)device {
    beginIRDatabaseThreadsafe();
    if(!irDatabase) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSString *deviceIDString = [SwitchamajigIRDeviceDriver getDeviceIdForDevice:device];
    if(!deviceIDString) {
        endIRDatabaseThreadsafe();
        return nil;
    }
    NSMutableArray *brands = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *query = [NSString stringWithFormat:@"select distinct brandname from m_brands,m_setofcodes where m_brands.brandid=m_setofcodes.brandid and m_setofcodes.typeid=\"%@\" order by brandname", deviceIDString];
    FMResultSet *queryResults = [irDatabase executeQuery:query];
    while([queryResults next]) {
        NSString *brandName = [queryResults stringForColumn:@"brandname"];
        [brands addObject:brandName];
    }
    endIRDatabaseThreadsafe();
    return brands;    
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
        netServices = [[NSMutableArray alloc] initWithCapacity:5];
    }
    return self;
}

// NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
    NSLog(@"didFindDomain: %@\n", domainName);
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"didFindService %@. Resolving with timeout.\n", [netService hostName]);
    [netService setDelegate:self];
    [netServices addObject:netService];
    [netService resolveWithTimeout:10];
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
    NSLog(@"netServiceDidResolveAddress\n");
    // We've found a candidate for a Switchamajig IR. Send it a "puckstatus" request. We'll know from
    // the response if this is a true IR unit
    NSString *hostName = [NSString stringWithFormat:@"%@:%d", [sender hostName], [sender port]];
    //NSLog(@"hostname %@", hostName);
    NSString *puckStatusRequestString = [NSString stringWithFormat:@"http://%@/puckStatus.xml", hostName];
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
    if(error || ![nameNodes count]) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error getting name: %@", error);
        return;
    }
    // Check the oem key
    NSArray *keyNodes = [puckResponse nodesForXPath:@".//puckdata/oem_key" error:&error];
    if(error || ![keyNodes count]) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error getting oemkey: %@", error);
        return;
    }
    NSString *oemKeyString = [[keyNodes objectAtIndex:0] stringValue];
    NSArray *macNodes = [puckResponse nodesForXPath:@".//puckdata/mac_address" error:&error];
    if(error || ![macNodes count]) {
        NSLog(@"SwitchamajigIRDeviceListener: connectionDidFinishLoading: error getting mac address: %@", error);
        return;
    }
    NSString *macAddrString = [[macNodes objectAtIndex:0] stringValue];
    NSScanner *macAddrScan = [[NSScanner alloc] initWithString:macAddrString];
    [macAddrScan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@": "]];
    unsigned char macAddress[6];
    for(int i=0; i < sizeof(macAddress); ++i) {
        unsigned macAddrPartInt;
        if(![macAddrScan scanHexInt:&macAddrPartInt]) {
            NSLog(@"Failing to scan mac address. String is %@, i=%d", macAddrString, i);
            return;
        }
        macAddress[i] = (unsigned char) macAddrPartInt;
    }
    unsigned char signature[32] = {0x03, 0x14, 0x15, 0x92, 0x65, 0x35, 0x89, 0x79, 0x32, 0x38, 0x46, 0x26, 0x43, 0x38, 0x32, 0x79, 0x64, 0x6f, 0x6e, 0x74, 0x63, 0x6c, 0x6f, 0x6e, 0x65, 0x73, 0x27, 0x6d, 0x61, 0x6a, 0x69, 0x67};
    SHA1Context sha;
    SHA1Reset(&sha);
    SHA1Input(&sha, signature, sizeof(signature));
    SHA1Input(&sha, macAddress, sizeof(macAddress));
    if(!SHA1Result(&sha)) {
        NSLog(@"Failed to compute hash\n");
        return;
    }
    // Encode the digest with base64 encoding to store it in the oemKey
    unsigned char messageDigest[21];
    memset(messageDigest, 0, sizeof(messageDigest));
    NSLog(@"digest[0] = %u", sha.Message_Digest[0]);
    for(int i=0,j=0; i < 5; ++i) {
        messageDigest[j++] = sha.Message_Digest[i] & 0xff;
        messageDigest[j++] = (sha.Message_Digest[i] >> 8) & 0xff;
        messageDigest[j++] = (sha.Message_Digest[i] >> 16) & 0xff;
        messageDigest[j++] = (sha.Message_Digest[i] >> 24) & 0xff;
    }
    unsigned char messageDigestBase64[32];
    memset(messageDigestBase64, 0, sizeof(messageDigestBase64));
    const char *base64Lookup = "abcdefGhijklmABCDEFgHIJKLMNOPQRSTUVWXYZnopqrstuvwxyz1234567890+-"; // A little different just to annoy people
    for(unsigned i=0,j=0; i < sizeof(messageDigest); i=i+3){
        messageDigestBase64[j++] = base64Lookup[messageDigest[i]&0x3f];
        messageDigestBase64[j++] = base64Lookup[((messageDigest[i]&0xc0) >> 6) | ((messageDigest[i+1]&0x0f) << 2)];
        messageDigestBase64[j++] = base64Lookup[((messageDigest[i+1]&0xf0) >> 4) | ((messageDigest[i+1]&0x03) << 4)];
        messageDigestBase64[j++] = base64Lookup[(messageDigest[i]&0xfc) >> 2];
    }
    NSString *computedOemKeyString = [NSString stringWithCString:(const char *)messageDigestBase64 encoding:NSASCIIStringEncoding];
    if(![computedOemKeyString isEqualToString:oemKeyString]) {
        NSLog(@"OEM Key verification failed. Computed = %@, Read = %@", computedOemKeyString, oemKeyString);
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
        NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <execCmndResponse> <status messageNum=\"70\" reasonCode=\"0\" /> </execCmndResponse>"];
        NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
        //NSLog(@"header = %@", header);
        //NSLog(@"response = %@", response);
        [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    }
    BOOL islearnIR = [[NSPredicate predicateWithFormat:@"SELF contains \"GET /learnIR\""] evaluateWithObject:readString];
    if(islearnIR) {
        numIRLearnRequests++;
    }
    // Keep reading
    [sock readDataWithTimeout:-1 tag:0];
}

- (void) returnValidPuckStatus {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <puckdata> <name>%@</name> <mac_address>00:06:66:72:16:dd</mac_address> <oem_key>S4I4eA8EOA1JS6qKk5ucYWd6OFiZ</oem_key> </puckdata>", [self deviceName]];
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
    //NSLog(@"header = %@", header);
    //NSLog(@"response = %@", response);
    [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void) returnPuckStatusWithNoOEMKey {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <puckdata> <name>%@</name> <mac_address>00:06:66:72:16:dd</mac_address> </puckdata>", [self deviceName]];
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nCache-Control: no-cache\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n", [response length]];
    //NSLog(@"header = %@", header);
    //NSLog(@"response = %@", response);
    [connectedSocket writeData:[header dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [connectedSocket writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void) returnPuckStatusWithInvalidOEMKey {
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <puckdata> <name>%@</name> <mac_address>00:06:66:72:16:dd</mac_address> <oem_key>junkeA8EOA1JS6qKk5ucYWd6OFiZ</oem_key> </puckdata>", [self deviceName]];
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
    NSString *response = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?> <learnIRResponse> <status messageNum=\"70\" reasonCode=\"6\" /> <learnedData data=\"\"/> </learnIRResponse>"];
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

