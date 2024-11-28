// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {DELEGATION_EXECUTOR_ROLE, InteractionDelegator} from "src/kernel/interaction/InteractionDelegator.sol";
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";
import {ProductAdministratorRegistry, ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract GrantRoles is Script, DeterminedAddress {
    function run() public {
        Addresses memory addresses = _getAddresses();
        KernelAddresses memory kAddresses = _getKernelAddresses();

        // All the address that will be allowed to mint products
        address[] memory productMinters = _getMintersForEnv();

        // All the address that will be allowed to delegate interactions
        address[] memory interactionDelegators = _getDelegatorsForEnv();

        // Grant every roles
        _addProductMinter(addresses, productMinters);
        _addKernelInteractionExecutor(kAddresses, interactionDelegators);
    }

    /// @dev Get the addresses of the minters
    function _getMintersForEnv() private view returns (address[] memory minters) {
        // Get the current chain
        if (block.chainid == 42_161) {
            // prod
            minters = new address[](1);
            minters[0] = 0x3586ef9c352B07DEAb79E52ad70b96DB6264F913; // prod
        } else {
            // dev
            minters = new address[](1);
            minters[0] = 0x7b18c41665A4Eff371DdE0db605764D3B01b73f9; // dev
        }
    }

    /// @dev Get the addresses of the delegators
    function _getDelegatorsForEnv() private view returns (address[] memory interactionDelegators) {
        // Get the current chain
        if (block.chainid == 42_161) {
            // prod
            interactionDelegators = new address[](1);
            interactionDelegators[0] = 0xc9a29de8a25333aaB013F1eF8b595eb79aE74C3C; // prod
        } else {
            // dev
            interactionDelegators = new address[](1);
            interactionDelegators[0] = 0x486b3b8E942CDa32287C1C1Ed3597d630271DbCb; // dev
        }
    }

    /// @dev Grant the product minter role
    function _addProductMinter(Addresses memory addresses, address[] memory minters) internal {
        ProductRegistry _productRegistry = ProductRegistry(addresses.productRegistry);
        mUSDToken _musdToken = mUSDToken(addresses.mUSDToken);
        ProductInteractionManager _productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();
        for (uint256 i = 0; i < minters.length; i++) {
            address minter = minters[i];

            if (!_productRegistry.hasAllRoles(minter, MINTER_ROLE)) {
                console.log("Granting role on ProductRegistry to: %s", minter);
                _productRegistry.grantRoles(minter, MINTER_ROLE);
            }

            if (!_musdToken.hasAllRoles(minter, MINTER_ROLE)) {
                console.log("Granting role on Mocked USD to: %s", minter);
                _musdToken.grantRoles(minter, MINTER_ROLE);
            }

            if (!_productInteractionManager.hasAllRoles(minter, MINTER_ROLE)) {
                console.log("Granting role on ProductInteractionManager to: %s", minter);
                _productInteractionManager.grantRoles(minter, MINTER_ROLE);
            }
        }
        vm.stopBroadcast();
    }

    /// @dev Grant the delegation executor role
    function _addKernelInteractionExecutor(KernelAddresses memory addresses, address[] memory executors) internal {
        InteractionDelegator _interactionDelegator = InteractionDelegator(payable(addresses.interactionDelegator));

        vm.startBroadcast();
        for (uint256 i = 0; i < executors.length; i++) {
            address executor = executors[i];

            if (!_interactionDelegator.hasAllRoles(executor, DELEGATION_EXECUTOR_ROLE)) {
                console.log("Granting interaction executor role to: %s", executor);
                _interactionDelegator.grantRoles(executor, DELEGATION_EXECUTOR_ROLE);
            }
        }
        vm.stopBroadcast();
    }
}
