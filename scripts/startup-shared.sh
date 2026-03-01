#!/bin/bash

sudo wget -P shared/ https://archive.apache.org/dist/zookeeper/zookeeper-3.8.6/apache-zookeeper-3.8.6-bin.tar.gz
sleep 2
sudo wget -P shared/ https://archive.apache.org/dist/hadoop/common/hadoop-3.4.2/hadoop-3.4.2.tar.gz
sleep 2
sudo chmod 777 shared/hadoop-3.4.2.tar.gz
sleep 2
sudo chmod 777 shared/apache-zookeeper-3.8.6-bin.tar.gz