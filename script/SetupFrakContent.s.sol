// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CONTENT_TYPE_DAPP, ContentTypes, DENOMINATOR_DAPP} from "src/constants/ContentTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {DappInteractionFacet} from "src/interaction/facets/DappInteractionFacet.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {IContentConsumptionContract} from "src/stylus/StylusFlatten.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract SetupTestContents is Script, DeterminedAddress {
    address internal interactionValidator = 0x8747C17970464fFF597bd5a580A72fCDA224B0A1;
    address internal stylusContract = 0x5F83f5780B301B4eFb8dDa2715b280ba297bAEA0;

    function run() public {
        Addresses memory addresses = _getAddresses();
        ContentRegistry contentRegistry = ContentRegistry(addresses.contentRegistry);
        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        // Mint the contents
        //uint256 frakContentId = _mintFrakContent(contentRegistry);
        uint256 frakContentId = _getContentIds().cFrakDapp;

        // Setup the interactions
        _setupInteractions(contentInteractionManager, frakContentId);

        // allow the callable verificaion on the stylus contract
        _allowStylusContract(contentInteractionManager, frakContentId);
    }

    /// @dev Mint the test contents
    function _mintFrakContent(ContentRegistry contentRegistry) internal returns (uint256 contentId) {
        vm.startBroadcast();

        // Mint the tests contents
        uint256 cFrak = _mintContent(contentRegistry, CONTENT_TYPE_DAPP, "Frak", "frak.id");

        vm.stopBroadcast();

        console.log("Content id:");
        console.log(" - Frak: %s", cFrak);

        return cFrak;
    }

    /// @dev Mint a content with the given name and domain
    function _mintContent(
        ContentRegistry _contentRegistry,
        ContentTypes _contentTypes,
        string memory _name,
        string memory _domain
    ) internal returns (uint256) {
        return _contentRegistry.mint(_contentTypes, _name, _domain);
    }

    /// @dev Setup the paywall for the given contents
    function _setupInteractions(ContentInteractionManager _interactionManager, uint256 _contentId) internal {
        console.log("Setting up interactions");
        vm.startBroadcast();
        // Deploy the interaction contract
        _interactionManager.deployInteractionContract(_contentId);
        // Grant the right roles
        _grantValidatorRole(_interactionManager, _contentId);
        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _grantValidatorRole(ContentInteractionManager _interactionManager, uint256 _contentId) internal {
        ContentInteractionDiamond interactionContract = _interactionManager.getInteractionContract(_contentId);
        interactionContract.grantRoles(interactionValidator, INTERCATION_VALIDATOR_ROLE);
    }

    function _allowStylusContract(ContentInteractionManager _interactionManager, uint256 _contentId) internal {
        ContentInteractionDiamond interactionContract = _interactionManager.getInteractionContract(_contentId);
        // build the data
        bytes memory allowStylusData = abi.encodeWithSelector(
            DappInteractionFacet.setContentContract.selector,
            stylusContract,
            IContentConsumptionContract.getUserConsumption.selector
        );
        vm.startBroadcast();
        interactionContract.delegateToFacet(DENOMINATOR_DAPP, allowStylusData);
        vm.stopBroadcast();
    }
}
