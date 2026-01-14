// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

interface IFraxlendPair {
    struct CurrentRateInfo {
        uint32 lastBlock;
        uint32 feeToProtocolRate;
        uint64 lastTimestamp;
        uint64 ratePerSec;
        uint64 fullUtilizationRate;
    }

    struct ExchangeRateInfo {
        address oracle;
        uint32 maxOracleDeviation;
        uint184 lastTimestamp;
        uint256 lowExchangeRate;
        uint256 highExchangeRate;
    }

    struct VaultAccount {
        uint128 amount;
        uint128 shares;
    }

    // ERC20 functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);

    // ERC4626-like functions
    function asset() external view returns (address);
    function deposit(uint256 _amount, address _receiver) external returns (uint256 _sharesReceived);
    function mint(uint256 _shares, address _receiver) external returns (uint256 _amount);
    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _amountToReturn);
    function withdraw(uint256 _amount, address _receiver, address _owner) external returns (uint256 _sharesToBurn);
    function convertToAssets(uint256 _shares) external view returns (uint256 _assets);
    function convertToShares(uint256 _assets) external view returns (uint256 _shares);
    function maxDeposit(address _receiver) external view returns (uint256 _maxAssets);
    function maxMint(address _receiver) external view returns (uint256 _maxShares);
    function maxRedeem(address _owner) external view returns (uint256 _maxShares);
    function maxWithdraw(address _owner) external view returns (uint256 _maxAssets);
    function previewDeposit(uint256 _assets) external view returns (uint256 _sharesReceived);
    function previewMint(uint256 _shares) external view returns (uint256 _amount);
    function previewRedeem(uint256 _shares) external view returns (uint256 _assets);
    function previewWithdraw(uint256 _amount) external view returns (uint256 _sharesToBurn);
    function totalAssets() external view returns (uint256);

    // Ownership
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function renounceOwnership() external;
    function pendingOwner() external view returns (address);
    function acceptOwnership() external;

    // Timelock
    function timelockAddress() external view returns (address);
    function pendingTimelockAddress() external view returns (address);
    function transferTimelock(address _newTimelock) external;
    function acceptTransferTimelock() external;
    function renounceTimelock() external;

    // Core lending functions
    function addCollateral(uint256 _collateralAmount, address _borrower) external;
    function removeCollateral(uint256 _collateralAmount, address _receiver) external;
    function borrowAsset(uint256 _borrowAmount, uint256 _collateralAmount, address _receiver)
        external
        returns (uint256 _shares);
    function repayAsset(uint256 _shares, address _borrower) external returns (uint256 _amountToRepay);
    function liquidate(uint128 _sharesToLiquidate, uint256 _deadline, address _borrower)
        external
        returns (uint256 _collateralForLiquidator);

    // Interest
    function addInterest(bool _returnAccounting)
        external
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            CurrentRateInfo memory _currentRateInfo,
            VaultAccount memory _totalAsset,
            VaultAccount memory _totalBorrow
        );
    function previewAddInterest()
        external
        view
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            CurrentRateInfo memory _newCurrentRateInfo,
            VaultAccount memory _totalAsset,
            VaultAccount memory _totalBorrow
        );

    // Exchange rate
    function updateExchangeRate()
        external
        returns (bool _isBorrowAllowed, uint256 _lowExchangeRate, uint256 _highExchangeRate);

    // View functions - accounting
    function toAssetAmount(uint256 _shares, bool _roundUp, bool _previewInterest)
        external
        view
        returns (uint256 _amount);
    function toAssetShares(uint256 _amount, bool _roundUp, bool _previewInterest)
        external
        view
        returns (uint256 _shares);

    // Public state variables
    function DEPLOYER_ADDRESS() external view returns (address);
    function circuitBreakerAddress() external view returns (address);
    function collateralContract() external view returns (address);
    function currentRateInfo()
        external
        view
        returns (
            uint32 lastBlock,
            uint32 feeToProtocolRate,
            uint64 lastTimestamp,
            uint64 ratePerSec,
            uint64 fullUtilizationRate
        );
    function exchangeRateInfo()
        external
        view
        returns (
            address oracle,
            uint32 maxOracleDeviation,
            uint184 lastTimestamp,
            uint256 lowExchangeRate,
            uint256 highExchangeRate
        );
    function totalAsset() external view returns (uint128 amount, uint128 shares);
    function totalBorrow() external view returns (uint128 amount, uint128 shares);
    function totalCollateral() external view returns (uint256);
    function userBorrowShares(address) external view returns (uint256);
    function userCollateralBalance(address) external view returns (uint256);
    function rateContract() external view returns (address);
    function maxLTV() external view returns (uint256);
    function cleanLiquidationFee() external view returns (uint256);
    function dirtyLiquidationFee() external view returns (uint256);
    function protocolLiquidationFee() external view returns (uint256);

    // Pause state
    function isBorrowPaused() external view returns (bool);
    function isDepositPaused() external view returns (bool);
    function isRepayPaused() external view returns (bool);
    function isWithdrawPaused() external view returns (bool);
    function isLiquidatePaused() external view returns (bool);
    function isInterestPaused() external view returns (bool);

    // Admin functions
    function pause() external;
    function unpause() external;
    function setOracle(address _newOracle, uint32 _newMaxOracleDeviation) external;
    function setMaxLTV(uint256 _newMaxLTV, uint256 _newMaxBorrowLTV) external;
    function setRateContract(address _newRateContract) external;
    function setLiquidationFees(
        uint256 _newCleanLiquidationFee,
        uint256 _newDirtyLiquidationFee,
        uint256 _newProtocolLiquidationFee
    ) external;
    function changeFee(uint32 _newFee) external;
    function withdrawFees(uint128 _shares, address _recipient) external returns (uint256 _amountToTransfer);
    function setCircuitBreaker(address _newCircuitBreaker) external;

    // Flash loan
    function flashLoan(address _receiver, address _token, uint256 _amount, bytes calldata _data) external returns (bool);

    // Constants
    function LTV_PRECISION() external view returns (uint256);
    function LIQ_PRECISION() external view returns (uint256);
    function UTIL_PREC() external view returns (uint256);
    function FEE_PRECISION() external view returns (uint256);
    function EXCHANGE_PRECISION() external view returns (uint256);
    function DEVIATION_PRECISION() external view returns (uint256);
    function RATE_PRECISION() external view returns (uint256);
    function MAX_PROTOCOL_FEE() external view returns (uint256);

    // Whitelist
    function whitelistedBorrowers(address) external view returns (bool);
    function setWhitelistedBorrower(address _account, bool _isWhitelisted) external;

    // Collateral initialization (called by deployer after CREATE2 deployment)
    function setCollateral(address _collateral) external;
}
