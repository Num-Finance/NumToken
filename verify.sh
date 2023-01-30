#!/bin/bash

chainid=$1
impl=$2
forwarder=$FORWARDER_ADDRESS
beacon=$4
proxy=$5

forge verify-contract \
    --chain-id $chainid \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args \
    $(cast abi-encode "constructor(address)" \
        "$forwarder" \
    )\
    $impl \
    src/NumToken.sol:NumToken \
    $ETHERSCAN_API_KEY

forge verify-contract \
    --chain-id $chainid \
    --num-of-optimizations 200 \
    --constructor-args \
    $(cast abi-encode \
        "constructor(address)" \
        "$impl" \
    ) \
    $beacon \
    lib/openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol:UpgradeableBeacon \
    $ETHERSCAN_API_KEY

forge verify-contract \
    --chain-id $chainid \
    --num-of-optimizations 200 \
    --constructor-args \
    $(cast abi-encode \
        "constructor(address,string)" \
        "$beacon" \
        "" \
    ) \
    $proxy \
    lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy \
    $ETHERSCAN_API_KEY