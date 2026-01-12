# FraxlendPair

The FraxlendPair is a lending pair that allows users to engage in lending and borrowing activities. It implements ERC20 for fTokens (lender shares) and ERC4626-like vault functionality.

## ERC20 Metadata

### name

```solidity
function name() public view returns (string memory)
```

Returns the name of the fToken.

### symbol

```solidity
function symbol() public view returns (string memory)
```

Returns the symbol of the fToken.

### decimals

```solidity
function decimals() public view returns (uint8)
```

Returns the decimals of the fToken.

### totalSupply

```solidity
function totalSupply() public view returns (uint256)
```

Returns the total supply of fTokens (total asset shares).

## ERC4626-like Functions

### asset

```solidity
function asset() external view returns (address)
```

Returns the address of the underlying asset token.

### toAssetAmount

```solidity
function toAssetAmount(uint256 _shares, bool _roundUp, bool _previewInterest) public view returns (uint256 _amount)
```

Converts a given number of shares to an asset amount.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint256 | Shares of asset (fToken) |
| _roundUp | bool | Whether to round up after division |
| _previewInterest | bool | Whether to preview interest accrual before calculation |

### toAssetShares

```solidity
function toAssetShares(uint256 _amount, bool _roundUp, bool _previewInterest) public view returns (uint256 _shares)
```

Converts a given asset amount to a number of asset shares (fTokens).

| Param | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of asset |
| _roundUp | bool | Whether to round up after division |
| _previewInterest | bool | Whether to preview interest accrual before calculation |

### convertToAssets

```solidity
function convertToAssets(uint256 _shares) external view returns (uint256 _assets)
```

Converts shares to assets (ERC4626 compliant).

### convertToShares

```solidity
function convertToShares(uint256 _assets) external view returns (uint256 _shares)
```

Converts assets to shares (ERC4626 compliant).

### totalAssets

```solidity
function totalAssets() external view returns (uint256)
```

Returns the total assets managed by the vault, including external vault assets.

### maxDeposit

```solidity
function maxDeposit(address) public view returns (uint256 _maxAssets)
```

Returns the maximum amount of assets that can be deposited. Returns 0 if deposits are paused.

### maxMint

```solidity
function maxMint(address) external view returns (uint256 _maxShares)
```

Returns the maximum amount of shares that can be minted. Returns 0 if deposits are paused.

### maxWithdraw

```solidity
function maxWithdraw(address _owner) external view returns (uint256 _maxAssets)
```

Returns the maximum amount of assets that can be withdrawn by the owner.

### maxRedeem

```solidity
function maxRedeem(address _owner) external view returns (uint256 _maxShares)
```

Returns the maximum amount of shares that can be redeemed by the owner.

### previewDeposit

```solidity
function previewDeposit(uint256 _assets) external view returns (uint256 _sharesReceived)
```

Previews the number of shares that would be received for a deposit.

### previewMint

```solidity
function previewMint(uint256 _shares) external view returns (uint256 _amount)
```

Previews the amount of assets needed to mint a given number of shares.

### previewRedeem

```solidity
function previewRedeem(uint256 _shares) external view returns (uint256 _assets)
```

Previews the amount of assets that would be received for redeeming shares.

### previewWithdraw

```solidity
function previewWithdraw(uint256 _amount) external view returns (uint256 _sharesToBurn)
```

Previews the number of shares that would be burned for a withdrawal.

### deposit

```solidity
function deposit(uint256 _amount, address _receiver) external returns (uint256 _sharesReceived)
```

Deposits assets and mints fTokens to the receiver.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of Asset Token to transfer |
| _receiver | address | The address to receive the fTokens |

### mint

```solidity
function mint(uint256 _shares, address _receiver) external returns (uint256 _amount)
```

Mints a specific number of fTokens to the receiver.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint256 | The number of fTokens to mint |
| _receiver | address | The address to receive the fTokens |

### redeem

```solidity
function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _amountToReturn)
```

Redeems fTokens for underlying assets.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint256 | The number of fTokens to redeem |
| _receiver | address | The address to receive the assets |
| _owner | address | The owner of the fTokens |

### withdraw

```solidity
function withdraw(uint256 _amount, address _receiver, address _owner) external returns (uint256 _sharesToBurn)
```

Withdraws a specific amount of assets.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount to withdraw |
| _receiver | address | The address to receive the assets |
| _owner | address | The owner of the fTokens |

## Core Lending Functions

### addCollateral

```solidity
function addCollateral(uint256 _collateralAmount, address _borrower) external
```

Adds collateral to a borrower's position.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _collateralAmount | uint256 | The amount of Collateral Token to add |
| _borrower | address | The account to be credited |

### removeCollateral

```solidity
function removeCollateral(uint256 _collateralAmount, address _receiver) external
```

Removes collateral from msg.sender's borrow position.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _collateralAmount | uint256 | The amount of Collateral Token to transfer |
| _receiver | address | The address to receive the transferred funds |

### borrowAsset

```solidity
function borrowAsset(uint256 _borrowAmount, uint256 _collateralAmount, address _receiver) external returns (uint256 _shares)
```

Allows a user to open/increase a borrow position.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _borrowAmount | uint256 | The amount of Asset Token to borrow |
| _collateralAmount | uint256 | The amount of Collateral Token to transfer |
| _receiver | address | The address to receive the Asset Tokens |

### repayAsset

```solidity
function repayAsset(uint256 _shares, address _borrower) external returns (uint256 _amountToRepay)
```

Allows the caller to pay down the debt for a given borrower.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint256 | The number of Borrow Shares to repay |
| _borrower | address | The account for which the debt will be reduced |

### liquidate

```solidity
function liquidate(uint128 _sharesToLiquidate, uint256 _deadline, address _borrower) external returns (uint256 _collateralForLiquidator)
```

Allows a third party to repay a borrower's debt when they become insolvent and receive collateral in return.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _sharesToLiquidate | uint128 | The number of Borrow Shares to repay |
| _deadline | uint256 | The Unix timestamp after which the transaction will revert |
| _borrower | address | The address of the insolvent borrower |

## Interest Functions

### addInterest

```solidity
function addInterest(bool _returnAccounting) external returns (uint256 _interestEarned, uint256 _feesAmount, uint256 _feesShare, CurrentRateInfo memory _currentRateInfo, VaultAccount memory _totalAsset, VaultAccount memory _totalBorrow)
```

Public implementation of interest accrual, allows 3rd parties to trigger interest accrual.

### previewAddInterest

```solidity
function previewAddInterest() public view returns (uint256 _interestEarned, uint256 _feesAmount, uint256 _feesShare, CurrentRateInfo memory _newCurrentRateInfo, VaultAccount memory _totalAsset, VaultAccount memory _totalBorrow)
```

Previews interest accrual without modifying state.

## Exchange Rate Functions

### updateExchangeRate

```solidity
function updateExchangeRate() external returns (bool _isBorrowAllowed, uint256 _lowExchangeRate, uint256 _highExchangeRate)
```

Updates the exchange rate from the oracle.

## CBR Burn Function

### burnForCBR

```solidity
function burnForCBR(uint256 _shares) external returns (uint256 _assetsValue)
```

Burns shares owned by msg.sender to improve CBR (Collateral Backing Ratio) for all remaining holders. Only callable by whitelisted addresses.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint256 | The number of shares to burn |

## Flash Loan

### flashLoan

```solidity
function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data) external returns (bool)
```

Provides ERC-3156 compliant flash loans for local assets only.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _receiver | IERC3156FlashBorrower | The address that will receive the flash loan |
| _token | address | The token address to flash loan (must be the asset token) |
| _amount | uint256 | The amount of tokens to flash loan |
| _data | bytes | Arbitrary data to pass to the receiver's callback |

## Admin Functions

### setOracle

```solidity
function setOracle(address _newOracle, uint32 _newMaxOracleDeviation) external
```

Sets the oracle data. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newOracle | address | The new oracle address |
| _newMaxOracleDeviation | uint32 | The new max oracle deviation |

### setMaxLTV

```solidity
function setMaxLTV(uint256 _newMaxLTV, uint256 _newMaxBorrowLTV) external
```

Sets the max LTV values. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newMaxLTV | uint256 | The new max LTV (liquidation threshold) |
| _newMaxBorrowLTV | uint256 | The new max borrow LTV |

### setRateContract

```solidity
function setRateContract(address _newRateContract) external
```

Sets the rate contract address. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newRateContract | address | The new rate contract address |

### setLiquidationFees

```solidity
function setLiquidationFees(uint256 _newCleanLiquidationFee, uint256 _newDirtyLiquidationFee, uint256 _newProtocolLiquidationFee, uint256 _newMinCollateralRequiredOnDirtyLiquidation) external
```

Sets the liquidation fees. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newCleanLiquidationFee | uint256 | The new clean liquidation fee |
| _newDirtyLiquidationFee | uint256 | The new dirty liquidation fee |
| _newProtocolLiquidationFee | uint256 | The new protocol liquidation fee |
| _newMinCollateralRequiredOnDirtyLiquidation | uint256 | The new min collateral required on dirty liquidation |

### changeFee

```solidity
function changeFee(uint32 _newFee) external
```

Changes the protocol fee, max 50%. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newFee | uint32 | The new fee |

### withdrawFees

```solidity
function withdrawFees(uint128 _shares, address _recipient) external returns (uint256 _amountToTransfer)
```

Withdraws fees accumulated. Requires owner.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _shares | uint128 | Number of fTokens to redeem (0 for all) |
| _recipient | address | Address to send the assets |

### pause

```solidity
function pause() external
```

Pauses all contract functionality. Requires protocol, owner, or deployer.

### unpause

```solidity
function unpause() external
```

Unpauses all contract functionality. Requires timelock or owner.

### setMinURChangeForExternalAddInterest

```solidity
function setMinURChangeForExternalAddInterest(uint256 _newURChange) external
```

Sets the minimum utilization rate change for external add interest. Requires timelock or owner.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newURChange | uint256 | The new rate change needed |

### setOverBorrowAndLiquidateDelays

```solidity
function setOverBorrowAndLiquidateDelays(uint256 _overBorrowDelayAfterAddCollateral, uint256 _liquidateDelayAfterBorrow) external
```

Sets delay parameters for overborrow and liquidation protection. Requires timelock or owner.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _overBorrowDelayAfterAddCollateral | uint256 | The new over borrow delay after adding collateral |
| _liquidateDelayAfterBorrow | uint256 | The new liquidate delay after borrowing |

### setCBRBurnWhitelist

```solidity
function setCBRBurnWhitelist(address _account, bool _isWhitelisted) external
```

Adds/removes an address from CBR burn whitelist. Requires timelock or owner.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The address to whitelist/remove |
| _isWhitelisted | bool | Whether to whitelist or remove |

### setWhitelistedBorrower

```solidity
function setWhitelistedBorrower(address _account, bool _isWhitelisted) external
```

Adds/removes an address from borrower whitelist. Whitelisted borrowers can bypass same-block overborrow protection. Requires timelock or owner.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The address to whitelist/remove |
| _isWhitelisted | bool | Whether to whitelist or remove |

### setExternalAssetVault

```solidity
function setExternalAssetVault(IERC4626Extended vault) external
```

Sets the external asset vault for the pair. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| vault | IERC4626Extended | The new external asset vault |

### setCircuitBreaker

```solidity
function setCircuitBreaker(address _newCircuitBreaker) external
```

Sets the circuit breaker address. Requires timelock.

| Param | Type | Description |
| ---- | ---- | ----------- |
| _newCircuitBreaker | address | The new circuit breaker address |

## Events

### Deposit

```solidity
event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares)
```

### Withdraw

```solidity
event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)
```

### AddCollateral

```solidity
event AddCollateral(address indexed sender, address indexed borrower, uint256 collateralAmount)
```

### RemoveCollateral

```solidity
event RemoveCollateral(address indexed _sender, uint256 _collateralAmount, address indexed _receiver, address indexed _borrower)
```

### BorrowAsset

```solidity
event BorrowAsset(address indexed _borrower, address indexed _receiver, uint256 _borrowAmount, uint256 _sharesAdded)
```

### RepayAsset

```solidity
event RepayAsset(address indexed payer, address indexed borrower, uint256 amountToRepay, uint256 shares)
```

### Liquidate

```solidity
event Liquidate(address indexed _borrower, uint256 _collateralForLiquidator, uint256 _sharesToLiquidate, uint256 _amountLiquidatorToRepay, uint256 _feesAmount, uint256 _sharesToAdjust, uint256 _amountToAdjust)
```

### AddInterest

```solidity
event AddInterest(uint256 interestEarned, uint256 rate, uint256 feesAmount, uint256 feesShare)
```

### UpdateRate

```solidity
event UpdateRate(uint256 oldRatePerSec, uint256 oldFullUtilizationRate, uint256 newRatePerSec, uint256 newFullUtilizationRate)
```

### UpdateExchangeRate

```solidity
event UpdateExchangeRate(uint256 lowExchangeRate, uint256 highExchangeRate)
```

### ChangeFee

```solidity
event ChangeFee(uint32 newFee)
```

### WithdrawFees

```solidity
event WithdrawFees(uint128 shares, address recipient, uint256 amountToTransfer, uint256 collateralAmount)
```

### SetOracleInfo

```solidity
event SetOracleInfo(address oldOracle, uint32 oldMaxOracleDeviation, address newOracle, uint32 newMaxOracleDeviation)
```

### SetMaxLTV

```solidity
event SetMaxLTV(uint256 oldMaxLTV, uint256 newMaxLTV, uint256 oldMaxBorrowLTV, uint256 newMaxBorrowLTV)
```

### SetRateContract

```solidity
event SetRateContract(address oldRateContract, address newRateContract)
```

### SetLiquidationFees

```solidity
event SetLiquidationFees(uint256 oldCleanLiquidationFee, uint256 oldDirtyLiquidationFee, uint256 oldProtocolLiquidationFee, uint256 newCleanLiquidationFee, uint256 newDirtyLiquidationFee, uint256 newProtocolLiquidationFee)
```

### CBRBurn

```solidity
event CBRBurn(address indexed burner, uint256 sharesBurned, uint256 assetsValue)
```

### SetCBRBurnWhitelist

```solidity
event SetCBRBurnWhitelist(address indexed account, bool isWhitelisted)
```

### SetWhitelistedBorrower

```solidity
event SetWhitelistedBorrower(address indexed account, bool isWhitelisted)
```

### FlashLoan

```solidity
event FlashLoan(address indexed receiver, uint256 amount, uint256 fee)
```

## Public State Variables

- `collateralContract` - The collateral token contract
- `totalAsset` - Total asset amount and shares (VaultAccount)
- `totalBorrow` - Total borrow amount and shares (VaultAccount)
- `totalCollateral` - Total collateral in the contract
- `userCollateralBalance(address)` - Collateral balance for each user
- `userBorrowShares(address)` - Borrow shares for each user
- `currentRateInfo` - Current interest rate information
- `exchangeRateInfo` - Current exchange rate information
- `rateContract` - Interest rate calculator contract
- `maxLTV` - Maximum LTV before liquidation
- `maxBorrowLTV` - Maximum LTV for borrowing
- `cleanLiquidationFee` - Fee for full liquidations
- `dirtyLiquidationFee` - Fee for partial liquidations
- `protocolLiquidationFee` - Protocol's share of liquidation fees
- `depositFee` - Fee charged on deposits (immutable)
- `withdrawFee` - Fee charged on withdrawals (immutable)
- `isBorrowPaused` - Whether borrowing is paused
- `isDepositPaused` - Whether deposits are paused
- `isRepayPaused` - Whether repayments are paused
- `isWithdrawPaused` - Whether withdrawals are paused
- `isLiquidatePaused` - Whether liquidations are paused
- `isInterestPaused` - Whether interest accrual is paused
- `whitelistedBorrowers(address)` - Addresses that can bypass overborrow protection
- `cbrBurnWhitelist(address)` - Addresses authorized to burn for CBR improvement

## Constants

- `LTV_PRECISION` - Precision for LTV calculations (1e5)
- `LIQ_PRECISION` - Precision for liquidation fee calculations (1e5)
- `UTIL_PREC` - Precision for utilization rate calculations (1e5)
- `FEE_PRECISION` - Precision for fee calculations (1e5)
- `EXCHANGE_PRECISION` - Precision for exchange rate calculations (1e18)
- `DEVIATION_PRECISION` - Precision for oracle deviation calculations (1e5)
- `RATE_PRECISION` - Precision for interest rate calculations (1e18)
- `MAX_PROTOCOL_FEE` - Maximum protocol fee (5e4 = 50%)
