FROM centos:7

RUN yum -y install make gcc gcc-c++ ncurses-devel which unzip perl cpio rsync fileutils bc bzip2 gzip sed git python file patch wget perl-Thread-Queue perl-Data-Dumper perl-ExtUtils-MakeMaker && \
    yum clean all

