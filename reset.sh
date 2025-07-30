export LOTUS_PATH=~/.lotus-local-net
export LOTUS_MINER_PATH=~/.lotus-miner-local-net
export LOTUS_SKIP_GENESIS_CHECK=_yes_
export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
export CGO_CFLAGS="-D__BLST_PORTABLE__"
export LOTUS_FEVM_ENABLEETHRPC=1




rm -rf ~/.genesis-sectors
rm -rf $LOTUS_MINER_PATH

cd lotus-local-net
./lotus fetch-params 2048

./lotus-seed pre-seal --sector-size 2KiB --num-sectors 2
./lotus-seed genesis new localnet.json
./lotus-seed genesis add-miner localnet.json ~/.genesis-sectors/pre-seal-t01000.json

echo starting daemon
./lotus daemon --lotus-make-genesis=devgen.car --genesis-template=localnet.json --bootstrap=false &> daemon.log &
trap "kill -2 $!" EXIT
until [ -e $LOTUS_PATH/api ]; do
    sleep 0.01
done

echo importing wallet
./lotus wallet import --as-default ~/.genesis-sectors/pre-seal-t01000.key 
echo init miner
./lotus-miner init --genesis-miner --actor=t01000 --sector-size=2KiB --pre-sealed-sectors=~/.genesis-sectors --pre-sealed-metadata=~/.genesis-sectors/pre-seal-t01000.json --nosync 
