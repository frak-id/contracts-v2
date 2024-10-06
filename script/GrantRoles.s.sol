// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
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
        address[] memory productMinters = new address[](1);
        productMinters[0] = 0x6A9553387Da23cbfFBdf58eC949c01580448F490; // local
        productMinters[1] = 0xee310229c31e000292d14Add9d4c317095808661; // dev

        // All the address that will be allowed to delegate interactions
        address[] memory interactionDelegators = new address[](2);
        interactionDelegators[0] = 0x0612994c389F253f22AF91B63DD622049b7D42C5; // local
        interactionDelegators[1] = 0xef33C59086808F63733C3b92d273930772466b08; // dev

        // Grant every roles
        _addProductMinter(addresses, productMinters);
        _addKernelInteractionExecutor(kAddresses, interactionDelegators);
    }

    /// @dev Grant the product minter role
    function _addProductMinter(Addresses memory addresses, address[] memory minters) internal {
        ProductRegistry _productRegistry = ProductRegistry(addresses.productRegistry);
        mUSDToken _musdToken = mUSDToken(addresses.mUSDToken);

        vm.startBroadcast();
        for (uint256 i = 0; i < minters.length; i++) {
            _productRegistry.grantRoles(minters[i], MINTER_ROLE);
            _musdToken.grantRoles(minters[i], MINTER_ROLE);
        }
        vm.stopBroadcast();
    }

    /// @dev Grant the delegation executor role
    function _addKernelInteractionExecutor(KernelAddresses memory addresses, address[] memory executors) internal {
        InteractionDelegator _interactionDelegator = InteractionDelegator(payable(addresses.interactionDelegator));

        vm.startBroadcast();
        for (uint256 i = 0; i < executors.length; i++) {
            _interactionDelegator.grantRoles(executors[i], DELEGATION_EXECUTOR_ROLE);
        }
        vm.stopBroadcast();
    }
}
