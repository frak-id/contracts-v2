// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentRegistry} from "./ContentRegistry.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author @KONFeature
/// @title ProductAdministratorRegistry
/// @notice Registery for the roles associated per users around a product
/// @dev Same as `OwnableRoles` from `solady` but with `productId` in the role slot seet, and some features removed
contract ProductAdministratorRegistry {
    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error Unauthorized();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev The `user`'s roles is updated to `roles`.
    /// Each bit of `roles` represents whether the role is set.
    event ProductRolesUpdated(uint256 indexed product, address indexed user, uint256 roles);

    /// @dev `keccak256(bytes("ProductRolesUpdated(uint256,address,uint256)"))`.
    uint256 private constant _PRODUCT_ROLES_UPDATED_EVENT_SIGNATURE =
        0xca5f6034cf7475c6c068781b337289c341f3350f95845d98e134a06ce879afa9;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The role slot of `user` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _ROLE_SLOT_SEED))
    ///     mstore(0x20, productId)
    ///     let roleSlot := keccak256(0x00, 0x40)
    /// ```
    /// This automatically ignores the upper bits of the `user` in case
    uint256 private constant _ROLE_SLOT_SEED = 0x8b78c6d8;

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The content registry
    ContentRegistry internal immutable _CONTENT_REGISTRY;

    constructor(ContentRegistry _contentRegistry) {
        _CONTENT_REGISTRY = _contentRegistry;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal functions                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Overwrite the roles directly without authorization guard.
    function _setRoles(uint256 productId, address user, uint256 roles) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            mstore(0x20, productId)
            // Store the new value.
            sstore(keccak256(0x0c, 0x40), roles)
            // Emit the {ProductRolesUpdated} event.
            let ptr := mload(0x40)
            mstore(0x40, roles)
            log3(0x40, 0x60, _PRODUCT_ROLES_UPDATED_EVENT_SIGNATURE, mload(0x20), shr(96, mload(0x0c)))
            mstore(0x40, ptr)
        }
    }

    /// @dev Updates the roles directly without authorization guard.
    /// If `on` is true, each set bit of `roles` will be turned on,
    /// otherwise, each set bit of `roles` will be turned off.
    function _updateRoles(uint256 productId, address user, uint256 roles, bool on) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            mstore(0x20, productId)
            let roleSlot := keccak256(0x0c, 0x40)
            // Load the current value.
            let current := sload(roleSlot)
            // Compute the updated roles if `on` is true.
            let updated := or(current, roles)
            // Compute the updated roles if `on` is false.
            // Use `and` to compute the intersection of `current` and `roles`,
            // `xor` it with `current` to flip the bits in the intersection.
            if iszero(on) { updated := xor(current, and(current, roles)) }
            // Then, store the new value.
            sstore(roleSlot, updated)
            // Emit the {ProductRolesUpdated} event.
            let ptr := mload(0x40)
            mstore(0x40, roles)
            log3(0x40, 0x60, _PRODUCT_ROLES_UPDATED_EVENT_SIGNATURE, mload(0x20), shr(96, mload(0x0c)))
            mstore(0x40, ptr)
        }
    }

    /// @dev Throws if the sender does not have any of the `roles`.
    function _checkRoles(uint256 productId, uint256 roles) internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the role slot.
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, caller())
            mstore(0x20, productId)
            // Load the stored value, and if the `and` intersection
            // of the value and `roles` is zero, revert.
            if iszero(and(sload(keccak256(0x0c, 0x40)), roles)) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Throws if the sender does not have any of the `roles`,
    /// and is not the owner.
    /// Checks for roles first, then lazily checks for ownership.
    function _checkRolesOrAdmin(uint256 productId, uint256 roles) internal view virtual {
        // Check the roles first.
        _checkRoles(productId, roles);
        // Then check if the user is an authorized product admin
        if (!isAuthorizedAdmin(productId, msg.sender)) revert Unauthorized();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public role updated                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Allow the caller to remove their own roles.
    /// If the caller does not have a role, then it will be an no-op for the role.
    function renounceRoles(uint256 productId, uint256 roles) public payable virtual {
        _updateRoles(productId, msg.sender, roles, false);
    }

    /// @dev Allows the owner to grant `user` `roles`.
    /// If the `user` already has a role, then it will be an no-op for the role.
    function grantRoles(uint256 productId, address user, uint256 roles)
        public
        payable
        virtual
        onlyProductAdmin(productId)
    {
        _updateRoles(productId, user, roles, true);
    }

    /// @dev Allows the owner to remove `user` `roles`.
    /// If the `user` does not have a role, then it will be an no-op for the role.
    function revokeRoles(uint256 productId, address user, uint256 roles)
        public
        payable
        virtual
        onlyProductAdmin(productId)
    {
        _updateRoles(productId, user, roles, false);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public role checks                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the `_caller` is authorized to manage the `_productId` (basically if he have the admin right on the product)
    function isAuthorizedAdmin(uint256 _productId, address _caller) public view returns (bool) {
        return _CONTENT_REGISTRY.isAuthorized(_productId, _caller);
    }

    /// @dev Returns the roles of `user`.
    function rolesOf(uint256 productId, address user) public view virtual returns (uint256 roles) {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the role slot.
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            mstore(0x20, productId)
            // Load the stored value.
            roles := sload(keccak256(0x0c, 0x40))
        }
    }

    /// @dev Returns whether `user` has any of `roles`.
    function hasAnyRole(uint256 productId, address user, uint256 roles) public view virtual returns (bool) {
        return rolesOf(productId, user) & roles != 0;
    }

    /// @dev Returns whether `user` has all of `roles`.
    function hasAllRoles(uint256 productId, address user, uint256 roles) public view virtual returns (bool) {
        return rolesOf(productId, user) & roles == roles;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */

    modifier onlyProductAdmin(uint256 productId) {
        if (!isAuthorizedAdmin(productId, msg.sender)) revert Unauthorized();
        _;
    }
}
