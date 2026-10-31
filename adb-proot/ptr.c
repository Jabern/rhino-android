#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <signal.h>
int main(int c,char**v){
  pid_t p=fork();
  if(!p){ long r=ptrace(PTRACE_TRACEME,0,0,0); printf("TRACEME=%ld errno=%s\n",r,r?strerror(errno):"ok"); fflush(stdout);
          raise(SIGSTOP); execl("/system/bin/true","true",(char*)0); printf("execl: %s\n",strerror(errno)); _exit(9);}
  int st; waitpid(p,&st,0); printf("stopped=%d\n",WIFSTOPPED(st));
  long r=ptrace(PTRACE_SETOPTIONS,p,0,PTRACE_O_TRACEEXEC); printf("SETOPT=%ld %s\n",r,r?strerror(errno):"");
  ptrace(PTRACE_CONT,p,0,0); waitpid(p,&st,0); printf("after cont: stopped=%d sig=%d exited=%d code=%d\n",WIFSTOPPED(st),WIFSTOPPED(st)?WSTOPSIG(st):0,WIFEXITED(st),WIFEXITED(st)?WEXITSTATUS(st):0);
  if(WIFSTOPPED(st)){ptrace(PTRACE_CONT,p,0,0); waitpid(p,&st,0); printf("final exited=%d code=%d\n",WIFEXITED(st),WEXITSTATUS(st));}
  return 0;}
