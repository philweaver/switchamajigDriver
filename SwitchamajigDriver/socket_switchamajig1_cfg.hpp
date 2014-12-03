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

#ifndef SwitchControl_socket_switchamajig1_cfg_h
#define SwitchControl_socket_switchamajig1_cfg_h
#import "sys/socket.h"
#import "netinet/in.h"
#import "netdb.h"
#import "sys/unistd.h"
#import "sys/fcntl.h"
#import "sys/poll.h"
#import "arpa/inet.h"
#import "errno.h"
#import "signal.h"
#if __cplusplus
extern "C" {
#endif
// Types
#define STANDARD_STRING_LENGTH 256
struct switchamajig1_network_info {
	char ssid[STANDARD_STRING_LENGTH];
	char passphrase[STANDARD_STRING_LENGTH];
	int channel;
	int join_mode;
	int dhcp_mode;
};

// This should be a tcp socket handle
typedef int SWITCHAMAJIG1_HANDLE;
SWITCHAMAJIG1_HANDLE switchamajig1_open_socket(const char *ip_addr_string);
void switchamajig1_close_socket(SWITCHAMAJIG1_HANDLE socket);
// Scan the wifi for access points. Returns the number found through a pointer and fills the array with network info.
// Returns true on success, false on any error
// Returns false if more points are found than the array can hold
bool switchamajig1_scan_wifi(SWITCHAMAJIG1_HANDLE switchamajig_handle, int *pNum_wifi_scan_results, struct switchamajig1_network_info *wifi_scan_results_array, int max_array_length);
// Basic functions that return true on success, false on error.
bool switchamajig1_enter_command_mode(SWITCHAMAJIG1_HANDLE switchamajig_handle);
bool switchamajig1_exit_command_mode(SWITCHAMAJIG1_HANDLE switchamajig_handle);
bool switchamajig1_get_name(SWITCHAMAJIG1_HANDLE switchamajig_handle, char *switchamajig_name, int switchamajig_name_max_len);
bool switchamajig1_set_name(SWITCHAMAJIG1_HANDLE switchamajig_handle, const char *name);
bool switchamajig1_get_netinfo(SWITCHAMAJIG1_HANDLE switchamajig_handle, struct switchamajig1_network_info *netinfo);
bool switchamajig1_set_netinfo(SWITCHAMAJIG1_HANDLE switchamajig_handle, struct switchamajig1_network_info *netinfo);
bool switchamajig1_save(SWITCHAMAJIG1_HANDLE switchamajig_handle);
#define SWITCHAMAJIG_IP_PROTOCOL_TCP 1
#define SWITCHAMAJIG_IP_PROTOCOL_UDP 2
bool switchamajig1_set_ip_protocol(SWITCHAMAJIG1_HANDLE switchamajig_handle, int protocol_mask);
// Commands to PIC
bool switchamajig1_write_eeprom(SWITCHAMAJIG1_HANDLE switchamajig_handle, int addr, int value);
bool switchamajig1_reset(SWITCHAMAJIG1_HANDLE switchamajig_handle);

#if __cplusplus
}
#endif

#endif
