// SPDX-License-Identifier: MIT
// Disposable macOS test of the exact datagram framing used by PacketPump.
#include <arpa/inet.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <unistd.h>
#include "libVyraxCore.h"
#include "hev-main.h"
static int pair[2],echo_fd;
static void fail(const char *text){fprintf(stderr,"%s\n",text);exit(1);}
static void *echo(void *arg){char b[200];struct sockaddr_in peer;socklen_t n=sizeof(peer);ssize_t count=recvfrom(echo_fd,b,sizeof(b),0,(struct sockaddr*)&peer,&n);if(count>0)sendto(echo_fd,b,count,0,(struct sockaddr*)&peer,n);return NULL;}
static void *tun(void *arg){const char *cfg="tunnel:\n  mtu: 1280\nsocks5:\n  address: 127.0.0.1\n  port: 10808\n  udp: udp\nmisc:\n  task-stack-size: 24576\n  tcp-buffer-size: 4096\n  max-session-count: 256\n  log-file: null\n";hev_socks5_tunnel_main_from_str((const unsigned char*)cfg,(unsigned)strlen(cfg),pair[1]);return NULL;}
static unsigned short checksum(const unsigned char *buf,int count){unsigned sum=0;for(int i=0;i<count;i+=2)sum+=(buf[i]<<8)|buf[i+1];while(sum>>16)sum=(sum&65535)+(sum>>16);return ~sum;}
int main(void){
 char *reply=VyraxInvoke("{\"method\":\"start\",\"payload\":{\"log\":{\"loglevel\":\"none\"},\"inbounds\":[{\"tag\":\"socks\",\"listen\":\"127.0.0.1\",\"port\":10808,\"protocol\":\"socks\",\"settings\":{\"auth\":\"noauth\",\"udp\":true}}],\"outbounds\":[{\"tag\":\"direct\",\"protocol\":\"freedom\"}]}}");
 if(!reply||strstr(reply,"error"))fail("Xray start failed");VyraxFree(reply);
 if(socketpair(AF_UNIX,SOCK_DGRAM,0,pair)!=0)fail("socketpair failed");
 echo_fd=socket(AF_INET,SOCK_DGRAM,0);struct sockaddr_in addr={0};addr.sin_family=AF_INET;addr.sin_addr.s_addr=htonl(INADDR_ANY);addr.sin_len=sizeof(addr);
 if(bind(echo_fd,(struct sockaddr*)&addr,sizeof(addr))!=0)fail("echo bind failed");socklen_t n=sizeof(addr);getsockname(echo_fd,(struct sockaddr*)&addr,&n);
 struct timeval timeout={15,0};setsockopt(pair[0],SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(echo_fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
 pthread_t a,b;pthread_create(&a,NULL,tun,NULL);pthread_create(&b,NULL,echo,NULL);
 unsigned char packet[4+20+8+5]={0};unsigned family=htonl(AF_INET);memcpy(packet,&family,4);unsigned char *ip=packet+4;
 ip[0]=0x45;ip[3]=33;ip[8]=64;ip[9]=17;ip[12]=198;ip[13]=18;ip[15]=2;
 struct ifaddrs *interfaces=NULL;getifaddrs(&interfaces);int found=0;
 for(struct ifaddrs *it=interfaces;it;it=it->ifa_next){if(it->ifa_addr&&it->ifa_addr->sa_family==AF_INET&&strcmp(it->ifa_name,"lo0")!=0){memcpy(ip+16,&((struct sockaddr_in*)it->ifa_addr)->sin_addr,4);found=1;break;}}
 freeifaddrs(interfaces);if(!found)fail("Runner has no non-loopback IPv4 address");
 unsigned short cs=checksum(ip,20);ip[10]=cs>>8;ip[11]=cs&255;
 unsigned char *udp=ip+20;udp[0]=0xc3;udp[1]=0x50;memcpy(udp+2,&addr.sin_port,2);udp[5]=13;memcpy(udp+8,"vyrax",5);
 // The socket queues the first datagram until Hev's stack is initialized.
 if(send(pair[0],packet,sizeof(packet),0)!=(ssize_t)sizeof(packet))fail("packet write failed");
 unsigned char received[1500];ssize_t size=recv(pair[0],received,sizeof(received),0);
 if(size<37||received[13]!=17||memcmp(received+size-5,"vyrax",5)!=0){fprintf(stderr,"Synthetic packet response bytes=%zd IP-protocol=%u\n",size,size>13?received[13]:0);if(size>0){for(int i=0;i<size&&i<80;i++)fprintf(stderr,"%02x",received[i]);fputc('\n',stderr);}fail("IPv4 UDP roundtrip through Xray/Hev failed");}
 hev_socks5_tunnel_quit();pthread_join(a,NULL);pthread_join(b,NULL);close(pair[0]);close(pair[1]);close(echo_fd);
 reply=VyraxInvoke("{\"method\":\"stop\",\"payload\":{}}");if(!reply||strstr(reply,"error"))fail("Xray stop failed");VyraxFree(reply);
 puts("Public packet-flow framing: IPv4 UDP roundtrip through Hev and Xray passed");return 0;
}
