cd $( dirname -- $BASH_SOURCE )
source env.sh
source util.sh

cd lotus-local-net

while [ -e $LOTUS_PATH/repo.lock ]; do
    echo found existing $LOTUS_PATH/repo.lock
    sleep 5
done

API_START=$(date +%s.%N)
./lotus daemon --bootstrap=false &> daemon.log &
DAEMON_PID=$!
EXIT_TRAP="kill -2 $DAEMON_PID 2>/dev/null"
trap "$EXIT_TRAP ; wait" EXIT


echo -n "Awaiting Lotus Daemon API...    "
until [ -e $LOTUS_PATH/api ]; do
    if kill -0 $DAEMON_PID
    then
        sleep 0.01
    else
        echo
        cat daemon.log
        exit 1
    fi
done

API_END=$(date +%s.%N)
echo `echo $API_END - $API_START | bc`

export API_MULTIADDR="$( <$LOTUS_PATH/api )"
export API_URL="$( url_from_multiaddr $API_MULTIADDR )"
echo $API_URL

if [ -n "${PROXY_PORT:-}" ]; then
    export API_URL="http://localhost:$PROXY_PORT"
    echo $API_URL
fi


while [ -e $LOTUS_MINER_PATH/repo.lock ]; do
    echo found existing $LOTUS_MINER_PATH/repo.lock
    sleep 5
done

./lotus-miner run --nosync &> miner.log &
EXIT_TRAP+="; kill -2 $! 2>/dev/null"
trap "$EXIT_TRAP ; wait" EXIT


f4=t410fow4ccuyh4g7vyggn6hiwuf6a366h343m45eatsa

timed_quiet "Awaiting miner api" ./lotus-miner wait-api
timed_set "Sending funding msg" FUNDING_MSG ./lotus send $f4 100
FUNDING_MSG=$(echo -e "$FUNDING_MSG" | tail -n 1)
echo -e $FUNDING_MSG

timed_set "Awaiting funding" FUNDING_RECEIPT ./lotus state wait-msg $FUNDING_MSG

echo -e "$FUNDING_RECEIPT" | grep "Gas Used: " | cut -c 11-

STAT=$(./lotus evm stat $f4)
export SENDER_ADDRESS=$( echo -e "$STAT" | grep "Eth address:" | cut -c 14- )
echo $SENDER_ADDRESS

WALLET32=$( echo -n "wallet-$f4" | base32 -w0 | cut -c -82 )
KEYFILE=$LOTUS_PATH/keystore/$WALLET32
export SENDER_KEY=$( jq -r .PrivateKey $KEYFILE | base64 -d | xxd -p | tr -d '\n' )
