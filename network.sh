#!/usr/bin/env bash

starttime=$(date +%s)

: ${PEER1:="aa"}
: ${PEER1_ID=0}
: ${PEER1_PORT:=26657}
: ${PEER2:="bb"}
: ${PEER2_ID=0}
: ${PEER2_PORT:=26667}
: ${PEER3:="cc"}
: ${PEER3_ID=0}
: ${PEER3_PORT:=26677}
: ${PEER4:="dd"}
: ${PEER1_ID=0}
: ${PEER4_PORT:=26687}
: ${EMPTY_BLOCK=false}
: ${ABCI_NAME="counter"}


# "CMD=tendermint node"
: ${INIT_CMD:="tendermint init"}
: ${GET_ID_CMD:="tendermint show_node_id"}

PEERS=""

DOCKER=./docker

GID=$(id -g)

function initPeers(){
	echo "-----------------------init nodes----------------------------"
	initPeer $PEER1 $PEER1_PORT
	initPeer $PEER2 $PEER2_PORT
	initPeer $PEER3 $PEER3_PORT
	initPeer $PEER4 $PEER4_PORT
}

function initPeer(){
	TM=$1
	PORT=$2
	f="${DOCKER}/docker-compose-${TM}.yaml"
	mkdir -p artifacts/$TM
	cp ${ABCI_NAME} artifacts/$TM
	sed -e "s/TM/$TM/g" -e "s/PORT/$PORT/g" -e "s/ABCI_NAME/${ABCI_NAME}/g" ${DOCKER}/docker-compose-template.yaml > ${f}
	docker-compose --file ${f} run --rm "tm_${TM}" ${INIT_CMD}
	id=$(docker-compose --file ${f} run --rm "tm_${TM}" ${GET_ID_CMD})
	echo -e "Peer \033[34m$TM\033[0m id is \033[32m$id\033[0m"
	PEERS=${id:0:40}@tm_$TM:26656,$PEERS
	docker-compose --file ${f} run --rm "tm_${TM}" bash -c "chown -R ${UID}:${GID} ."
}

function modifyToml(){
	echo "-----------------------modify configurations----------------------------"
	len=${#PEERS}
	PEERS=${PEERS:0:len-1}
	echo -e "\033[32mpeers addresses are:\033[0m"
	echo "$PEERS"
	for TM in $PEER1 $PEER2 $PEER3 $PEER4; do
		sed -e "s/^moniker =.*/moniker = \"tm_${TM}\"/" \
		-e "s/^persistent_peers =.*/persistent_peers = \"${PEERS}\"/g" \
		-e "s/^addr_book_strict.*/addr_book_strict=false/g" \
		-e "s/^create_empty_blocks =.*/create_empty_blocks =${EMPTY_BLOCK}/g" ${DOCKER}/config.toml > artifacts/$TM/.tendermint/config/config.toml
	done
}

function modifyGenesis(){
	echo "-----------------------modify genesis files----------------------------"
	base="artifacts/$PEER1/.tendermint/config/genesis.json"
	start=`sed -n "/validators/=" $base`
	validators=''
	for TM in $PEER1 $PEER2 $PEER3 $PEER4; do
		genesis="artifacts/$TM/.tendermint/config/genesis.json"
		startline=`sed -n "/validators/=" $genesis`
		endline=`sed -n "/app_hash/=" $genesis`
		let startline=startline+1 endline=endline-2
		validator=`sed -n "${startline},${endline}p" $genesis`
		validators=$validators$validator,
		sed -i "${startline},${endline}d" $genesis
	done
	len=${#validators}
	validators=`echo ${validators:0:len-1} | sed 's/\"/\\"/g'`
	echo -e "\033[32mvalidators are:\033[0m"
	echo "$validators"
	sed -i "${start}a ${validators}" $base
	for TM in $PEER2 $PEER3 $PEER4; do
		genesis="artifacts/$TM/.tendermint/config/genesis.json"
		cp $base $genesis
	done
}

function startTM(){
	for TM in $PEER1 $PEER2 $PEER3 $PEER4; do
		f="${DOCKER}/docker-compose-${TM}.yaml"
		echo -e "Running ABCI \033[32m${ABCI_NAME}\033[0m And Tendermint node on Peer \033[34m$TM\033[0m"
		docker-compose -f ${f} up -d 2>&1
		if [ $? -ne 0 ]; then
		    echo "ERROR !!!! Unable to start $TM"
		    exit 1
		fi

	done
}

function downTM(){
	for TM in $PEER1 $PEER2 $PEER3 $PEER4; do
		if [  -d "artifacts/$TM" ]; then
			f="${DOCKER}/docker-compose-${TM}.yaml"
			docker-compose -f ${f} down
		  	rm -rf artifacts/$TM
		  	rm ${f}
		fi
	done	
	rm -rf artifacts
}

function logs(){

  f="${DOCKE}/docker-compose-$1.yaml"

  docker-compose -f ${f} logs -f
}

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  network.sh -m up|down"
  echo "  network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'up', 'down'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo
  echo "For example: "
  echo "	network.sh -m up"
  echo "	network.sh -m down"
}

# Parse commandline args
while getopts "h?m:o:a:w:c:0:1:2:3:k:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
  esac
done

if [ "${MODE}" == "up" ]; then
	downTM
  	initPeers
	modifyToml
	modifyGenesis
	startTM
elif [ "${MODE}" == "down" ]; then
  	downTM
else
	printHelp
	exit 1
fi

endtime=$(date +%s)
echo "Finished in $(($endtime - $starttime)) seconds"
