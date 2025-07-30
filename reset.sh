export LOTUS_PATH=~/.lotus-local-net
export LOTUS_MINER_PATH=~/.lotus-miner-local-net
export LOTUS_SKIP_GENESIS_CHECK=_yes_
export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
export CGO_CFLAGS="-D__BLST_PORTABLE__"
export LOTUS_CHAININDEXER_ENABLEINDEXER=1
export LOTUS_FEVM_ENABLEETHRPC=1




rm -rf $LOTUS_PATH $LOTUS_MINER_PATH

cd lotus-local-net

echo Awaiting Lotus Daemon API...
./lotus daemon --lotus-make-genesis=devgen.car --genesis-template=localnet.json --bootstrap=false &> daemon.log &
DAEMON_PID=$!
trap "kill -2 $DAEMON_PID 2>/dev/null" EXIT
until [ -e $LOTUS_PATH/api ]; do
    if kill -0 $DAEMON_PID 2>&1
    then
        sleep 0.01
    else
        # died before starting API
        cat daemon.log
        exit 1
    fi
done

echo Importing genesis wallet
./lotus wallet import --as-default ~/.genesis-sectors/pre-seal-t01000.key 
echo Init genesis miner
./lotus-miner init --genesis-miner --actor=t01000 --sector-size=2KiB --pre-sealed-sectors=~/.genesis-sectors --pre-sealed-metadata=~/.genesis-sectors/pre-seal-t01000.json --nosync 
