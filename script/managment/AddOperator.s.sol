// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ProductAdministratorRegistry, ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract AddOperator is Script, DeterminedAddress {
    address private operator = 0xCf4990bBa0B9A56500501d0c6eF139B92a050352;

    address private productMinter = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    address private minter = 0x6A9553387Da23cbfFBdf58eC949c01580448F490;

    function run() public {
        Addresses memory addresses = _getAddresses();

        _addProductMinter(ProductRegistry(addresses.productRegistry));

        _addMinter(mUSDToken(addresses.mUSDToken));

        // Iterate over each product ids, and clean the attached campaigns
        // uint256[] memory productIds = _getProductIdsArr();
        // for (uint256 i = 0; i < productIds.length; i++) {
        //     uint256 cId = productIds[i];

        //     // Get the interaction contract and the active campaigns
        //     _addOperator(ProductAdministratorRegistry(addresses.productAdministratorRegistry), cId);
        // }
    }

    function _addOperator(ProductAdministratorRegistry _adminRegistry, uint256 _cId) internal {
        vm.startBroadcast();
        _adminRegistry.grantRoles(
            _cId,
            operator,
            ProductRoles.PRODUCT_ADMINISTRATOR | ProductRoles.CAMPAIGN_MANAGER_ROLE
                | ProductRoles.INTERACTION_MANAGER_ROLE
        );
        vm.stopBroadcast();
    }

    function _addProductMinter(ProductRegistry _productRegistry) internal {
        vm.startBroadcast();
        _productRegistry.grantRoles(minter, MINTER_ROLE);
        vm.stopBroadcast();
    }

    function _addMinter(mUSDToken _musdToken) internal {
        vm.startBroadcast();
        _musdToken.grantRoles(minter, MINTER_ROLE);
        vm.stopBroadcast();
    }
}
