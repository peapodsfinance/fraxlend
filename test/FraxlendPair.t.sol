// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FraxlendPair} from "../src/FraxlendPair.sol";
import {FraxlendPairCore} from "../src/FraxlendPairCore.sol";
import {IRateCalculatorV2} from "../src/interfaces/IRateCalculatorV2.sol";

/// @title Mock ERC20 Token for testing
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

/// @title Mock Oracle for testing
contract MockOracle {
    uint256 public price;

    constructor(uint256 _price) {
        price = _price;
    }

    function getPrices() external view returns (bool _isBadData, uint256 _priceLow, uint256 _priceHigh) {
        return (false, price, price);
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }
}

/// @title Mock Rate Calculator for testing
contract MockRateCalculator is IRateCalculatorV2 {
    function name() external pure returns (string memory) {
        return "MockRateCalculator";
    }

    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (1, 0, 0);
    }

    function getNewRate(uint256, uint256, uint64 _maxInterest)
        external
        pure
        returns (uint64 _newRatePerSec, uint64 _newMaxInterest)
    {
        return (0, _maxInterest); // Zero interest for simplicity
    }
}

/// @title Tests for FraxlendPair
contract FraxlendPairTest is Test {
    FraxlendPair public pair;
    MockERC20 public asset;
    MockERC20 public collateral;
    MockOracle public oracle;
    MockRateCalculator public rateCalculator;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public timelock = address(0x3);
    address public circuitBreaker = address(0x4);
    address public comptroller = address(0x5);

    uint256 public constant FEE_PRECISION = 1e5;
    uint256 public constant MIN_TREASURY_FEE = 10; // 0.01%
    uint256 public constant INITIAL_DEPOSIT = 1000e18;

    function setUp() public {
        // Deploy mock tokens
        asset = new MockERC20("Test Asset", "ASSET", 18);
        collateral = new MockERC20("Test Collateral", "COLL", 18);

        // Deploy mock oracle (1:1 ratio)
        oracle = new MockOracle(1e18);

        // Deploy mock rate calculator
        rateCalculator = new MockRateCalculator();

        // Prepare constructor parameters
        bytes memory configData = abi.encode(
            address(asset), // _asset
            address(0), // _collateral (set later via setCollateral)
            address(oracle), // _oracle
            uint32(1000), // _maxOracleDeviation (1%)
            address(rateCalculator), // _rateContract
            uint64(1e18), // _fullUtilizationRate
            uint256(75000), // _maxLTV (75%)
            uint256(50000), // _maxBorrowLTV (50%)
            uint256(1000), // _liquidationFee (1%)
            uint256(50000), // _protocolLiquidationFee (50%)
            uint256(0), // _depositFee (0, so MIN_TREASURY_FEE applies)
            uint256(0) // _withdrawFee (0, so MIN_TREASURY_FEE applies)
        );

        bytes memory immutables = abi.encode(
            circuitBreaker, // _circuitBreakerAddress
            comptroller, // _comptrollerAddress
            timelock // _timelockAddress
        );

        bytes memory customConfigData = abi.encode(
            "Test FraxlendPair", // _nameOfContract
            "tfFRAX", // _symbolOfContract
            uint8(18) // _decimalsOfContract
        );

        // Deploy FraxlendPair
        pair = new FraxlendPair(configData, immutables, customConfigData);

        // Set collateral (as timelock)
        vm.prank(timelock);
        pair.setCollateral(address(collateral));

        // Mint tokens to users
        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);
        collateral.mint(alice, 1_000_000e18);
        collateral.mint(bob, 1_000_000e18);

        // Approve pair to spend tokens
        vm.prank(alice);
        asset.approve(address(pair), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(pair), type(uint256).max);

        // Alice makes initial deposit to bootstrap the pool
        vm.prank(alice);
        pair.deposit(INITIAL_DEPOSIT, alice);
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _calculateEffectiveFee() internal view returns (uint256) {
        // Since depositFee and withdrawFee are 0, MIN_TREASURY_FEE applies
        return MIN_TREASURY_FEE;
    }

    function _applyDepositFee(uint256 amount) internal view returns (uint256) {
        uint256 fee = _calculateEffectiveFee();
        return amount - ((amount * fee) / FEE_PRECISION);
    }

    function _applyWithdrawFee(uint256 amount) internal view returns (uint256) {
        uint256 fee = _calculateEffectiveFee();
        return amount - ((amount * fee) / FEE_PRECISION);
    }

    function _grossAmountForNetDeposit(uint256 netAmount) internal view returns (uint256) {
        uint256 fee = _calculateEffectiveFee();
        return (netAmount * FEE_PRECISION) / (FEE_PRECISION - fee);
    }

    function _grossAmountForNetWithdraw(uint256 netAmount) internal view returns (uint256) {
        uint256 fee = _calculateEffectiveFee();
        return (netAmount * FEE_PRECISION) / (FEE_PRECISION - fee);
    }

    // ============================================================================================
    // Test: totalAssets
    // ============================================================================================

    function test_totalAssets() public {
        uint256 totalAssets = pair.totalAssets();
        // Initial deposit was 1000e18. The fee is split between protocol shares and CBR improvement,
        // but the underlying assets stay in the pool. So totalAssets equals the full deposit.
        assertEq(totalAssets, INITIAL_DEPOSIT, "totalAssets should equal full deposited amount");
    }

    // ============================================================================================
    // Test: convertToShares / convertToAssets
    // ============================================================================================

    function test_convertToShares() public {
        uint256 assets = 100e18;
        uint256 shares = pair.convertToShares(assets);
        // With 1:1 ratio (no interest accrued), shares should approximately equal assets
        // Note: convertToShares doesn't include fees, it's a pure conversion
        assertGt(shares, 0, "convertToShares should return positive value");
    }

    function test_convertToAssets() public {
        uint256 shares = 100e18;
        uint256 assets = pair.convertToAssets(shares);
        // With 1:1 ratio, assets should approximately equal shares
        assertGt(assets, 0, "convertToAssets should return positive value");
    }

    function test_convertRoundTrip() public {
        uint256 originalAssets = 100e18;
        uint256 shares = pair.convertToShares(originalAssets);
        uint256 recoveredAssets = pair.convertToAssets(shares);
        // Should be approximately equal (allowing for rounding)
        assertApproxEqAbs(recoveredAssets, originalAssets, 1, "Round trip conversion should preserve value");
    }

    // ============================================================================================
    // Test: previewDeposit
    // ============================================================================================

    function test_previewDeposit_accountsForFees() public {
        uint256 depositAmount = 100e18;
        uint256 previewShares = pair.previewDeposit(depositAmount);

        // previewDeposit should return shares AFTER accounting for fees
        // So if we deposit X and get Y shares, previewDeposit(X) should return Y
        uint256 assetsAfterFee = _applyDepositFee(depositAmount);
        uint256 expectedShares = pair.convertToShares(assetsAfterFee);

        assertEq(previewShares, expectedShares, "previewDeposit should account for deposit fee");
    }

    function test_previewDeposit_matchesActualDeposit() public {
        uint256 depositAmount = 100e18;
        uint256 previewShares = pair.previewDeposit(depositAmount);

        vm.prank(bob);
        uint256 actualShares = pair.deposit(depositAmount, bob);

        assertEq(actualShares, previewShares, "previewDeposit should match actual deposit shares");
    }

    // ============================================================================================
    // Test: previewMint
    // ============================================================================================

    function test_previewMint_accountsForFees() public {
        uint256 sharesToMint = 100e18;
        uint256 previewAssets = pair.previewMint(sharesToMint);

        // previewMint should return assets needed INCLUDING fees
        // User needs to send more assets to get the desired shares after fee deduction
        uint256 baseAssets = pair.convertToAssets(sharesToMint);
        uint256 expectedAssets = _grossAmountForNetDeposit(baseAssets);

        // Allow small rounding difference
        assertApproxEqAbs(previewAssets, expectedAssets, 2, "previewMint should account for deposit fee");
    }

    function test_previewMint_matchesActualMint() public {
        uint256 sharesToMint = 100e18;
        uint256 previewAssets = pair.previewMint(sharesToMint);

        vm.prank(bob);
        uint256 actualAssets = pair.mint(sharesToMint, bob);

        assertEq(actualAssets, previewAssets, "previewMint should match actual mint assets");
    }

    // ============================================================================================
    // Test: previewRedeem
    // ============================================================================================

    function test_previewRedeem_accountsForFees() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        uint256 previewAssets = pair.previewRedeem(shares);

        // previewRedeem should return assets AFTER accounting for withdrawal fee
        uint256 baseAssets = pair.convertToAssets(shares);
        uint256 expectedAssets = _applyWithdrawFee(baseAssets);

        assertEq(previewAssets, expectedAssets, "previewRedeem should account for withdrawal fee");
    }

    function test_previewRedeem_matchesActualRedeem() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        uint256 previewAssets = pair.previewRedeem(shares);

        vm.prank(bob);
        uint256 actualAssets = pair.redeem(shares, bob, bob);

        assertEq(actualAssets, previewAssets, "previewRedeem should match actual redeem assets");
    }

    // ============================================================================================
    // Test: previewWithdraw
    // ============================================================================================

    function test_previewWithdraw_accountsForFees() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 withdrawAmount = 50e18; // Net amount user wants to receive
        uint256 previewShares = pair.previewWithdraw(withdrawAmount);

        // previewWithdraw should return shares needed to get the net amount after fees
        // User needs to burn more shares because fee is deducted
        uint256 grossAmount = _grossAmountForNetWithdraw(withdrawAmount);
        uint256 expectedShares = pair.convertToShares(grossAmount);

        // Use ceiling for shares calculation (round up)
        assertApproxEqAbs(previewShares, expectedShares, 2, "previewWithdraw should account for withdrawal fee");
    }

    function test_previewWithdraw_matchesActualWithdraw() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        // Get max withdrawable to avoid insufficient balance
        uint256 maxWithdrawable = pair.maxWithdraw(bob);
        uint256 withdrawAmount = maxWithdrawable / 2;

        uint256 previewShares = pair.previewWithdraw(withdrawAmount);

        vm.prank(bob);
        uint256 actualShares = pair.withdraw(withdrawAmount, bob, bob);

        assertEq(actualShares, previewShares, "previewWithdraw should match actual withdraw shares");
    }

    // ============================================================================================
    // Test: deposit
    // ============================================================================================

    function test_deposit_returnsCorrectShares() public {
        uint256 depositAmount = 100e18;

        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        // Shares should be based on amount after fee
        uint256 assetsAfterFee = _applyDepositFee(depositAmount);
        uint256 expectedShares = pair.convertToShares(assetsAfterFee);

        // Allow 1 wei tolerance for rounding
        assertApproxEqAbs(shares, expectedShares, 1, "deposit should return shares based on post-fee amount");
    }

    function test_deposit_transfersCorrectAmount() public {
        uint256 depositAmount = 100e18;
        uint256 balanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 balanceAfter = asset.balanceOf(bob);
        assertEq(balanceBefore - balanceAfter, depositAmount, "deposit should transfer full amount from user");
    }

    // ============================================================================================
    // Test: mint
    // ============================================================================================

    function test_mint_returnsCorrectAssets() public {
        uint256 sharesToMint = 100e18;

        vm.prank(bob);
        uint256 assets = pair.mint(sharesToMint, bob);

        // User should receive exactly the shares they requested
        assertEq(pair.balanceOf(bob), sharesToMint, "mint should give user exact shares requested");

        // Assets pulled should include fee compensation
        uint256 baseAssets = pair.convertToAssets(sharesToMint);
        uint256 expectedAssets = _grossAmountForNetDeposit(baseAssets);

        assertApproxEqAbs(assets, expectedAssets, 2, "mint should return assets including fee");
    }

    function test_mint_transfersCorrectAmount() public {
        uint256 sharesToMint = 100e18;
        uint256 balanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        uint256 assetsUsed = pair.mint(sharesToMint, bob);

        uint256 balanceAfter = asset.balanceOf(bob);
        assertEq(balanceBefore - balanceAfter, assetsUsed, "mint should transfer correct asset amount");
    }

    // ============================================================================================
    // Test: redeem
    // ============================================================================================

    function test_redeem_returnsNetAssets() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        // Calculate expected BEFORE the redeem (state will change after)
        uint256 grossAssets = pair.convertToAssets(shares);
        uint256 expectedNetAssets = _applyWithdrawFee(grossAssets);

        uint256 balanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        uint256 assetsReturned = pair.redeem(shares, bob, bob);

        uint256 balanceAfter = asset.balanceOf(bob);

        // The returned value should equal what user actually received
        assertEq(balanceAfter - balanceBefore, assetsReturned, "redeem return value should match actual transfer");

        // Assets received should be post-fee (compare with pre-calculated expectation)
        assertEq(assetsReturned, expectedNetAssets, "redeem should return net assets after fee");
    }

    function test_redeem_burnsCorrectShares() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        uint256 sharesBefore = pair.balanceOf(bob);

        vm.prank(bob);
        pair.redeem(shares, bob, bob);

        uint256 sharesAfter = pair.balanceOf(bob);

        assertEq(sharesBefore - sharesAfter, shares, "redeem should burn exact shares specified");
    }

    // ============================================================================================
    // Test: withdraw
    // ============================================================================================

    function test_withdraw_returnsCorrectShares() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxWithdrawable = pair.maxWithdraw(bob);
        uint256 withdrawAmount = maxWithdrawable / 2;

        // Calculate expected BEFORE the withdraw (state will change after)
        uint256 grossAmount = _grossAmountForNetWithdraw(withdrawAmount);
        uint256 expectedShares = pair.convertToShares(grossAmount);

        vm.prank(bob);
        uint256 sharesBurned = pair.withdraw(withdrawAmount, bob, bob);

        // Allow slightly larger tolerance due to rounding in fee calculations
        assertApproxEqAbs(sharesBurned, expectedShares, 10, "withdraw should burn correct shares for net amount");
    }

    function test_withdraw_transfersExactAmount() public {
        // First deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxWithdrawable = pair.maxWithdraw(bob);
        uint256 withdrawAmount = maxWithdrawable / 2;

        uint256 balanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        pair.withdraw(withdrawAmount, bob, bob);

        uint256 balanceAfter = asset.balanceOf(bob);

        // User should receive exactly the amount they requested (net of fees)
        // Note: The withdraw function handles fee internally, so user gets withdrawAmount
        // But there might be rounding - check it's approximately correct
        assertApproxEqAbs(
            balanceAfter - balanceBefore, withdrawAmount, 2, "withdraw should transfer requested net amount"
        );
    }

    // ============================================================================================
    // Test: maxDeposit / maxMint
    // ============================================================================================

    function test_maxDeposit_returnsMax() public {
        uint256 maxDeposit = pair.maxDeposit(bob);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit should return max when not paused");
    }

    function test_maxMint_returnsMax() public {
        uint256 maxMint = pair.maxMint(bob);
        assertEq(maxMint, type(uint256).max, "maxMint should return max when not paused");
    }

    function test_maxDeposit_returnsZeroWhenPaused() public {
        vm.prank(circuitBreaker);
        pair.pause();

        uint256 maxDeposit = pair.maxDeposit(bob);
        assertEq(maxDeposit, 0, "maxDeposit should return 0 when paused");
    }

    function test_maxMint_returnsZeroWhenPaused() public {
        vm.prank(circuitBreaker);
        pair.pause();

        uint256 maxMint = pair.maxMint(bob);
        assertEq(maxMint, 0, "maxMint should return 0 when paused");
    }

    // ============================================================================================
    // Test: maxWithdraw / maxRedeem
    // ============================================================================================

    function test_maxWithdraw_accountsForFees() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxWithdraw = pair.maxWithdraw(bob);

        // maxWithdraw should return the NET amount user can receive (after fees)
        // It should be less than the gross asset value of their shares
        uint256 grossAssets = pair.convertToAssets(pair.balanceOf(bob));
        uint256 expectedMaxWithdraw = _applyWithdrawFee(grossAssets);

        assertEq(maxWithdraw, expectedMaxWithdraw, "maxWithdraw should account for withdrawal fee");
    }

    function test_maxWithdraw_isWithdrawable() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxWithdraw = pair.maxWithdraw(bob);

        // Should be able to withdraw the max amount
        vm.prank(bob);
        pair.withdraw(maxWithdraw, bob, bob);

        // Should have burned all shares (or very close to it)
        assertLe(pair.balanceOf(bob), 1, "Should have burned all or nearly all shares");
    }

    function test_maxRedeem_returnsCorrectShares() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        uint256 maxRedeem = pair.maxRedeem(bob);

        // maxRedeem should return user's share balance (fee is on asset side, not shares)
        assertEq(maxRedeem, shares, "maxRedeem should return user's share balance");
    }

    function test_maxRedeem_isRedeemable() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxRedeem = pair.maxRedeem(bob);

        // Should be able to redeem the max shares
        vm.prank(bob);
        pair.redeem(maxRedeem, bob, bob);

        // Should have no shares left
        assertEq(pair.balanceOf(bob), 0, "Should have no shares after max redeem");
    }

    function test_maxWithdraw_returnsZeroWhenPaused() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        vm.prank(circuitBreaker);
        pair.pause();

        uint256 maxWithdraw = pair.maxWithdraw(bob);
        assertEq(maxWithdraw, 0, "maxWithdraw should return 0 when paused");
    }

    function test_maxRedeem_returnsZeroWhenPaused() public {
        // Deposit to have shares
        uint256 depositAmount = 100e18;
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        vm.prank(circuitBreaker);
        pair.pause();

        uint256 maxRedeem = pair.maxRedeem(bob);
        assertEq(maxRedeem, 0, "maxRedeem should return 0 when paused");
    }

    // ============================================================================================
    // Test: Fee Consistency
    // ============================================================================================

    function test_depositAndRedeem_feeConsistency() public {
        uint256 depositAmount = 1000e18;

        // Deposit
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        // Immediately redeem all shares
        vm.prank(bob);
        uint256 assetsReturned = pair.redeem(shares, bob, bob);

        // User should lose approximately 2x MIN_TREASURY_FEE (once on deposit, once on withdraw)
        // Deposit fee: 0.01% on 1000e18 = 0.1e18
        // Post-deposit amount: ~999.9e18
        // Withdraw fee: 0.01% on ~999.9e18 = ~0.09999e18
        // Total loss: ~0.2e18

        uint256 totalFeePercentage = 2 * MIN_TREASURY_FEE; // Approximate
        uint256 expectedLoss = (depositAmount * totalFeePercentage) / FEE_PRECISION;

        uint256 actualLoss = depositAmount - assetsReturned;

        // Allow some tolerance for rounding
        assertApproxEqAbs(actualLoss, expectedLoss, 1e15, "Fee loss should be approximately 2x MIN_TREASURY_FEE");
    }

    function test_mintAndWithdraw_feeConsistency() public {
        uint256 sharesToMint = 100e18;

        // Mint specific shares
        vm.prank(bob);
        uint256 assetsUsed = pair.mint(sharesToMint, bob);

        // Get max withdrawable
        uint256 maxWithdrawable = pair.maxWithdraw(bob);

        // Withdraw all
        vm.prank(bob);
        pair.withdraw(maxWithdrawable, bob, bob);

        // User should have lost value due to fees
        assertGt(assetsUsed, maxWithdrawable, "Should lose value due to fees on mint and withdraw");
    }

    // ============================================================================================
    // Test: ERC4626 Standard Compliance - Preview == Actual
    // ============================================================================================

    function testFuzz_previewDeposit_matchesDeposit(uint256 amount) public {
        amount = bound(amount, 1e18, 100_000e18);

        uint256 preview = pair.previewDeposit(amount);

        vm.prank(bob);
        uint256 actual = pair.deposit(amount, bob);

        assertEq(actual, preview, "previewDeposit should exactly match deposit");
    }

    function testFuzz_previewMint_matchesMint(uint256 shares) public {
        shares = bound(shares, 1e18, 100_000e18);

        uint256 preview = pair.previewMint(shares);

        vm.prank(bob);
        uint256 actual = pair.mint(shares, bob);

        assertEq(actual, preview, "previewMint should exactly match mint");
    }

    function testFuzz_previewRedeem_matchesRedeem(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 10e18, 100_000e18);

        // First deposit
        vm.prank(bob);
        uint256 shares = pair.deposit(depositAmount, bob);

        uint256 preview = pair.previewRedeem(shares);

        vm.prank(bob);
        uint256 actual = pair.redeem(shares, bob, bob);

        assertEq(actual, preview, "previewRedeem should exactly match redeem");
    }

    function testFuzz_previewWithdraw_matchesWithdraw(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 10e18, 100_000e18);

        // First deposit
        vm.prank(bob);
        pair.deposit(depositAmount, bob);

        uint256 maxWithdrawable = pair.maxWithdraw(bob);
        uint256 withdrawAmount = maxWithdrawable / 2;

        uint256 preview = pair.previewWithdraw(withdrawAmount);

        vm.prank(bob);
        uint256 actual = pair.withdraw(withdrawAmount, bob, bob);

        assertEq(actual, preview, "previewWithdraw should exactly match withdraw");
    }
}
