hadoop-single-node-cluster
=======================

This will install a single node hadoop cluster on a machine with single command.  This is intended as use for a dev setup or simple testing.

- This is part of [NeverwinterDP the Data Pipeline for Hadoop](https://github.com/DemandCube/NeverwinterDP)



## Installation


# One liner 
```
  curl -sSL https://raw.githubusercontent.com/DemandCube/hadoop-single-node-cluster/master/INSTALL-HADOOP | bash -s -- -r
```
NOTE: Meant to be run as root

# Compatibility

OS
=======
* CentOS 6.5
```
Should be good on RED-HAT Family of Distros
```
ENVIRONMENTS (Been tested on)
- vagrant
- ec2 (centos 6.5 x86_64)
- digitalocean (centos 6.5 x86_64)

# Usage


* * *
## multiinit
```
Usage: INSTALL-HADOOP [-rf]
This will

    -r,                              (Optional) REMOTE - Pulls all templates as remote 
    -f,                              (Optional) FORCE  - Forces in install if less them 4 gigs of ram
```

# Local Execution
```
git clone https://github.com/DemandCube/hadoop-single-node-cluster.git
cd hadoop-single-node-cluster
./INSTALL-HADOOP
```

* * *

## Contributing

See the [NeverwinterDP Guide to Contributing] (https://github.com/DemandCube/NeverwinterDP#how-to-contribute)


