// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
int main(void){@autoreleasepool{
    SCPreferencesRef preferences=SCPreferencesCreate(NULL,CFSTR("Vyrax test"),NULL);
    NSArray *services=CFBridgingRelease(SCNetworkServiceCopyAll(preferences));
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    for(id item in services){
        SCNetworkServiceRef service=(__bridge SCNetworkServiceRef)item;
        NSMutableDictionary *protocols=[NSMutableDictionary dictionary];
        for(NSString *type in @[@"DNS",@"Proxies"]){
            SCNetworkProtocolRef protocol=SCNetworkServiceCopyProtocol(service,(__bridge CFStringRef)type);
            if(protocol){protocols[type]=@{@"enabled":@(SCNetworkProtocolGetEnabled(protocol)),@"config":(__bridge NSDictionary *)SCNetworkProtocolGetConfiguration(protocol)?:NSNull.null};CFRelease(protocol);}
        }
        result[(__bridge NSString *)SCNetworkServiceGetServiceID(service)]=protocols;
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingSortedKeys error:nil];
    fwrite(data.bytes,1,data.length,stdout);CFRelease(preferences);return 0;
}}
