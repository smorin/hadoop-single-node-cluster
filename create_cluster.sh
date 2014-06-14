#!/usr/bin/env bash

cat HADOOP-SINGLE-NODE-CLUSTER
printf "\n\n"

sleep 1

# Check memory and if it's low warn the user
ram=$(free -l | head -n 2 | tail -n 1 | awk '{print $2}')
if [ "$ram" == "" ] ; then
    echo "WARNING: Problem checking how much ram you have."
else
    # test if machine has 4 gigs
    if [ $ram -lt 4194304 ] ; then
        echo "WARNING NOT ENOUGH MEMORY"
        echo "RAM=$ram kilobytes"
        echo "NOTE: 1 gig of ram is 1048576 kilobytes"
        echo ""
        echo "RECOMMENDED: Minimum of 4 Gigs of RAM or will probably fail"
        echo ""
        exit 1;
    fi
fi

if [ -f /etc/redhat-release ] ; then
    echo "Using OS:"
    cat /etc/redhat-release
else
    echo "WARNING this is only tested on CENTOS this may not work"
    printf "\n\n"
fi


email_contact=$1 # nagios wants the sysadmin's email address
if [[ $email_contact == "" ]] ; then
    echo "Usage: create_cluster.sh [someone@example.com]"
    echo "Optionally supply a contact email for Nagios monitoring. Exiting."

    email_contact='nobody@noop.com'
    echo "Using default email for nagios: ${email_contact}"
    echo "Add argument to custom install email"
fi



function check_http_status(){
    url=$1
    target_status=$2
    actual_status=$(curl -o /dev/null -s -w %{http_code} $url)
    if [[ $target_status == actual_status ]]; then
                #echo "Target status matched."
                echo true
        else
                #echo "Target status $target_status not equal to $actual_status"
                echo false
        fi
}


function wait_until_some_http_status () {
    local url=$1
    local target_status=$2
    local s=0
    local spinstr='|/-\'
    local clean_spin=0


    while [[ $s != $target_status ]]
        do
            s=$(curl -o /dev/null -s -w %{http_code} $url)
            if [[ $s == "000" ]]
                then
                    if [ $clean_spin -eq 1 ] ; then
                        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
                    fi
                    local temp=${spinstr#?}
                    printf "no response from server - [%c]  " "$spinstr"
                    local spinstr=$temp${spinstr%"$temp"}
                    clean_spin=1
                    #echo "<no response from server>"
                else
                    echo "HTTP status: $s"
            fi
            sleep 2

        done
}

spinner()
{
    local thetime=$1
    local delay=0.75
    local spinstr='|/-\'
    for (( c=0 ; c<=$thetime ; c++ )) {
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    }
    printf "    \b\b\b\b"
}

echo "First install and start needed services"
sudo yum install -y ntp ntpdate ntp-doc  # in many installs, ex. RHEL EC2 AMI, we already have ntpd and ntpupdate installed
sudo chkconfig ntpd on
sudo service ntpd restart
echo "To get ambari with yum we need the Hortonworks repo"
sudo yum install -y wget
sudo wget -c -P /etc/yum.repos.d/ http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.6.0/ambari.repo
sudo yum -y install ambari-server ambari-agent

# hostname -f
# hostname
# uname -n
# /etc/sysconfig/network
# /etc/hosts
# /etc/hostname

my_fqdn=$(python -c 'from socket import getfqdn; print getfqdn()')

# Internally Ambari uses the following to get it's hostname
# >>> import socket
# >>> socket.getfqdn()
# 'localhost.localdomain'

ping -c 1 $my_fqdn

if [ !  $? -eq 0 ] ; then
my_fqdn=$(hostname)

# get the main ip address
# this gets the ip address that would be used to route to ip 8.8.8.8
my_ip=`ip route get 8.8.8.8 | awk 'NR==1 {print $NF}'`
my_short_fqdn=$my_fqdn
my_long_fqdn="${my_short_fqdn}.sandbox.neverwinterdp.com"

echo "FQDN:$my_fqdn"
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 $my_fqdn" > /etc/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
echo "$my_ip      ${my_long_fqdn} $my_fqdn" >> /etc/hosts
my_fqdn=$my_long_fqdn
fi
echo "FQDN:$my_lofqdn"


sudo ambari-agent restart
sudo ambari-server setup -v -s
sudo ambari-server restart

echo "Replace the dummy email address in the blueprint JSON file with the specified email address"
sed s/NAGIOS_CONTACT_GOES_HERE/$email_contact/ blueprint-raw.json > blueprint.json

echo "Trying http://localhost:8080/api/v1/blueprints to confirm Ambari server is up..."
wait_until_some_http_status "http://admin:admin@localhost:8080/api/v1/blueprints" "200"
sleep 2 # wait a few moments longer just to let the server settle down

echo "Add the blueprint.json blueprint file to our Ambari server's available blueprints"
curl -v -X POST -d @blueprint.json http://admin:admin@localhost:8080/api/v1/blueprints/bp-all-services --header "Content-Type:application/json" --header "X-Requested-By:mycompany"

echo "Trying http://localhost:8080/api/v1/clusters to confirm Ambari server is still up..."
wait_until_some_http_status "http://admin:admin@localhost:8080/api/v1/clusters" "200"

echo "Replace the dummy hostname in the cluster creation JSON file with this host's fully qualified domain name"
# now set above
# my_fqdn=$(hostname -f)
sed s/FQDN_GOES_HERE/$my_fqdn/ cluster-creation-raw.json > cluster-creation.json

echo ""
echo "Pausing for 30 seconds to let Ambari server settle down"
spinner 40

#if cluster already exists delete it
if check_http_status  '-H "X-Requested-By: ambari" -u admin:admin -i  http://localhost:8080/api/v1/clusters/cl1' 200; then
    echo "Cluster [cl1] already exists - deleting it"
	curl -H "X-Requested-By: ambari" -u admin:admin -i -X DELETE http://localhost:8080/api/v1/clusters/cl1
fi

echo "Now cause a cluster to be created with our loaded blueprint"
curl -v -X POST -d @cluster-creation.json http://admin:admin@localhost:8080/api/v1/clusters/cl1 --header "Content-Type:application/json" --header "X-Requested-By:mycompany"
echo ""
echo "Single node Ambari setup finished. Point browser to localhost:8080 and log in as admin:admin to use Ambari."
