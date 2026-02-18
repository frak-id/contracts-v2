// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {REWARDER_ROLE} from "src/constants/Roles.sol";
import {RewardOp, RewarderHub} from "src/reward/RewarderHub.sol";
import {ERC1967Proxy} from
    "lib/FreshCryptoLib/solidity/tests/WebAuthn_forge/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title RewarderHubHandler
/// @notice Handler contract that exposes bounded actions for invariant testing
contract RewarderHubHandler is Test {
    RewarderHub public hub;
    MockErc20 public token;
    address public bank;
    address public rewarder;

    address[] public wallets;
    mapping(address => uint256) public ghostClaimable;
    uint256 public ghostPendingBalance;

    uint256 public pushCount;
    uint256 public claimCount;

    bytes internal constant _ATTESTATION = "invariant-attestation";

    constructor(RewarderHub _hub, MockErc20 _token, address _bank, address _rewarder) {
        hub = _hub;
        token = _token;
        bank = _bank;
        rewarder = _rewarder;

        wallets.push(makeAddr("wallet1"));
        wallets.push(makeAddr("wallet2"));
        wallets.push(makeAddr("wallet3"));
        wallets.push(makeAddr("wallet4"));
        wallets.push(makeAddr("wallet5"));
    }

    function walletsLength() external view returns (uint256) {
        return wallets.length;
    }

    function pushReward(uint256 walletSeed, uint256 amount) external {
        address wallet = wallets[walletSeed % wallets.length];
        uint256 boundedAmount = bound(amount, 1, 10_000e18);

        vm.prank(rewarder);
        hub.pushReward(wallet, boundedAmount, address(token), bank, _ATTESTATION);

        ghostClaimable[wallet] += boundedAmount;
        ghostPendingBalance += boundedAmount;
        pushCount++;
    }

    function batch(uint256 walletSeed1, uint256 walletSeed2, uint256 amount1, uint256 amount2) external {
        address wallet1 = wallets[walletSeed1 % wallets.length];
        address wallet2 = wallets[walletSeed2 % wallets.length];
        uint256 boundedAmount1 = bound(amount1, 1, 10_000e18);
        uint256 boundedAmount2 = bound(amount2, 1, 10_000e18);

        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = RewardOp({
            wallet: wallet1,
            amount: boundedAmount1,
            token: address(token),
            bank: bank,
            attestation: _ATTESTATION
        });
        ops[1] = RewardOp({
            wallet: wallet2,
            amount: boundedAmount2,
            token: address(token),
            bank: bank,
            attestation: _ATTESTATION
        });

        vm.prank(rewarder);
        hub.batch(ops);

        ghostClaimable[wallet1] += boundedAmount1;
        ghostClaimable[wallet2] += boundedAmount2;
        ghostPendingBalance += boundedAmount1 + boundedAmount2;
        pushCount += 2;
    }

    function claim(uint256 walletSeed) external {
        address wallet = wallets[walletSeed % wallets.length];
        uint256 amount = hub.getClaimable(wallet, address(token));
        if (amount == 0) return;

        vm.prank(wallet);
        hub.claim(address(token));

        ghostClaimable[wallet] = 0;
        ghostPendingBalance -= amount;
        claimCount++;
    }
}

/// @title RewarderHubInvariantTest
/// @notice Invariant tests verifying pendingBalance == Σ claimable across all state transitions
contract RewarderHubInvariantTest is StdInvariant, Test {
    RewarderHub public hub;
    RewarderHubHandler public handler;
    MockErc20 public token;

    address public owner = makeAddr("owner");
    address public rewarder = makeAddr("rewarder");
    address public bank = makeAddr("bank");

    function setUp() public {
        RewarderHub implementation = new RewarderHub();
        bytes memory initData = abi.encodeCall(RewarderHub.init, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        hub = RewarderHub(address(proxy));

        vm.prank(owner);
        hub.grantRoles(rewarder, REWARDER_ROLE);

        token = new MockErc20();
        token.mint(bank, type(uint128).max);

        vm.prank(bank);
        token.approve(address(hub), type(uint256).max);

        handler = new RewarderHubHandler(hub, token, bank, rewarder);
        targetContract(address(handler));
    }

    /// @dev Core invariant: pendingBalance must equal sum of all claimable amounts
    function invariant_pendingBalanceEqualsClaimableSum() public view {
        uint256 totalClaimable;
        uint256 length = handler.walletsLength();

        for (uint256 i; i < length;) {
            address wallet = handler.wallets(i);
            totalClaimable += hub.getClaimable(wallet, address(token));

            unchecked {
                ++i;
            }
        }

        assertEq(hub.getPendingBalance(address(token)), totalClaimable);
    }

    /// @dev Token balance invariant: hub balance >= pendingBalance
    function invariant_hubBalanceCoversObligations() public view {
        assertGe(token.balanceOf(address(hub)), hub.getPendingBalance(address(token)));
    }

    /// @dev After all operations, pending balance should never be negative (underflow protected)
    function invariant_pendingBalanceNonNegative() public view {
        // getPendingBalance returns uint256, so this checks it's a valid non-underflowed value
        // by ensuring it doesn't exceed the total supply minted to the bank
        assertLe(hub.getPendingBalance(address(token)), type(uint128).max);
    }
}
