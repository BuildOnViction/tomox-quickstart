#!/bin/bash

# Version
TOMOCHAIN_VERSION=v2.0.2-beta
TOMOX_SDK_VERSION=v1.0.1-beta
TOMOX_SDK_UI_VERSION=v1.0.1-beta

# Default service port
RABBITMQ_PORT_DEFAULT=5672
MONGODB_PORT_DEFAULT=27017
SDK_PORT_DEFAULT=8080
SDK_UI_PORT_DEFAULT=3000
INSTALL_PATH_DEFAULT=$HOME"/tomox-sdk"

RABBITMQ_PORT=$RABBITMQ_PORT_DEFAULT
MONGODB_PORT=$MONGODB_PORT_DEFAULT
SDK_PORT=$SDK_PORT_DEFAULT
SDK_UI_PORT=$SDK_UI_PORT_DEFAULT
INSTALL_PATH=$INSTALL_PATH_DEFAULT

EXCHANGE_ADDRESS=""
RELAYER_SC_ADDRESS="0xe7c16037992bEcAFaeeE779Dacaf8991637953F3"

SDK_BACKEND_RELEASE_URL="https://github.com/tomochain/tomox-sdk/releases/download/${TOMOX_SDK_VERSION}/tomox-sdk.${TOMOX_SDK_VERSION}.linux.amd64"
SDK_UI_RELEASE_URL="https://github.com/tomochain/tomox-sdk-ui/releases/download/${TOMOX_SDK_UI_VERSION}/tomox-sdk-ui.${TOMOX_SDK_UI_VERSION}.testnet.tar.gz"
FULLNODE_RELEASE_URL="https://github.com/tomochain/tomochain/releases/download/${TOMOCHAIN_VERSION}/tomo-linux-amd64"
FULLNODE_CHAIN_DATA=$INSTALL_PATH"/tomox/data"
TOMOX_GENESIS="https://raw.githubusercontent.com/tomochain/tomochain/master/genesis/testnet.json"
TOMOX_CHAIN_DATA_URL="https://chaindata-testnet.s3-ap-southeast-1.amazonaws.com/chaindata-testnet.tar"

PWD=$(pwd)

DOWNLOAD_CHAIN_DATA_ENABLED=1

TOMOX_UI_HTML_PATH="/var/www/tomox-sdk-ui"
NODE_NAME=$USER


UBUNTU=0
CENTOS=0


################################## raw function begin, depend on os ########################################

update_os(){
    if [ $UBUNTU -eq 1 ]; then
        sudo apt-get update
    elif [ $CENTOS -eq 1 ]; then
        sudo yum -y check-update
        install_package epel-release
    fi
   
}
install_package(){
    if [ $UBUNTU -eq 1 ]; then
        sudo apt-get install -y $1  
    elif [ $CENTOS -eq 1 ]; then
        sudo yum install -y $1
    fi  
}
start_service(){
    if [ $UBUNTU -eq 1 ] || [ $CENTOS -eq 1 ]; then
        sudo service $1 start
    fi
    
}
restart_service(){
    if [ $UBUNTU -eq 1 ] || [ $CENTOS -eq 1 ]; then
        sudo service $1 restart
    fi
}
check_installed_service(){
    if [ $UBUNTU -eq 1 ]; then
        if test -f "/etc/init.d/$1" ; then    
            return 1
        else
            return 0
        fi
    elif [ $CENTOS -eq 1 ] ; then 
        STATUS=`systemctl is-enabled $1`
        if [[ ${STATUS} == 'enabled' ]]; then
            return 1
        fi
        if [[ ${STATUS} == 'disabled' ]]; then
            return 1
        fi
        return 0
            
    fi
    return 2
}

# require nc installed
checl_open_port2(){
    local=0.0.0.0
    </dev/tcp/$local/$1
    if [ "$?" -ne 0 ]; then
        return 0
    else
        return 1
    fi
}
check_open_port(){
    if nc -zw1 0.0.0.0 $1; then
        return 1
    else
        return 0
    fi
}

# check service is running, if not start it
# require debian os
check_running_service(){
    if (( $(ps -ef | grep -v grep | grep $1 | wc -l) > 0 ))
    then
        return 1
    else
        return 0
fi
}

install_nginx(){
    if [ $UBUNTU -eq 1 ]; then
        install_package nginx
    elif [ $CENTOS -eq 1 ]; then
        install_package nginx
    fi  
    
}
install_supervisor(){
    if [ $UBUNTU -eq 1 ]; then
        install_package supervisor
    elif [ $CENTOS -eq 1 ]; then
        install_package supervisor
        restart_service supervisord
    fi
     
    
} 
install_docker(){
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo chmod +x get-docker.sh
    sudo sh get-docker.sh
    restart_service docker
}

# param 1 exchange_address
# param 2 contract_address
sdk_write_config(){
    coinsebase_patern="coinsebaseaddress"
    coinbase=$EXCHANGE_ADDRESS
    sc_patern="relayersmartcontract"
    sc=$RELAYER_SC_ADDRESS
    cp config.yaml config.yaml.bk 
    sed -i "s|${coinsebase_patern}|${coinbase}|g" config.yaml.bk
    sed -i "s|${sc_patern}|${sc}|g" config.yaml.bk
    mv config.yaml.bk $INSTALL_PATH"/config/config.yaml"
    cp errors.yaml $INSTALL_PATH"/config/errors.yaml"
}

check_running_docker_service(){
    if [[ $(docker ps -aqf "name=$1") ]]; then
        return 1
    else
        return 0
    fi
}

reset_mongodb(){
    sudo docker kill mongodb
    sudo docker rm mongodb
    sudo docker run --restart always -d -p $1:27017 --name mongodb \
    --hostname mongodb mongo:4.2 --replSet rs0

    sleep 5
    sudo docker exec -it mongodb mongo --eval "rs.initiate()"
}

reset_rabbitmq(){
    sudo docker kill rabbitmq
    sudo docker rm rabbitmq
    sudo docker run --restart always -d -p $1:5672 --name rabbitmq rabbitmq:3.8
}

setup_rabbitmq(){
    check_running_docker_service rabbitmq
    if [ $? -eq 0 ]; then
        reset_rabbitmq $RABBITMQ_PORT
    fi
    
}
setup_mongodb(){
    check_running_docker_service mongodb
    if [ $? -eq 0 ]; then
        reset_mongodb $MONGODB_PORT
    fi
}
stop_fullnode(){
    sudo supervisorctl stop tomox-node
}

supervisord_restart_fullnode(){
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl restart tomox-node
}
supervisord_stop_fullnode(){
    sudo supervisorctl stop tomox-node
}
supervisord_start_fullnode(){
    sudo supervisorctl start tomox-node
}
supervisord_stop_sdk(){
    sudo supervisorctl stop tomox-sdk
}

download_chain_data(){
    echo "Download chain data, it takes time!"
    wget -O $INSTALL_PATH"/tomox/chaindata-testnet.tar" $TOMOX_CHAIN_DATA_URL
    echo "Extracting chain data ......"
    tar xf $INSTALL_PATH"/tomox/chaindata-testnet.tar" -C $INSTALL_PATH"/tomox/"

}
download_tomo_binary(){
    echo "Downloading new tomo binary..."
    wget -O $INSTALL_PATH"/tomox/tomo" $FULLNODE_RELEASE_URL
    chmod +x $INSTALL_PATH"/tomox/tomo"
}
start_fullnode(){
    default_chaindata=$INSTALL_PATH"/tomox/data"
    if [ "$FULLNODE_CHAIN_DATA" != "$default_chaindata" ]; then
        echo "Start fullnode with specific user chain data"
        supervisord_stop_fullnode
        download_tomo_binary
        supervisord_restart_fullnode
    else
        if ! test -d $INSTALL_PATH"/tomox/data"; then
            write_tomoxnode_supervisor
            if [ "$DOWNLOAD_CHAIN_DATA_ENABLED" -eq 1 ]; then
                download_chain_data
            fi
            supervisord_stop_fullnode
            download_tomo_binary
            curl -L $TOMOX_GENESIS -o $INSTALL_PATH"/tomox/genesis.json"
        
            echo "">$INSTALL_PATH"/tomox/passparser"
            $INSTALL_PATH"/tomox/tomo" account new --datadir $FULLNODE_CHAIN_DATA --password $INSTALL_PATH"/tomox/passparser"
            echo $FULLNODE_CHAIN_DATA
            $INSTALL_PATH"/tomox/tomo" init $INSTALL_PATH"/tomox/genesis.json" --datadir $FULLNODE_CHAIN_DATA
            if [ "$DOWNLOAD_CHAIN_DATA_ENABLED" -eq 1 ]; then
                rm -rf $INSTALL_PATH"/tomox/data/tomo/chaindata"
                mv  $INSTALL_PATH"/tomox/chaindata" $INSTALL_PATH"/tomox/data/tomo/chaindata"
            fi 

            supervisord_restart_fullnode
        else
            echo "Preparing updated tomo fullnode"
            echo "Stopping tomo fullnode..."
            supervisord_stop_fullnode
            sleep 2
            download_tomo_binary
            echo "Starting updated tomo fullnode"
            supervisord_start_fullnode
        fi
    fi
}

setup_fullnode(){
    setup_mongodb
    start_fullnode

}

user_config_sdk(){
    echo "Input exchage address (it is the address you registered in relayer)"
    echo "if you are not registered, access https://relayer.testnet.tomochain.com to register"
    echo "Your relayer coinbase:"
    read exaddress
    if ! test -z "$exaddress" ;then
        EXCHANGE_ADDRESS=$exaddress
    fi

    #echo "Relayer Contract address:"
    #read readdress
    #if test -z "$readdress" ;then
    #    RELAYER_SC_ADDRESS=$readdress
    #fi
    
}

user_config_fullnode(){

    echo "Enter fullnode name:"
    read nodename
    if ! test -z "$nodename" ;then
        NODE_NAME=$nodename
    fi

    # echo "Enter fullnode chain data(if you dont have, press enter key):"
    # read datachain
    # if ! test -z "$datachain" ;then
    #     FULLNODE_CHAIN_DATA=$datachain
    # fi
    
}
supervisor_restart_sdk(){
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl restart tomox-sdk
}
start_sdk(){
    url=$SDK_BACKEND_RELEASE_URL
    rm -f $INSTALL_PATH"/tomox-sdk"
    wget -O $INSTALL_PATH"/tomox-sdk" $url
    chmod +x $INSTALL_PATH"/tomox-sdk"
    write_sdk_supervisor $INSTALL_PATH
    sdk_write_config
    supervisor_restart_sdk
    
}
# param 1: path to sdk binary
write_sdk_supervisor(){
    supervisor_conf="/etc/supervisor/conf.d/tomox-sdk.conf"
    if [ $UBUNTU -eq 1 ]; then
        supervisor_conf="/etc/supervisor/conf.d/tomox-sdk.conf"
    elif [ $CENTOS -eq 1 ]; then
        supervisor_conf="/etc/supervisord.d/tomox-sdk.ini"
    fi

    installpath_patern="tomoxinstallpath"
    installpath=$INSTALL_PATH
    
    cp tomoxsdk.supervisord tomoxsdk.supervisord.bk 
    sed -i "s|${installpath_patern}|${installpath}|g" tomoxsdk.supervisord.bk
    sudo mv tomoxsdk.supervisord.bk $supervisor_conf
}

write_tomoxnode_supervisor(){
    supervisor_conf="/etc/supervisor/conf.d/tomox-node.conf"
    if [ $UBUNTU -eq 1 ]; then
        supervisor_conf="/etc/supervisor/conf.d/tomox-node.conf"
    elif [ $CENTOS -eq 1 ]; then
        supervisor_conf="/etc/supervisord.d/tomox-node.ini"
    fi
    cp tomoxnode.supervisord tomoxnode.supervisord.bk 
    tomo_patern="tomobinarypath"
    tomo=$INSTALL_PATH"/tomox/tomo"
    sed -i "s|${tomo_patern}|${tomo}|g" tomoxnode.supervisord.bk

    datadir_patern="tomoxdatadir"
    datadir=$FULLNODE_CHAIN_DATA
    sed -i "s|${datadir_patern}|${datadir}|g" tomoxnode.supervisord.bk

    tomoxdir_patern="tomoxdirectory"
    tomoxdir=$INSTALL_PATH"/tomox"
    sed -i "s|${tomoxdir_patern}|${tomoxdir}|g" tomoxnode.supervisord.bk

    path_patern="installpath"
    path=$INSTALL_PATH
    sed -i "s|${path_patern}|${path}|g" tomoxnode.supervisord.bk

    name_patern="nodename"
    name=$NODE_NAME
    sed -i "s|${name_patern}|${name}|g" tomoxnode.supervisord.bk
    sudo mv tomoxnode.supervisord.bk $supervisor_conf
    
}

write_tomoxnode_bash(){
    tomobashpath=$INSTALL_PATH"/tomox/tomox.sh"
    cp tomox.bash tomox.bash.bk 
    tomo_patern="tomobinarypath"
    tomo=$INSTALL_PATH"/tomox/tomo"
    sed -i "s|${tomo_patern}|${tomo}|g" tomox.bash.bk

    datadir_patern="tomoxdatadir"
    datadir=$FULLNODE_CHAIN_DATA
    sed -i "s|${datadir_patern}|${datadir}|g" tomox.bash.bk

    tomoxdir_patern="tomoxdirectory"
    tomoxdir=$INSTALL_PATH"/tomox"
    sed -i "s|${tomoxdir_patern}|${tomoxdir}|g" tomox.bash.bk

    path_patern="installpath"
    path=$INSTALL_PATH
    sed -i "s|${path_patern}|${path}|g" tomox.bash.bk

    sudo mv tomox.bash.bk $tomobashpath
    
}
run_tomox_bash(){
    cd $INSTALL_PATH"/tomox"
    nohup bash tomox.sh &
    nohup bash tomox.sh &> ../logs/fullnode.log&
}

setup_sdk(){
    cd $PWD
    setup_rabbitmq
    for (( c=1; c<=15; c++ ))
    do  
        check_open_port 5672
        if [ "$?" -eq 1 ]; then
                echo "Waiting for rabbitmq to start...."
                sleep 15
                break
        fi
        echo "Waiting for rabbitmq to start..."
        sleep 2
    done
    start_sdk
}



setup_install_path(){
    if ! test -d $INSTALL_PATH; then
        echo "Create tomox-sdk install path"
        mkdir $INSTALL_PATH
    fi
    if ! test -d $INSTALL_PATH"/logs"; then
        echo "Create tomox-sdk logs directory"
        mkdir $INSTALL_PATH"/logs"
    fi
    if ! test -d $INSTALL_PATH"/config"; then
        echo "Create tomox-sdk logs directory"
        mkdir $INSTALL_PATH"/config"
    fi
    if ! test -d $INSTALL_PATH"/tomox"; then
        echo "Create tomox full node directory"
        mkdir $INSTALL_PATH"/tomox"
    fi
    if ! test -d $INSTALL_PATH"/tomox-sdk-ui"; then
        echo "Create tomox-sdk-ui full node directory"
        mkdir $INSTALL_PATH"/tomox-sdk-ui"
    fi

}
setup_docker(){
    check_running_service docker
    if [ "$?" -eq 0 ]; then
        echo "docker is not running"
        check_installed_service docker
        if [ "$?" -eq 1 ]; then
            echo "docker is installed but not running, starts it"
            start_service docker
        else
            echo "docker is not installed, installs it"
            install_docker
        fi

    fi
}
setup_supervisor(){
    name="supervisor"
    if [ $UBUNTU -eq 1 ]; then
        name="supervisor"
    elif [ $CENTOS -eq 1 ]; then
        name="supervisord"
    fi

    check_running_service $name
    if [ "$?" -eq 0 ]; then
        echo "Supervisor is not running"
        check_installed_service $name
        if [ "$?" -eq 1 ]; then
            echo "Service supervisor is installed but not running, starts it"
            start_service $name
        else
            echo "Service supervisor is not installed, installs it"
            install_supervisor
        fi
    fi
}

setup_nginx(){
    check_running_service nginx
    if [ "$?" -eq 0 ]; then
        echo "Nginx is not running"
        check_installed_service nginx
        if [ "$?" -eq 1 ]; then
            echo "Service nginx is installed but not running, starts it"
            start_service nginx
        else
            echo "Service nginx is not installed, installs it"
            install_nginx
        fi

    fi
    
}


config_tomox_ui_nginx(){
    nginx_conf="/etc/nginx/sites-enabled/tomox-sdk.conf"
    path=$TOMOX_UI_HTML_PATH
    if [ $UBUNTU -eq 1 ]; then
        nginx_conf="/etc/nginx/sites-enabled/tomox-sdk.conf"
        sudo rm -f /etc/nginx/sites-enabled/default
        path=$TOMOX_UI_HTML_PATH
        sample_conf="tomox-nginx.conf"
    elif [ $CENTOS -eq 1 ]; then
        nginx_conf="/etc/nginx/nginx.conf"
        path="/usr/share/nginx/tomox-sdk-ui"
        sample_conf="tomox-nginx-centos.conf"
    fi
    path_patern="htmlroot"
    sed "s|${path_patern}|${path}|g" $sample_conf>tomox-sdk.conf
    sudo cat tomox-sdk.conf >$nginx_conf
} 


setup_sdk_ui(){
    setup_nginx
    cd $PWD
    url=$SDK_UI_RELEASE_URL
    wget -O "tomox-sdk-ui.tar.gz" $url
    tar xzf "tomox-sdk-ui.tar.gz"
    rm -rf "tomox-sdk-ui.tar.gz"
    if [ $UBUNTU -eq 1 ]; then
        html_path=$TOMOX_UI_HTML_PATH
    elif [ $CENTOS -eq 1 ]; then
        html_path="/usr/share/nginx/tomox-sdk-ui"
    fi
    sudo mv build $html_path
    config_tomox_ui_nginx

    if [ $CENTOS -eq 1 ]; then
        setenforce Permissive
    fi
    restart_service nginx

}

update_sdk_ui(){
    setup_nginx
    cd $PWD
    url=$SDK_UI_RELEASE_URL
    wget -O "tomox-sdk-ui.tar.gz" $url
    tar xzf "tomox-sdk-ui.tar.gz"
    rm -rf "tomox-sdk-ui.tar.gz"
    if [ $UBUNTU -eq 1 ]; then
        html_path=$TOMOX_UI_HTML_PATH
    elif [ $CENTOS -eq 1 ]; then
        html_path="/usr/share/nginx/tomox-sdk-ui"
    fi
    sudo mv build $html_path
    if [ $CENTOS -eq 1 ]; then
        setenforce Permissive
    fi
    restart_service nginx

}
check_package_install(){
    if [ $UBUNTU -eq 1 ]; then
        dpkg -s $1 &> /dev/null
        if [ $? -eq 0 ]; then
            return 1
        else
            return 0
        fi
    elif [ $CENTOS -eq 1 ]; then
        if yum list installed "$1" >/dev/null 2>&1; then
            return 1
        else
            return 0
        fi
    fi  
}




install_dependency(){
    update_os
    echo "Checking packages to install..."
    declare -a arr=("curl" "wget" "netcat-openbsd")
    if [ $UBUNTU -eq 1 ]; then
        declare -a arr=("curl" "wget" "netcat-openbsd")
    elif [ $CENTOS -eq 1 ]; then
        declare -a arr=("curl" "wget" "nmap-ncat.x86_64")
    fi

    for pkg in "${arr[@]}"
    do
        check_package_install $pkg
        if [ $? -eq 1 ]; then
            echo "$pkg installed "
        else
            echo "Installing $pkg"
            install_package "$pkg"
        fi
    done

}
setup_environment(){
    install_dependency
    setup_docker
    setup_supervisor
    setup_install_path
}

progressbar() {
    number=$(( 100* $1/$2 ))
    printf "\r"
    printf "%d/%d" $1 $2
    printf "["
    for (( c=1; c<=$number; c++ )) 
    do
        printf  "▓"
    done
    n=$(($number +1))
    for (( d=$n; d<=100; d++ )) 
    do
        printf  "_"
    done

    printf "]"
}

show_install_status(){
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
    echo "********************** Waiting for checking installed status **********************"
    sleep 10
    check_open_port 8080
    if [ "$?" -eq 1 ]; then
        printf "${GREEN}Tomox SDK backend is running on port 8080${NC}\n"
    else
        echo "Tomox SDK backend is not running, try to start..."
        supervisor_restart_sdk
        sleep 5
        started=false
        for (( c=1; c<=5; c++ ))
        do  
            check_open_port 8080
            if [ "$?" -eq 1 ]; then
                    printf "${GREEN}Tomox SDK backend is running on port 8080${NC}\n"
                    started=true
                    break
            fi
            echo "Waiting for sdk backend to start..."
            sleep 2
        done
        if [ "$started" = false ] ; then
            printf "${RED}Tomox SDK backend is not running!${NC}\n"
        fi
    fi

    check_open_port 80
    if [ "$?" -eq 1 ]; then
        printf "${GREEN}Tomox UI is running on port 80${NC}\n"
    else
        printf "${RED}Tomox UI is not running!${NC}\n"
    fi

    check_open_port 8545
    if [ "$?" -eq 1 ]; then
        printf "${GREEN}Tomox Fullnode in running${NC}\n"
        echo "You have to wait for the synchronization blocks process"
        echo "Synchronization process is running in background, press any key to exit showing synchronization status"
        while [ true ] ; do
            read -t 3 -n 1
            if [ $? = 0 ] ; then
                exit ;
            else
                chain_block=`$INSTALL_PATH"/tomox/tomo" attach https://testnet.tomochain.com --exec 'eth.blockNumber'`
                myfullnode_block=`$INSTALL_PATH"/tomox/tomo" attach http://localhost:8545 --exec 'eth.blockNumber'`
                progressbar $myfullnode_block $chain_block
                sleep 5
            fi
        done
        echo "Finish!"
    else
        printf "${RED}Tomox fullnode in not running!${NC}\n"

    fi
}


echo "#######################################################################################"
echo "###                           INSTALL TOMOX SDK                                     ###"
echo "#######################################################################################"


os=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')
if [[ "$os" == *"ubuntu"* ]]; then
    UBUNTU=1
    echo "Preparing install on ubuntu os"
fi
if [[ "$os" == *"debian"* ]]; then
    UBUNTU=1
    echo "Preparing install on debian os"
fi
if [[ "$os" == *"centos"* ]]; then
    CENTOS=1
     echo "Preparing install on centos os"
fi

if [ $UBUNTU -eq 0 ] && [ $CENTOS -eq 0 ]; then
    echo "Script doesn't support this operation system"
    exit 1
fi
user_config_sdk
user_config_fullnode

setup_environment
#supervisord_stop_sdk


echo "*****************INSTALL TOMOX FULLNODE*********************"
check_open_port 8545
if [ "$?" -eq 1 ]; then
    while true; do
        read -p "Fullnode is running, do you want to update it? (Y/N)" yn
        case $yn in
            [Yy]* ) setup_fullnode; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no";;
        esac
    done
else
    setup_fullnode
fi

echo "*****************INSTALL TOMOX SDK BACKEND*********************"
for (( c=1; c<=15; c++ ))
do  
   check_open_port 8545
   if [ "$?" -eq 1 ]; then
        echo "Waiting for fullnode to start..."
        sleep 15
        break
   fi
   echo "Waiting for fullnode to start..."
   sleep 2
done

check_open_port 8080
if [ "$?" -eq 1 ]; then
    while true; do
        read -p "Tomox SDK Backend is running on port 8080, do you want to update it? (Y/N)" yn
        case $yn in
            [Yy]* ) setup_sdk; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no";;
        esac
    done
else
    setup_sdk
fi

echo "*****************INSTALL TOMOX SDK UI*********************"

check_open_port 80
if [ "$?" -eq 1 ]; then
    while true; do
        read -p "Tomox SDK UI is running on port 80, do you want to update it?" yn
        case $yn in
            [Yy]* ) update_sdk_ui; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no";;
        esac
    done
else
    setup_sdk_ui
fi

show_install_status
