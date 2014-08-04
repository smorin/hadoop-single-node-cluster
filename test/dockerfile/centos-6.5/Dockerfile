FROM centos:centos6
MAINTAINER DemandCube

RUN yum update -y
RUN yum install -y sudo wget curl rpm openssh-clients
RUN yum groupinstall -y 'Development Tools'

RUN mkdir /home/hadoopdevelopersetup
RUN git clone https://github.com/DemandCube/hadoop-single-node-cluster.git /home/hadoopdevelopersetup
RUN chmod +x /home/hadoopdevelopersetup/test/unittest.sh

ENTRYPOINT /home/hadoopdevelopersetup/test/unittest.sh
