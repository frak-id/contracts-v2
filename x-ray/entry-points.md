# Entry Point Map

> Frak Paywall | 25 entry points | 9 permissionless | 14 role-gated | 2 initializers

---

## Protocol Flow Paths

### Setup (Merchant / Owner)

`CampaignBankFactory.deployBank(owner[, salt])` → `CampaignBank.init()` ◄── one-shot, called by factory
        → `CampaignBank.setOpen(true)` → `CampaignBank.deposit(token, amount)` → `CampaignBank.updateAllowance(token, amount)` ◄── requires isOpen

### Reward Distribution (REWARDER_ROLE)

`[merchant setup above]` → `RewarderHub.pushReward(wallet, amount, token, bank, attestation)` ◄── requires bank allowance + balance
                                          └─→ `RewarderHub.batch(ops[])` ◄── aggregates by (bank, token)
        ⇒ credits `claimable[wallet][token]` + `pendingBalance[token]`, pulls `bank → hub`

### Claim (User — permissionless)

`[pushReward above]` → `RewarderHub.claim(token)` ◄── requires not frozen, claimable > 0
                              └─→ `RewarderHub.claimBatch(tokens[])`
        ⇒ transfers `hub → user`, zeroes claimable, decrements pendingBalance

### Compliance (COMPLIANCE_ROLE)

`RewarderHub.freezeUser(wallet)` → [60 days elapse] → `RewarderHub.recoverFrozenFunds(ops[], recipient)` ◄── requires frozen + FREEZE_DURATION passed
`RewarderHub.unfreezeUser(wallet)`  (reverses freeze, restarts clock)
`RewarderHub.withdrawExcess(token, recipient)` ◄── sweeps balance − pendingBalance

### Wind-down (Merchant / Owner)

`CampaignBank.setOpen(false)` → `CampaignBank.withdraw(token, amount, to)` ◄── requires !isOpen
`CampaignBank.revokeAllowance(token)` ◄── owner only, any state — the true outflow kill switch

### Smart-Wallet Auth (Account owner — self-scoped)

`MultiWebAuthNValidator.enable(initData)` → `addPassKey()` / `setPrimaryPassKey()` / `removePassKey()` → `validateUserOp()` (by EntryPoint/Kernel)

---

## Permissionless

### `RewarderHub.claim()`

| Aspect | Detail |
|--------|--------|
| Visibility | external, nonReentrant |
| Caller | User (reward recipient) |
| Parameters | `_token` (user-controlled) |
| Call chain | `→ SafeTransferLib.safeTransfer(token → msg.sender)` |
| State modified | `claimable[msg.sender][_token]=0`, `pendingBalance[_token]-=claimed` |
| Value flow | Tokens: Hub → msg.sender |
| Reentrancy guard | yes |

### `RewarderHub.claimBatch()`

| Aspect | Detail |
|--------|--------|
| Visibility | external, nonReentrant |
| Caller | User |
| Parameters | `_tokens[]` (user-controlled) |
| Call chain | `→ SafeTransferLib.safeTransfer(token → msg.sender)` per token |
| State modified | `claimable[msg.sender][token]=0`, `pendingBalance[token]-=amount` |
| Value flow | Tokens: Hub → msg.sender |
| Reentrancy guard | yes |

### `CampaignBankFactory.deployBank(address)` / `deployBank(address,bytes32)`

| Aspect | Detail |
|--------|--------|
| Visibility | external |
| Caller | Anyone (typically Frak backend / merchant) |
| Parameters | `_owner` (user-controlled), `_salt` (user-controlled) |
| Call chain | `→ LibClone.clone()/cloneDeterministic() → CampaignBank.init(_owner, REWARDER_HUB)` |
| State modified | new clone storage (owner, rewarderHub) |
| Value flow | None |
| Reentrancy guard | no |

### `MultiWebAuthNValidator.enable()` / `disable()` / `addPassKey()` / `removePassKey()` / `setPrimaryPassKey()`

| Aspect | Detail |
|--------|--------|
| Visibility | external/public (no modifier) — self-scoped to `msg.sender` storage |
| Caller | Smart account (the account being configured) |
| Parameters | `authenticatorId`, `x`, `y` (user-controlled); `enable` `_data` (user-controlled) |
| Call chain | writes `signerStorage[msg.sender]` only |
| State modified | `mainAuthenticatorIdHash`, `pubKeys[id]` for msg.sender |
| Value flow | None |
| Reentrancy guard | no |

### `MultiWebAuthNRecoveryAction.doAddPasskey()`

| Aspect | Detail |
|--------|--------|
| Visibility | public — intended for delegatecall as a Kernel recovery action |
| Caller | Kernel account (recovery flow) |
| Parameters | `authenticatorId`, `x`, `y` (user-controlled) |
| Call chain | `→ MultiWebAuthNValidatorV2.addPassKey()` |
| State modified | `pubKeys[id]` for the executing account |
| Value flow | None |
| Reentrancy guard | no |

---

## Role-Gated

### `REWARDER_ROLE` (on RewarderHub)

#### `RewarderHub.pushReward()`

| Aspect | Detail |
|--------|--------|
| Visibility | external, onlyRoles(REWARDER_ROLE), nonReentrant |
| Caller | Frak rewarder backend |
| Parameters | `_wallet` `_amount` `_token` `_bank` `_attestation` (all keeper-provided) |
| Call chain | `→ SafeTransferLib.safeTransferFrom(_bank → Hub)` |
| State modified | `claimable[_wallet][_token]+=`, `pendingBalance[_token]+=` |
| Value flow | Tokens: CampaignBank → Hub |
| Reentrancy guard | yes |

#### `RewarderHub.batch()`

| Aspect | Detail |
|--------|--------|
| Visibility | external, onlyRoles(REWARDER_ROLE), nonReentrant |
| Caller | Frak rewarder backend |
| Parameters | `_ops[]` (keeper-provided; ideally sorted by bank,token) |
| Call chain | `→ safeTransferFrom(bank → Hub)` per (bank,token) chunk |
| State modified | `claimable[wallet][token]+=`, `pendingBalance[token]+=` |
| Value flow | Tokens: CampaignBank(s) → Hub |
| Reentrancy guard | yes |

### `COMPLIANCE_ROLE` (on RewarderHub)

| Function | Visibility | Parameters | Value flow | State modified |
|----------|-----------|------------|------------|----------------|
| `freezeUser()` | external, onlyRoles | `_wallet` | none | `frozen[_wallet]=block.timestamp` |
| `unfreezeUser()` | external, onlyRoles | `_wallet` | none | `frozen[_wallet]=0` |
| `recoverFrozenFunds()` | external, onlyRoles, nonReentrant | `_ops[]`, `_recipient` | Hub → recipient | `claimable=0`, `pendingBalance-=`, transfer |
| `withdrawExcess()` | external, onlyRoles, nonReentrant | `_token`, `_recipient` | Hub → recipient | none (reads balance vs pending) |

### `CAMPAIGN_BANK_MANAGER_ROLE` or owner (on CampaignBank)

| Function | Visibility | Parameters | Value flow | State modified |
|----------|-----------|------------|------------|----------------|
| `setOpen()` | onlyRolesOrOwner | `_isOpen` | none | `isOpen` |
| `updateAllowance()` | onlyRolesOrOwner | `_token`,`_amount` | none | ERC20 approval (token→Hub) |
| `updateAllowances()` | onlyRolesOrOwner | `_tokens[]`,`_amounts[]` | none | ERC20 approvals |
| `deposit()` | onlyRolesOrOwner | `_token`,`_amount` | sender → Bank | none (token balance) |
| `withdraw()` | onlyRolesOrOwner | `_token`,`_amount`,`_to` | Bank → _to (only when closed) | none |

### owner-only (on CampaignBank)

| Function | Visibility | Parameters | Value flow | State modified |
|----------|-----------|------------|------------|----------------|
| `revokeAllowance()` | onlyOwner | `_token` | none | ERC20 approval → 0 |
| `revokeAllowances()` | onlyOwner | `_tokens[]` | none | ERC20 approvals → 0 |

### `MINTER_ROLE` (on mUSDToken)

| Function | Visibility | Parameters | Value flow | State modified |
|----------|-----------|------------|------------|----------------|
| `mint()` | public, onlyRoles | `_to`,`_amount` | mint → _to | `balanceOf`, `totalSupply` |

---

## Initialization

| Contract | Function | Access | Notes |
|----------|----------|--------|-------|
| RewarderHub | `init(address _owner)` | `initializer` | sets owner + grants UPGRADE_ROLE; UUPS proxy |
| CampaignBank | `init(address _owner, address _rewarderHub)` | `initializer` | called by factory on each clone; one-shot rewarderHub bind |

> Upgrade authorization: `RewarderHub._authorizeUpgrade()` — `onlyRoles(UPGRADE_ROLE)`.
