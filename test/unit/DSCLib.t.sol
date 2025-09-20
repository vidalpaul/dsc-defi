// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DSCLib} from "../../src/DSCLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

/**
 * @title DSCLib_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for DSCLib library
 * @dev Tests all library functions including validation, price feeds, transfers, and calculations
 */
contract DSCLib_Unit_Test is Test {
    // Test contracts
    ERC20Mock public token;
    MockV3Aggregator public priceFeed;

    // Test accounts
    address public constant USER_ALICE = address(0x1);
    address public constant USER_BOB = address(0x2);

    // Test constants
    uint8 public constant PRICE_FEED_DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8; // $2000 with 8 decimals
    uint256 public constant TOKEN_AMOUNT = 1e18; // 1 token with 18 decimals
    uint256 public constant USD_AMOUNT = 2000e18; // $2000 with 18 decimals
    uint256 public constant TRANSFER_AMOUNT = 100e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // 50%

    // Mock contract for testing library functions
    MockDSCLibHelper public mockContract;

    function setUp() public {
        token = new ERC20Mock("Test Token", "TEST", address(this), 1000000e18);
        priceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, ETH_USD_PRICE);
        mockContract = new MockDSCLibHelper();

        // Setup test accounts with tokens
        token.mint(USER_ALICE, 1000e18);
        token.mint(USER_BOB, 1000e18);
    }

    ////////////////////////////////
    // Validation Function Tests
    ////////////////////////////////

    function test_ValidateAmountGreaterThanZero_Success() public view {
        // Should not revert for positive amounts
        mockContract.mockValidateAmountGreaterThanZero(1);
        mockContract.mockValidateAmountGreaterThanZero(1e18);
        mockContract.mockValidateAmountGreaterThanZero(type(uint256).max);
    }

    function test_ValidateAmountGreaterThanZero_RevertsOnZero() public {
        vm.expectRevert(DSCLib.DSCLib_AmountMustBeGreaterThanZero.selector);
        mockContract.mockValidateAmountGreaterThanZero(0);
    }

    function test_ValidateAddressNotZero_Success() public view {
        // Should not revert for non-zero addresses
        mockContract.mockValidateAddressNotZero(USER_ALICE);
        mockContract.mockValidateAddressNotZero(USER_BOB);
        mockContract.mockValidateAddressNotZero(address(this));
        mockContract.mockValidateAddressNotZero(address(token));
    }

    function test_ValidateAddressNotZero_RevertsOnZeroAddress() public {
        vm.expectRevert(DSCLib.DSCLib_AddressCannotBeZero.selector);
        mockContract.mockValidateAddressNotZero(address(0));
    }

    ////////////////////////////////
    // Price Feed Function Tests
    ////////////////////////////////

    function test_GetLatestPrice_Success() public view {
        uint256 price = mockContract.mockGetLatestPrice(address(priceFeed));
        assertEq(price, uint256(ETH_USD_PRICE), "Should return correct price");
    }

    function test_GetLatestPrice_UpdatedPrice() public {
        int256 newPrice = 2500e8;
        priceFeed.updateAnswer(newPrice);

        uint256 price = mockContract.mockGetLatestPrice(address(priceFeed));
        assertEq(price, uint256(newPrice), "Should return updated price");
    }

    function test_GetLatestPrice_ZeroPrice() public {
        priceFeed.updateAnswer(0);

        uint256 price = mockContract.mockGetLatestPrice(address(priceFeed));
        assertEq(price, 0, "Should handle zero price");
    }

    function test_GetUSDValue_Success() public view {
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), TOKEN_AMOUNT);
        uint256 expectedValue = (uint256(ETH_USD_PRICE) * 1e10 * TOKEN_AMOUNT) / 1e18;
        assertEq(usdValue, expectedValue, "Should calculate USD value correctly");
    }

    function test_GetUSDValue_ZeroAmount() public view {
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), 0);
        assertEq(usdValue, 0, "Should return zero for zero amount");
    }

    function test_GetUSDValue_LargeAmount() public view {
        uint256 largeAmount = 1000e18;
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), largeAmount);
        uint256 expectedValue = (uint256(ETH_USD_PRICE) * 1e10 * largeAmount) / 1e18;
        assertEq(usdValue, expectedValue, "Should handle large amounts");
    }

    function test_GetUSDValue_SmallAmount() public view {
        uint256 smallAmount = 1e15; // 0.001 tokens
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), smallAmount);
        uint256 expectedValue = (uint256(ETH_USD_PRICE) * 1e10 * smallAmount) / 1e18;
        assertEq(usdValue, expectedValue, "Should handle small amounts");
    }

    function test_GetTokenAmountFromUSD_Success() public view {
        uint256 tokenAmount = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), USD_AMOUNT);
        uint256 expectedAmount = (USD_AMOUNT * 1e18) / (uint256(ETH_USD_PRICE) * 1e10);
        assertEq(tokenAmount, expectedAmount, "Should calculate token amount correctly");
    }

    function test_GetTokenAmountFromUSD_ZeroUSD() public view {
        uint256 tokenAmount = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), 0);
        assertEq(tokenAmount, 0, "Should return zero for zero USD");
    }

    function test_GetTokenAmountFromUSD_LargeUSD() public view {
        uint256 largeUSD = 1000000e18; // $1M
        uint256 tokenAmount = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), largeUSD);
        uint256 expectedAmount = (largeUSD * 1e18) / (uint256(ETH_USD_PRICE) * 1e10);
        assertEq(tokenAmount, expectedAmount, "Should handle large USD amounts");
    }

    function test_GetTokenAmountFromUSD_SmallUSD() public view {
        uint256 smallUSD = 1e15; // $0.001
        uint256 tokenAmount = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), smallUSD);
        uint256 expectedAmount = (smallUSD * 1e18) / (uint256(ETH_USD_PRICE) * 1e10);
        assertEq(tokenAmount, expectedAmount, "Should handle small USD amounts");
    }

    function test_PriceFeedRoundTrip() public view {
        // Convert token to USD and back to token
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), TOKEN_AMOUNT);
        uint256 tokenAmountBack = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), usdValue);

        // Should be approximately equal (allowing for rounding differences)
        uint256 difference =
            tokenAmountBack > TOKEN_AMOUNT ? tokenAmountBack - TOKEN_AMOUNT : TOKEN_AMOUNT - tokenAmountBack;

        assertLt(difference, TOKEN_AMOUNT / 1000, "Round trip should be accurate within 0.1%");
    }

    ////////////////////////////////
    // Transfer Function Tests
    ////////////////////////////////

    function test_SafeTransfer_Success() public {
        // Setup: Transfer tokens to mock contract first
        token.transfer(address(mockContract), TRANSFER_AMOUNT * 2);

        uint256 initialBalance = token.balanceOf(USER_BOB);
        uint256 initialMockBalance = token.balanceOf(address(mockContract));

        mockContract.mockSafeTransfer(address(token), USER_BOB, TRANSFER_AMOUNT);

        assertEq(token.balanceOf(USER_BOB), initialBalance + TRANSFER_AMOUNT, "Transfer should succeed");
        assertEq(
            token.balanceOf(address(mockContract)),
            initialMockBalance - TRANSFER_AMOUNT,
            "Sender balance should decrease"
        );
    }

    function test_SafeTransfer_InsufficientBalance() public {
        uint256 excessiveAmount = 2000e18; // More than mock contract has

        vm.expectRevert(); // OpenZeppelin will revert with ERC20InsufficientBalance
        mockContract.mockSafeTransfer(address(token), USER_BOB, excessiveAmount);
    }

    function test_SafeTransfer_ZeroAmount() public {
        // Setup: Transfer some tokens to mock contract
        token.transfer(address(mockContract), TRANSFER_AMOUNT);

        uint256 initialBalance = token.balanceOf(USER_BOB);

        mockContract.mockSafeTransfer(address(token), USER_BOB, 0);

        assertEq(token.balanceOf(USER_BOB), initialBalance, "Balance should not change for zero transfer");
    }

    function test_SafeTransferFrom_Success() public {
        // Setup: Alice approves mock contract to spend her tokens
        vm.prank(USER_ALICE);
        token.approve(address(mockContract), TRANSFER_AMOUNT);

        uint256 initialAliceBalance = token.balanceOf(USER_ALICE);
        uint256 initialBobBalance = token.balanceOf(USER_BOB);

        mockContract.mockSafeTransferFrom(address(token), USER_ALICE, USER_BOB, TRANSFER_AMOUNT);

        assertEq(token.balanceOf(USER_ALICE), initialAliceBalance - TRANSFER_AMOUNT, "Alice balance should decrease");
        assertEq(token.balanceOf(USER_BOB), initialBobBalance + TRANSFER_AMOUNT, "Bob balance should increase");
    }

    function test_SafeTransferFrom_InsufficientAllowance() public {
        // Alice approves less than the transfer amount
        vm.prank(USER_ALICE);
        token.approve(address(mockContract), TRANSFER_AMOUNT / 2);

        vm.expectRevert(); // OpenZeppelin will revert with ERC20InsufficientAllowance
        mockContract.mockSafeTransferFrom(address(token), USER_ALICE, USER_BOB, TRANSFER_AMOUNT);
    }

    function test_SafeTransferFrom_InsufficientBalance() public {
        // Alice approves but doesn't have enough tokens
        vm.prank(USER_ALICE);
        token.approve(address(mockContract), 2000e18);

        vm.expectRevert(); // OpenZeppelin will revert with ERC20InsufficientBalance
        mockContract.mockSafeTransferFrom(address(token), USER_ALICE, USER_BOB, 2000e18);
    }

    function test_SafeTransferFrom_ZeroAmount() public {
        vm.prank(USER_ALICE);
        token.approve(address(mockContract), TRANSFER_AMOUNT);

        uint256 initialAliceBalance = token.balanceOf(USER_ALICE);
        uint256 initialBobBalance = token.balanceOf(USER_BOB);

        mockContract.mockSafeTransferFrom(address(token), USER_ALICE, USER_BOB, 0);

        assertEq(token.balanceOf(USER_ALICE), initialAliceBalance, "Alice balance should not change");
        assertEq(token.balanceOf(USER_BOB), initialBobBalance, "Bob balance should not change");
    }

    ////////////////////////////////
    // Calculation Function Tests
    ////////////////////////////////

    function test_CalculateHealthFactor_HealthyPosition() public view {
        uint256 totalDSCMinted = 1000e18;
        uint256 collateralValueInUsd = 3000e18; // $3000 collateral, $1000 debt = 300% collateralization

        uint256 healthFactor =
            mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, LIQUIDATION_THRESHOLD);

        uint256 expectedHealthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD * 1e18) / (100 * totalDSCMinted);
        assertEq(healthFactor, expectedHealthFactor, "Should calculate healthy position correctly");
        assertGt(healthFactor, 1e18, "Healthy position should have health factor > 1");
    }

    function test_CalculateHealthFactor_UnhealthyPosition() public view {
        uint256 totalDSCMinted = 1000e18;
        uint256 collateralValueInUsd = 1500e18; // $1500 collateral, $1000 debt = 150% collateralization

        uint256 healthFactor =
            mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, LIQUIDATION_THRESHOLD);

        uint256 expectedHealthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD * 1e18) / (100 * totalDSCMinted);
        assertEq(healthFactor, expectedHealthFactor, "Should calculate unhealthy position correctly");
        assertLt(healthFactor, 1e18, "Unhealthy position should have health factor < 1");
    }

    function test_CalculateHealthFactor_ZeroDSCMinted() public view {
        uint256 totalDSCMinted = 0;
        uint256 collateralValueInUsd = 1000e18;

        uint256 healthFactor =
            mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, LIQUIDATION_THRESHOLD);

        assertEq(healthFactor, type(uint256).max, "Zero DSC minted should return max health factor");
    }

    function test_CalculateHealthFactor_ZeroCollateral() public view {
        uint256 totalDSCMinted = 1000e18;
        uint256 collateralValueInUsd = 0;

        uint256 healthFactor =
            mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, LIQUIDATION_THRESHOLD);

        assertEq(healthFactor, 0, "Zero collateral should return zero health factor");
    }

    function test_CalculateHealthFactor_ExactlyAtThreshold() public view {
        uint256 totalDSCMinted = 1000e18;
        uint256 collateralValueInUsd = 2000e18; // Exactly 200% collateralization with 50% threshold

        uint256 healthFactor =
            mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, LIQUIDATION_THRESHOLD);

        assertEq(healthFactor, 1e18, "Should be exactly at liquidation threshold");
    }

    function test_CalculateHealthFactor_DifferentThresholds() public view {
        uint256 totalDSCMinted = 1000e18;
        uint256 collateralValueInUsd = 2000e18;

        // Test with different liquidation thresholds
        uint256 healthFactor75 = mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, 75);
        uint256 healthFactor50 = mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, 50);
        uint256 healthFactor25 = mockContract.mockCalculateHealthFactor(totalDSCMinted, collateralValueInUsd, 25);

        assertGt(healthFactor75, healthFactor50, "Higher threshold should give higher health factor");
        assertGt(healthFactor50, healthFactor25, "Higher threshold should give higher health factor");
    }

    ////////////////////////////////
    // Getter Function Tests
    ////////////////////////////////

    function test_GetPrecision() public view {
        uint256 precision = mockContract.mockGetPrecision();
        assertEq(precision, 1e18, "Precision should be 1e18");
    }

    function test_GetAdditionalFeedPrecision() public view {
        uint256 additionalPrecision = mockContract.mockGetAdditionalFeedPrecision();
        assertEq(additionalPrecision, 1e10, "Additional feed precision should be 1e10");
    }

    function test_GetFeedPrecision() public view {
        uint256 feedPrecision = mockContract.mockGetFeedPrecision();
        assertEq(feedPrecision, 1e8, "Feed precision should be 1e8");
    }

    ////////////////////////////////
    // Integration Tests
    ////////////////////////////////

    function test_CompleteUSDConversionWorkflow() public view {
        uint256 tokenAmount = 5e18; // 5 tokens

        // Convert tokens to USD
        uint256 usdValue = mockContract.mockGetUSDValue(address(priceFeed), tokenAmount);

        // Convert USD back to tokens
        uint256 tokenAmountBack = mockContract.mockGetTokenAmountFromUSD(address(priceFeed), usdValue);

        // Should be approximately equal
        uint256 difference =
            tokenAmountBack > tokenAmount ? tokenAmountBack - tokenAmount : tokenAmount - tokenAmountBack;

        assertLt(difference, tokenAmount / 100, "Conversion round trip should be accurate within 1%");
    }

    function test_HealthFactorWithRealWorldValues() public {
        // Simulate real-world scenario: $10,000 collateral, $4,000 debt
        uint256 collateralValue = 10000e18;
        uint256 dscMinted = 4000e18;
        uint256 threshold = 80; // 80% threshold (125% overcollateralization required)

        uint256 healthFactor = mockContract.mockCalculateHealthFactor(dscMinted, collateralValue, threshold);

        // Expected: (10000 * 80 / 100) * 1e18 / 4000 = 2e18 (200% health factor)
        uint256 expectedHealthFactor = 2e18;
        assertEq(healthFactor, expectedHealthFactor, "Real-world health factor calculation should be correct");
        assertGt(healthFactor, 1e18, "Position should be healthy");
    }

    function test_PriceFeedPrecisionHandling() public {
        // Test with different price feed decimals
        MockV3Aggregator priceFeed6Decimals = new MockV3Aggregator(6, 2000e6); // 6 decimals
        MockV3Aggregator priceFeed18Decimals = new MockV3Aggregator(18, 2000e18); // 18 decimals

        uint256 price6 = mockContract.mockGetLatestPrice(address(priceFeed6Decimals));
        uint256 price18 = mockContract.mockGetLatestPrice(address(priceFeed18Decimals));

        assertEq(price6, 2000e6, "Should handle 6 decimal price feed");
        assertEq(price18, 2000e18, "Should handle 18 decimal price feed");
    }

    ////////////////////////////////
    // Edge Cases
    ////////////////////////////////

    function test_ExtremeValues() public view {
        // Test with very large numbers
        uint256 maxCollateral = type(uint128).max;
        uint256 maxDSC = type(uint128).max;

        uint256 healthFactor = mockContract.mockCalculateHealthFactor(maxDSC, maxCollateral, LIQUIDATION_THRESHOLD);

        // Should not overflow and should be reasonable
        assertGt(healthFactor, 0, "Should handle extreme values without reverting");
        assertLt(healthFactor, type(uint256).max, "Should not return max value for non-zero DSC");
    }
}

// Mock contract to test DSCLib functions
contract MockDSCLibHelper {
    using DSCLib for *;

    constructor() {
        // Constructor intentionally empty - tokens will be transferred in tests
    }

    function mockValidateAmountGreaterThanZero(uint256 amount) external pure {
        DSCLib.validateAmountGreaterThanZero(amount);
    }

    function mockValidateAddressNotZero(address addr) external pure {
        DSCLib.validateAddressNotZero(addr);
    }

    function mockGetLatestPrice(address priceFeed) external view returns (uint256) {
        return DSCLib.getLatestPrice(priceFeed);
    }

    function mockGetUSDValue(address priceFeed, uint256 amount) external view returns (uint256) {
        return DSCLib.getUSDValue(priceFeed, amount);
    }

    function mockGetTokenAmountFromUSD(address priceFeed, uint256 usdAmount) external view returns (uint256) {
        return DSCLib.getTokenAmountFromUSD(priceFeed, usdAmount);
    }

    function mockSafeTransfer(address token, address to, uint256 amount) external {
        DSCLib.safeTransfer(token, to, amount);
    }

    function mockSafeTransferFrom(address token, address from, address to, uint256 amount) external {
        DSCLib.safeTransferFrom(token, from, to, amount);
    }

    function mockCalculateHealthFactor(
        uint256 totalDSCMinted,
        uint256 collateralValueInUsd,
        uint256 liquidationThreshold
    ) external pure returns (uint256) {
        return DSCLib.calculateHealthFactor(totalDSCMinted, collateralValueInUsd, liquidationThreshold);
    }

    function mockGetPrecision() external pure returns (uint256) {
        return DSCLib.getPrecision();
    }

    function mockGetAdditionalFeedPrecision() external pure returns (uint256) {
        return DSCLib.getAdditionalFeedPrecision();
    }

    function mockGetFeedPrecision() external pure returns (uint256) {
        return DSCLib.getFeedPrecision();
    }
}
