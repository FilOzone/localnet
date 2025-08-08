# Localnet

The purpose of this repo is to provide a standardized reusable Filecoin test environment.

## Configuration

Basic configuration is defined in `env.sh`.
The default settings enable the FEVM.
Set `$LOTUS_PATH` to specify the lotus daemon repo directory.
Set `LOTUS_MINER_PATH` to specify the lotus-miner repo directory.

## Setup

```
bash setup.sh
```

## Usage

In a script that wants a fresh running local lotus node, do
```
source local_lotus.sh
```
When your script exits, the `lotus daemon` and the `lotus-miner` will both be interrupted.

Optionally, to reset your local blockchain to genesis, run `reset.sh` before `local_lotus.sh`:
```
bash reset.sh
```

### Reverse Proxy Monitoring
To setup a reverse proxy to watch the network traffic to your local lotus node, run this in another shell:
```
mitmdump --mode reverse:http://localhost:1234 --flow-detail 4
```
Then set this environment variable in the shell that will run the lotus node:
```
export PROXY_PORT=8080
```

### Test Key
A test key is used because several EVM operations such as keccak and ecrecover will cost different amounts in the FVM according to the content of the hash or the signature.
So, to get deterministic gas measurements, the same key should be used each time for such testing.
