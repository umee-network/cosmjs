#!/bin/bash

# This must get from 2-3 different repos, fix the versions here:

COSMWASM_VERSION="v0.16.0-rc5"
PLUS_VERSION="v0.8.0-rc1"

curl -L -O "https://github.com/CosmWasm/cosmwasm/releases/download/${COSMWASM_VERSION}/hackatom.wasm"
curl -L -O "https://github.com/CosmWasm/cosmwasm/releases/download/${COSMWASM_VERSION}/ibc_reflect.wasm"

curl -L -O "https://github.com/CosmWasm/cosmwasm-plus/releases/download/${PLUS_VERSION}/cw1_subkeys.wasm"
curl -L -O "https://github.com/CosmWasm/cosmwasm-plus/releases/download/${PLUS_VERSION}/cw3_fixed_multisig.wasm"

sha256sum *.wasm >checksums.sha256