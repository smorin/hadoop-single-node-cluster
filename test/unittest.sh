#!/bin/sh

curl -sSL https://raw.githubusercontent.com/DemandCube/hadoop-single-node-cluster/master/INSTALL-HADOOP | bash -s -- -r

set -e
echo ""
echo ""
echo ""
echo ""
echo ""
echo "*************************************************************************************************************"
echo "                                                      TESTS                                                  "
echo "*************************************************************************************************************"

declare -a result=()
EXIT_VALUE=0;

echo "Determining running hadoop services..."
R_MANAGER=false
N_MANAGER=false
NAMENODE=false
SNAMENODE=false
DATANODE=false
QUORUMPEERMAIN=false
HREGION=false
HMASTER=false

sNames=( $(/usr/jdk64/jdk*/bin/jps | awk '{print $2}') )
for sName in "${sNames[@]}"; do
        if [ "$sName" == "NameNode" ] ; then
                echo $sName
                NAMENODE=true
        elif [ "$sName" == "SecondaryNameNode" ] ; then
                echo $sName
                SNAMENODE=true
        elif [ "$sName" == "DataNode" ] ; then
                echo $sName
                DATANODE=true
        elif [ "$sName" == "QuorumPeerMain" ] ; then
                echo $sName
                QUORUMPEERMAIN=true
        elif [ "$sName" == "ResourceManager" ] ; then
                echo $sName
                R_MANAGER=true
        elif [ "$sName" == "NodeManager" ] ; then
                echo $sName
                N_MANAGER=true
        elif [ "$sName" == "HRegionServer" ] ; then
                echo $sName
                HREGION=true
        elif [ "$sName" == "HMaster" ] ; then
                echo $sName
                HMASTER=true
        fi
done



echo "1. HDFS"


mkdir -p /tmp/input
chmod 777 /tmp
echo "hello how are you!" >> /tmp/input/test.txt



sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/input || echo "/tmp/input not found"
sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/output || echo "/tmp/output not found"
sudo -u hdfs hdfs dfs -put /tmp/input /tmp/input && result+=('1. [PASS] - HDFS') || (result+=('1. [FAIL] - HDFS');EXIT_VALUE=1;)

echo "2. MAPREDUCE"

if [ "$R_MANAGER" == "true" ] && [ "$N_MANAGER" == "true" ] ; then
        sudo -u hdfs hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount /tmp/input /tmp/output && result+=('2. [PASS] - MAP_REDUCE') || result+=('2. [FAIL] - MAP_REDUCE')
else
        result+=('2. [FAIL] - MAP_REDUCE');
        EXIT_VALUE=1;
fi

echo "3. HIVE"
echo "DROP TABLE IF EXISTS pokes;CREATE TABLE pokes (foo INT, bar STRING);DROP TABLE IF EXISTS invites;CREATE TABLE invites (foo INT, bar STRING) PARTITIONED BY (ds STRING);SHOW TABLES;" >> /tmp/hivetest.sql
hive -f /tmp/hivetest.sql && result+=('3. [PASS] - HIVE') || (result+=('3. [FAIL] - HIVE'); EXIT_VALUE=1;)

echo "4. YARN"
if [ "$R_MANAGER" == "true" ] && [ "$N_MANAGER" == "true" ] ; then
        sudo -u hdfs yarn jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 16 1000 && result+=('4. [PASS] - YARN') || result+=('4. [FAIL] - YARN')
else
        result+=('4. [FAIL] - YARN');
        EXIT_VALUE=1;
fi



echo "5. HBASE"
echo "Identifying HMaster and HRegionServer..."
if [ "$HMASTER" == "true" ] && [ "$HREGION" == "true" ] ; then
        echo "disable 'test';drop 'test';create 'test', 'cf';put 'test', 'row1', 'cf:a', 'value1';put 'test', 'row2', 'cf:b', 'value2';put 'test', 'row3', 'cf:c', 'value3';scan 'test';exit;" >> /tmp/hbasescript.rb
        hbase shell /tmp/hbasescript.rb && result+=('5. [PASS] - HBASE') || (result+=('5. [FAIL] - HBASE'); EXIT_VALUE=1;)
else
        result+=('5. [FAIL] - HBASE');
        EXIT_VALUE=1;
fi

echo ""
echo ""
echo "*************************************************************************************************************"
echo "                                                TEST RESULTS                                                 "
echo "*************************************************************************************************************"
echo ""
for i in "${result[@]}"
do
   echo "$i"
done
echo ""
echo "*************************************************************************************************************"
echo "exit $EXIT_VALUE";
exit $EXIT_VALUE;
