export LOTUS_PATH=~/.lotus-local-net
export LOTUS_MINER_PATH=~/.lotus-miner-local-net
export LOTUS_SKIP_GENESIS_CHECK=_yes_
export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
export CGO_CFLAGS="-D__BLST_PORTABLE__"
export LOTUS_FEVM_ENABLEETHRPC=1




TAG=v1.33.0

git config --global advice.detachedHead false
git clone -b $TAG --depth 1 https://github.com/filecoin-project/lotus lotus-local-net
cd lotus-local-net

make 2k
