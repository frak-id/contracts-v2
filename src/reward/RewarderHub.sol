// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {COMPLIANCE_ROLE, REWARDER_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
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

/// @dev Struct for a single frozen funds recovery operation
struct FrozenFundsRecoverOp {
    /// @dev Wallet address to recover funds from
    address wallet;
    /// @dev Token address to recover
    address token;
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

    /// @dev Emitted when a user is frozen
    event UserFrozen(address indexed wallet, uint256 timestamp);

    /// @dev Emitted when a user is unfrozen
    event UserUnfrozen(address indexed wallet);

    /// @dev Emitted when frozen funds are recovered
    event FrozenFundsRecovered(address indexed wallet, address token, uint256 amount, address recipient);

    /// @dev Emitted when excess tokens are withdrawn
    event ExcessWithdrawn(address indexed token, uint256 amount, address recipient);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Thrown when an invalid address is provided
    error InvalidAddress();

    /// @dev Thrown when an invalid amount is provided
    error InvalidAmount();

    /// @dev Thrown when there's nothing to claim
    error NothingToClaim();

    /// @dev Thrown when user is frozen and tries to claim
    error UserIsFrozen();

    /// @dev Thrown when trying to unfreeze a user that is not frozen
    error UserNotFrozen();

    /// @dev Thrown when trying to freeze a user that is already frozen
    error UserAlreadyFrozen();

    /// @dev Thrown when trying to recover funds before freeze period has elapsed
    error FreezePeriodNotElapsed();

    /// @dev Thrown when there's no excess to withdraw
    error NothingToWithdraw();

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Duration a user must be frozen before funds can be recovered (60 days)
    uint256 public constant FREEZE_DURATION = 60 days;

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
        /// @dev Frozen wallets: wallet => timestamp when frozen (0 = not frozen)
        mapping(address wallet => uint256 frozenAt) frozen;
        /// @dev Total pending balance per token (owed to users)
        mapping(address token => uint256 amount) pendingBalance;
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
        if (_wallet == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update claimable and pending balance
        RewarderHubStorage storage $ = _storage();
        $.claimable[_wallet][_token] += _amount;
        $.pendingBalance[_token] += _amount;

        emit RewardPushed(_wallet, _token, _bank, _amount, _attestation);
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
                $.pendingBalance[currentToken] += pendingAmount;
                currentBank = op.bank;
                currentToken = op.token;
                pendingAmount = 0;
            }

            // Accumulate for transfer
            pendingAmount += op.amount;

            // Push reward to wallet and track pending balance
            address wallet = op.wallet;
            $.claimable[wallet][currentToken] += op.amount;
            emit RewardPushed(wallet, currentToken, currentBank, op.amount, op.attestation);

            unchecked {
                ++i;
            }
        }

        // Transfer final chunk
        currentToken.safeTransferFrom(currentBank, address(this), pendingAmount);
        $.pendingBalance[currentToken] += pendingAmount;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Compliance Functions                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Freeze a user, preventing them from claiming rewards
    /// @param _wallet The wallet address to freeze
    function freezeUser(address _wallet) external onlyRoles(COMPLIANCE_ROLE) {
        if (_wallet == address(0)) revert InvalidAddress();

        RewarderHubStorage storage $ = _storage();
        if ($.frozen[_wallet] != 0) revert UserAlreadyFrozen();

        $.frozen[_wallet] = block.timestamp;

        emit UserFrozen(_wallet, block.timestamp);
    }

    /// @notice Unfreeze a user, allowing them to claim rewards again
    /// @param _wallet The wallet address to unfreeze
    function unfreezeUser(address _wallet) external onlyRoles(COMPLIANCE_ROLE) {
        RewarderHubStorage storage $ = _storage();
        if ($.frozen[_wallet] == 0) revert UserNotFrozen();

        $.frozen[_wallet] = 0;

        emit UserUnfrozen(_wallet);
    }

    /// @notice Recover funds from users who have been frozen for longer than FREEZE_DURATION
    /// @param _ops Array of wallet-token pairs to recover
    /// @param _recipient Address to send recovered funds to
    function recoverFrozenFunds(FrozenFundsRecoverOp[] calldata _ops, address _recipient)
        external
        onlyRoles(COMPLIANCE_ROLE)
        nonReentrant
    {
        if (_recipient == address(0)) revert InvalidAddress();

        RewarderHubStorage storage $ = _storage();

        for (uint256 i; i < _ops.length;) {
            FrozenFundsRecoverOp calldata op = _ops[i];
            uint256 frozenAt = $.frozen[op.wallet];

            // Must be frozen and freeze period must have elapsed
            if (frozenAt == 0) revert UserNotFrozen();
            if (block.timestamp < frozenAt + FREEZE_DURATION) revert FreezePeriodNotElapsed();

            uint256 amount = $.claimable[op.wallet][op.token];
            if (amount > 0) {
                $.claimable[op.wallet][op.token] = 0;
                $.pendingBalance[op.token] -= amount;
                op.token.safeTransfer(_recipient, amount);
                emit FrozenFundsRecovered(op.wallet, op.token, amount, _recipient);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Withdraw excess tokens that are not owed to users
    /// @dev Use address(0) for native ETH withdrawal
    /// @param _token The token address to withdraw (address(0) for native ETH)
    /// @param _recipient Address to send excess funds to
    /// @return excess The amount of excess withdrawn
    function withdrawExcess(address _token, address _recipient)
        external
        onlyRoles(COMPLIANCE_ROLE)
        nonReentrant
        returns (uint256 excess)
    {
        if (_recipient == address(0)) revert InvalidAddress();

        RewarderHubStorage storage $ = _storage();

        if (_token == address(0)) {
            // Native ETH - no pending balance tracked for native, withdraw full balance
            excess = address(this).balance;
        } else {
            // ERC20 token
            uint256 balance = _token.balanceOf(address(this));
            uint256 pending = $.pendingBalance[_token];
            excess = balance > pending ? balance - pending : 0;
        }

        if (excess == 0) revert NothingToWithdraw();

        if (_token == address(0)) {
            SafeTransferLib.safeTransferETH(_recipient, excess);
        } else {
            _token.safeTransfer(_recipient, excess);
        }

        emit ExcessWithdrawn(_token, excess, _recipient);
    }

    /* -------------------------------------------------------------------------- */
    /*                              User Functions                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim rewards for a specific token
    /// @param _token The token address to claim
    /// @return claimed The amount claimed
    function claim(address _token) external nonReentrant returns (uint256 claimed) {
        RewarderHubStorage storage $ = _storage();

        // Check if user is frozen
        if ($.frozen[msg.sender] != 0) revert UserIsFrozen();

        claimed = $.claimable[msg.sender][_token];
        if (claimed == 0) revert NothingToClaim();

        $.claimable[msg.sender][_token] = 0;
        $.pendingBalance[_token] -= claimed;

        _token.safeTransfer(msg.sender, claimed);

        emit RewardClaimed(msg.sender, _token, claimed);
    }

    /// @notice Claim rewards for multiple tokens
    /// @param _tokens Array of token addresses to claim
    function claimBatch(address[] calldata _tokens) external nonReentrant {
        RewarderHubStorage storage $ = _storage();

        // Check if user is frozen
        if ($.frozen[msg.sender] != 0) revert UserIsFrozen();

        // Claimable storage reference
        mapping(address token => uint256 amount) storage claimable = $.claimable[msg.sender];

        for (uint256 t; t < _tokens.length;) {
            address token = _tokens[t];
            uint256 amount = claimable[token];

            claimable[token] = 0;
            $.pendingBalance[token] -= amount;
            token.safeTransfer(msg.sender, amount);
            emit RewardClaimed(msg.sender, token, amount);

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

    /// @notice Get freeze information for a wallet
    /// @param _wallet The wallet address
    /// @return frozenAt Timestamp when wallet was frozen (0 if not frozen)
    /// @return canRecover Whether funds can be recovered (frozen for longer than FREEZE_DURATION)
    function getFreezeInfo(address _wallet) external view returns (uint256 frozenAt, bool canRecover) {
        frozenAt = _storage().frozen[_wallet];
        canRecover = frozenAt != 0 && block.timestamp >= frozenAt + FREEZE_DURATION;
    }

    /// @notice Get the total pending balance for a token (amount owed to users)
    /// @param _token The token address
    /// @return amount The total pending balance
    function getPendingBalance(address _token) external view returns (uint256 amount) {
        return _storage().pendingBalance[_token];
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Authorize upgrade - only UPGRADE_ROLE can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
