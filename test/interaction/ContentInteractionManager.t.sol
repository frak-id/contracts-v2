// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CONTENT_TYPE_DAPP, CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ContentInteractionManagerTest is Test {
    address owner = makeAddr("owner");
    address minter = makeAddr("minter");

    ContentRegistry private contentRegistry;
    ReferralRegistry private referralRegistry;

    uint256 contentIdDapp;
    uint256 contentIdPress;
    uint256 contentIdUnknown;

    ContentInteractionManager private contentInteractionManager;

    function setUp() public {
        contentRegistry = new ContentRegistry(owner);
        referralRegistry = new ReferralRegistry(owner);

        address implem = address(new ContentInteractionManager(contentRegistry, referralRegistry));
        address proxy = LibClone.deployERC1967(implem);
        contentInteractionManager = ContentInteractionManager(proxy);
        contentInteractionManager.init(owner);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(contentInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        vm.startPrank(owner);
        contentIdDapp = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "dapp-domain");
        contentIdPress = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        contentIdUnknown = contentRegistry.mint(ContentTypes.wrap(bytes32(uint256(1 << 99))), "name", "unknown-domain");
        vm.stopPrank();
    }

    function test_deployInteractionContract_ContentDoesntExist() public {
        vm.expectRevert(ContentInteractionManager.ContentDoesntExist.selector);
        contentInteractionManager.deployInteractionContract(0);
    }

    function test_deployInteractionContract_CantHandleContentTypes() public {
        vm.expectRevert(ContentInteractionManager.CantHandleContentTypes.selector);
        contentInteractionManager.deployInteractionContract(contentIdDapp);

        vm.expectRevert(ContentInteractionManager.CantHandleContentTypes.selector);
        contentInteractionManager.deployInteractionContract(contentIdUnknown);
    }

    function test_deployInteractionContract_InteractionContractAlreadyDeployed() public {
        contentInteractionManager.deployInteractionContract(contentIdPress);
        assertNotEq(contentInteractionManager.getInteractionContract(contentIdPress), address(0));

        vm.expectRevert(ContentInteractionManager.InteractionContractAlreadyDeployed.selector);
        contentInteractionManager.deployInteractionContract(contentIdPress);
    }

    function test_deployInteractionContract() public {
        // Deploy the interaction contract
        contentInteractionManager.deployInteractionContract(contentIdPress);

        // Assert it's deployed
        assertNotEq(contentInteractionManager.getInteractionContract(contentIdPress), address(0));

        // Ensure the deployed contract match the interaction contract
        ContentInteraction interactionContract =
            ContentInteraction(contentInteractionManager.getInteractionContract(contentIdPress));
        assertEq(ContentTypes.unwrap(interactionContract.getContentType()), ContentTypes.unwrap(CONTENT_TYPE_PRESS));
    }

    function test_getInteractionContract() public {
        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        contentInteractionManager.getInteractionContract(contentIdPress);

        contentInteractionManager.deployInteractionContract(contentIdPress);
        address deployedAddress = contentInteractionManager.getInteractionContract(contentIdPress);
        assertNotEq(deployedAddress, address(0));
    }

    function test_reinit() public {
        vm.expectRevert();
        contentInteractionManager.init(address(1));

        // Ensure we can't init raw instance
        ContentInteractionManager rawImplem = new ContentInteractionManager(contentRegistry, referralRegistry);
        vm.expectRevert();
        rawImplem.init(owner);
    }

    function test_upgrade() public {
        address newImplem = address(new ContentInteractionManager(contentRegistry, referralRegistry));

        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.upgradeToAndCall(newImplem, "");

        vm.prank(owner);
        contentInteractionManager.upgradeToAndCall(newImplem, "");
    }
}
