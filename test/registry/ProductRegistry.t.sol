// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {PRODUCT_TYPE_DAPP, PRODUCT_TYPE_PRESS, ProductTypes} from "src/constants/ProductTypes.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {Metadata, ProductRegistry} from "src/registry/ProductRegistry.sol";

contract ProductRegistryTest is Test {
    /// @dev The module we will test
    ProductRegistry private productRegistry;

    address private owner = makeAddr("owner");
    address private minter = makeAddr("minter");

    function setUp() public {
        productRegistry = new ProductRegistry(owner);
        vm.prank(owner);
        productRegistry.grantRoles(minter, MINTER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Simple metadata tests                           */
    /* -------------------------------------------------------------------------- */

    function test_productRegistry_description() public view {
        assertEq(productRegistry.name(), "ProductRegistry");
        assertEq(productRegistry.symbol(), "CR");

        assertEq(productRegistry.tokenURI(0), "https://content.frak.id/metadata/0.json");
        assertEq(productRegistry.tokenURI(13), "https://content.frak.id/metadata/13.json");
        assertEq(productRegistry.tokenURI(420), "https://content.frak.id/metadata/420.json");
        assertEq(
            productRegistry.tokenURI(type(uint256).max),
            "https://content.frak.id/metadata/115792089237316195423570985008687907853269984665640564039457584007913129639935.json"
        );
    }

    function test_mint_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);
    }

    function test_mint_InvalidNameOrDomain() public {
        vm.prank(minter);
        vm.expectRevert(ProductRegistry.InvalidNameOrDomain.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.InvalidNameOrDomain.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.InvalidNameOrDomain.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "", "", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.InvalidOwner.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "test", "test", address(0));
    }

    function test_mint_AlreadyExistingProduct() public {
        vm.prank(minter);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.AlreadyExistingProduct.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.AlreadyExistingProduct.selector);
        productRegistry.mint(PRODUCT_TYPE_DAPP, "name-wtf", "domain", minter);

        vm.prank(minter);
        vm.expectRevert(ProductRegistry.AlreadyExistingProduct.selector);
        productRegistry.mint(PRODUCT_TYPE_PRESS, "name", "domain", minter);
    }

    function test_mint() public {
        uint256 id = uint256(keccak256("domain"));

        vm.prank(minter);
        uint256 mintedId = productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);

        assertEq(mintedId, id);
        assertEq(productRegistry.ownerOf(mintedId), address(minter));
        assertEq(ProductTypes.unwrap(productRegistry.getProductTypes(id)), ProductTypes.unwrap(PRODUCT_TYPE_DAPP));
        assertEq(productRegistry.isExistingProduct(id), true);

        Metadata memory metadata = productRegistry.getMetadata(id);
        assertEq(ProductTypes.unwrap(metadata.productTypes), ProductTypes.unwrap(PRODUCT_TYPE_DAPP));
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");
    }

    function test_updateMetadata() public {
        vm.prank(minter);
        uint256 id = productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);

        Metadata memory metadata = productRegistry.getMetadata(id);
        assertEq(ProductTypes.unwrap(metadata.productTypes), ProductTypes.unwrap(PRODUCT_TYPE_DAPP));
        assertEq(metadata.name, "name");
        assertEq(metadata.domain, "domain");

        vm.prank(minter);
        productRegistry.updateMetadata(id, ProductTypes.wrap(uint256(13)), "new-name");

        metadata = productRegistry.getMetadata(id);
        assertEq(ProductTypes.unwrap(metadata.productTypes), uint256(13));
        assertEq(metadata.name, "new-name");
        assertEq(metadata.domain, "domain");

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        productRegistry.updateMetadata(id, PRODUCT_TYPE_DAPP, "new-name");

        vm.expectRevert(ProductRegistry.InvalidNameOrDomain.selector);
        vm.prank(minter);
        productRegistry.updateMetadata(id, PRODUCT_TYPE_DAPP, "");
    }

    function test_isAuthorized() public {
        vm.prank(minter);
        uint256 id = productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "domain", minter);

        assertEq(productRegistry.isAuthorized(id, minter), true);
        assertEq(productRegistry.isAuthorized(id, owner), false);

        address operator = makeAddr("operator");
        vm.prank(minter);
        productRegistry.setApprovalForAll(operator, true);

        assertEq(productRegistry.isAuthorized(id, operator), true);

        vm.prank(minter);
        productRegistry.setApprovalForAll(operator, false);

        assertEq(productRegistry.isAuthorized(id, operator), false);
    }
}
