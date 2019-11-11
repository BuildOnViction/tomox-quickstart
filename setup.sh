#!/bin/bash


#Default service port
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


SDK_BACKEND_RELEASE_URL="https://github.com/tomochain/tomox-sdk/releases/download/v1.0.1-beta/tomox-sdk.v1.0.1-beta.linux.amd64"
SDK_UI_RELEASE_URL="https://github.com/tomochain/tomox-sdk-ui/releases/download/v1.0.1-beta/tomox-sdk-ui.v1.0.1-beta.testnet.tar.gz"
FULLNODE_RELEASE_URL="https://github.com/tomochain/tomochain/releases/download/v2.0.0-beta/tomo-linux-amd64"
FULLNODE_CHAIN_DATA=$INSTALL_PATH"/tomox/data"
TOMOX_GENESIS="https://raw.githubusercontent.com/tomochain/tomochain/master/genesis/testnet.json"
TOMOX_CHAIN_DATA_URL="https://chaindata-testnet.s3-ap-southeast-1.amazonaws.com/chaindata-testnet.tar"

PWD=$(pwd)

DOWNLOAD_CHAIN_DATA_ENABLED=1

TOMOX_UI_HTML_PATH="/var/www/tomox-sdk-ui"
# require nc installed
check_open_port(){
    local=0.0.0.0
    </dev/tcp/$local/$1
    if [ "$?" -ne 0 ]; then
        return 0
    else
        return 1
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
check_installed_service(){
    FILE=/etc/init.d/$1
    if test -f "$FILE"; then
        return 1
    else
        return 0
    fi
}

start_service(){
    sudo /etc/init.d/$1 start
}
install_docker(){
    sudo apt-get update
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
    #sudo usermod -aG docker $USER
    #su - $USER
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
    sudo docker run -d -p $1:27017 --name mongodb \
    --hostname mongodb mongo:4.2 --replSet rs0

    sleep 5
    sudo docker exec -it mongodb mongo --eval "rs.initiate()"
}

reset_rabbitmq(){
    sudo docker kill rabbitmq
    sudo docker rm rabbitmq
    sudo docker run -d -p $1:5672 --name rabbitmq rabbitmq:3.8
}

setup_rabbitmq(){
    reset_rabbitmq $RABBITMQ_PORT
}
setup_mongodb(){
    reset_mongodb $MONGODB_PORT
}
stop_fullnode(){
    sudo supervisorctl stop tomox-node
}

supervisord_restart_fullnode(){
    sudo supervisorctl restart tomox-node
}
supervisord_stop_fullnode(){
    sudo supervisorctl stop tomox-node
}
supervisord_stop_sdk(){
    sudo supervisorctl stop tomox-sdk
}

download_chain_data(){
    echo "Download chain data, it takes time!"
    wget -O $INSTALL_PATH"/tomox/chaindata-testnet.tar" $TOMOX_CHAIN_DATA_URL
    tar xvf $INSTALL_PATH"/tomox/chaindata-testnet.tar" -C $INSTALL_PATH"/tomox/"

}
start_fullnode(){
    default_chaindata=$INSTALL_PATH"/tomox/data"
    if [ "$FULLNODE_CHAIN_DATA" != "$default_chaindata" ]; then
        echo "Start fullnode with specific user chain data"
        supervisord_restart_fullnode
    else
        if ! test -d $INSTALL_PATH"/tomox/data"; then
            write_tomoxnode_supervisor
            if [ "$DOWNLOAD_CHAIN_DATA_ENABLED" -eq 1 ]; then
                download_chain_data
            fi
            wget -O $INSTALL_PATH"/tomox/tomo" $FULLNODE_RELEASE_URL
            chmod +x $INSTALL_PATH"/tomox/tomo"
            curl -L $TOMOX_GENESIS -o $INSTALL_PATH"/tomox/genesis.json"
            #stop_fullnode
            echo "">$INSTALL_PATH"/tomox/passparser"
            $INSTALL_PATH"/tomox/tomo" account new --datadir $FULLNODE_CHAIN_DATA --password $INSTALL_PATH"/tomox/passparser"
            echo $FULLNODE_CHAIN_DATA
            $INSTALL_PATH"/tomox/tomo" init $INSTALL_PATH"/tomox/genesis.json" --datadir $FULLNODE_CHAIN_DATA
            if [ "$DOWNLOAD_CHAIN_DATA_ENABLED" -eq 1 ]; then
                cp -r $INSTALL_PATH"/tomox/chaindata" $INSTALL_PATH"/tomox/data/tomo"
            fi 

            supervisord_restart_fullnode
        else
            supervisord_restart_fullnode
        fi
    fi
    
    #write_tomoxnode_supervisor
    #sudo supervisorctl reread
    #sudo supervisorctl update
    #sudo supervisorctl restart tomox-node
    
    

}

setup_fullnode(){
    setup_mongodb
    user_config_fullnode
    start_fullnode

}

user_config_sdk(){
    echo "Input exchage address (it is the address you registered in relayer):"
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
    echo "Enter fullnode chain data(if you dont have, press enter key):"
    read datachain
    if ! test -z "$datachain" ;then
        FULLNODE_CHAIN_DATA=$datachain
    fi
    
}

start_sdk(){
    url=$SDK_BACKEND_RELEASE_URL
    rm -f $INSTALL_PATH"/tomox-sdk"
    wget -O $INSTALL_PATH"/tomox-sdk" $url
    chmod +x $INSTALL_PATH"/tomox-sdk"
    write_sdk_supervisor $INSTALL_PATH
    sdk_write_config
    sudo supervisorctl reread
    sudo supervisorctl update

    
}
# param 1: path to sdk binary
write_sdk_supervisor(){
    supervisor_log="/etc/supervisor/conf.d/tomox-sdk.conf"
    installpath_patern="tomoxinstallpath"
    installpath=$INSTALL_PATH
    
    cp tomoxsdk.supervisord tomoxsdk.supervisord.bk 
    sed -i "s|${installpath_patern}|${installpath}|g" tomoxsdk.supervisord.bk
    sudo mv tomoxsdk.supervisord.bk $supervisor_log
    sudo supervisorctl reread
}

write_tomoxnode_supervisor(){
    supervisor_conf="/etc/supervisor/conf.d/tomox-node.conf"
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

    sudo mv tomoxnode.supervisord.bk $supervisor_conf
    sudo supervisorctl reread
    
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
    user_config_sdk
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
    check_running_service supervisor
    if [ "$?" -eq 0 ]; then
        echo "supervisor is not running"
        check_installed_service supervisor
        if [ "$?" -eq 1 ]; then
            echo "service supervisor is installed but not running, starts it"
            start_service supervisor
        else
            echo "service supervisor is not installed, installs it"
            sudo apt-get -y install supervisor
        fi

    fi
    
}

setup_nginx(){
    check_running_service nginx
    if [ "$?" -eq 0 ]; then
        echo "nginx is not running"
        check_installed_service nginx
        if [ "$?" -eq 1 ]; then
            echo "service nginx is installed but not running, starts it"
            start_service supervisor
        else
            echo "service nginx is not installed, installs it"
            sudo apt-get -y install nginx
        fi

    fi
    
}


config_tomox_ui_nginx(){
    path_patern="htmlroot"
    path=$TOMOX_UI_HTML_PATH
    sed "s|${path_patern}|${path}|g" tomox-nginx.conf>tomox-sdk.conf
    sudo mv tomox-sdk.conf /etc/nginx/sites-enabled/tomox-sdk.conf
    sudo rm -f /etc/nginx/sites-enabled/default
} 


setup_sdk_ui(){
    cd $PWD
    url=$SDK_UI_RELEASE_URL
    wget -O "tomox-sdk-ui.tar.gz" $url
    tar xvzf "tomox-sdk-ui.tar.gz"
    rm -rf "tomox-sdk-ui.tar.gz"
    sudo mv build $TOMOX_UI_HTML_PATH
    config_tomox_ui_nginx
    sudo /etc/init.d/nginx restart

}
install_dependency(){
    sudo apt-get update
    sudo apt-get install -y curl wget  netcat-openbsd
}
setup_environment(){
    install_dependency
    setup_docker
    setup_supervisor
    setup_nginx
    setup_install_path
}

setup_environment
supervisord_stop_sdk

echo "*****************INSTALL TOMOX FULLNODE*********************"
check_open_port 8545
if [ "$?" -eq 1 ]; then
    while true; do
        read -p "Fullnode may be running, if continue you must stop it first. Continue installing? (Y/N)" yn
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

for (( c=1; c<=5; c++ ))
do  
   check_open_port 8545
   if [ "$?" -eq 1 ]; then
        sleep 5
        break
   fi
   sleep 2
done

check_open_port 8080
if [ "$?" -eq 1 ]; then
    while true; do
        read -p "A program isrunning on port 8080, if continue you must stop it first. Continue installing? (Y/N)" yn
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
setup_sdk_ui
