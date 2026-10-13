// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
#include <libproc.h>
#include <mach-o/dyld.h>
#include <sys/proc_info.h>
#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
static int processInfo(pid_t pid, struct proc_bsdinfo *info) {
    return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, info, sizeof(*info)) == sizeof(*info);
}
static int sameOwner(pid_t pid, const struct proc_bsdinfo *original) {
    struct proc_bsdinfo current;
    return processInfo(pid, &current) && current.pbi_uid == original->pbi_uid &&
        current.pbi_start_tvsec == original->pbi_start_tvsec && current.pbi_start_tvusec == original->pbi_start_tvusec;
}
static int nativeDirectory(char *output) {
    char buffer[PATH_MAX], resolved[PATH_MAX]; uint32_t size=sizeof(buffer);
    if (_NSGetExecutablePath(buffer,&size) || !realpath(buffer,resolved)) return 0;
    char *slash=strrchr(resolved,'/');if(!slash)return 0;*slash=0;strcpy(output,resolved);return 1;
}
static long number(const char *text,long low,long high) {
    char *end;long n=strtol(text,&end,10);return *text && !*end && n>=low && n<=high ? n : -1;
}
