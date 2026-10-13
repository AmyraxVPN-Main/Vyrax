// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <CommonCrypto/CommonDigest.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <poll.h>
#include <signal.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>
#include "process.h"
#include "core-pins.h"

static NSString *const journal=@"/var/run/com.amyrax.vyrax-network.rollback";
static volatile sig_atomic_t quitting=0;
static void stop(int signalNumber){quitting=1;}
#include "tunnel-lease.h"
static void require(BOOL valid){if(!valid)@throw [NSException exceptionWithName:@"Vyrax" reason:@"Network operation failed" userInfo:nil];}
static void saveJournal(NSArray *entries){
    NSData *data=[NSJSONSerialization dataWithJSONObject:entries options:0 error:nil];require(data!=nil);
    int fd=open(journal.fileSystemRepresentation,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW,0600);require(fd>=0);
    fchmod(fd,0600);const char *bytes=data.bytes;ssize_t left=data.length;
    while(left>0){ssize_t n=write(fd,bytes,left);if(n<0&&errno==EINTR)continue;if(n<=0){close(fd);require(NO);}bytes+=n;left-=n;}
    fsync(fd);close(fd);
}
static void recover(SCPreferencesRef preferences){
    NSData *data=[NSData dataWithContentsOfFile:journal];if(!data)return;
    NSArray *entries=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];require([entries isKindOfClass:NSArray.class]);
    require(SCPreferencesLock(preferences,FALSE));BOOL committed=NO;
    @try {
        SCPreferencesSynchronize(preferences);
        for(NSDictionary *entry in entries.reverseObjectEnumerator){
            SCNetworkServiceRef service=SCNetworkServiceCopy(preferences,(__bridge CFStringRef)entry[@"id"]);if(!service)continue;
            SCNetworkProtocolRef protocol=SCNetworkServiceCopyProtocol(service,(__bridge CFStringRef)entry[@"type"]);
            if(protocol){
                NSDictionary *current=(__bridge NSDictionary *)SCNetworkProtocolGetConfiguration(protocol);
                // Preserve network settings subsequently changed by the user/another VPN.
                if([current isEqual:entry[@"applied"]]&&SCNetworkProtocolGetEnabled(protocol)){
                    if([entry[@"created"] boolValue])require(SCNetworkServiceRemoveProtocolType(service,(__bridge CFStringRef)entry[@"type"]));
                    else {id before=entry[@"previous"];require(SCNetworkProtocolSetConfiguration(protocol,before==NSNull.null?NULL:(__bridge CFDictionaryRef)before));require(SCNetworkProtocolSetEnabled(protocol,[entry[@"enabled"] boolValue]));}
                }
                CFRelease(protocol);
            }CFRelease(service);
        }
        require(SCPreferencesCommitChanges(preferences));require(SCPreferencesApplyChanges(preferences));committed=YES;
    } @finally {SCPreferencesUnlock(preferences);}
    if(committed)require(unlink(journal.fileSystemRepresentation)==0);
}
static void configure(SCPreferencesRef preferences,BOOL tun,int http,int socks){
    require(SCPreferencesLock(preferences,FALSE));
    @try {
        SCPreferencesSynchronize(preferences);
        NSArray *services=CFBridgingRelease(SCNetworkServiceCopyAll(preferences));require(services.count>0);
        NSMutableArray *entries=[NSMutableArray array];
        NSString *type=(__bridge NSString *)(tun?kSCNetworkProtocolTypeDNS:kSCNetworkProtocolTypeProxies);
        NSDictionary *applied=tun?@{@"ServerAddresses":@[@"172.28.0.2"]}:@{@"HTTPEnable":@1,@"HTTPProxy":@"127.0.0.1",@"HTTPPort":@(http),@"HTTPSEnable":@1,@"HTTPSProxy":@"127.0.0.1",@"HTTPSPort":@(http),@"SOCKSEnable":@1,@"SOCKSProxy":@"127.0.0.1",@"SOCKSPort":@(socks),@"ProxyAutoConfigEnable":@0,@"ProxyAutoDiscoveryEnable":@0,@"ExceptionsList":@[@"localhost",@"127.0.0.1",@"::1",@"*.local"],@"ExcludeSimpleHostnames":@1};
        for(id item in services){
            SCNetworkServiceRef service=(__bridge SCNetworkServiceRef)item;if(!SCNetworkServiceGetEnabled(service))continue;
            SCNetworkProtocolRef protocol=SCNetworkServiceCopyProtocol(service,(__bridge CFStringRef)type);BOOL created=!protocol;
            if(created){require(SCNetworkServiceAddProtocolType(service,(__bridge CFStringRef)type));protocol=SCNetworkServiceCopyProtocol(service,(__bridge CFStringRef)type);}require(protocol!=NULL);
            NSDictionary *previous=(__bridge NSDictionary *)SCNetworkProtocolGetConfiguration(protocol);
            [entries addObject:@{@"id":(__bridge NSString *)SCNetworkServiceGetServiceID(service),@"type":type,@"previous":previous?:NSNull.null,@"enabled":@(SCNetworkProtocolGetEnabled(protocol)),@"created":@(created),@"applied":applied}];
            CFRelease(protocol);
        }
        require(entries.count>0);saveJournal(entries);
        for(NSDictionary *entry in entries){
            SCNetworkServiceRef service=SCNetworkServiceCopy(preferences,(__bridge CFStringRef)entry[@"id"]);
            SCNetworkProtocolRef protocol=SCNetworkServiceCopyProtocol(service,(__bridge CFStringRef)type);
            require(protocol&&SCNetworkProtocolSetConfiguration(protocol,(__bridge CFDictionaryRef)applied)&&SCNetworkProtocolSetEnabled(protocol,TRUE));CFRelease(protocol);CFRelease(service);
        }
        require(SCPreferencesCommitChanges(preferences));require(SCPreferencesApplyChanges(preferences));
    } @finally {SCPreferencesUnlock(preferences);}
}
static BOOL tunnelUp(void){
    struct ifaddrs *interfaces=NULL;BOOL found=NO;if(getifaddrs(&interfaces))return NO;
    for(struct ifaddrs *i=interfaces;i;i=i->ifa_next)if(i->ifa_addr&&i->ifa_addr->sa_family==AF_INET&&strncmp(i->ifa_name,"utun",4)==0){
        char address[INET_ADDRSTRLEN];inet_ntop(AF_INET,&((struct sockaddr_in *)i->ifa_addr)->sin_addr,address,sizeof(address));if(strcmp(address,"172.28.0.1")==0)found=YES;
    }freeifaddrs(interfaces);return found;
}
static NSDictionary *tunConfig(int socks,int mtu,NSString *xray){
    return @{@"log":@{@"level":@"warn"},@"dns":@{@"servers":@[@{@"type":@"https",@"tag":@"remote-dns",@"server":@"1.1.1.1",@"server_port":@443,@"path":@"/dns-query",@"detour":@"proxy"}],@"final":@"remote-dns"},@"inbounds":@[@{@"type":@"tun",@"tag":@"tun-in",@"address":@[@"172.28.0.1/30",@"fdfe:dcba:9876::1/126"],@"mtu":@(mtu),@"auto_route":@YES,@"strict_route":@YES,@"stack":@"mixed"}],@"outbounds":@[@{@"type":@"socks",@"tag":@"proxy",@"server":@"127.0.0.1",@"server_port":@(socks),@"version":@"5"},@{@"type":@"direct",@"tag":@"direct"}],@"route":@{@"auto_detect_interface":@YES,@"rules":@[@{@"process_path":@[xray],@"action":@"route",@"outbound":@"direct"},@{@"action":@"sniff"},@{@"protocol":@"dns",@"action":@"hijack-dns"},@{@"ip_is_private":@YES,@"action":@"route",@"outbound":@"direct"}],@"final":@"proxy"}};
}
static NSString *copyCore(NSString *base,NSString *folder){
    NSData *binary=[NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:@"cores/sing-box"]];require(binary&&binary.length<160*1024*1024);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(binary.bytes,(CC_LONG)binary.length,digest);NSMutableString *hash=[NSMutableString string];for(int i=0;i<sizeof(digest);i++)[hash appendFormat:@"%02x",digest[i]];
    require([hash isEqualToString:@SINGBOX_SHA256]);
    NSString *file=[folder stringByAppendingPathComponent:@"sing-box"];require([binary writeToFile:file options:NSDataWritingAtomic error:nil]);require(chmod(file.fileSystemRepresentation,0700)==0);return file;
}
int main(int argc,char **argv){@autoreleasepool{
    int result=1,lock=-1,status=0;pid_t child=-1;SCPreferencesRef preferences=NULL;NSString *folder=nil;
    @try {
        require(argc==7&&geteuid()==0);BOOL tun=!strcmp(argv[1],"tun");require(tun||!strcmp(argv[1],"proxy"));
        pid_t parent=(pid_t)number(argv[2],2,INT_MAX);uid_t uid=(uid_t)number(argv[3],1,INT_MAX);int socks=(int)number(argv[4],1,65535),http=(int)number(argv[5],0,65535),mtu=(int)number(argv[6],1280,1500);
        require(socks>0&&mtu>0&&(tun||http>0));struct proc_bsdinfo owner;require(processInfo(parent,&owner)&&owner.pbi_uid==uid);
        char directory[PATH_MAX];require(nativeDirectory(directory));NSString *base=[NSString stringWithUTF8String:directory];
        lock=open("/var/run/com.amyrax.vyrax-network.lock",O_CREAT|O_RDWR|O_NOFOLLOW,0600);require(lock>=0&&flock(lock,LOCK_EX|LOCK_NB)==0);
        preferences=SCPreferencesCreate(NULL,CFSTR("Vyrax"),NULL);require(preferences!=NULL);recover(preferences);
        signal(SIGTERM,stop);signal(SIGINT,stop);signal(SIGPIPE,SIG_IGN);
        if(tun){
            require(!tunnelUp());char temporary[]="/var/run/vyrax-tun-XXXXXX";require(mkdtemp(temporary)!=NULL);folder=[NSString stringWithUTF8String:temporary];
            NSString *core=copyCore(base,folder),*config=[folder stringByAppendingPathComponent:@"tun.json"];
            NSDictionary *value=tunConfig(socks,mtu,[base stringByAppendingPathComponent:@"cores/xray"]);
            require([[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] writeToFile:config options:NSDataWritingAtomic error:nil]);require(chmod(config.fileSystemRepresentation,0600)==0);
            child=launchTunnel(core.fileSystemRepresentation,config.fileSystemRepresentation,lock);require(child>0);
        }
        struct pollfd input={STDIN_FILENO,POLLIN,0};NSMutableData *pending=[NSMutableData data];BOOL ready=NO;CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+10;
        while(!quitting&&sameOwner(parent,&owner)&&(!tun||tunnelRunning(&child,&status))){
            if(poll(&input,1,200)>0){
                char bytes[4096];ssize_t count=read(STDIN_FILENO,bytes,sizeof(bytes));if(count<=0)break;
                [pending appendBytes:bytes length:count];require(pending.length<=8192);
                for(;;){const char *data=pending.bytes;const char *end=memchr(data,'\n',pending.length);if(!end)break;NSUInteger size=end-data;NSString *line=[[NSString alloc]initWithBytes:data length:size encoding:NSUTF8StringEncoding];[pending replaceBytesInRange:NSMakeRange(0,size+1) withBytes:NULL length:0];if([line isEqualToString:@"stop"]){quitting=1;break;}require([line isEqualToString:@"alive"]);deadline=CFAbsoluteTimeGetCurrent()+10;}
            }
            if(quitting||CFAbsoluteTimeGetCurrent()>deadline)break;
            if(!ready&&(!tun||tunnelUp())){configure(preferences,tun,http,socks);puts("VYRAX_NETWORK_READY");printf("VYRAX_NETWORK_PID=%d\n",getpid());fflush(stdout);ready=YES;}
        }
        require(ready&&(!tun||child>0||(WIFEXITED(status)&&WEXITSTATUS(status)==0)));result=0;
    } @catch(NSException *error){fprintf(stderr,"err.tunnelFailed\n");}
    @finally {
        if(child>0){kill(child,SIGTERM);for(int i=0;i<100&&tunnelRunning(&child,&status);i++)usleep(100000);if(child>0){kill(child,SIGKILL);waitpid(child,&status,0);}}
        if(preferences){@try{recover(preferences);}@catch(NSException *error){result=1;fprintf(stderr,"err.proxyRestore\n");puts("VYRAX_NETWORK_RESTORE_FAILED");}CFRelease(preferences);}
        if(folder)[NSFileManager.defaultManager removeItemAtPath:folder error:nil];if(lock>=0)close(lock);
    }printf("VYRAX_NETWORK_EXIT=%d\n",result);fflush(stdout);return result;
}}
