# ip-tracking
Track multiple system IPs with Syncthing, cron, and bash scripts

-------
This serves as an alternative to DDNS. The idea here is to track changes in IP addresses across multiple systems, logging IP changes in separate files for each host. Then Syncthing or any other application that provides folder synchronization serves to maintain the IP log files that track IP history across the connected machines.

The basic components are: 
 - <b>get-ip.sh</b>: This is a script that should be called by a cron job or similar task scheduler to fetch and log external IP changes. It can also be used in an interactive mode to test all of the urls in ip-fetch_server-list.txt or to check for compatibility of a new url that you are considering adding to ip-fetch_server-list.txt. To run in this mode, pass "check" as the first argument.
 - <b>ip-to-clipboard.sh</b>: This is a script that can be used to fetch the most recently recorded IP address for any system that tracks its own IP. It can be called with a IP log file (named as [hostname].ip) for incorporation in scripts to fetch the current IP address of a given system
 - <b>[hostname].ip</b>\*: A file with a name fitting this pattern represents an IP log file for the system with a matching hostname. Each line in such a file records a timestamp, the most recently discovered external IP address for that system, and the site used to determine the external IP. It is only updated when a change is detected by get-ip.sh
 - <b>ip-fetch_server-list.txt</b>: This file lists one web address per line (without leading http(s):// ). This list is used by get-ip.sh when attempting to discover a system's external IP using curl.
 - <b>error.log</b>\*: This file is modified anytime get-ip.sh has trouble fetching the external IP from a given source. Each line records a timestamp, the host name of the machine that experienced the issue, and a description of the issue.
 
    *\* These files are generated automatically by get-ip.sh when it is run.*

Warning!
--------
If you plan to use this on a system where someone might have access to modify any of your \*.sh script files files, be careful! Any arbitrary modifications to script files will result in those modifications being run anytime those scripts are run on any of your hosts, including scheduled calls to run get-ip.sh. In my particular case, I use gpg2 to sign my scripts. That way, I can check the signature before running. If the signature doesn't match, I know the file was modifed, and I don't run them.
