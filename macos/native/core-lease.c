// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#include <signal.h>
#include <sys/wait.h>
#include <stdio.h>
#include "process.h"
static volatile sig_atomic_t quitting=0;
static void stop(int signalNumber){quitting=1;}
int main(int argc,char **argv) {
    if(argc<3)return 1;pid_t parent=(pid_t)number(argv[1],2,INT_MAX);struct proc_bsdinfo owner;
    if(!processInfo(parent,&owner)||owner.pbi_uid!=getuid())return 1;
    char directory[PATH_MAX],core[PATH_MAX];if(!nativeDirectory(directory))return 1;
    if(snprintf(core,sizeof(core),"%s/cores/xray",directory)>=sizeof(core))return 1;
    signal(SIGTERM,stop);signal(SIGINT,stop);pid_t child=fork();if(child<0)return 1;
    if(!child){signal(SIGTERM,SIG_DFL);signal(SIGINT,SIG_DFL);argv[1]=core;execv(core,argv+1);_exit(1);}
    int status=0;
    while(!quitting&&sameOwner(parent,&owner)){if(waitpid(child,&status,WNOHANG)==child)return WIFEXITED(status)?WEXITSTATUS(status):1;usleep(200000);}
    kill(child,SIGTERM);
    for(int i=0;i<40;i++){if(waitpid(child,&status,WNOHANG)==child)return 0;usleep(200000);}
    kill(child,SIGKILL);waitpid(child,&status,0);return 0;
}
