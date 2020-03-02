#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
bred(){
    echo -e "\033[31m\033[01m\033[05m$1\033[0m"
}
byellow(){
    echo -e "\033[33m\033[01m\033[05m$1\033[0m"
}

if [ ! -e '/etc/redhat-release' ]; then
red "==============="
red " Only CentOS7 is supported"
red "==============="
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
red "==============="
red " Only CentOS7 is supported"
red "==============="
exit
fi

function install_trojan(){
systemctl stop firewalld
systemctl disable firewalld
if [ "$CHECK" == "SELINUX=enforcing" ]; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
if [ "$CHECK" == "SELINUX=permissive" ]; then
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
yum -y install bind-utils wget unzip zip curl tar
green "======================="
yellow "Please enter the domain that you used to create an A record for this server"
green "======================="
read your_domain
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
	green "=========================================="
	green "Domain ping passed. Installing nginx and applying for https certificate."
	green "=========================================="
	sleep 1s
	rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    	yum install -y nginx
	systemctl enable nginx.service
	# setting up the fake webiste
	rm -rf /usr/share/nginx/html/*
	cd /usr/share/nginx/html/
	wget https://github.com/bnwproxy/bnwproxy-trojan/raw/master/dist/web.zip
    	unzip web.zip
	systemctl start nginx.service
	# applying for https certificate
	mkdir /usr/src/trojan-cert
	curl https://get.acme.sh | sh
	~/.acme.sh/acme.sh  --issue  -d $your_domain  --webroot /usr/share/nginx/html/
    	~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /usr/src/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan-cert/fullchain.cer \
        --reloadcmd  "systemctl force-reload  nginx.service"
	if test -s /usr/src/trojan-cert/fullchain.cer; then
        cd /usr/src
	wget https://github.com/trojan-gfw/trojan/releases/download/v1.14.0/trojan-1.14.0-linux-amd64.tar.xz
	tar xf trojan-1.*
	# download trojan client
	wget https://github.com/bnwproxy/bnwproxy-trojan/raw/master/dist/trojan-client.zip
	unzip trojan-client.zip
	cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-client/linux/fullchain.cer
    cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-client/mac/fullchain.cer
    cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-client/windows/fullchain.cer
    if [[ ! -v trojan_passwd ]]; then
        trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    fi
	cat > /usr/src/trojan-client/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
    cp /usr/src/trojan-client/config.json /usr/src/trojan-client/linux/config.json
    cp /usr/src/trojan-client/config.json /usr/src/trojan-client/mac/config.json
    cp /usr/src/trojan-client/config.json /usr/src/trojan-client/windows/config.json
    rm -rf /usr/src/trojan-client/config.json
	rm -rf /usr/src/trojan/server.conf
	cat > /usr/src/trojan/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/src/trojan-cert/fullchain.cer",
        "key": "/usr/src/trojan-cert/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
	cd /usr/src/trojan-client/
	zip -q -r trojan-client.zip .
	trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16)
	mkdir /usr/share/nginx/html/${trojan_path}
	mv /usr/src/trojan-client/trojan-client.zip /usr/share/nginx/html/${trojan_path}/
	# add script to enable services
	
	cat > /usr/lib/systemd/system/trojan.service <<-EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF

	chmod +x /usr/lib/systemd/system/trojan.service
	systemctl start trojan.service
	systemctl enable trojan.service
	green "======================================================================"
	green "Torjan has been successfully installed."
    green "Server config is located at /usr/src/trojan/server.conf"
    green "The client password is $trojan_passwd if you want to use mobile clients (IOS or Android)"
    green "Please use the link below to download the trojan client for desktops (windows, linux, mac)"
	green "1、Copy the link below and open it in a browser and download the client"
	blue "http://${your_domain}/$trojan_path/trojan-client.zip"
    green "2. Unzip the clients and enter the folder with the name of your OS (windows, linux, mac)"
    green "3. Select either using the gui or cli for connection"
    green "4. If gui is selected, open Connection -> Add -> "
    green "   Paste trojan://$trojan_passwd@${your_domain}:443#gfw-trojan ->"
    green "   **IMPORTANT** disable `Verify certificate` and `Verify Hostname`"
    green "   Click ok and then you are good to connect."
    green "   Notice you can click on the icons of system tray to select "
    green "   Global Mode, PAC Mode, or Global Mode"
	green "======================================================================"
	else
        red "================================"
	red "FAILED to apply for https cetificate"
	red "================================"
	fi
	
else
	red "================================"
	red "The entered domain does not map to the IP address of this server"
	red "Installation failed"
	red "================================"
fi
}

function remove_trojan(){
    red "================================"
    red "Uninstalling Trojan"
    red "Uninstalling Nginx"
    red "================================"
    systemctl stop trojan
    systemctl disable trojan
    rm -f /usr/lib/systemd/system/trojan.service
    yum remove -y nginx
    rm -rf /usr/src/trojan*
    rm -rf /usr/share/nginx/html/*
    green "=============="
    green "trojan uninstalled"
    green "=============="
}
start_menu(){
    clear
    green " ===================================="
    green " Intro：one-click install trojan     "
    green " System：>=centos7                   "
    green " Author：bnwproxy                 "
    green " Modified based on：www.atrandys.com "
    green " Youtube：atrandys                   "
    green " ===================================="
    echo
    green " 1. Install trojan"
    red " 2. Uninstall trojan"
    yellow " 0. Exit"
    echo
    read -p "Please enter a number:" num
    case "$num" in
    1)
    install_trojan
    ;;
    2)
    remove_trojan 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Please enter the correct number"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu
