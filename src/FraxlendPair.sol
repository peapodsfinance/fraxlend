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

    function maxDeposit(address) public view returns (uint256) {
        return isDepositPaused ? 0 : type(uint256).max;
    }

    function maxMint(address) external view returns (uint256) {
        return isDepositPaused ? 0 : type(uint256).max;
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
        uint256 _effectiveFee = _effectiveWithdrawFee();
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

    event SetOracle(address oracle, uint32 maxDeviation);

    /// @notice Sets oracle data
    function setOracle(address _newOracle, uint32 _newMaxOracleDeviation) external {
        _requireTimelock();
        exchangeRateInfo.oracle = _newOracle;
        exchangeRateInfo.maxOracleDeviation = _newMaxOracleDeviation;
        emit SetOracle(_newOracle, _newMaxOracleDeviation);
    }

    event SetMaxLTV(uint256 maxLTV, uint256 maxBorrowLTV);

    /// @notice Sets max LTV values
    function setMaxLTV(uint256 _newMaxLTV, uint256 _newMaxBorrowLTV) external {
        _requireTimelock();
        if (_newMaxLTV < _newMaxBorrowLTV) revert MaxBorrowLTVLargerThanMaxLTV();
        maxLTV = _newMaxLTV;
        maxBorrowLTV = _newMaxBorrowLTV;
        emit SetMaxLTV(_newMaxLTV, _newMaxBorrowLTV);
    }

    event SetRateContract(address rateContract);

    /// @notice Sets rate contract address
    function setRateContract(address _newRateContract) external {
        _requireTimelock();
        rateContract = IRateCalculatorV2(_newRateContract);
        emit SetRateContract(_newRateContract);
    }

    event SetLiquidationFees(uint256 cleanFee, uint256 dirtyFee, uint256 protocolFee, uint256 minCollateral);

    /// @notice Sets liquidation fees
    function setLiquidationFees(uint256 _clean, uint256 _dirty, uint256 _protocol, uint256 _minCollateral) external {
        _requireTimelock();
        cleanLiquidationFee = _clean;
        dirtyLiquidationFee = _dirty;
        protocolLiquidationFee = _protocol;
        minCollateralRequiredOnDirtyLiquidation = _minCollateral;
        emit SetLiquidationFees(_clean, _dirty, _protocol, _minCollateral);
    }

    event ChangeFee(uint32 newFee);

    /// @notice Changes protocol fee, max 50%
    function changeFee(uint32 _newFee) external {
        _requireTimelock();
        if (isInterestPaused) revert InterestPaused();
        if (_newFee > MAX_PROTOCOL_FEE) revert BadProtocolFee();
        _addInterest();
        currentRateInfo.feeToProtocolRate = _newFee;
        emit ChangeFee(_newFee);
    }

    event WithdrawFees(uint128 shares, address recipient, uint256 amount, uint256 collateral);

    /// @notice Withdraws accumulated fees
    function withdrawFees(uint128 _shares, address _recipient) external onlyOwner returns (uint256 _amountToTransfer) {
        if (_recipient == address(0)) revert InvalidReceiver();
        VaultAccount memory _totalAsset = totalAsset;
        if (_shares == 0) _shares = balanceOf(address(this)).toUint128();
        _amountToTransfer = _totalAsset.toAmount(_shares, true);
        _approve(address(this), msg.sender, _shares);
        _redeem(_totalAsset, _amountToTransfer.toUint128(), _shares, _recipient, address(this), false);
        uint256 _collateral = userCollateralBalance[address(this)];
        _removeCollateral(_collateral, _recipient, address(this));
        emit WithdrawFees(_shares, _recipient, _amountToTransfer, _collateral);
    }

    // ============================================================================================
    // Functions: Access Control
    // ============================================================================================

    /// @notice The ```pause``` function is called to pause all contract functionality
    function pause() external {
        _requireProtocolOrOwner();
        _setPauseAll(true);
    }

    /// @notice The ```unpause``` function is called to unpause all contract functionality
    function unpause() external {
        _requireTimelockOrOwner();
        _setPauseAll(false);
        currentRateInfo.lastTimestamp = uint64(block.timestamp);
    }

    function _setPauseAll(bool _paused) internal {
        _pauseBorrow(_paused);
        _pauseDeposit(_paused);
        _pauseRepay(_paused);
        _pauseWithdraw(_paused);
        _pauseLiquidate(_paused);
        _addInterest();
        _pauseInterest(_paused);
    }

    event UpdatedMinURChange(uint256 newURChange);

    /// @notice Sets minimum UR change for external add interest
    function setMinURChangeForExternalAddInterest(uint256 _newURChange) external {
        _requireTimelockOrOwner();
        if (_newURChange > UTIL_PREC) revert MinURChangeMax();
        minURChangeForExternalAddInterest = _newURChange;
        emit UpdatedMinURChange(_newURChange);
    }

    event SetDelays(uint256 overBorrowDelay, uint256 liquidateDelay);

    /// @notice Sets delay configurations for over borrow and liquidation
    function setOverBorrowAndLiquidateDelays(uint256 _overBorrowDelay, uint256 _liquidateDelay) external {
        _requireTimelockOrOwner();
        overBorrowDelayAfterAddCollateral = _overBorrowDelay;
        liquidateDelayAfterBorrow = _liquidateDelay;
        emit SetDelays(_overBorrowDelay, _liquidateDelay);
    }

    // ============================================================================================
    // Functions: Peapods Whitelist Management
    // ============================================================================================

    /// @notice Adds/removes address from CBR burn whitelist
    function setCBRBurnWhitelist(address _account, bool _isWhitelisted) external {
        _requireTimelockOrOwner();
        cbrBurnWhitelist[_account] = _isWhitelisted;
        emit SetCBRBurnWhitelist(_account, _isWhitelisted);
    }

    /// @notice Adds/removes address from borrower whitelist
    function setWhitelistedBorrower(address _account, bool _isWhitelisted) external {
        _requireTimelockOrOwner();
        whitelistedBorrowers[_account] = _isWhitelisted;
        emit SetWhitelistedBorrower(_account, _isWhitelisted);
    }
}
