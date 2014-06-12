#!/usr/bin/env bash
email_contact=$1 # nagios wants the sysadmin's email address
if [[ $email_contact == "" ]]
    then
        echo "Usage: create_cluster.sh someone@example.com"
        echo "You must supply a contact email for Nagios monitoring. Exiting."
        exit 1
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
    url=$1
    target_status=$2
    s=0
    while [[ $s != $target_status ]]
        do
            s=$(curl -o /dev/null -s -w %{http_code} $url)
            if [[ $s == "000" ]]
                then
                    echo "<no response from server>"
                else
                    echo "HTTP status: $s"
            fi
            sleep 2
        done
}

echo "First install and start needed services"
sudo yum install -y ntp ntpdate ntp-doc  # in many installs, ex. RHEL EC2 AMI, we already have ntpd and ntpupdate installed
sudo chkconfig ntpd on
sudo service ntpd restart
echo "To get ambari with yum we need the Hortonworks repo"
sudo yum install -y wget
sudo wget -P /etc/yum.repos.d/ http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.6.0/ambari.repo
sudo yum -y install ambari-server ambari-agent

my_fqdn=$(hostname -f)
if [ !  $? -eq 0 ] ; then
my_fqdn=$(hostname)

echo "FQDN:$my_fqdn"
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 $my_fqdn" > /etc/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
fi
echo "FQDN:$my_fqdn"


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
echo "Pausing for 15 seconds to let Ambari server settle down"
sleep 15

#if cluster already exists delete it
if check_http_status  '-H "X-Requested-By: ambari" -u admin:admin -i  http://localhost:8080/api/v1/clusters/cl1' 200; then
	curl -H "X-Requested-By: ambari" -u admin:admin -i -X DELETE http://localhost:8080/api/v1/clusters/cl1
fi

echo "Now cause a cluster to be created with our loaded blueprint"
curl -v -X POST -d @cluster-creation.json http://admin:admin@localhost:8080/api/v1/clusters/cl1 --header "Content-Type:application/json" --header "X-Requested-By:mycompany"
echo ""
echo "Single node Ambari setup finished. Point browser to localhost:8080 and log in as admin:admin to use Ambari."
