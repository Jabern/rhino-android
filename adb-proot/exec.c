#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
int main(int c,char**v){
  void*p=mmap(0,4096,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0); memset(p,0,64);
  printf("anon RW->RX (execmem): %s\n", mprotect(p,4096,PROT_READ|PROT_EXEC)?strerror(errno):"OK");
  void*q=mmap(0,4096,PROT_READ|PROT_WRITE|PROT_EXEC,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
  printf("anon RWX: %s\n", q==MAP_FAILED?strerror(errno):"OK");
  int fd=open(v[1],O_RDONLY);
  void*f=mmap(0,4096,PROT_READ|PROT_EXEC,MAP_PRIVATE,fd,0); printf("file RX mmap: %s\n", f==MAP_FAILED?strerror(errno):"OK");
  void*g=mmap(0,4096,PROT_READ|PROT_WRITE,MAP_PRIVATE,fd,0);
  printf("file RW->RX untouched: %s\n", mprotect(g,4096,PROT_READ|PROT_EXEC)?strerror(errno):"OK");
  void*h=mmap(0,4096,PROT_READ|PROT_WRITE,MAP_PRIVATE,fd,0); ((char*)h)[10]^=1;
  printf("file RW->RX written (execmod): %s\n", mprotect(h,4096,PROT_READ|PROT_EXEC)?strerror(errno):"OK");
  return 0;}
