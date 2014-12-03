/*
Copyright 2014 PAW Solutions LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

#import "SwitchamajigDriver.h"
#import "GCDAsyncSocket.h"

@interface SwitchamajigIRDeviceDriver () <NSURLConnectionDelegate> {
    BOOL irLearningInProgress;
    int numTimeouts;
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
- (void) returnValidPuckStatus;
- (void) returnPuckStatusWithNoOEMKey;
- (void) returnPuckStatusWithInvalidOEMKey;
- (void) resetPuckRequestCount;
- (int) getPuckRequestCount;
- (void) resetIRLearnRequestCount;
- (int) getIRLearnRequestCount;
- (NSString *) lastCommand;
- (void) returnIRLearningCommand:(NSString*)command;
- (void) returnIRLearningErrorWithReasonCode:(int)reasonCode;
@property int port;
@property NSString *deviceName;
@end