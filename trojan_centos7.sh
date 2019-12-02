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
	wget https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-linux-amd64.tar.xz
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
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:RSA-AES128-GCM-SHA256:RSA-AES256-GCM-SHA384:RSA-AES128-SHA:RSA-AES256-SHA:RSA-3DES-EDE-SHA",
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
        "cipher": "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256",
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
	zip -q -r trojan-client.zip /usr/src/trojan-client/
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
    green "server password is" $trojan_passwd
    green "server config is located at /usr/src/trojan/server.conf"
	green "======================================================================"
	green "Torjan has been successfully installed. Please use the link below to download the *fully configured* trojan client"
	green "1、Copy the link below and open it in a browser and download the client"
	blue "http://${your_domain}/$trojan_path/trojan-client.zip"
	green "2、将下载的压缩包解压，打开文件夹，打开start.bat即打开并运行Trojan客户端"
	green "3、打开stop.bat即关闭Trojan客户端"
	green "4、Trojan客户端需要搭配浏览器插件使用，例如switchyomega等"
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