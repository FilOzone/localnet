export LOTUS_PATH=~/.lotus-local-net
export LOTUS_MINER_PATH=~/.lotus-miner-local-net
export LOTUS_SKIP_GENESIS_CHECK=_yes_
export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
export CGO_CFLAGS="-D__BLST_PORTABLE__"
export LOTUS_CHAININDEXER_ENABLEINDEXER=1
export LOTUS_FEVM_ENABLEETHRPC=1


cd lotus-local-net

while [ -e $LOTUS_PATH/repo.lock ]; do
    echo found existing $LOTUS_PATH/repo.lock
    sleep 5
done

API_START=$(date +%s.%N)
./lotus daemon --bootstrap=false &> daemon.log &
DAEMON_PID=$!
EXIT_TRAP="kill -2 $DAEMON_PID 2>&1" 
trap "$EXIT_TRAP" EXIT

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


f4=$(./lotus wallet new delegated)

while [ -e $LOTUS_MINER_PATH/repo.lock ]; do
    echo found existing $LOTUS_MINER_PATH/repo.lock
    sleep 5
done

./lotus-miner run --nosync &> miner.log &
EXIT_TRAP+="; kill -2 $!"
trap "$EXIT_TRAP" EXIT

MINING_START=$(date +%s.%N)
FUNDING_MSG=$(./lotus send $f4 1 | tail -n 1)

echo -n "Awaiting funding...    "
FUNDING_RECEIPT=$(./lotus state wait-msg $FUNDING_MSG)
MINING_END=$(date +%s.%N)
echo `echo $MINING_END - $MINING_START | bc`

echo -e "$FUNDING_RECEIPT"

./lotus evm stat $f4
