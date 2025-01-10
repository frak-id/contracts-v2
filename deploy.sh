#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 {deploy|update|role}"
  exit 1
fi

# Set the script path based on the argument
case "$1" in
  deploy)
    SCRIPT_PATH="Deploy.s.sol"
    ;;
  update)
    SCRIPT_PATH="Update.s.sol"
    ;;
  role)
    SCRIPT_PATH="GrantRoles.s.sol"
    ;;
  *)
    echo "Invalid argument: $1"
    echo "Usage: $0 {deploy|update|role}"
    exit 1
    ;;
esac

source .env
export FORCE_DEPLOY="false"

# echo "Deploying contracts to arbitrum testnet"
forge script script/$SCRIPT_PATH --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account mainnettDeployer --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C --broadcast --verify
# forge script script/$SCRIPT_PATH --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account mainnettDeployer --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C

# echo "Deploying contracts to arbitrum"
forge script script/$SCRIPT_PATH --rpc-url $ARBITRUM_RPC_URL --account mainnettDeployer --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C --broadcast --verify
# forge script script/$SCRIPT_PATH --rpc-url $ARBITRUM_RPC_URL --account mainnettDeployer --sender 0xaE4e57b886541829BA70eFC84340653c41e2908C
