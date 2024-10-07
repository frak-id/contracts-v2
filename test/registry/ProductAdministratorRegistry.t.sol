// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";

import {PRODUCT_TYPE_DAPP} from "src/constants/ProductTypes.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ProductAdministratorRegistry, ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";

contract ProductAdministratorRegistryTest is Test {
    /// @dev The module we will test
    ProductRegistry private productRegistry;
    ProductAdministratorRegistry private adminRegistry;

    address private owner = makeAddr("owner");
    address private minter = makeAddr("minter");

    address private pOwner = makeAddr("productOwner");
    address private pAdmin = makeAddr("productAdmin");

    uint256 private pId;

    uint256 constant ALL_ROLES = type(uint256).max;

    function setUp() public {
        productRegistry = new ProductRegistry(owner);
        adminRegistry = new ProductAdministratorRegistry(productRegistry);

        vm.prank(owner);
        productRegistry.grantRoles(minter, MINTER_ROLE);

        vm.prank(minter);
        pId = productRegistry.mint(PRODUCT_TYPE_DAPP, "p-test", "p-test.com", pOwner);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, pAdmin, ProductRoles.PRODUCT_ADMINISTRATOR);
    }

    function test_hasRoles_noDefaultRoles(address user) public view {
        vm.assume(user != pOwner && user != address(0));

        assertFalse(adminRegistry.hasAnyRole(pId, user, ALL_ROLES));
        assertFalse(adminRegistry.hasAllRoles(pId, user, ALL_ROLES));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, ALL_ROLES));

        assertTrue(adminRegistry.hasAllRolesOrOwner(pId, pOwner, ALL_ROLES));
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Grant                                   */
    /* -------------------------------------------------------------------------- */

    function test_grant_Unauthorized(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin);

        vm.expectRevert(ProductAdministratorRegistry.Unauthorized.selector);
        adminRegistry.grantRoles(pId, user, roles);
    }

    function test_grant_randomRoles_fromOwner(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, user, roles);

        assertTrue(adminRegistry.hasAnyRole(pId, user, roles));
        assertTrue(adminRegistry.hasAnyRole(pId, user, ALL_ROLES));
        assertTrue(adminRegistry.hasAllRoles(pId, user, roles));
        assertTrue(adminRegistry.hasAllRolesOrOwner(pId, user, roles));

        vm.prank(pOwner);
        adminRegistry.revokeRoles(pId, user, roles);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAnyRole(pId, user, ALL_ROLES));
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }

    function test_grant_randomRoles_fromAdmin(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pAdmin);
        adminRegistry.grantRoles(pId, user, roles);

        assertTrue(adminRegistry.hasAnyRole(pId, user, roles));
        assertTrue(adminRegistry.hasAnyRole(pId, user, ALL_ROLES));
        assertTrue(adminRegistry.hasAllRoles(pId, user, roles));
        assertTrue(adminRegistry.hasAllRolesOrOwner(pId, user, roles));

        vm.prank(pAdmin);
        adminRegistry.revokeRoles(pId, user, roles);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAnyRole(pId, user, ALL_ROLES));
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Revoke                                   */
    /* -------------------------------------------------------------------------- */

    function test_revoke_randomRoles(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, user, roles);

        vm.prank(pOwner);
        adminRegistry.revokeRoles(pId, user, roles);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAnyRole(pId, user, ALL_ROLES)); // also test bitmasking here
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }

    function test_revokeAll_randomRoles(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, user, roles);

        vm.prank(pOwner);
        adminRegistry.revokeAllRoles(pId, user);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAnyRole(pId, user, ALL_ROLES)); // also test bitmasking here
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Renounce                                  */
    /* -------------------------------------------------------------------------- */

    function test_renonce_randomRoles(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, user, roles);

        vm.prank(user);
        adminRegistry.renounceRoles(pId, roles);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }

    function test_renonceAll_randomRoles(address user, uint256 roles) public {
        vm.assume(user != pOwner && user != pAdmin && user != address(0));
        vm.assume(roles != 0);

        vm.prank(pOwner);
        adminRegistry.grantRoles(pId, user, roles);

        vm.prank(user);
        adminRegistry.renounceAllRoles(pId);

        assertFalse(adminRegistry.hasAnyRole(pId, user, roles));
        assertFalse(adminRegistry.hasAllRoles(pId, user, roles));
        assertFalse(adminRegistry.hasAllRolesOrOwner(pId, user, roles));
    }
}
