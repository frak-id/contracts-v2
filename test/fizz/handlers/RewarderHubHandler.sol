// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../Base.sol";
import {Properties} from "../Properties.sol";

/// @notice Handles the interaction with RewarderHub
/// @dev `admin` holds REWARDER_ROLE + COMPLIANCE_ROLE, so push/batch/freeze/recover use `asAdmin`.
///      Claims are user actions, so they use `asActor`.
abstract contract RewarderHubHandler is Properties {
    // ――――――――――――――――――――――――― Clamped ――――――――――――――――――――――――――

    /// @notice Push a reward from the merchant bank to an actor wallet, bounded by what the bank can supply.
    function rewarderHub_pushReward_clamped(address _wallet, uint256 _amount, uint256 tokenSeed) public {
        address _token = toToken(tokenSeed);
        uint256 pullable = _pullable(_token);
        if (pullable == 0) return;
        _amount = clampBetween(_amount, 1, pullable);
        rewarderHub_pushReward(_wallet, _amount, _token, address(bank), "");
    }

    /// @notice Push a batch of rewards (single bank, single token) to actor wallets.
    function rewarderHub_batch_clamped(uint256 tokenSeed, uint256 seedA, uint256 seedB, uint256 seedC) public {
        address _token = toToken(tokenSeed);
        uint256 pullable = _pullable(_token);
        if (pullable < 3) return;

        // Split the pullable budget across 3 ops so the aggregated transfer stays valid.
        uint256 each = clampBetween(seedA, 1, pullable / 3);
        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = RewardOp({wallet: toActor(address(uint160(seedA))), amount: each, token: _token, bank: address(bank), attestation: ""});
        ops[1] = RewardOp({wallet: toActor(address(uint160(seedB))), amount: each, token: _token, bank: address(bank), attestation: ""});
        ops[2] = RewardOp({wallet: toActor(address(uint160(seedC))), amount: each, token: _token, bank: address(bank), attestation: ""});
        rewarderHub_batch(ops);
    }

    /// @notice Claim a single registered token for the current actor, then assert SP-01.
    function rewarderHub_claim_clamped(uint256 tokenSeed) public {
        address tkn = toToken(tokenSeed);
        uint256 claimableBefore = hub.getClaimable(actor, tkn);
        uint256 balBefore = tokenBalanceOf(tkn, actor);
        rewarderHub_claim(tkn);
        // Only a successful, non-reverting claim reaches here; assert settlement correctness.
        if (claimableBefore > 0) {
            _prop_claimSettles(actor, tkn, balBefore, claimableBefore);
        }
    }

    /// @notice Claim all registered tokens for the current actor.
    function rewarderHub_claimAll() public {
        rewarderHub_claimBatch(tokens);
    }

    /// @notice Freeze an actor, advance past FREEZE_DURATION, then recover their funds — covers the full recovery path.
    function rewarderHub_freezeWarpRecover(address _wallet, uint256 tokenSeed) public {
        address w = toActor(_wallet);
        address _token = toToken(tokenSeed);

        (uint256 frozenAt,) = hub.getFreezeInfo(w);
        if (frozenAt == 0) {
            vm.prank(admin);
            hub.freezeUser(w);
        }
        skipTime(hub.FREEZE_DURATION() + 1);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: w, token: _token});
        vm.prank(admin);
        hub.recoverFrozenFunds(ops, admin);
    }

    /// @notice Donate tokens straight into the hub to create withdrawable excess.
    function rewarderHub_donateERC20(uint256 tokenSeed, uint256 _amount) public {
        address _token = toToken(tokenSeed);
        uint256 bal = tokenBalanceOf(_token, actor);
        if (bal == 0) return;
        _amount = clampBetween(_amount, 1, bal);
        vm.prank(actor);
        (bool ok,) = _token.call(abi.encodeWithSignature("transfer(address,uint256)", address(hub), _amount));
        ok; // ignore return; donation is best-effort
    }

    /// @notice Dispatcher for lower-frequency compliance actions.
    function rewarderHub_secondary(uint8 selector, address _wallet, uint256 tokenSeed) public {
        selector = uint8(selector % 4);
        address w = toActor(_wallet);
        address _token = toToken(tokenSeed);
        if (selector == 0) {
            _rewarderHub_freezeUser(w);
        } else if (selector == 1) {
            _rewarderHub_unfreezeUser(w);
        } else if (selector == 2) {
            FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
            ops[0] = FrozenFundsRecoverOp({wallet: w, token: _token});
            _rewarderHub_recoverFrozenFunds(ops, admin);
        } else {
            _rewarderHub_withdrawExcess(_token, admin);
        }
    }

    // ―――――――――――――――――――――――― Unclamped ―――――――――――――――――――――――――

    function rewarderHub_pushReward(address _wallet, uint256 _amount, address _token, address _bank, bytes memory _attestation)
        public
        asAdmin
    {
        // Bound credited wallets to the actor set so conservation/solvency properties stay enumerable.
        hub.pushReward(toActor(_wallet), _amount, _token, _bank, _attestation);
    }

    function rewarderHub_batch(RewardOp[] memory _ops) public asAdmin {
        for (uint256 i; i < _ops.length; i++) {
            _ops[i].wallet = toActor(_ops[i].wallet);
        }
        hub.batch(_ops);
    }

    function rewarderHub_claim(address _token) public asActor {
        hub.claim(_token);
    }

    function rewarderHub_claimBatch(address[] memory _tokens) public asActor {
        hub.claimBatch(_tokens);
    }

    function _rewarderHub_freezeUser(address _wallet) internal asAdmin {
        hub.freezeUser(_wallet);
    }

    function _rewarderHub_unfreezeUser(address _wallet) internal asAdmin {
        hub.unfreezeUser(_wallet);
    }

    function _rewarderHub_recoverFrozenFunds(FrozenFundsRecoverOp[] memory _ops, address _recipient) internal asAdmin {
        hub.recoverFrozenFunds(_ops, _recipient);
    }

    function _rewarderHub_withdrawExcess(address _token, address _recipient) internal asAdmin {
        hub.withdrawExcess(_token, _recipient);
    }

    // ――――――――――――――――――――――――― Helpers ―――――――――――――――――――――――――

    /// @dev Maximum amount the hub can pull from the bank for a token = min(bank balance, hub allowance).
    function _pullable(address _token) internal view returns (uint256) {
        uint256 bal = tokenBalanceOf(_token, address(bank));
        uint256 allowed = bank.getAllowance(_token);
        return bal < allowed ? bal : allowed;
    }
}
