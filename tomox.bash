pkill -f tomobinarypath
tomobinarypath \
    --bootnodes "enode://ce1191bf9a634e7939676d136816ad84941b079c03d6a96e64cca35852363012169055c6879c644e821dc236a01d0499a1b7ff39e9518dbc00da87c7f1898604@13.251.101.216:30301,enode://cf2d05f71f143d85dce45dae6f74fae0ba56fc5ea1d1c548a095e29a5becb3a1fb93eb33e7b1dec43946dcfe608fd1495a02740af710bc615b90ad60fcc04d14@13.250.94.232:30301" \
    --networkid 89 \
    --rpc \
    --rpccorsdomain "*" --rpcaddr 0.0.0.0 --rpcport 8545 --rpcvhosts "*" \
    --ws --wsaddr 0.0.0.0 --wsport 8546 --wsorigins "*" \
    --rpcapi "personal,db,eth,net,web3,txpool,miner,tomox" \
    --announce-txs --tomo-testnet --tomox.dbengine "mongodb" \
    --ethstats "tomoxnodetest:anna-coal-flee-carrie-zip-hhhh-tarry-laue-felon-rhine@stats.testnet.tomochain.com" \
    --datadir tomoxdatadir