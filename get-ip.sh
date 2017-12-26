#!/bin/bash

# arbitrary code

#---------------------- Function Declarations ----------------------#

# DESC: this function optionally runs through all of the saved servers, checking
#	to see if they still work. I can also be used to see if a particular server is
#	capable of returning an IP address in the expected format.
function testURLs {
	
	read -p "Would you like to check saved URLs [Y/n]: " opt
	if [ "${opt,,}" != "n" ]; then
		# check saved URLs
		echo "Checking saved URLs..."
		while read url
		do
			url=$(sed 's#http.://##' <<< "$url")
			# extract server from url
			server=$(cut -f1 -d/ <<< $url)
			
			# make call for IP and attempt to extract
			mode="https"
			ip=$(curl -s --connect-timeout 5 https://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
			[ "$ip" == "" ] && ip=$(curl -s --connect-timeout 5 http://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1) && mode="http"
			[ "$ip" != "" ] && echo "$server works! your IP is $ip; fetch using $mode" || echo "$url doesn't work; site may be down, blocked, or responding too slowly, or we may not be scraping output correctly."
		done <<< "$serverList"
	fi	
	
	echo -e "\nBegin manual checking. Type \"exit\" or \"quit\" to close this window."
	while :
	do
		echo "----------------------------------------------------"
		read -p "URL for fetching IP: " url
		([ "${url,,}" == "quit" ] || [ "${url,,}" == "exit" ]) && exit
		url=$(sed 's#http.://##' <<< "$url")
		# extract server from url
		server=$(cut -f1 -d/ <<< $url)
		# ping the server to see if it's up
		success=$(ping -c 1 -W2 $server | grep -o "1 received" | grep -o "1" || echo 0)
		[ $success -eq 1 ] && failure="successfully pinged $url -- couldn't fetch ip; may not be scraping correctly" || ping="could not ping $url"
		# make call for IP and attempt to extract
		mode="https"
		ip=$(curl -s --connect-timeout 5 https://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
		[ "$ip" == "" ] && ip=$(curl -s --connect-timeout 5 http://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1) && mode="http"
		[ "$ip" != "" ] && echo "$server works! your IP is $ip; fetch using $mode" || echo "$failure"
	done
	exit
}

# DESC: return a formatted timestamp with the current time
function getTimestamp {
	date +%Y%m%d.%H%M%S
}

# DESC: this accepts a single string argument and outputs it to the screen with a timestamp
function debug {
	DEBUG=1
	if [ $DEBUG -eq 1 ]; then
		printf "[%s]: %s\n" "$(getTimestamp)" "$@" 1>&2
	fi
}

# DESC: this accepts a single string argument and logs it with timestamp to the error log 
#	file. It also passes the string along to the debug function so that if debugging is on, 
#	we get notified on screen as well.
function logErr {
	# enable or disable logging
	LOGERR=1
	
	# if enabled, write to the log with machine name and timestamp
	if [ $LOGERR -eq 1 ]; then
		host=$(hostname)
		printf "[%s]: On $host: %s\n" "$(getTimestamp)" "$@"  >> "$errLog"
	fi
	debug "ERROR: $@"
}

# DESC: this function attempts to fetch the external IP with dig. If dig is not installed,
#	it will fall back to curl
# RETURN: returns the external ip and the server that was used to find it separated by a tab
	#ex: 10.0.0.1	opendns.com
function getIP {
	# attempt with dig first
	if [ "$(which dig)" != "" ]; then
		ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
		echo -e "$ip\topendns.com"
		exit
	fi

	# dig isn't installed attempt with curl
	if [ "$(which curl)" == "" ]; then
		logErr "Neither dig nor curl is installed! Please install one of these programs first!"
		exit
	fi
	
	debug "Dig not installed; using curl."
	#strip the tabs we use here for readability and shuffle the list
	# so that we're not always pulling from the same server
	serverList="$(tr -d '\t' <<< "$serverList" | shuf)"

	while read url
	do
		#strip http(s):// away from url
		url=$(sed 's#http.://##' <<< "$url")
		server=$(cut -f1 -d/ <<< $url)
		debug "fetching IP using $url"
		# attempt to fetch with https
		ip=$(curl -s --connect-timeout 5 https://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
		[ "$ip" != "" ] && echo -e "$ip\t$server" && break

		# if https failed try http, returning ip with server or logging error
		ip=$(curl -s --connect-timeout 5 http://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
		[ "$ip" == "" ] && ip=$(curl -s --connect-timeout 5 http://$url | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
		[ "$ip" != "" ] && echo -e "$ip\t$server" && break || logErr "Can't fetch IP from $server -- site may be down, blocked, or responding too slowly"

	done <<< "$serverList"
}

# this function runs a ping test to check for an Internet connection and
#	returns "1" if there is and "" if there isn't
function hasInternetConnection {
	# servers to perform ping test against
	pingList="bing.com
		yahoo.com
		wikipedia.org
		amazon.com
		speedtest.net
		baidu.com
		qq.com
		wechat.com"
	# remove leading tabs that are there for the sake of readability
	pingList="$(tr -d '\t' <<< "$pingList")"
	
	# iterate through the server list to see if we have an Internet connection, dropping out
	#	once we have confirmed that we do
	while read server
	do
		debug "testing Internet connectivity via ping against $server"
		online=$(ping -c 1 "$server" | grep "1 received" | wc -l)
		[ $online -eq 1 ] && echo 1 && break
	done <<< "$pingList"

}

#---------------------- Environment Setup ----------------------#

errLog=~/ip-addresses/error.log
ipFile=~/ip-addresses/$(hostname).ip
host=$(hostname)
serverList="$(cat ip-fetch_server-list.txt)"

#---------------------- Script Body ----------------------#

# quit if there's no Internet connection
[ "$(hasInternetConnection)" == "" ] && logErr "no Internet connection" && exit

# If this script is called with "check" as the first argument, it will be started in a mode
#	that allows checking of sites that supposedly return the caller's external IP.
[ "$1" == "check" ] && testURLs

# create IP file if it doesn't already exist
[ ! -e $ipFile ] && echo "IP address update log for $(hostname)" > "$ipFile"
# get previously recorded and current IPs
oldIP=$(tail -n1 $ipFile | grep -oP "([0-9]{1,3}\.){3}[0-9]{1,3}")
fetched=$(getIP)
curIP=$(cut -f1 <<< "$fetched")
server=$(cut -f2 <<< "$fetched")

# quit if we couldn't fetch external IP and log
[ "$curIP" == "" ] && logErr "could not fetch external IP. All servers tried." && exit
# quit if IP hasn't changed
[ "$oldIP" == "$curIP" ] && debug "There has been no IP address change since it was last recorded." && exit

# log change of IP address
printf "[%s]: IP address changed to %s (pulled from %s)\n" "$(getTimestamp)" "$curIP" "$server" | tee -a $ipFile
