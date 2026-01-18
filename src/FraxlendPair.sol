// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================== FraxlendPair ============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FraxlendPairConstants} from "./FraxlendPairConstants.sol";
import {FraxlendPairCore} from "./FraxlendPairCore.sol";
import {Timelock2Step} from "./Timelock2Step.sol";
import {SafeERC20} from "./libraries/SafeERC20.sol";
import {VaultAccount, VaultAccountingLibrary} from "./libraries/VaultAccount.sol";
import {IRateCalculatorV2} from "./interfaces/IRateCalculatorV2.sol";

/// @title FraxlendPair
/// @author Drake Evans (Frax Finance) https://github.com/drakeevans
/// @notice  The FraxlendPair is a lending pair that allows users to engage in lending and borrowing activities
contract FraxlendPair is IERC20Metadata, FraxlendPairCore {
    using VaultAccountingLibrary for VaultAccount;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @param _configData abi.encode(address _asset, address _collateral, address _oracle, uint32 _maxOracleDeviation, address _rateContract, uint64 _fullUtilizationRate, uint256 _maxLTV, uint256 _cleanLiquidationFee, uint256 _dirtyLiquidationFee, uint256 _protocolLiquidationFee)
    /// @param _immutables abi.encode(address _circuitBreakerAddress, address _comptrollerAddress, address _timelockAddress)
    /// @param _customConfigData abi.encode(string memory _nameOfContract, string memory _symbolOfContract, uint8 _decimalsOfContract)
    constructor(bytes memory _configData, bytes memory _immutables, bytes memory _customConfigData)
        FraxlendPairCore(_configData, _immutables, _customConfigData)
    {}

    // ============================================================================================
    // ERC20 Metadata
    // ============================================================================================

    function name() public view override(ERC20, IERC20Metadata) returns (string memory) {
        return nameOfContract;
    }

    function symbol() public view override(ERC20, IERC20Metadata) returns (string memory) {
        return symbolOfContract;
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return decimalsOfContract;
    }

    // totalSupply for fToken ERC20 compatibility
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return totalAsset.shares;
    }

    // ============================================================================================
    // Functions: Helpers
    // ============================================================================================

    function asset() external view returns (address) {
        return address(assetContract);
    }

    /// @notice The ```toAssetAmount``` function converts a given number of shares to an asset amount
    /// @param _shares Shares of asset (fToken)
    /// @param _roundUp Whether to round up after division
    /// @param _previewInterest Whether to preview interest accrual before calculation
    /// @return _amount The amount of asset
    function toAssetAmount(uint256 _shares, bool _roundUp, bool _previewInterest)
        public
        view
        returns (uint256 _amount)
    {
        if (_previewInterest) {
            (,,,, VaultAccount memory _totalAsset,) = previewAddInterest();
            _amount = _totalAsset.toAmount(_shares, _roundUp);
        } else {
            _amount = totalAsset.toAmount(_shares, _roundUp);
        }
    }

    /// @notice The ```toAssetShares``` function converts a given asset amount to a number of asset shares (fTokens)
    /// @param _amount The amount of asset
    /// @param _roundUp Whether to round up after division
    /// @param _previewInterest Whether to preview interest accrual before calculation
    /// @return _shares The number of shares (fTokens)
    function toAssetShares(uint256 _amount, bool _roundUp, bool _previewInterest)
        public
        view
        returns (uint256 _shares)
    {
        if (_previewInterest) {
            (,,,, VaultAccount memory _totalAsset,) = previewAddInterest();
            _shares = _totalAsset.toShares(_amount, _roundUp);
        } else {
            _shares = totalAsset.toShares(_amount, _roundUp);
        }
    }

    function convertToAssets(uint256 _shares) external view returns (uint256 _assets) {
        _assets = toAssetAmount(_shares, false, true);
    }

    function convertToShares(uint256 _assets) external view returns (uint256 _shares) {
        _shares = toAssetShares(_assets, false, true);
    }

    function totalAssets() external view returns (uint256) {
        (,,,, VaultAccount memory _totalAsset,) = previewAddInterest();
        return _totalAsset.totalAmount(address(externalAssetVault));
    }

    function maxDeposit(address) public view returns (uint256 _maxAssets) {
        if (isDepositPaused) return 0;
        _maxAssets = type(uint256).max;
    }

    function maxMint(address) external view returns (uint256 _maxShares) {
        if (isDepositPaused) return 0;
        _maxShares = type(uint256).max;
    }

    function maxWithdraw(address _owner) external view returns (uint256 _maxAssets) {
        if (isWithdrawPaused) return 0;
        (,, uint256 _feesShare,, VaultAccount memory _totalAsset, VaultAccount memory _totalBorrow) =
            previewAddInterest();
        // Get the owner balance and include the fees share if owner is this contract
        uint256 _ownerBalance = _owner == address(this) ? balanceOf(_owner) + _feesShare : balanceOf(_owner);

        // Return the lower of total assets in contract or total assets available to _owner
        uint256 _totalAssetsAvailable = _totalAssetAvailable(_totalAsset, _totalBorrow, true);
        uint256 _totalUserWithdraw = _totalAsset.toAmount(_ownerBalance, false);
        uint256 _grossMaxAssets =
            _totalAssetsAvailable < _totalUserWithdraw ? _totalAssetsAvailable : _totalUserWithdraw;

        // Account for withdrawal fee to return net amount user would actually receive
        uint256 _effectiveFee = withdrawFee > 0 ? withdrawFee : MIN_TREASURY_FEE;
        _maxAssets = _grossMaxAssets - ((_grossMaxAssets * _effectiveFee) / FEE_PRECISION);
    }

    function maxRedeem(address _owner) external view returns (uint256 _maxShares) {
        if (isWithdrawPaused) return 0;
        (,, uint256 _feesShare,, VaultAccount memory _totalAsset, VaultAccount memory _totalBorrow) =
            previewAddInterest();

        // Calculate the total shares available
        uint256 _totalAssetsAvailable = _totalAssetAvailable(_totalAsset, _totalBorrow, true);
        uint256 _totalSharesAvailable = _totalAsset.toShares(_totalAssetsAvailable, false);

        // Get the owner balance and include the fees share if owner is this contract
        uint256 _ownerBalance = _owner == address(this) ? balanceOf(_owner) + _feesShare : balanceOf(_owner);
        _maxShares = _totalSharesAvailable < _ownerBalance ? _totalSharesAvailable : _ownerBalance;
    }

    // ============================================================================================
    // Functions: Configuration
    // ============================================================================================

    /// @notice The ```SetOracleInfo``` event is emitted when the oracle info (address and max deviation) is set
    /// @param oldOracle The old oracle address
    /// @param oldMaxOracleDeviation The old max oracle deviation
    /// @param newOracle The new oracle address
    /// @param newMaxOracleDeviation The new max oracle deviation
    event SetOracleInfo(
        address oldOracle, uint32 oldMaxOracleDeviation, address newOracle, uint32 newMaxOracleDeviation
    );

    /// @notice The ```setOracleInfo``` function sets the oracle data
    /// @param _newOracle The new oracle address
    /// @param _newMaxOracleDeviation The new max oracle deviation
    function setOracle(address _newOracle, uint32 _newMaxOracleDeviation) external {
        _requireTimelock();
        ExchangeRateInfo memory _exchangeRateInfo = exchangeRateInfo;
        emit SetOracleInfo(
            _exchangeRateInfo.oracle, _exchangeRateInfo.maxOracleDeviation, _newOracle, _newMaxOracleDeviation
        );
        _exchangeRateInfo.oracle = _newOracle;
        _exchangeRateInfo.maxOracleDeviation = _newMaxOracleDeviation;
        exchangeRateInfo = _exchangeRateInfo;
    }

    /// @notice The ```SetMaxLTV``` event is emitted when the max LTV is set
    /// @param oldMaxLTV The old max LTV
    /// @param newMaxLTV The new max LTV
    /// @param oldMaxBorrowLTV The old max borrow LTV
    /// @param newMaxBorrowLTV The new max borrow LTV
    event SetMaxLTV(uint256 oldMaxLTV, uint256 newMaxLTV, uint256 oldMaxBorrowLTV, uint256 newMaxBorrowLTV);

    /// @notice The ```setMaxLTV``` function sets the max LTV
    /// @param _newMaxLTV The new max LTV
    /// @param _newMaxBorrowLTV The new max borrow LTV
    function setMaxLTV(uint256 _newMaxLTV, uint256 _newMaxBorrowLTV) external {
        _requireTimelock();
        if (_newMaxLTV < _newMaxBorrowLTV) revert MaxBorrowLTVLargerThanMaxLTV();
        emit SetMaxLTV(maxLTV, _newMaxLTV, maxBorrowLTV, _newMaxBorrowLTV);
        maxLTV = _newMaxLTV;
        maxBorrowLTV = _newMaxBorrowLTV;
    }

    /// @notice The ```SetRateContract``` event is emitted when the rate contract is set
    /// @param oldRateContract The old rate contract
    /// @param newRateContract The new rate contract
    event SetRateContract(address oldRateContract, address newRateContract);

    /// @notice The ```setRateContract``` function sets the rate contract address
    /// @param _newRateContract The new rate contract address
    function setRateContract(address _newRateContract) external {
        _requireTimelock();
        emit SetRateContract(address(rateContract), _newRateContract);
        rateContract = IRateCalculatorV2(_newRateContract);
    }

    /// @notice The ```SetLiquidationFees``` event is emitted when the liquidation fees are set
    /// @param oldCleanLiquidationFee The old clean liquidation fee
    /// @param oldDirtyLiquidationFee The old dirty liquidation fee
    /// @param oldProtocolLiquidationFee The old protocol liquidation fee
    /// @param newCleanLiquidationFee The new clean liquidation fee
    /// @param newDirtyLiquidationFee The new dirty liquidation fee
    /// @param newProtocolLiquidationFee The new protocol liquidation fee
    event SetLiquidationFees(
        uint256 oldCleanLiquidationFee,
        uint256 oldDirtyLiquidationFee,
        uint256 oldProtocolLiquidationFee,
        uint256 newCleanLiquidationFee,
        uint256 newDirtyLiquidationFee,
        uint256 newProtocolLiquidationFee
    );

    /// @notice The ```setLiquidationFees``` function sets the liquidation fees
    /// @param _newCleanLiquidationFee The new clean liquidation fee
    /// @param _newDirtyLiquidationFee The new dirty liquidation fee
    /// @param _newProtocolLiquidationFee The new protocol liquidation fee
    /// @param _newMinCollateralRequiredOnDirtyLiquidation The new min collateral required to leave on dirty liquidation
    function setLiquidationFees(
        uint256 _newCleanLiquidationFee,
        uint256 _newDirtyLiquidationFee,
        uint256 _newProtocolLiquidationFee,
        uint256 _newMinCollateralRequiredOnDirtyLiquidation
    ) external {
        _requireTimelock();
        emit SetLiquidationFees(
            cleanLiquidationFee,
            dirtyLiquidationFee,
            protocolLiquidationFee,
            _newCleanLiquidationFee,
            _newDirtyLiquidationFee,
            _newProtocolLiquidationFee
        );
        cleanLiquidationFee = _newCleanLiquidationFee;
        dirtyLiquidationFee = _newDirtyLiquidationFee;
        protocolLiquidationFee = _newProtocolLiquidationFee;
        minCollateralRequiredOnDirtyLiquidation = _newMinCollateralRequiredOnDirtyLiquidation;
    }

    /// @notice The ```ChangeFee``` event first when the fee is changed
    /// @param newFee The new fee
    event ChangeFee(uint32 newFee);

    /// @notice The ```changeFee``` function changes the protocol fee, max 50%
    /// @param _newFee The new fee
    function changeFee(uint32 _newFee) external {
        _requireTimelock();
        if (isInterestPaused) revert InterestPaused();
        if (_newFee > MAX_PROTOCOL_FEE) {
            revert BadProtocolFee();
        }
        _addInterest();
        currentRateInfo.feeToProtocolRate = _newFee;
        emit ChangeFee(_newFee);
    }

    /// @notice The ```WithdrawFees``` event fires when the fees are withdrawn
    /// @param shares Number of shares (fTokens) redeemed
    /// @param recipient To whom the assets were sent
    /// @param amountToTransfer The amount of fees redeemed
    event WithdrawFees(uint128 shares, address recipient, uint256 amountToTransfer, uint256 collateralAmount);

    /// @notice The ```withdrawFees``` function withdraws fees accumulated
    /// @param _shares Number of fTokens to redeem
    /// @param _recipient Address to send the assets
    /// @return _amountToTransfer Amount of assets sent to recipient
    function withdrawFees(uint128 _shares, address _recipient) external onlyOwner returns (uint256 _amountToTransfer) {
        if (_recipient == address(0)) revert InvalidReceiver();

        // Grab some data from state to save gas
        VaultAccount memory _totalAsset = totalAsset;

        // Take all available if 0 value passed
        if (_shares == 0) _shares = balanceOf(address(this)).toUint128();

        // We must calculate this before we subtract from _totalAsset or invoke _burn
        _amountToTransfer = _totalAsset.toAmount(_shares, true);

        _approve(address(this), msg.sender, _shares);
        _redeem(_totalAsset, _amountToTransfer.toUint128(), _shares, _recipient, address(this), false);
        uint256 _collateralAmount = userCollateralBalance[address(this)];
        _removeCollateral(_collateralAmount, _recipient, address(this));
        emit WithdrawFees(_shares, _recipient, _amountToTransfer, _collateralAmount);
    }

    // ============================================================================================
    // Functions: Access Control
    // ============================================================================================

    /// @notice The ```pause``` function is called to pause all contract functionality
    function pause() external {
        _requireProtocolOrOwner();
        _pauseBorrow(true);
        _pauseDeposit(true);
        _pauseRepay(true);
        _pauseWithdraw(true);
        _pauseLiquidate(true);
        _addInterest();
        _pauseInterest(true);
    }

    /// @notice The ```unpause``` function is called to unpause all contract functionality
    function unpause() external {
        _requireTimelockOrOwner();
        _pauseBorrow(false);
        _pauseDeposit(false);
        _pauseRepay(false);
        _pauseWithdraw(false);
        _pauseLiquidate(false);
        _addInterest();
        _pauseInterest(false);
        currentRateInfo.lastTimestamp = uint64(block.timestamp);
    }

    event UpdatedMinURChange(uint256 newURChange);

    /// @notice The ```setMinURChangeForExternalAddInterest``` function sets the new minimum UR change for external add interest
    /// @param _newURChange The new rate change needed
    function setMinURChangeForExternalAddInterest(uint256 _newURChange) external {
        _requireTimelockOrOwner();
        if (_newURChange > UTIL_PREC) revert MinURChangeMax();
        minURChangeForExternalAddInterest = _newURChange;
        emit UpdatedMinURChange(_newURChange);
    }

    event SetOverBorrowAndLiquidateDelays(
        uint256 oldOverBorrowDelayAfterAddCollateral,
        uint256 newOverBorrowDelayAfterAddCollateral,
        uint256 oldLiquidateDelayAfterBorrow,
        uint256 newLiquidateDelayAfterBorrow
    );

    /// @notice The ```setOverBorrowAndLiquidateDelays``` function sets a few protocol delay configurations for over borrow and liquidation
    /// @param _overBorrowDelayAfterAddCollateral The new over borrow delay after adding collateral
    /// @param _liquidateDelayAfterBorrow The new liquidate delay after over borrowing
    function setOverBorrowAndLiquidateDelays(
        uint256 _overBorrowDelayAfterAddCollateral,
        uint256 _liquidateDelayAfterBorrow
    ) external {
        _requireTimelockOrOwner();
        emit SetOverBorrowAndLiquidateDelays(
            overBorrowDelayAfterAddCollateral,
            _overBorrowDelayAfterAddCollateral,
            liquidateDelayAfterBorrow,
            _liquidateDelayAfterBorrow
        );
        overBorrowDelayAfterAddCollateral = _overBorrowDelayAfterAddCollateral;
        liquidateDelayAfterBorrow = _liquidateDelayAfterBorrow;
    }

    // ============================================================================================
    // Functions: Peapods Whitelist Management
    // ============================================================================================

    /// @notice The ```setCBRBurnWhitelist``` function adds/removes an address from CBR burn whitelist
    /// @param _account The address to whitelist/remove
    /// @param _isWhitelisted Whether to whitelist or remove
    function setCBRBurnWhitelist(address _account, bool _isWhitelisted) external {
        _requireTimelockOrOwner();
        cbrBurnWhitelist[_account] = _isWhitelisted;
        emit SetCBRBurnWhitelist(_account, _isWhitelisted);
    }

    /// @notice The ```setWhitelistedBorrower``` function adds/removes an address from borrower whitelist
    /// @dev Whitelisted borrowers can bypass same-block overborrow protection
    /// @param _account The address to whitelist/remove
    /// @param _isWhitelisted Whether to whitelist or remove
    function setWhitelistedBorrower(address _account, bool _isWhitelisted) external {
        _requireTimelockOrOwner();
        whitelistedBorrowers[_account] = _isWhitelisted;
        emit SetWhitelistedBorrower(_account, _isWhitelisted);
    }
}
