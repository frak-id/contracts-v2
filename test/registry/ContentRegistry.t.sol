// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {CONTENT_TYPE_DAPP, CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";

contract ContentRegistryTest is Test {
    /// @dev The module we will test
    ContentRegistry private contentRegistry;

    address private owner = makeAddr("owner");
    address private minter = makeAddr("minter");

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
        contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);
    }

    function test_mint_InvalidNameOrDomain() public {
        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "", "", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.InvalidOwner.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "test", "test", address(0));
    }

    function test_mint_AlreadyExistingContent() public {
        vm.prank(minter);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(CONTENT_TYPE_DAPP, "name-wtf", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ContentRegistry.AlreadyExistingContent.selector);
        contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "domain", minter);
    }

    function test_mint() public {
        uint256 id = uint256(keccak256("domain"));

        vm.prank(minter);
        uint256 mintedId = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);

        assertEq(mintedId, id);
        assertEq(contentRegistry.ownerOf(mintedId), address(minter));
        assertEq(ContentTypes.unwrap(contentRegistry.getContentTypes(id)), ContentTypes.unwrap(CONTENT_TYPE_DAPP));
        assertEq(contentRegistry.isExistingContent(id), true);

        Metadata memory metadata = contentRegistry.getMetadata(id);
        assertEq(ContentTypes.unwrap(metadata.contentTypes), ContentTypes.unwrap(CONTENT_TYPE_DAPP));
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");
    }

    function test_updateMetadata() public {
        vm.prank(minter);
        uint256 id = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);

        Metadata memory metadata = contentRegistry.getMetadata(id);
        assertEq(ContentTypes.unwrap(metadata.contentTypes), ContentTypes.unwrap(CONTENT_TYPE_DAPP));
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");

        vm.prank(minter);
        contentRegistry.updateMetadata(id, ContentTypes.wrap(uint256(13)), "new-name");

        metadata = contentRegistry.getMetadata(id);
        assertEq(ContentTypes.unwrap(metadata.contentTypes), uint256(13));
        assertEq(metadata.name, "new-name");
        assertEq(metadata.domain, "domain");

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        contentRegistry.updateMetadata(id, CONTENT_TYPE_DAPP, "new-name");

        vm.expectRevert(ContentRegistry.InvalidNameOrDomain.selector);
        vm.prank(minter);
        contentRegistry.updateMetadata(id, CONTENT_TYPE_DAPP, "");
    }

    function test_isAuthorized() public {
        vm.prank(minter);
        uint256 id = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "domain", minter);

        assertEq(contentRegistry.isAuthorized(id, minter), true);
        assertEq(contentRegistry.isAuthorized(id, owner), false);

        address operator = makeAddr("operator");
        vm.prank(minter);
        contentRegistry.setApprovalForAll(operator, true);

        assertEq(contentRegistry.isAuthorized(id, operator), true);

        vm.prank(minter);
        contentRegistry.setApprovalForAll(operator, false);

        assertEq(contentRegistry.isAuthorized(id, operator), false);
    }
}
