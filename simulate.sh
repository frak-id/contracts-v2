#!/bin/sh

source .env

export FORCE_DEPLOY="true"

#echo "Deploying contracts to Mumbai testnet"
#forge script script/Deploy.s.sol --rpc-url $MUMBAI_RPC_URL --account testnetDeployer --sender 0x7caF754C934710D7C73bc453654552BEcA38223F --broadcast --verify

echo "Testing contracts deployment"
forge script script/Deploy.s.sol --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C 
