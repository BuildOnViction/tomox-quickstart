#!/bin/bash

APP_VERSION=1.1.0-beta

cd /tmp && \
    wget -O "tomox-quickstart-${APP_VERSION}.tar.gz" https://github.com/tomochain/tomox-quickstart/archive/v${APP_VERSION}.tar.gz && \
    tar xzf "tomox-quickstart-${APP_VERSION}.tar.gz" && \
    rm -rf "tomox-quickstart-${APP_VERSION}.tar.gz" && \
    cd "tomox-quickstart-${APP_VERSION}" && bash setup.sh testnet
