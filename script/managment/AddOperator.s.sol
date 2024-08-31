// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, ProductIds} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE, PRODUCT_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract AddOperator is Script, DeterminedAddress {
    address private operator = 0xB875AAD94cd568CE0359A73b62Af1614E4ff0901;

    address private productMinter = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    function run() public {
        Addresses memory addresses = _getAddresses();

        // _addProductMinter(ProductRegistry(addresses.productRegistry));

        // _addMinter(mUSDToken(addresses.mUSDToken));

        // Iterate over each product ids, and clean the attached campaigns
        uint256[] memory productIds = _getProductIdsArr();
        for (uint256 i = 0; i < productIds.length; i++) {
            uint256 cId = productIds[i];

            // Get the interaction contract and the active campaigns
            _addOperator(ProductAdministratorRegistry(addresses.productAdministratorlRegistry), cId);
        }
    }

    function _addOperator(ProductAdministratorRegistry _adminRegistry, uint256 _cId) internal {
        vm.startBroadcast();
        _adminRegistry.grantRoles(_cId, operator, CAMPAIGN_MANAGER_ROLE | PRODUCT_MANAGER_ROLE);
        vm.stopBroadcast();
    }

    function _addProductMinter(ProductRegistry _productRegistry) internal {
        vm.startBroadcast();
        _productRegistry.grantRoles(productMinter, MINTER_ROLE);
        vm.stopBroadcast();
    }

    function _addMinter(mUSDToken _musdToken) internal {
        vm.startBroadcast();
        _musdToken.grantRoles(airdropper, MINTER_ROLE);
        vm.stopBroadcast();
    }
}
