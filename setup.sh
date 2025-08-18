cd $( dirname -- $BASH_SOURCE )

source env.sh


TAG=v1.33.1

git config --global advice.detachedHead false
git clone -b $TAG --depth 1 https://github.com/filecoin-project/lotus lotus-local-net
cd lotus-local-net

make 2k

#rm -rf ~/.genesis-sectors

./lotus fetch-params 2048

./lotus-seed pre-seal --sector-size 2KiB --num-sectors 2
./lotus-seed genesis new localnet.json
./lotus-seed genesis add-miner localnet.json ~/.genesis-sectors/pre-seal-t01000.json
