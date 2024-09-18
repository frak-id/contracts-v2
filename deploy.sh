#!/bin/sh

source .env

export FORCE_DEPLOY="false"

# echo "Deploying contracts to arbitrum testnet"
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account testnetDeployer --sender 0x7caF754C934710D7C73bc453654552BEcA38223F --broadcast --verify

# echo "Deploying contracts to arbitrum"
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --account mainnettDeployer --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C --broadcast --verify
