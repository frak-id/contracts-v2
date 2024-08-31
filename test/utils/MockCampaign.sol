// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ProductTypes} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ICampaignFactory} from "src/interfaces/ICampaignFactory.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";

contract MockCampaign is InteractionCampaign {
    uint256 private interactionHandled;
    bool private fail;

    constructor(ProductAdministratorRegistry adminRegistry, address _owner, ProductInteractionDiamond _interaction)
        InteractionCampaign(adminRegistry, _interaction, "mock")
    {}

    /// @dev Get the campaign metadata
    function getMetadata() public pure override returns (string memory _type, string memory version, bytes32 name) {
        _type = "mock";
        version = "0.0.1";
        name = "mock";
    }

    /// @dev Check if the campaign is active or not
    function isActive() public pure override returns (bool) {
        return true;
    }

    /// @dev Check if the given campaign support the `_productType`
    function supportProductType(ProductTypes) public pure override returns (bool) {
        return true;
    }

    /// @dev Handle the given interaction
    function innerHandleInteraction(bytes calldata) internal override {
        if (fail) {
            revert("MockCampaign: fail");
        }
        interactionHandled++;
    }

    function setFail(bool _fail) public {
        fail = _fail;
    }

    function getInteractionHandled() public view returns (uint256) {
        return interactionHandled;
    }
}
