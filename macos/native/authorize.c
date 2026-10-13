// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#include <Security/Authorization.h>
#include <Security/AuthorizationTags.h>
#include <poll.h>
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#include "process.h"
static int copyBytes(int output,const char *bytes,ssize_t size) {
    while(size>0){ssize_t n=write(output,bytes,size);if(n<0&&errno==EINTR)continue;if(n<=0)return 0;bytes+=n;size-=n;}return 1;
}
int main(int argc,char **argv) {
    if(argc!=7 || number(argv[2],2,INT_MAX)!=getppid() || number(argv[3],1,INT_MAX)!=getuid())return 1;
    char directory[PATH_MAX],helper[PATH_MAX];if(!nativeDirectory(directory))return 1;
    if(snprintf(helper,sizeof(helper),"%s/vyrax-network",directory)>=sizeof(helper))return 1;
    AuthorizationRef authorization=NULL;
    OSStatus status=AuthorizationCreate(NULL,kAuthorizationEmptyEnvironment,kAuthorizationFlagDefaults,&authorization);
    if(status!=errAuthorizationSuccess)return 126;
    AuthorizationItem item={kAuthorizationRightExecute,0,NULL,0};AuthorizationRights rights={1,&item};
    status=AuthorizationCopyRights(authorization,&rights,kAuthorizationEmptyEnvironment,
        kAuthorizationFlagInteractionAllowed|kAuthorizationFlagExtendRights|kAuthorizationFlagPreAuthorize,NULL);
    if(status!=errAuthorizationSuccess){AuthorizationFree(authorization,kAuthorizationFlagDestroyRights);return 126;}
    FILE *channel=NULL;
    // Native macOS administrator dialog; only this fixed, narrow helper is elevated.
    status=AuthorizationExecuteWithPrivileges(authorization,helper,kAuthorizationFlagDefaults,argv+1,&channel);
    if(status!=errAuthorizationSuccess || !channel){AuthorizationFree(authorization,kAuthorizationFlagDestroyRights);return 126;}
    signal(SIGPIPE,SIG_IGN);setvbuf(channel,NULL,_IONBF,0);
    struct pollfd ports[2]={{STDIN_FILENO,POLLIN,0},{fileno(channel),POLLIN,0}};
    char bytes[4096],tail[8192]={0};size_t used=0;int result=1;
    for(;;){
        if(poll(ports,2,-1)<0){if(errno==EINTR)continue;break;}
        if(ports[0].revents&(POLLIN|POLLHUP|POLLERR)){
            ssize_t n=read(STDIN_FILENO,bytes,sizeof(bytes));
            if(n<=0){copyBytes(fileno(channel),"stop\n",5);ports[0].fd=-1;}
            else if(!copyBytes(fileno(channel),bytes,n))break;
        }
        if(ports[1].revents&(POLLIN|POLLHUP|POLLERR)){
            ssize_t n=read(fileno(channel),bytes,sizeof(bytes));if(n<=0){result=strstr(tail,"VYRAX_NETWORK_EXIT=0\n")?0:1;break;}
            if(used+(size_t)n>=sizeof(tail)){size_t keep=sizeof(tail)/4;memmove(tail,tail+used-keep,keep);used=keep;}
            memcpy(tail+used,bytes,n);used+=n;tail[used]=0;
            if(!copyBytes(STDOUT_FILENO,bytes,n))break;
        }
    }
    fclose(channel);AuthorizationFree(authorization,kAuthorizationFlagDestroyRights);return result;
}
