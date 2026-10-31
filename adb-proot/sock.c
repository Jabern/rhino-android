#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
int t(const char*p,int abs){int s=socket(AF_UNIX,SOCK_STREAM,0);struct sockaddr_un a={.sun_family=AF_UNIX};
 socklen_t l; if(abs){a.sun_path[0]=0;strcpy(a.sun_path+1,p);l=offsetof(struct sockaddr_un,sun_path)+1+strlen(p);}else{unlink(p);strcpy(a.sun_path,p);l=sizeof a;}
 int r=bind(s,(void*)&a,l);printf("%-45s %s\n",p,r?strerror(errno):"OK");if(!abs)unlink(p);close(s);return r;}
int main(int c,char**v){for(int i=1;i<c;i++)t(v[i],0);t("rhino-abstract-test",1);}
