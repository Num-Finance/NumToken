#!/bin/bash

name=$1
symbol=$2

name=$name symbol=$symbol forge script \
    script/ExtraNumToken.sol:NumTokenDeploy \
    --rpc-url $RPC_URL \
    -vvvv \
    --verifier etherscan \
    --broadcast

grep "$name deployed to" log