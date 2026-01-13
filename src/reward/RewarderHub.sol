// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {REWARDER_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @dev Struct for a single reward operation in batch
struct RewardOp {
    /// @dev Wallet address to push reward to
    address wallet;
    /// @dev Amount of tokens to reward
    uint256 amount;
    /// @dev Token address
    address token;
    /// @dev Bank address (source of funds)
    address bank;
    /// @dev Attestation data for audit trail
    bytes attestation;
}

/// @author @KONFeature
/// @title RewarderHub
/// @notice Central hub for managing and distributing rewards across the Frak ecosystem
/// @dev IMPORTANT: Token Compatibility
///      This contract does NOT support:
///      - Fee-on-transfer tokens: The contract credits the full transfer amount to users without
///        measuring actual received amounts. Fee-on-transfer tokens would cause accounting
///        discrepancies where users are credited more than the contract receives.
///      - Rebasing tokens: The contract tracks fixed amounts in storage. Rebasing tokens that
///        change balances over time would cause over/under-collateralization issues.
///      Only use standard ERC20 tokens that transfer the exact requested amount.
/// @custom:security-contact contact@frak.id
contract RewarderHub is OwnableRoles, UUPSUpgradeable, Initializable, ReentrancyGuard {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a reward is pushed directly to a wallet
    event RewardPushed(address indexed wallet, address token, address bank, uint256 amount, bytes attestation);

    /// @dev Emitted when rewards are claimed by a user
    event RewardClaimed(address indexed wallet, address token, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Thrown when an invalid address is provided
    error InvalidAddress();

    /// @dev Thrown when an invalid amount is provided
    error InvalidAmount();

    /// @dev Thrown when there's nothing to claim
    error NothingToClaim();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.reward.hub')) - 1)
    bytes32 private constant _REWARDER_HUB_STORAGE_SLOT =
        0x5765d97f39456ee4cd0e1fa62a9e5c3f6b4a0c7d8e9f0a1b2c3d4e5f6a7b8c9d;

    /// @custom:storage-location erc7201:frak.reward.hub
    struct RewarderHubStorage {
        /// @dev Claimable rewards: wallet => token => amount
        mapping(address wallet => mapping(address token => uint256 amount)) claimable;
    }

    function _storage() private pure returns (RewarderHubStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REWARDER_HUB_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the RewarderHub
    /// @param _owner The owner address
    function init(address _owner) external initializer {
        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Push a reward directly to a wallet
    /// @param _wallet The recipient wallet address
    /// @param _amount The amount of tokens to reward
    /// @param _token The token address
    /// @param _bank The bank address (source of funds)
    /// @param _attestation Attestation data for audit trail
    function pushReward(address _wallet, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        external
        onlyRoles(REWARDER_ROLE)
    {
        _pushReward(_wallet, _amount, _token, _bank, _attestation);
    }

    /// @notice Execute a batch of reward operations
    /// @dev Gas Optimization: Operations SHOULD be sorted by (bank, token) for optimal gas usage.
    ///      The function aggregates consecutive operations with the same (bank, token) pair into
    ///      a single transfer. Unsorted operations will still execute correctly but may result
    ///      in multiple smaller transfers instead of aggregated ones, consuming more gas.
    ///      Example of optimal sorting: [(bankA, tokenX), (bankA, tokenX), (bankA, tokenY), (bankB, tokenX)]
    ///      Reverts if any transfer fails. Caller should simulate first to ensure success.
    /// @dev Security: nonReentrant guard protects against malicious token callbacks (e.g., ERC777 hooks)
    ///      that could attempt to manipulate state during transfers.
    /// @param _ops Array of reward operations, ideally sorted by (bank, token) for gas efficiency
    function batch(RewardOp[] calldata _ops) external onlyRoles(REWARDER_ROLE) nonReentrant {
        uint256 len = _ops.length;
        if (len == 0) return;

        RewarderHubStorage storage $ = _storage();

        // Track current chunk for deferred transfer
        address currentBank = _ops[0].bank;
        address currentToken = _ops[0].token;
        uint256 pendingAmount;

        for (uint256 i; i < len;) {
            RewardOp calldata op = _ops[i];

            // Chunk boundary - transfer previous chunk
            if (op.bank != currentBank || op.token != currentToken) {
                currentToken.safeTransferFrom(currentBank, address(this), pendingAmount);
                currentBank = op.bank;
                currentToken = op.token;
                pendingAmount = 0;
            }

            // Accumulate for transfer
            pendingAmount += op.amount;

            // Push reward to wallet
            $.claimable[op.wallet][op.token] += op.amount;
            emit RewardPushed(op.wallet, op.token, op.bank, op.amount, op.attestation);

            unchecked {
                ++i;
            }
        }

        // Transfer final chunk
        currentToken.safeTransferFrom(currentBank, address(this), pendingAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                              User Functions                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim rewards for a specific token
    /// @param _token The token address to claim
    /// @return claimed The amount claimed
    function claim(address _token) external nonReentrant returns (uint256 claimed) {
        RewarderHubStorage storage $ = _storage();

        claimed = $.claimable[msg.sender][_token];
        if (claimed == 0) revert NothingToClaim();

        $.claimable[msg.sender][_token] = 0;

        _token.safeTransfer(msg.sender, claimed);

        emit RewardClaimed(msg.sender, _token, claimed);
    }

    /// @notice Claim rewards for multiple tokens
    /// @param _tokens Array of token addresses to claim
    /// @return claimed Array of amounts claimed per token
    function claimBatch(address[] calldata _tokens) external nonReentrant returns (uint256[] memory claimed) {
        claimed = new uint256[](_tokens.length);
        RewarderHubStorage storage $ = _storage();

        for (uint256 t; t < _tokens.length;) {
            address token = _tokens[t];
            uint256 amount = $.claimable[msg.sender][token];

            if (amount > 0) {
                $.claimable[msg.sender][token] = 0;
                token.safeTransfer(msg.sender, amount);
                emit RewardClaimed(msg.sender, token, amount);
            }

            claimed[t] = amount;

            unchecked {
                ++t;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the claimable amount for a wallet
    /// @param _wallet The wallet address
    /// @param _token The token address
    /// @return amount The claimable amount
    function getClaimable(address _wallet, address _token) external view returns (uint256 amount) {
        return _storage().claimable[_wallet][_token];
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Internal push reward implementation
    function _pushReward(address _wallet, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        internal
    {
        if (_wallet == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update claimable
        _storage().claimable[_wallet][_token] += _amount;

        emit RewardPushed(_wallet, _token, _bank, _amount, _attestation);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Authorize upgrade - only UPGRADE_ROLE can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
