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

#include <stdio.h>
#include <string.h>
#include "socket_switchamajig1_cfg.hpp"
#include <unistd.h>
#if __cplusplus
extern "C" {
#endif

#define debug_printf if(debug) printf

#define DEVICE_STRING_LEN 100

// Local prototypes
bool get_ssid_string(SWITCHAMAJIG1_HANDLE hSerial, char *ssid_string, int max_str_len);
bool get_name_string(SWITCHAMAJIG1_HANDLE hSerial, char *ssid_string, int max_str_len);
bool get_phrase_string(SWITCHAMAJIG1_HANDLE hSerial, char *ssid_string, int max_str_len);
bool get_dhcp_mode(SWITCHAMAJIG1_HANDLE hSerial, int *dhcp_mode);
bool get_join_mode(SWITCHAMAJIG1_HANDLE hSerial, int *join_mode);
bool get_channel(SWITCHAMAJIG1_HANDLE hSerial, int *channel);
bool get_tag_in_buffer(const char *buffer, const char *tag, char *stringRead, int max_str_len);
bool set_default_timeouts(SWITCHAMAJIG1_HANDLE hSerial);
int read_until_timeout(int hSerial, char *buffer, int bufflen);
bool write_string_and_expect_response(SWITCHAMAJIG1_HANDLE hSerial, const char *stringToSend, const char *expectedString);
bool set_timeouts(SWITCHAMAJIG1_HANDLE hSerial, int timeout);
bool get_tag_after_sending_string(SWITCHAMAJIG1_HANDLE hSerial, const char *stringToSend, const char *tag, char *stringRead, int max_str_len);
int read_with_two_timeouts(int socket, char *buffer, int bufflen, int timeout1, int min_data_for_timeout1, int timeout2);
// 5 seconds
#define DEFAULT_TIMEOUT 5000000
// 0.1 second
#define SHORT_TIMEOUT 100000
static int timeout = DEFAULT_TIMEOUT;
static bool debug = true;

int read_until_timeout(int socket, char *buffer, int bufflen) {
	int bufflen_start = bufflen;
    // Set timeout
    struct timeval tv;
    fd_set readfds;
    tv.tv_sec = timeout / 1000000;
    tv.tv_usec = timeout - (tv.tv_sec * 1000000); 
    FD_ZERO(&readfds);
    FD_SET(socket, &readfds);
    int lengths[100], lenindex = 0;
	while(bufflen) {
        int bytes = 0;
        select(socket+1, &readfds, NULL, NULL, &tv);
        if(FD_ISSET(socket, &readfds)) {
            bytes = recv(socket, buffer, bufflen, 0);
        }
        lengths[lenindex++] = bytes;
 		if(bytes < 0)
			return bytes;
		if(!bytes) {
            debug_printf("read_until_timeout: %d read events, lens %d %d %d %d.\n", lenindex, lengths[0], lengths[1], lengths[2], lengths[3]);
			return (bufflen_start - bufflen);
        }
		buffer += bytes;
		bufflen -= bytes;
	}
	return bufflen_start; // Filled buffer
}

// Read with timeout1 until we get a minimum amt of data, and then read up to bufflen with the second timeout
int read_with_two_timeouts(int socket, char *buffer, int bufflen, int timeout1, int min_data_for_timeout1, int timeout2) {
    int savetimeout = timeout;
    timeout = timeout1;
    int bytesRead = read_until_timeout(socket, buffer, min_data_for_timeout1);
    if(bytesRead < min_data_for_timeout1) {
        timeout = savetimeout;
        return bytesRead;
    }
    timeout = timeout2;
    int bytesRead2 = read_until_timeout(socket, buffer+bytesRead, bufflen-bytesRead);
    timeout = savetimeout;
    if(bytesRead2 < 0)
        return bytesRead2;
    return bytesRead + bytesRead2;
}

bool write_string_and_expect_response(SWITCHAMAJIG1_HANDLE socket, const char *stringToSend, const char *expectedString) {
	int bytes;
	char buffer[4096];
    // Absorb extra bytes
    read_with_two_timeouts(socket, buffer, sizeof(buffer), SHORT_TIMEOUT, 1, SHORT_TIMEOUT);

    // Expect to get the command echoed, and then the expected string
    int minlen = strlen(stringToSend) + strlen(expectedString);
	memset(buffer, 0, sizeof(buffer));
    int bytesSent = 0;
    while(strlen(stringToSend) > bytesSent > 0) {
        bytes = send(socket, stringToSend+bytesSent, strlen(stringToSend)-bytesSent, 0);
        if(bytes < 0) {
            debug_printf("write_string_and_expect_response: write failed.\n");
            return false;
        }
        bytesSent += bytes;
    }
	bytes = read_with_two_timeouts(socket, buffer, sizeof(buffer), DEFAULT_TIMEOUT, minlen, SHORT_TIMEOUT);
	if(bytes < 0) {
		debug_printf("write_string_and_expect_response: read failed.\n");
		return false;
	}
	//printf("Received %d bytes: %s\n", bytes, buffer);
	buffer[bytes] = 0;
	// The buffer may contain 0's, which will stop strstr from finding the expected string after them. Search each segment.
	int bufferindex = 0;
	while(bufferindex < bytes) {
		if(strstr(buffer+bufferindex, expectedString))
			return true;
		bufferindex += strlen(buffer+bufferindex)+1;
	}
	debug_printf("write_string_and_expect_response: expected string %s not received. Got %s\n", expectedString, buffer);
	return false;
}

bool set_default_timeouts(SWITCHAMAJIG1_HANDLE hSerial) {
    timeout = DEFAULT_TIMEOUT; 
	return true;
}

bool set_timeouts(SWITCHAMAJIG1_HANDLE hSerial, int newtimeout) {
    timeout = newtimeout;
	return true;
}


bool switchamajig1_set_name(SWITCHAMAJIG1_HANDLE hSerial, const char *name) {
	char command[DEVICE_STRING_LEN];
	sprintf(command, "set opt device %s\r", name);
	if(!write_string_and_expect_response(hSerial, command, "AOK")) {
		debug_printf("switchamajig1_set_name: Failed.\n");
		return false;
	}
	return true;
}

bool switchamajig1_set_ip_protocol(SWITCHAMAJIG1_HANDLE hSerial, int protocol_mask) {
	char command[DEVICE_STRING_LEN];
	sprintf(command, "set ip protocol %d\r", protocol_mask);
	if(!write_string_and_expect_response(hSerial, command, "AOK")) {
		debug_printf("switchamajig1_set_name: Failed.\n");
		return false;
	}
	return true;
}


bool switchamajig1_save(SWITCHAMAJIG1_HANDLE hSerial) {
	if(!write_string_and_expect_response(hSerial, "save\r", "Storing")) {
		debug_printf("switchamajig1_save: Failed.\n");
		return false;
	}
	return true;
}


#define SWITCHAMAJIG_COMMAND_LEN 8
#define SWITCHAMAJIG_COMMAND_BYTE_0 255
#define COMMAND_WRITE_EEPROM 2
#define COMMAND_RESET 3
bool switchamajig1_write_eeprom(SWITCHAMAJIG1_HANDLE hSerial, int addr, int data) {
	char command[8];
	unsigned i;
	for(i=0; i < sizeof(command); ++i)
		command[i] = 0;
	command[0] = SWITCHAMAJIG_COMMAND_BYTE_0;
	command[1] = COMMAND_WRITE_EEPROM;
	command[2] = addr & 0x7f;
	command[3] = (addr >> 7) & 0x7f;
	command[4] = data & 0x7f;
	command[5] = (data >> 7) & 0x7f;
	for(i=0; i<sizeof(command); ++i)
		if(!command[i])
			command[i] = 0x80;
	if(write(hSerial, command, sizeof(command)) <=0) {
		debug_printf("switchamajig1_write_eeprom: Write failed.\n");
		return false;
	}
	return true;
}

bool switchamajig1_reset(SWITCHAMAJIG1_HANDLE hSerial) {
	char command[8];
	unsigned i;
	for(i=0; i < sizeof(command); ++i)
		command[i] = 0;
	command[0] = SWITCHAMAJIG_COMMAND_BYTE_0;
	command[1] = COMMAND_RESET;
	for(i=0; i<sizeof(command); ++i)
		if(!command[i])
			command[i] = 0x80;
	if(write(hSerial, command, sizeof(command)) <= 0) {
		debug_printf("switchamajig1_write_eeprom: Write failed.\n");
		return false;
	}
	return true;
}

bool switchamajig1_enter_command_mode(SWITCHAMAJIG1_HANDLE socket) {
	char recv_buffer[1024];
	int bytes;
    // Absorb extra bytes
    read_with_two_timeouts(socket, recv_buffer, sizeof(recv_buffer), SHORT_TIMEOUT, 1, SHORT_TIMEOUT);
    bytes = send(socket, "$$$\r", 4, 0);
    if(bytes < 0) {
        perror("enter_command_mode: send");
        return false;
    }
	bytes = read_with_two_timeouts(socket, recv_buffer, sizeof(recv_buffer), DEFAULT_TIMEOUT, 3, SHORT_TIMEOUT);
	if(bytes < 0) {
		if(debug)
			perror("enter_command_mode: Read File error");
		return false;
	}
	debug_printf("enter_command_mode: %d bytes received\n", bytes);
	if(!bytes)
		return false;
	recv_buffer[bytes] = 0;
	debug_printf("enter_command_mode: Received %s\n", recv_buffer);
	// Expected response
	if(!strstr(recv_buffer, "CMD") && !strstr(recv_buffer, "$$$"))
		return false; // Something's gone wrong.
	// Try to get a command prompt
	if(!write_string_and_expect_response(socket, "\r", ">")) {
		debug_printf("enter_command_mode: No command prompt.\n");
		return false;
	}
    
	return true; 
}

bool switchamajig1_exit_command_mode(SWITCHAMAJIG1_HANDLE hSerial) {
	if(!write_string_and_expect_response(hSerial, "exit\r", "EXIT")) {
		debug_printf("switchamajig1_exit_command_mode: Failed.\n");
		return false;
	}
	return true;
}

bool switchamajig1_get_netinfo(SWITCHAMAJIG1_HANDLE hSerial, struct switchamajig1_network_info *netinfo) {
	if(!get_ssid_string(hSerial, netinfo->ssid, sizeof(netinfo->ssid))) {
		debug_printf("switchamajig1_get_netinfo: Failed to read ssid.\n");
		return false;
	}
	if(!get_phrase_string(hSerial, netinfo->passphrase, sizeof(netinfo->passphrase))) {
		debug_printf("switchamajig1_get_netinfo: Failed to read pass phrase.\n");
		return false;
	}
	if(!get_channel(hSerial, &netinfo->channel)) {
		debug_printf("switchamajig1_get_netinfo: Failed to read channel.\n");
		return false;
	}
	if(!get_dhcp_mode(hSerial, &netinfo->dhcp_mode)) {
		debug_printf("switchamajig1_get_netinfo: Failed to read dhcp mode.\n");
		return false;
	}
	if(!get_join_mode(hSerial, &netinfo->join_mode)) {
		debug_printf("switchamajig1_get_netinfo: Failed to read join mode.\n");
		return false;
	}
	return true;
}

bool get_tag_in_buffer(const char *buffer, const char *tag, char *stringRead, int max_str_len) {
	const char *tag_ptr = strstr(buffer, tag);
	if(!tag_ptr)
		return false;
	tag_ptr += strlen(tag);
	while((*tag_ptr != '\r') && (*tag_ptr != '\r')) {
		if(max_str_len-- <= 0)
			return false;
		*(stringRead++) = *(tag_ptr++);
	}
	*stringRead = 0;
	return true;
}

bool get_tag_after_sending_string(SWITCHAMAJIG1_HANDLE hSerial, const char *stringToSend, const char *tag, char *stringRead, int max_str_len) {
	char recv_buffer[4096];
	int bytes;
	if(write(hSerial, stringToSend, strlen(stringToSend)) < 0) {
		debug_printf("get_tag_after_sending_string: Write File error.\n");
		return false;
	}
	bytes = read_until_timeout(hSerial, recv_buffer, sizeof(recv_buffer));
	debug_printf("get_tag_after_sending_string: %d bytes received\n", bytes);
	if(bytes <= 0)
		return false;
	recv_buffer[bytes] = 0;
	debug_printf("get_tag_after_sending_string: Received %s\n", recv_buffer);
	return get_tag_in_buffer(recv_buffer, tag, stringRead, max_str_len);
}

bool get_ssid_string(SWITCHAMAJIG1_HANDLE hSerial, char *ssid_string, int max_str_len) {
	return get_tag_after_sending_string(hSerial, "get wlan\r", "SSID=", ssid_string, max_str_len);
}

bool get_phrase_string(SWITCHAMAJIG1_HANDLE hSerial, char *phrase_string, int max_str_len) {
	return get_tag_after_sending_string(hSerial, "get wlan\r", "Passphrase=", phrase_string, max_str_len);
}

bool switchamajig1_get_name(SWITCHAMAJIG1_HANDLE hSerial, char *switchamajig_name, int switchamajig_name_max_len) {
	return get_tag_after_sending_string(hSerial, "get opt\r", "DeviceId=", switchamajig_name, switchamajig_name_max_len);
}

bool get_dhcp_mode(SWITCHAMAJIG1_HANDLE hSerial, int *dhcp_mode) {
	char dhcpModeString[256];
	if(!get_tag_after_sending_string(hSerial, "get ip\r", "DHCP=", dhcpModeString, sizeof(dhcpModeString)))
		return false;
	if(dhcpModeString[0] == 'A')
		*dhcp_mode = 2;
	else if(dhcpModeString[1] == 'N')
		*dhcp_mode = 1;
	else if(dhcpModeString[1] == 'F')
		*dhcp_mode = 0;
	else
		return false;
	return true;
}

bool get_join_mode(SWITCHAMAJIG1_HANDLE hSerial, int *join_mode) {
	char joinModeString[5];
	if(!get_tag_after_sending_string(hSerial, "get wlan\r", "Join=", joinModeString, sizeof(joinModeString)))
		return false;
	if(!sscanf(joinModeString, "%d", join_mode))
		return false;
	return true;
}

bool get_channel(SWITCHAMAJIG1_HANDLE hSerial, int *channel) {
	char chanString[5];
	if(!get_tag_after_sending_string(hSerial, "get wlan\r", "Chan=", chanString, sizeof(chanString)))
		return false;
	if(!sscanf(chanString, "%d", channel))
		return false;
	return true;
}
#define MIN_LEN_FOR_SCAN 30
bool switchamajig1_scan_wifi(SWITCHAMAJIG1_HANDLE hSerial, int *pNum_wifi_scan_results, struct switchamajig1_network_info *wifi_scan_results_array, int max_array_length) {
	int bytes;
    
	if(write(hSerial, "scan\r\n\0", 6) < 0) {
		debug_printf("switchamajig1_scan_wifi: Write File error on scan.\n");
		return false;
	}
	char recv_buffer[4096];
    // Do one wait with a long timeout for enough bytes to make sure we get a response
	bytes = read_with_two_timeouts(hSerial, recv_buffer, sizeof(recv_buffer), 15000000, MIN_LEN_FOR_SCAN, SHORT_TIMEOUT);
	recv_buffer[bytes] = 0;
	debug_printf("switchamajig1_scan_wifi: Received %s\n", recv_buffer);
	char num_wifi_scan_results_string[10];
	if(!get_tag_in_buffer(recv_buffer, "SCAN:Found", num_wifi_scan_results_string, sizeof(num_wifi_scan_results_string))){
		debug_printf("switchamajig1_scan_wifi: Can't find num_wifi_scan_results_string.\n");
		return false;
	}
	if(!sscanf(num_wifi_scan_results_string, "%d", pNum_wifi_scan_results)) {
		debug_printf("switchamajig1_scan_wifi: Can't find num_wifi_scan_results.\n");
		return false;
	}
	debug_printf("switchamajig1_scan_wifi: %d found\n", *pNum_wifi_scan_results);
	if((*pNum_wifi_scan_results > max_array_length) || (*pNum_wifi_scan_results < 0)) {
		debug_printf("switchamajig1_scan_wifi: Num_wifi_scan_results out of bounds (=%d).\n", *pNum_wifi_scan_results);
		return false;
	}
	if(*pNum_wifi_scan_results == 0)
		return true;
	// Extract names and channel numbers for all the options
	for(int i=0; i < *pNum_wifi_scan_results; ++i) {
		char tag[20];
		sprintf(tag, "\n %d", i+1);
		char extendedName[DEVICE_STRING_LEN];
		if(!get_tag_in_buffer(recv_buffer, tag, extendedName, sizeof(extendedName))) {
			debug_printf("switchamajig1_scan_wifi: Can't find tag %d.\n", i+1);
			return false;
		}
		if(!sscanf(extendedName, "%s %d", (char *) &wifi_scan_results_array[i].ssid, &wifi_scan_results_array[i].channel)) {
			debug_printf("switchamajig1_scan_wifi: scanf failed for number %d.\n", i+1);
			return false;
		}
		// Set join and dhcp mode for infrastructure mode
		wifi_scan_results_array[i].join_mode = 1;
		wifi_scan_results_array[i].dhcp_mode = 1;
	}
	return true;
}


bool switchamajig1_set_netinfo(SWITCHAMAJIG1_HANDLE hSerial, struct switchamajig1_network_info *netinfo) {
	char command[256];
	set_timeouts(hSerial, 5000000); // 5 seconds
	if(!write_string_and_expect_response(hSerial, "set ip dhcp 1\r", "AOK")) {
		debug_printf("switchamajig1_set_netinfo: set dhcp failed.\n");
		return false;
	}
	if(!write_string_and_expect_response(hSerial, "set wlan join 1\r", "AOK")) {
		debug_printf("switchamajig1_set_netinfo: set join failed.\n");
		return false;
	}
	sprintf(command, "set wlan ssid %s\r", netinfo->ssid);
	if(!write_string_and_expect_response(hSerial, command, "AOK")) {
		debug_printf("switchamajig1_set_netinfo: set ssid failed.\n");
		return false;
	}
	sprintf(command, "set wlan chan %d\r", netinfo->channel);
	if(!write_string_and_expect_response(hSerial, command, "AOK")) {
		debug_printf("switchamajig1_set_netinfo: set chan failed.\n");
		return false;
	}
	sprintf(command, "set wlan phrase %s\r", netinfo->passphrase);
	if(!write_string_and_expect_response(hSerial, command, "AOK")) {
		debug_printf("switchamajig1_set_netinfo: set phrase failed.\n");
		return false;
	}
	return true;
}

#define ROVING_PORTNUM 2000
SWITCHAMAJIG1_HANDLE switchamajig1_open_socket(const char *ip_addr_string) {
    struct hostent *host = gethostbyname(ip_addr_string);
    if(!host) {
        debug_printf("Retrying hostname not found");
        return 0;
    }
    int portno = ROVING_PORTNUM;
    int server_socket = 0, socket_flags = 0;
    struct sockaddr_in sin;
    memcpy(&sin.sin_addr.s_addr, host->h_addr, host->h_length);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(portno);
    server_socket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    char on = 1;
    setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
    // Set timeout on all operations to 1 second
    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(server_socket, SOL_SOCKET, SO_SNDTIMEO, (void *)&tv, sizeof(tv));
    setsockopt(server_socket, SOL_SOCKET, SO_RCVTIMEO, (void *)&tv, sizeof(tv));
    socket_flags = fcntl(server_socket, F_GETFL);
    socket_flags |= O_NONBLOCK;
    fcntl(server_socket, F_SETFL, socket_flags);
    if(connect(server_socket, (struct sockaddr *) &sin, sizeof(sin)) < 0) {
        struct pollfd socket_poll;
        socket_poll.fd = server_socket;
        socket_poll.events = POLLOUT;
        int poll_ret = poll(&socket_poll, 1, 1000);
        if(poll_ret <= 0) {
            close(server_socket);
            return 0;
        }
    }
    socket_flags &= ~O_NONBLOCK;
    fcntl(server_socket, F_SETFL, socket_flags);
    // Prevent signals; we'll handle error messages instead
    int on2;
    setsockopt(server_socket, SOL_SOCKET, SO_NOSIGPIPE, &on2, sizeof(on2));
    char buffer[1024];
    read_until_timeout(server_socket, buffer, sizeof(buffer));
    return server_socket;
}

void switchamajig1_close_socket(SWITCHAMAJIG1_HANDLE socket) {
    close(socket);
}
#if __cplusplus
}
#endif
