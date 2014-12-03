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

#import <Foundation/Foundation.h>
#import "SwitchamajigDriver.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"


@interface SwitchamajigControllerDeviceDriver () {
    int switchState;
    GCDAsyncSocket *asyncSocket;
    NSLock *networkLock;
}

- (void) sendSwitchState;

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, strong) NSString *friendlyName;
@end


@interface SwitchamajigControllerDeviceListener () {
}

@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;

@end


@interface SimulatedSwitchamajigController : NSObject <NSStreamDelegate> {
    NSInputStream *inputStream;
    GCDAsyncUdpSocket *udpListenSocket;
    GCDAsyncSocket *listenSocket;
    int switchState;
    bool lastPacketWasUDP;
@public
    NSString *deviceName;
    NSString *ssidName;
    int wifiChannel;
    NSString *wifiPassphrase;
}
- (void) startListening;
- (void) stopListening;
- (int) getSwitchState;
- (bool) wasLastPacketUDP;
- (void) sendHeartbeat:(char *)friendlyName batteryVoltageInmV:(int)batteryVoltageInmV;

@property (strong) GCDAsyncSocket *connectedSocket;
@property (strong) GCDAsyncUdpSocket *sendSocket;
@end