if [ -z "$1" ]
then
  echo "[Usage] setEnv.sh [RPC PORT]"
else	
  export ETH_GAS=${ETH_GAS:-"4700000"}
  export SETH_STATUS=yes
  export ETH_RPC_ACCOUNTS=yes # Don't use ethsign
  export ETH_RPC_URL=http://127.0.0.1:$1
  export ETH_FROM=$(seth rpc eth_coinbase)
  echo "ETH Gas limit : " $ETH_GAS
  echo "SETH set Coinbase as : " $ETH_FROM
fi
