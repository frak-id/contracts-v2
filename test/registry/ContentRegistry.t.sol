// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";

contract ContentRegistryTest is Test {
    /// @dev The module we will test
    ContentRegistry private contentRegistry;

    address owner = makeAddr("owner");
    address minter = makeAddr("minter");

    function setUp() public {
        contentRegistry = new ContentRegistry(owner);
        vm.prank(owner);
        contentRegistry.grantRoles(minter, MINTER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Simple metadata tests                           */
    /* -------------------------------------------------------------------------- */

    function test_contentRegistry_description() public view {
        assertEq(contentRegistry.name(), "ContentRegistry");
        assertEq(contentRegistry.symbol(), "CR");

        assertEq(contentRegistry.tokenURI(0), "https://content.frak.id/metadata/0.json");
        assertEq(contentRegistry.tokenURI(13), "https://content.frak.id/metadata/13.json");
        assertEq(contentRegistry.tokenURI(420), "https://content.frak.id/metadata/420.json");
        assertEq(
            contentRegistry.tokenURI(type(uint256).max),
            "https://content.frak.id/metadata/115792089237316195423570985008687907853269984665640564039457584007913129639935.json"
        );
    }

    function test_mint_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentRegistry.mint(0, "name", "domain");
    }

    function test_mint_InvalidNameOrDomain() public {
        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(0, "", "domain");

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(0, "name", "");

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(0, "", "");
    }

    function test_mint_AlreadyExistingContent() public {
        vm.prank(minter);
        contentRegistry.mint(0, "name", "domain");

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(0, "name", "domain");

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(0, "name-wtf", "domain");

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(bytes32(uint256(13)), "name", "domain");
    }

    function test_mint() public {
        uint256 id = uint256(keccak256("domain"));

        vm.prank(minter);
        uint256 mintedId = contentRegistry.mint(0, "name", "domain");

        assertEq(mintedId, id);
        assertEq(contentRegistry.ownerOf(mintedId), address(minter));
        assertEq(contentRegistry.getContentTypes(id), 0);
        assertEq(contentRegistry.isExistingContent(id), true);

        Metadata memory metadata = contentRegistry.getMetadata(id);
        assertEq(metadata.contentTypes, 0);
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");
    }

    function test_updateMetadata() public {
        vm.prank(minter);
        uint256 id = contentRegistry.mint(0, "name", "domain");

        Metadata memory metadata = contentRegistry.getMetadata(id);
        assertEq(metadata.contentTypes, 0);
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");

        vm.prank(minter);
        contentRegistry.updateMetadata(id, bytes32(uint256(1)), "new-name");

        metadata = contentRegistry.getMetadata(id);
        assertEq(metadata.contentTypes, bytes32(uint256(1)));
        assertEq(metadata.name, "new-name");
        assertEq(metadata.domain, "domain");

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        contentRegistry.updateMetadata(id, 0, "new-name");

        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        vm.prank(minter);
        contentRegistry.updateMetadata(id, 0, "");
    }
}
