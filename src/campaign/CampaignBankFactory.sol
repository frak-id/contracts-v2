// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {CampaignBank} from "./CampaignBank.sol";

/// @author @KONFeature
/// @title CampaignBankFactory
/// @notice Contract deploying a campaign bank for a product
/// @custom:security-contact contact@frak.id
contract CampaignBankFactory {
    event CampaignBankCreated(address campaignBank);

    /// @dev The product administrator registry
    ProductAdministratorRegistry private immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /// @dev Construct a new campaign bank
    constructor(ProductAdministratorRegistry _adminRegistry) {
        PRODUCT_ADMINISTRATOR_REGISTRY = _adminRegistry;
    }

    /// @dev Deploy a new campaign bank for `_productId` and `_token`
    function deployCampaignBank(uint256 _productId, address _token) public returns (CampaignBank campaignBank) {
        // Compute the salt
        bytes32 salt = keccak256(abi.encodePacked(_productId, _token));

        campaignBank = new CampaignBank{salt: salt}(PRODUCT_ADMINISTRATOR_REGISTRY, _productId, _token);
        emit CampaignBankCreated(address(campaignBank));
    }
}
