#!/bin/bash
echo -e "\e[1;31;40m####### \e[1;32m#    #    \e[1;33m####### \e[1;34m ##### \e[0m"
echo -e "\e[1;31;40m#       \e[1;32m#   #     \e[1;33m#     # \e[1;34m#     #\e[0m"
echo -e "\e[1;31;40m#       \e[1;32m#  #      \e[1;33m#     # \e[1;34m#      \e[0m"
echo -e "\e[1;31;40m#####   \e[1;32m###       \e[1;33m#     # \e[1;34m ##### \e[0m"
echo -e "\e[1;31;40m#       \e[1;32m#  #      \e[1;33m#     # \e[1;34m      #\e[0m"
echo -e "\e[1;31;40m#       \e[1;32m#   #     \e[1;33m#     # \e[1;34m#     #\e[0m"
echo -e "\e[1;31;40m#       \e[1;32m#    #    \e[1;33m####### \e[1;34m ##### \e[0m"

# TODO
# 自动部署环境
# 半自动做实验

# 检测环境
if [ `whoami` != 'shiyanlou' ]
then
    echo '环境错误，请在正确的环境中运行'
    exit
fi

echo -e "\e[1;31;40m操作系统实验半自动化助手\e[0m"
echo "初始化实验环境..."
sleep 3

echo "目前仅支持系统调用实验"

function Init()
{
    if mountpoint -q '/home/shiyanlou/oslab/hdc'
    then
        sudo umount '/home/shiyanlou/oslab/hdc'
    fi
    cd '/home/shiyanlou/oslab'
    ls|grep -v 'hit-oslab-linux-20110823.tar.gz'|xargs rm -rf
    tar -zxf /home/shiyanlou/oslab/hit-oslab-linux-20110823.tar.gz \
        -C /home/shiyanlou/
    cd /home/shiyanlou/oslab
    cd ./linux-0.11/
    # make clean
    # make all -j 2
    if [ ! -d '/home/shiyanlou/oslab/linux-0.11' ];then
        echo "初始化失败，请检查hit-oslab-linux-20110823.tar.gz"
        exit
    fi
}

Init

# exit 0

###############################系统调用#
cd '/home/shiyanlou/oslab/linux-0.11'
sed -i '72a\extern int sys_iam();\nextern int sys_whoami();' 'include/linux/sys.h'
sed -i '88csys_setreuid,sys_setregid,sys_iam,sys_whoami };' 'include/linux/sys.h'
sed -i '61s/72/74/' 'kernel/system_call.s'
sed -i '132a\\#define __NR_iam        72\n\#define __NR_whoami     73\n' 'include/unistd.h'

    cd 'lib'

cat>'whoami.c'<<EOF
#define __LIBRARY__
#include <unistd.h>

_syscall2(int, whoami, char *, name, unsigned int, size)
EOF

cat>'iam.c'<<EOF
#define __LIBRARY__
#include <unistd.h>

_syscall1(int, iam, const char *, name)
EOF

cd ..
cd 'kernel'

cat>'who.c'<<EOF
#include <unistd.h>
#include <asm/segment.h>
#include <errno.h>
#include <string.h>

char msg[32];

int sys_iam(const char * name)
{
    char tep[34];
    int i = 0;
    for(; i < 34; i++)
    {
        tep[i] = get_fs_byte(name+i);
        if(tep[i] == '\0')  break;
    }

    if (i > 31) return -(EINVAL);

    strcpy(msg, tep);
    return i;
}
int sys_whoami(char * name, unsigned int size)
{
    int len = 0;
    for (;msg[len] != '\0'; len++);
    
    if (len > size) 
    {
        return -(EINVAL);
    }
    
    int i = 0;
    for(i = 0; i < size; i++)
    {
        put_fs_byte(msg[i], name+i);
        if(msg[i] == '\0') break;
    }
    return i;
}
EOF

cd ..
cd 'lib'

cat>>'Makefile'<<EOF
iam.s iam.o : iam.c ../include/unistd.h ../include/sys/stat.h \
  ../include/sys/types.h ../include/sys/times.h ../include/sys/utsname.h \
  ../include/utime.h

whoami.s whoami.o : whoami.c ../include/unistd.h ../include/sys/stat.h \
  ../include/sys/types.h ../include/sys/times.h ../include/sys/utsname.h \
  ../include/utime.h
EOF

cd ..
cd 'kernel'

sed -i '29s/$/ who.o/' 'Makefile'

cd ..

make clean
make -j 2

cd ..

sudo ./mount-hdc
sed -i '132a\\#define __NR_iam        72\n\#define __NR_whoami     73\n' 'hdc/usr/include/unistd.h'
cp '/home/teacher/testlab2.c' 'hdc/usr/root/'
cp '/home/teacher/testlab2.sh' 'hdc/usr/root/'

cd 'hdc/usr/root/'

cat>'iam.c'<<EOF
#define  __LIBRARY__
#include <unistd.h>
_syscall1(int,iam,const char*,name);

int main(int argc, char* argv[]){
    iam(argv[1]);
    return 0;
}
EOF

cat>'whoami.c'<<EOF
#define __LIBRARY__
#include <stdio.h>
#include <unistd.h>
_syscall2(int, whoami, char*, name, unsigned int, size);

int main(int argc, char* argv[]){
    char name[26];
    whoami(name,sizeof(name));
    printf("%s\n", name);

    return 0;
}
EOF

# This is a very very long string!

cat>'mr.sh'<<EOF
gcc testlab2.c -o test
gcc whoami.c -o whoami
gcc iam.c -o iam
EOF

sudo chmod 0777 'mr.sh'

cd ~/oslab/

sudo umount hdc

###############################


