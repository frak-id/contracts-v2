#!/bin/sh

source .env

export FORCE_DEPLOY="false"

#echo "Deploying contracts to Mumbai testnet"
#forge script script/Deploy.s.sol --rpc-url $MUMBAI_RPC_URL --account testnetDeployer --sender 0x7caF754C934710D7C73bc453654552BEcA38223F --broadcast --verify

echo "Deploying contracts to arbitrum testnet"
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account testnetDeployer --sender 0x7caF754C934710D7C73bc453654552BEcA38223F --broadcast --verify

echo "Deploying kernel contracts to arbitrum testnet"
forge script script/kernel/DeployModuleV2.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account testnetDeployer --sender 0x7caF754C934710D7C73bc453654552BEcA38223F --broadcast --verify