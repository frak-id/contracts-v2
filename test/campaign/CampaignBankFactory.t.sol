// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {CampaignBankFactory} from "src/campaign/CampaignBankFactory.sol";

contract CampaignBankFactoryTest is EcosystemAwareTest {
    /// @dev The bank factory we will test
    CampaignBankFactory private factory;

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the bank
        factory = new CampaignBankFactory(adminRegistry);
    }

    function test_deployCampaignBank() public {
        // Deploy a new campaign bank
        CampaignBank bank = factory.deployCampaignBank(1, address(token));

        // Check the bank
        (uint256 productId, address tokenAddr) = bank.getConfig();
        assertEq(productId, 1);
        assertEq(tokenAddr, address(token));
    }

    function test_deployCampaignBank_CantRedeploySameOne() public {
        factory.deployCampaignBank(1, address(token));

        vm.expectRevert();
        factory.deployCampaignBank(1, address(token));
    }

    function testFuzz_deployCampaignBank(uint256 _productId, address _token) public {
        // Deploy a new campaign bank
        CampaignBank bank = factory.deployCampaignBank(_productId, _token);

        // Check the bank
        (uint256 productId, address tokenAddr) = bank.getConfig();
        assertEq(productId, _productId);
        assertEq(tokenAddr, _token);
    }
}
