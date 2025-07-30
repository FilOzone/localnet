export LOTUS_PATH=~/.lotus-local-net
export LOTUS_MINER_PATH=~/.lotus-miner-local-net
export LOTUS_SKIP_GENESIS_CHECK=_yes_
export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
export CGO_CFLAGS="-D__BLST_PORTABLE__"
export LOTUS_CHAININDEXER_ENABLEINDEXER=1
export LOTUS_FEVM_ENABLEETHRPC=1


cd lotus-local-net


./lotus daemon --lotus-make-genesis=devgen.car --genesis-template=localnet.json --bootstrap=false &
EXIT_TRAP="kill -2 $!" 
echo $EXIT_TRAP
trap "$EXIT_TRAP" EXIT
until [ -e $LOTUS_PATH/api ]; do
    sleep 0.01
done


f4=$(./lotus wallet new delegated)

./lotus-miner run --nosync &
EXIT_TRAP+="; kill -2 $!"
echo $EXIT_TRAP
trap "$EXIT_TRAP" EXIT

./lotus send $f4 1

./lotus evm stat $f4
