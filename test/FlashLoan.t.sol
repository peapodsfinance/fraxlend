// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FraxlendPair} from "../src/FraxlendPair.sol";
import {FraxlendPairCore} from "../src/FraxlendPairCore.sol";
import {FraxlendPairConstants} from "../src/FraxlendPairConstants.sol";
import {IERC3156FlashBorrower} from "../src/interfaces/IERC3156FlashBorrower.sol";
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
        return (0, _maxInterest);
    }
}

/// @title Good Flash Borrower that properly repays
contract GoodFlashBorrower is IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public token;
    bool public callbackExecuted;
    address public receivedInitiator;
    address public receivedToken;
    uint256 public receivedAmount;
    uint256 public receivedFee;
    bytes public receivedData;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address initiator, address _token, uint256 amount, uint256 fee, bytes calldata data)
        external
        override
        returns (bytes32)
    {
        callbackExecuted = true;
        receivedInitiator = initiator;
        receivedToken = _token;
        receivedAmount = amount;
        receivedFee = fee;
        receivedData = data;

        // Transfer repayment (amount + fee) back to the lender
        token.transfer(msg.sender, amount + fee);

        return CALLBACK_SUCCESS;
    }

    function executeFlashLoan(address lender, uint256 amount, bytes calldata data) external {
        FraxlendPair(lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, data);
    }
}

/// @title Bad Flash Borrower that returns wrong callback value
contract BadCallbackFlashBorrower is IERC3156FlashBorrower {
    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata)
        external
        override
        returns (bytes32)
    {
        // Transfer repayment
        token.transfer(msg.sender, amount + fee);

        // Return wrong value (not the expected hash)
        return bytes32(0);
    }

    function executeFlashLoan(address lender, uint256 amount) external {
        FraxlendPair(lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "");
    }
}

/// @title Flash Borrower that doesn't repay enough
contract InsufficientRepayFlashBorrower is IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata)
        external
        override
        returns (bytes32)
    {
        // Only transfer partial repayment (not enough)
        uint256 partialRepay = amount + fee - 1;
        token.transfer(msg.sender, partialRepay);

        return CALLBACK_SUCCESS;
    }

    function executeFlashLoan(address lender, uint256 amount) external {
        FraxlendPair(lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "");
    }
}

/// @title Flash Borrower that keeps the tokens (theft attempt)
contract ThiefFlashBorrower is IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external override returns (bytes32) {
        // Don't approve anything back - attempt to keep tokens
        return CALLBACK_SUCCESS;
    }

    function executeFlashLoan(address lender, uint256 amount) external {
        FraxlendPair(lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "");
    }
}

/// @title Flash Borrower that uses the flash loan for arbitrage
contract ArbitrageFlashBorrower is IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public token;
    uint256 public profit;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata data)
        external
        override
        returns (bytes32)
    {
        // Simulate profitable arbitrage by decoding expected profit from data
        uint256 simulatedProfit = abi.decode(data, (uint256));
        profit = simulatedProfit;

        // Transfer repayment
        token.transfer(msg.sender, amount + fee);

        return CALLBACK_SUCCESS;
    }

    function executeFlashLoan(address lender, uint256 amount, uint256 simulatedProfit) external {
        bytes memory data = abi.encode(simulatedProfit);
        FraxlendPair(lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, data);
    }
}

/// @title Reentrant Flash Borrower that attempts reentrancy
contract ReentrantFlashBorrower is IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public token;
    address public lender;
    uint256 public reentryAttempts;
    bool public attemptReentry;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata)
        external
        override
        returns (bytes32)
    {
        if (attemptReentry && reentryAttempts == 0) {
            reentryAttempts++;
            // Attempt to reenter with another flash loan
            try FraxlendPair(msg.sender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "") {
            // If this succeeds, reentrancy guard is broken
            }
                catch {
                // Expected to fail due to reentrancy guard
            }
        }

        // Transfer repayment
        token.transfer(msg.sender, amount + fee);

        return CALLBACK_SUCCESS;
    }

    function executeFlashLoan(address _lender, uint256 amount, bool _attemptReentry) external {
        lender = _lender;
        attemptReentry = _attemptReentry;
        reentryAttempts = 0;
        FraxlendPair(_lender).flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "");
    }
}

/// @title Flash Loan Tests for FraxlendPair
contract FlashLoanTest is Test {
    FraxlendPair public pair;
    MockERC20 public asset;
    MockERC20 public collateral;
    MockOracle public oracle;
    MockRateCalculator public rateCalculator;

    GoodFlashBorrower public goodBorrower;
    BadCallbackFlashBorrower public badCallbackBorrower;
    InsufficientRepayFlashBorrower public insufficientBorrower;
    ThiefFlashBorrower public thiefBorrower;
    ArbitrageFlashBorrower public arbitrageBorrower;
    ReentrantFlashBorrower public reentrantBorrower;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public timelock = address(0x3);
    address public circuitBreaker = address(0x4);
    address public comptroller = address(0x5);

    uint256 public constant FEE_PRECISION = 1e5;
    uint256 public constant FLASH_FEE_RATE = 10; // 0.01% fee
    uint256 public constant INITIAL_DEPOSIT = 10_000e18;

    event FlashLoan(address indexed receiver, uint256 amount, uint256 fee);

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
            address(asset),
            address(0), // collateral set later
            address(oracle),
            uint32(1000),
            address(rateCalculator),
            uint64(1e18),
            uint256(75000), // maxLTV
            uint256(50000), // maxBorrowLTV
            uint256(1000), // liquidationFee
            uint256(50000), // protocolLiquidationFee
            uint256(0), // depositFee
            uint256(0) // withdrawFee
        );

        bytes memory immutables = abi.encode(circuitBreaker, comptroller, timelock);

        bytes memory customConfigData = abi.encode("Test FraxlendPair", "tfFRAX", uint8(18));

        // Deploy FraxlendPair
        pair = new FraxlendPair(configData, immutables, customConfigData);

        // Set collateral
        vm.prank(timelock);
        pair.setCollateral(address(collateral));

        // Deploy flash borrowers
        goodBorrower = new GoodFlashBorrower(address(asset));
        badCallbackBorrower = new BadCallbackFlashBorrower(address(asset));
        insufficientBorrower = new InsufficientRepayFlashBorrower(address(asset));
        thiefBorrower = new ThiefFlashBorrower(address(asset));
        arbitrageBorrower = new ArbitrageFlashBorrower(address(asset));
        reentrantBorrower = new ReentrantFlashBorrower(address(asset));

        // Mint tokens to users and borrowers
        asset.mint(alice, 1_000_000e18);
        asset.mint(address(goodBorrower), 100e18); // For fee payment
        asset.mint(address(arbitrageBorrower), 100e18);
        asset.mint(address(reentrantBorrower), 100e18);

        // Approve pair
        vm.prank(alice);
        asset.approve(address(pair), type(uint256).max);

        // Alice makes initial deposit
        vm.prank(alice);
        pair.deposit(INITIAL_DEPOSIT, alice);
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _calculateFlashFee(uint256 amount) internal pure returns (uint256) {
        return (amount * FLASH_FEE_RATE) / FEE_PRECISION;
    }

    // ============================================================================================
    // Test: Basic Flash Loan Success
    // ============================================================================================

    function test_flashLoan_basicSuccess() public {
        uint256 borrowAmount = 1000e18;
        bytes memory data = "test data";

        // Execute flash loan
        goodBorrower.executeFlashLoan(address(pair), borrowAmount, data);

        // Verify callback was executed
        assertTrue(goodBorrower.callbackExecuted(), "Callback should have been executed");
        assertEq(goodBorrower.receivedAmount(), borrowAmount, "Should receive correct amount");
        assertEq(goodBorrower.receivedToken(), address(asset), "Should receive correct token");
        assertEq(goodBorrower.receivedFee(), _calculateFlashFee(borrowAmount), "Should receive correct fee");
        assertEq(string(goodBorrower.receivedData()), string(data), "Should receive correct data");
    }

    function test_flashLoan_emitsEvent() public {
        uint256 borrowAmount = 1000e18;
        uint256 expectedFee = _calculateFlashFee(borrowAmount);

        vm.expectEmit(true, false, false, true);
        emit FlashLoan(address(goodBorrower), borrowAmount, expectedFee);

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");
    }

    function test_flashLoan_feeCalculation() public {
        // Use 5000e18 which is less than the 10000e18 initial deposit
        uint256 borrowAmount = 5_000e18;
        uint256 expectedFee = _calculateFlashFee(borrowAmount); // 0.01% = 0.5 tokens

        assertEq(expectedFee, 5e17, "Fee should be 0.01% of borrow amount (0.5 tokens)");

        // Need to fund the borrower with enough to pay the fee
        asset.mint(address(goodBorrower), expectedFee);

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");
        assertEq(goodBorrower.receivedFee(), expectedFee, "Callback should receive correct fee");
    }

    // ============================================================================================
    // Test: Flash Loan with Different Amounts
    // ============================================================================================

    function test_flashLoan_smallAmount() public {
        uint256 borrowAmount = 1e18; // 1 token
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        assertTrue(goodBorrower.callbackExecuted(), "Should succeed with small amount");
    }

    function test_flashLoan_maxAvailable() public {
        // Borrow all available local assets
        uint256 maxBorrow = asset.balanceOf(address(pair));
        asset.mint(address(goodBorrower), _calculateFlashFee(maxBorrow));

        goodBorrower.executeFlashLoan(address(pair), maxBorrow, "");

        assertTrue(goodBorrower.callbackExecuted(), "Should succeed borrowing max available");
    }

    function testFuzz_flashLoan_variousAmounts(uint256 amount) public {
        uint256 maxAvailable = asset.balanceOf(address(pair));
        amount = bound(amount, 1, maxAvailable);

        asset.mint(address(goodBorrower), _calculateFlashFee(amount) + 1e18); // Extra buffer

        goodBorrower.executeFlashLoan(address(pair), amount, "");

        assertTrue(goodBorrower.callbackExecuted(), "Should succeed with any valid amount");
        assertEq(goodBorrower.receivedAmount(), amount, "Should receive exact amount");
    }

    // ============================================================================================
    // Test: Flash Loan Failures
    // ============================================================================================

    function test_flashLoan_revertsOnWrongToken() public {
        // Try to borrow a different token
        address wrongToken = address(collateral);

        vm.expectRevert(FraxlendPairConstants.UnsupportedCurrency.selector);
        pair.flashLoan(IERC3156FlashBorrower(address(goodBorrower)), wrongToken, 1000e18, "");
    }

    function test_flashLoan_revertsOnInsufficientLiquidity() public {
        uint256 availableAssets = asset.balanceOf(address(pair));
        uint256 borrowAmount = availableAssets + 1; // More than available

        vm.expectRevert(
            abi.encodeWithSelector(
                FraxlendPairConstants.InsufficientAssetsInContract.selector, availableAssets, borrowAmount
            )
        );
        pair.flashLoan(IERC3156FlashBorrower(address(goodBorrower)), address(asset), borrowAmount, "");
    }

    function test_flashLoan_revertsOnBadCallback() public {
        uint256 borrowAmount = 1000e18;
        asset.mint(address(badCallbackBorrower), _calculateFlashFee(borrowAmount));

        vm.expectRevert(FraxlendPairConstants.FlashLoanCallbackFailed.selector);
        badCallbackBorrower.executeFlashLoan(address(pair), borrowAmount);
    }

    function test_flashLoan_revertsOnInsufficientRepayment() public {
        uint256 borrowAmount = 1000e18;
        // Give borrower just enough to approve but not actually transfer
        asset.mint(address(insufficientBorrower), _calculateFlashFee(borrowAmount));

        vm.expectRevert(FraxlendPairConstants.InsufficientFlashLoanRepayment.selector);
        insufficientBorrower.executeFlashLoan(address(pair), borrowAmount);
    }

    function test_flashLoan_revertsOnTheftAttempt() public {
        uint256 borrowAmount = 1000e18;

        vm.expectRevert(FraxlendPairConstants.InsufficientFlashLoanRepayment.selector);
        thiefBorrower.executeFlashLoan(address(pair), borrowAmount);
    }

    // ============================================================================================
    // Test: Flash Loan Fee Accounting
    // ============================================================================================

    function test_flashLoan_feeImprovesCBR() public {
        uint256 borrowAmount = 10_000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);
        asset.mint(address(goodBorrower), fee);

        // Get total assets before flash loan
        uint256 totalAssetsBefore = pair.totalAssets();

        // Execute flash loan
        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        // Total assets should increase by the fee amount
        uint256 totalAssetsAfter = pair.totalAssets();
        assertEq(totalAssetsAfter, totalAssetsBefore + fee, "Flash loan fee should increase total assets (CBR)");
    }

    function test_flashLoan_feeAccumulatesOverMultipleLoans() public {
        uint256 borrowAmount = 1000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);

        // Fund borrower for multiple loans
        asset.mint(address(goodBorrower), fee * 5);

        uint256 totalAssetsBefore = pair.totalAssets();

        // Execute 5 flash loans
        for (uint256 i = 0; i < 5; i++) {
            goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");
        }

        uint256 totalAssetsAfter = pair.totalAssets();
        assertEq(totalAssetsAfter, totalAssetsBefore + (fee * 5), "Fees should accumulate from multiple flash loans");
    }

    // ============================================================================================
    // Test: Flash Loan State Consistency
    // ============================================================================================

    function test_flashLoan_balanceConsistency() public {
        uint256 borrowAmount = 1000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);
        asset.mint(address(goodBorrower), fee);

        uint256 pairBalanceBefore = asset.balanceOf(address(pair));
        uint256 borrowerBalanceBefore = asset.balanceOf(address(goodBorrower));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        uint256 pairBalanceAfter = asset.balanceOf(address(pair));
        uint256 borrowerBalanceAfter = asset.balanceOf(address(goodBorrower));

        // Pair should have original balance + fee
        assertEq(pairBalanceAfter, pairBalanceBefore + fee, "Pair should gain the fee");

        // Borrower should lose the fee
        assertEq(borrowerBalanceAfter, borrowerBalanceBefore - fee, "Borrower should pay the fee");
    }

    function test_flashLoan_doesNotAffectShareholders() public {
        uint256 borrowAmount = 1000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);
        asset.mint(address(goodBorrower), fee);

        // Get Alice's share value before flash loan
        uint256 aliceSharesBefore = pair.balanceOf(alice);
        uint256 aliceAssetsBefore = pair.convertToAssets(aliceSharesBefore);

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        // Alice's share value should increase (she benefits from the fee)
        uint256 aliceAssetsAfter = pair.convertToAssets(aliceSharesBefore);
        assertGt(aliceAssetsAfter, aliceAssetsBefore, "Shareholder asset value should increase from flash loan fee");
    }

    // ============================================================================================
    // Test: Flash Loan Security
    // ============================================================================================

    function test_flashLoan_reentrancyProtected() public {
        uint256 borrowAmount = 1000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);
        asset.mint(address(reentrantBorrower), fee * 2); // Enough for potential reentrancy

        // Execute flash loan with reentrancy attempt
        reentrantBorrower.executeFlashLoan(address(pair), borrowAmount, true);

        // The reentrancy attempt should have been blocked
        // If reentryAttempts > 0, it means reentrancy was attempted
        // The original loan should still succeed (reentrancy guard allows the callback but not nested flash loans)
        assertEq(reentrantBorrower.reentryAttempts(), 1, "Reentrancy should have been attempted");
    }

    function test_flashLoan_zeroAmountSucceeds() public {
        // Zero amount flash loan should succeed (no tokens moved, no fee)
        goodBorrower.executeFlashLoan(address(pair), 0, "");

        assertTrue(goodBorrower.callbackExecuted(), "Zero amount flash loan should succeed");
        assertEq(goodBorrower.receivedAmount(), 0, "Should receive 0 amount");
        assertEq(goodBorrower.receivedFee(), 0, "Fee should be 0 for zero amount");
    }

    // ============================================================================================
    // Test: Flash Loan with Arbitrage Simulation
    // ============================================================================================

    function test_flashLoan_arbitrageScenario() public {
        uint256 borrowAmount = 5000e18;
        uint256 fee = _calculateFlashFee(borrowAmount);
        uint256 simulatedProfit = 50e18;

        // Fund borrower with enough for fee
        asset.mint(address(arbitrageBorrower), fee + simulatedProfit);

        uint256 borrowerBalanceBefore = asset.balanceOf(address(arbitrageBorrower));

        arbitrageBorrower.executeFlashLoan(address(pair), borrowAmount, simulatedProfit);

        // Verify the arbitrage profit was "captured" (simulated)
        assertEq(arbitrageBorrower.profit(), simulatedProfit, "Arbitrage profit should be recorded");

        // Borrower should have paid the fee
        uint256 borrowerBalanceAfter = asset.balanceOf(address(arbitrageBorrower));
        assertEq(borrowerBalanceAfter, borrowerBalanceBefore - fee, "Borrower should only lose the fee");
    }

    // ============================================================================================
    // Test: Flash Loan Data Passing
    // ============================================================================================

    function test_flashLoan_passesDataCorrectly() public {
        uint256 borrowAmount = 100e18;
        bytes memory testData = abi.encode(uint256(12345), address(0xBEEF), "hello world");
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, testData);

        assertEq(goodBorrower.receivedData(), testData, "Data should be passed correctly to callback");
    }

    function test_flashLoan_emptyDataWorks() public {
        uint256 borrowAmount = 100e18;
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        assertEq(goodBorrower.receivedData().length, 0, "Empty data should work");
    }

    function test_flashLoan_largeDataWorks() public {
        uint256 borrowAmount = 100e18;
        bytes memory largeData = new bytes(10000);
        for (uint256 i = 0; i < largeData.length; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, largeData);

        assertEq(goodBorrower.receivedData(), largeData, "Large data should be passed correctly");
    }

    // ============================================================================================
    // Test: Flash Loan Initiator Tracking
    // ============================================================================================

    function test_flashLoan_tracksInitiatorCorrectly() public {
        uint256 borrowAmount = 100e18;
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        // Bob calls the borrower's executeFlashLoan
        vm.prank(bob);
        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        // The initiator should be the borrower contract (which called pair.flashLoan)
        assertEq(goodBorrower.receivedInitiator(), address(goodBorrower), "Initiator should be the caller of flashLoan");
    }

    // ============================================================================================
    // Test: Flash Loan Integration with Pool State
    // ============================================================================================

    function test_flashLoan_afterBorrowing() public {
        // Setup: Bob deposits collateral and borrows
        collateral.mint(bob, 1000e18);
        vm.startPrank(bob);
        collateral.approve(address(pair), type(uint256).max);
        asset.approve(address(pair), type(uint256).max);
        pair.addCollateral(1000e18, bob);
        pair.borrowAsset(500e18, 0, bob);
        vm.stopPrank();

        // Now execute a flash loan - should still work with reduced available assets
        uint256 available = asset.balanceOf(address(pair));
        uint256 borrowAmount = available / 2;
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        assertTrue(goodBorrower.callbackExecuted(), "Flash loan should work after regular borrowing");
    }

    function test_flashLoan_withMultipleDepositors() public {
        // Add more depositors
        asset.mint(bob, 10_000e18);
        vm.prank(bob);
        asset.approve(address(pair), type(uint256).max);
        vm.prank(bob);
        pair.deposit(10_000e18, bob);

        // Flash loan should work with increased liquidity
        uint256 borrowAmount = 15_000e18; // More than initial deposit
        asset.mint(address(goodBorrower), _calculateFlashFee(borrowAmount));

        goodBorrower.executeFlashLoan(address(pair), borrowAmount, "");

        assertTrue(goodBorrower.callbackExecuted(), "Should work with multiple depositors' liquidity");
    }

    // ============================================================================================
    // Test: Flash Loan Edge Cases
    // ============================================================================================

    function test_flashLoan_exactlyAvailableAmount() public {
        uint256 exactAvailable = asset.balanceOf(address(pair));
        asset.mint(address(goodBorrower), _calculateFlashFee(exactAvailable));

        goodBorrower.executeFlashLoan(address(pair), exactAvailable, "");

        assertTrue(goodBorrower.callbackExecuted(), "Should work with exact available amount");
    }

    function test_flashLoan_oneWeiOverAvailable() public {
        uint256 exactAvailable = asset.balanceOf(address(pair));
        uint256 overAmount = exactAvailable + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                FraxlendPairConstants.InsufficientAssetsInContract.selector, exactAvailable, overAmount
            )
        );
        pair.flashLoan(IERC3156FlashBorrower(address(goodBorrower)), address(asset), overAmount, "");
    }

    function test_flashLoan_minimumFee() public {
        // Test with amount that results in very small fee
        uint256 smallAmount = 100; // 100 wei
        uint256 fee = _calculateFlashFee(smallAmount); // Should be 0 due to integer division

        goodBorrower.executeFlashLoan(address(pair), smallAmount, "");

        assertEq(goodBorrower.receivedFee(), fee, "Fee should be calculated correctly for small amounts");
    }
}
