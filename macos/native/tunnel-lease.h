// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#include <sys/wait.h>
// A second lease stops sing-box even if the root network helper is killed.
// The forked branch uses C/POSIX calls only, never Foundation after fork.
static pid_t launchTunnel(const char *core,const char *config,int lock) {
    pid_t parent=getpid();struct proc_bsdinfo owner;if(!processInfo(parent,&owner))return -1;
    pid_t lease=fork();if(lease!=0)return lease;
    close(lock);pid_t child=fork();if(child<0)_exit(1);
    if(!child){
        signal(SIGTERM,SIG_DFL);signal(SIGINT,SIG_DFL);signal(SIGPIPE,SIG_DFL);
        execl(core,core,"run","-c",config,NULL);_exit(1);
    }
    int status=0;
    while(!quitting&&sameOwner(parent,&owner)){
        if(waitpid(child,&status,WNOHANG)==child)_exit(WIFEXITED(status)?WEXITSTATUS(status):1);
        usleep(200000);
    }
    kill(child,SIGTERM);
    for(int i=0;i<80;i++){if(waitpid(child,&status,WNOHANG)==child)_exit(0);usleep(100000);}
    kill(child,SIGKILL);waitpid(child,&status,0);_exit(0);
}
static int tunnelRunning(pid_t *child,int *status){
    if(*child<=0)return 0;
    if(waitpid(*child,status,WNOHANG)==0)return 1;
    *child=-1;return 0;
}
