// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {CampaignBankFactory} from "src/campaign/CampaignBankFactory.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ProductAdministratorRegistry, ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract AddFundingBank is Script, DeterminedAddress {
    function run() public {
        Addresses memory addresses = _getAddresses();

        uint256[] memory productIds = new uint256[](4);
        productIds[0] = 0x2d0cdaf9a1153a9a4b68379c64d4397611a0f3d9fa4015376435f9a64aafc0c1;
        productIds[1] = 0x4b1115a4946079f8d83c63061f5c49c2f351a054d8dfb284b197f54dbfa8ed62;
        productIds[2] = 0x492b0afd98946a7041772b747fd12b5b734043da5948f58afe0ca2287d3ed6c;
        productIds[3] = 0xac8885004fee2cfa1e20f8ae581b79340670b72f80f4369c863c22e7c20004ec;

        _setupBanks(addresses, productIds);
    }

    /// @dev Setup the interaction contracts for the given products
    function _setupBanks(Addresses memory addresses, uint256[] memory _productIds) internal {
        console.log("Setting up banks");
        CampaignBankFactory campaignBankFactory = CampaignBankFactory(addresses.campaignBankFactory);
        vm.startBroadcast();
        for (uint256 i = 0; i < _productIds.length; i++) {
            // Deploy the interaction contract
            CampaignBank bank = campaignBankFactory.deployCampaignBank(_productIds[i], addresses.mUSDToken);
            // Mint a few tokens to the bank
            mUSDToken(addresses.mUSDToken).mint(address(bank), 10_000 ether);
            // Enable the bank to distribute tokens
            bank.updateDistributionState(true);
        }
        vm.stopBroadcast();
    }
}
