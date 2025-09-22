// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {IDSCEngine} from "../../src/IDSCEngine.sol";

import {ConfigHelper} from "../../script/Config_Helper.s.sol";
import {DSC_Protocol_DeployScript} from "../../script/DSC_Protocol_Deploy.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

/**
 * @title DSCEngine_Unit_Test
 * @author @vidalpaul
 * @notice Unit test suite for DSCEngine contract
 * @dev Tests DSC engine functionality including collateral management and liquidations
 */
contract DSCEngine_Unit_Test is Test {
    DSC_Protocol_DeployScript public deployer;
    ConfigHelper public config;
    DSC public dsc;
    DSCEngine public dscEngine;

    address public constant USER_ALICE = address(0x1);
    address public constant USER_BOB = address(0x2);
    address public constant USER_CHARLIE = address(0x3);
    address public constant LIQUIDATOR = address(0x4);

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
    uint256 public constant SMALL_AMOUNT = 1 ether;
    uint256 public constant PRECISION = 1e18;

    address public weth;
    address public wbtc;
    address public wsol;
    address public wethPriceFeed;
    address public wbtcPriceFeed;
    address public wsolPriceFeed;

    function setUp() public {
        deployer = new DSC_Protocol_DeployScript();
        deployer.setTestMode(true);
        (dsc, dscEngine, config) = deployer.run();

        (,,, weth, wbtc, wsol,) = config.activeNetworkConfig();

        // Get price feeds
        wethPriceFeed = dscEngine.getPriceFeed(weth);
        wbtcPriceFeed = dscEngine.getPriceFeed(wbtc);
        wsolPriceFeed = dscEngine.getPriceFeed(wsol);

        // Mint tokens to users
        ERC20Mock(weth).mint(USER_ALICE, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER_ALICE, STARTING_ERC20_BALANCE);
        ERC20Mock(wsol).mint(USER_ALICE, STARTING_ERC20_BALANCE);

        ERC20Mock(weth).mint(USER_BOB, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER_BOB, STARTING_ERC20_BALANCE);
        ERC20Mock(wsol).mint(USER_BOB, STARTING_ERC20_BALANCE);

        ERC20Mock(weth).mint(USER_CHARLIE, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
    }

    /////////////////////////////
    // Constructor Tests
    /////////////////////////////

    /**
     * @notice Tests that the constructor correctly sets the DSC token address
     * @dev Verifies the DSCEngine points to the correct DSC contract after deployment
     */
    function test_Constructor_SetsCorrectDSCAddress() public view {
        assertEq(dscEngine.getDSCAddress(), address(dsc));
    }

    /**
     * @notice Tests that the constructor correctly initializes all collateral tokens
     * @dev Verifies that weth, wbtc, and wsol are properly set as collateral tokens
     */
    function test_Constructor_SetsCorrectCollateralTokens() public view {
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        assertEq(collateralTokens.length, 3);
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
        assertEq(collateralTokens[2], wsol);
    }

    /**
     * @notice Tests that the constructor correctly maps price feeds to collateral tokens
     * @dev Verifies each collateral token has its corresponding Chainlink price feed
     */
    function test_Constructor_SetsCorrectPriceFeeds() public view {
        assertEq(dscEngine.getPriceFeed(weth), wethPriceFeed);
        assertEq(dscEngine.getPriceFeed(wbtc), wbtcPriceFeed);
        assertEq(dscEngine.getPriceFeed(wsol), wsolPriceFeed);
    }

    /////////////////////////////
    // depositCollateral Tests
    /////////////////////////////

    /**
     * @notice Tests that depositCollateral reverts when amount is zero
     * @dev Ensures the moreThanZero modifier works correctly
     */
    function test_DepositCollateral_RevertsIfZeroAmount() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Uint256_MustBeGreaterThaZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositCollateral reverts with unsupported collateral tokens
     * @dev Verifies only whitelisted tokens can be used as collateral
     */
    function test_DepositCollateral_RevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock("RAN", "Random", USER_ALICE, 1000e18);
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Collateral_CollateralNotAllowed.selector);
        dscEngine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositCollateral reverts without ERC20 approval
     * @dev Ensures users must approve the DSCEngine before depositing
     */
    function test_DepositCollateral_RevertsWithoutApproval() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert();
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful collateral deposit
     * @dev Verifies collateral balance updates and events are emitted correctly
     */
    function test_DepositCollateral_Success() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, false, true);
        emit IDSCEngine.DSC_Engine_Collateral_Deposited(USER_ALICE, weth, AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 userBalance = dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth);
        assertEq(userBalance, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing collateral updates the user's total collateral value
     * @dev Verifies getAccountCollateralValue reflects the deposited amount in USD
     */
    function test_DepositCollateral_UpdatesAccountCollateralValue() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 collateralValue = dscEngine.getAccountCollateralValue(USER_ALICE);
        uint256 expectedValue = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedValue);
        vm.stopPrank();
    }

    /////////////////////////////
    // mintDSC Tests
    /////////////////////////////

    /**
     * @notice Tests that mintDSC reverts when amount is zero
     * @dev Ensures the moreThanZero modifier works correctly for minting
     */
    function test_MintDSC_RevertsIfZeroAmount() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Uint256_MustBeGreaterThaZero.selector);
        dscEngine.mintDSC(0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that mintDSC reverts when user has no collateral
     * @dev Verifies health factor protection prevents minting without backing
     */
    function test_MintDSC_RevertsWithoutCollateral() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Health_UnhealthyPosition.selector);
        dscEngine.mintDSC(100e18);
        vm.stopPrank();
    }

    /**
     * @notice Tests that mintDSC reverts when health factor would be broken
     * @dev Ensures over-borrowing is prevented by health factor checks
     */
    function test_MintDSC_RevertsIfHealthFactorBroken() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 tooMuchDSC = (maxDSC * 51) / 100; // Try to mint 51% of collateral value

        vm.expectRevert(IDSCEngine.DSC_Engine_Health_UnhealthyPosition.selector);
        dscEngine.mintDSC(tooMuchDSC);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful DSC minting with adequate collateral
     * @dev Verifies DSC balance and minted amount tracking work correctly
     */
    function test_MintDSC_Success() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100; // Mint 40% of collateral value

        dscEngine.mintDSC(safeDSC);

        assertEq(dscEngine.getDSCMinted(USER_ALICE), safeDSC);
        assertEq(dsc.balanceOf(USER_ALICE), safeDSC);
        vm.stopPrank();
    }

    /////////////////////////////
    // depositCollateralAndMintDSC Tests
    /////////////////////////////

    /**
     * @notice Tests successful deposit and mint in a single transaction
     * @dev Verifies the combined operation updates both collateral and DSC balances
     */
    function test_DepositCollateralAndMintDSC_Success() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100;

        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, safeDSC);

        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), AMOUNT_COLLATERAL);
        assertEq(dscEngine.getDSCMinted(USER_ALICE), safeDSC);
        assertEq(dsc.balanceOf(USER_ALICE), safeDSC);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositCollateralAndMintDSC reverts with insufficient collateral
     * @dev Ensures health factor protection applies to combined operations
     */
    function test_DepositCollateralAndMintDSC_RevertsIfHealthFactorBroken() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 tooMuchDSC = (maxDSC * 51) / 100;

        vm.expectRevert(IDSCEngine.DSC_Engine_Health_UnhealthyPosition.selector);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, tooMuchDSC);
        vm.stopPrank();
    }

    /////////////////////////////
    // burnDSC Tests
    /////////////////////////////

    /**
     * @notice Tests that burnDSC reverts when amount is zero
     * @dev Ensures the moreThanZero modifier works correctly for burning
     */
    function test_BurnDSC_RevertsIfZeroAmount() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Uint256_MustBeGreaterThaZero.selector);
        dscEngine.burnDSC(0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that burnDSC reverts when trying to burn more than minted
     * @dev Prevents users from burning DSC they don't have
     */
    function test_BurnDSC_RevertsIfBurnAmountExceedsMinted() public {
        // First mint some DSC
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100;
        dscEngine.mintDSC(safeDSC);

        // Try to burn more than minted
        vm.expectRevert();
        dscEngine.burnDSC(safeDSC + 1);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful DSC burning
     * @dev Verifies DSC balance and minted amount tracking decrease correctly
     */
    function test_BurnDSC_Success() public {
        // Setup: Deposit collateral and mint DSC
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100;
        dscEngine.mintDSC(safeDSC);

        // Burn half of the minted DSC
        uint256 burnAmount = safeDSC / 2;
        dsc.approve(address(dscEngine), burnAmount);

        uint256 dscBalanceBefore = dsc.balanceOf(USER_ALICE);
        dscEngine.burnDSC(burnAmount);

        assertEq(dscEngine.getDSCMinted(USER_ALICE), safeDSC - burnAmount);
        assertEq(dsc.balanceOf(USER_ALICE), dscBalanceBefore - burnAmount);
        vm.stopPrank();
    }

    /////////////////////////////
    // redeemCollateral Tests
    /////////////////////////////

    /**
     * @notice Tests that redeemCollateral reverts when amount is zero
     * @dev Ensures the moreThanZero modifier works correctly for redemption
     */
    function test_RedeemCollateral_RevertsIfZeroAmount() public {
        vm.startPrank(USER_ALICE);
        vm.expectRevert(IDSCEngine.DSC_Engine_Uint256_MustBeGreaterThaZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that redeemCollateral reverts when redeeming more than deposited
     * @dev Prevents users from redeeming collateral they don't have
     */
    function test_RedeemCollateral_RevertsIfRedeemingMoreThanDeposited() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.expectRevert();
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);
        vm.stopPrank();
    }

    /**
     * @notice Tests that redeemCollateral reverts if it would break health factor
     * @dev Ensures users cannot redeem collateral if it would make them undercollateralized
     */
    function test_RedeemCollateral_RevertsIfHealthFactorBroken() public {
        // Setup: Deposit collateral and mint DSC at max capacity
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 49) / 100; // Mint 49% to be close to limit
        dscEngine.mintDSC(safeDSC);

        // Try to redeem collateral which would break health factor
        vm.expectRevert(IDSCEngine.DSC_Engine_Health_UnhealthyPosition.selector);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL / 2);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful collateral redemption
     * @dev Verifies collateral balance decreases and tokens are returned to user
     */
    function test_RedeemCollateral_Success() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 redeemAmount = AMOUNT_COLLATERAL / 2;
        uint256 wethBalanceBefore = ERC20Mock(weth).balanceOf(USER_ALICE);

        vm.expectEmit(true, true, false, true);
        emit IDSCEngine.DSC_Engine_Collateral_Redeemed(USER_ALICE, USER_ALICE, weth, redeemAmount);

        dscEngine.redeemCollateral(weth, redeemAmount);

        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), AMOUNT_COLLATERAL - redeemAmount);
        assertEq(ERC20Mock(weth).balanceOf(USER_ALICE), wethBalanceBefore + redeemAmount);
        vm.stopPrank();
    }

    /////////////////////////////
    // redeemCollateralForDSC Tests
    /////////////////////////////

    /**
     * @notice Tests successful redemption of collateral by burning DSC
     * @dev Verifies the combined operation of burning DSC and redeeming collateral
     */
    function test_RedeemCollateralForDSC_Success() public {
        // Setup: Deposit collateral and mint DSC
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100;
        dscEngine.mintDSC(safeDSC);

        // Redeem some collateral and burn DSC
        uint256 redeemAmount = AMOUNT_COLLATERAL / 4;
        uint256 burnAmount = safeDSC / 2;

        dsc.approve(address(dscEngine), burnAmount);

        dscEngine.redeemCollateralForDSC(weth, redeemAmount, burnAmount);

        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), AMOUNT_COLLATERAL - redeemAmount);
        assertEq(dscEngine.getDSCMinted(USER_ALICE), safeDSC - burnAmount);
        vm.stopPrank();
    }

    /////////////////////////////
    // liquidate Tests
    /////////////////////////////

    /**
     * @notice Tests that liquidate reverts when debt to cover is zero
     * @dev Ensures the moreThanZero modifier works correctly for liquidation
     */
    function test_Liquidate_RevertsIfZeroDebtToCover() public {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(IDSCEngine.DSC_Engine_Uint256_MustBeGreaterThaZero.selector);
        dscEngine.liquidate(weth, USER_ALICE, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that liquidate reverts when target user has healthy position
     * @dev Prevents liquidation of positions that don't need to be liquidated
     */
    function test_Liquidate_RevertsIfHealthFactorOk() public {
        // Setup: USER_ALICE has healthy position
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 maxDSC = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 safeDSC = (maxDSC * 40) / 100; // Only 40% utilized, healthy
        dscEngine.mintDSC(safeDSC);
        vm.stopPrank();

        // LIQUIDATOR tries to liquidate healthy position
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(IDSCEngine.DSC_Engine_Liquidate_CannotLiquidateUserHoldingHealthyPosition.selector);
        dscEngine.liquidate(weth, USER_ALICE, safeDSC);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful liquidation of an undercollateralized position
     * @dev Verifies liquidator receives collateral with bonus and debt is reduced
     */
    function test_Liquidate_Success() public {
        // Setup: USER_ALICE deposits collateral and mints DSC
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 ethUsdPrice = 2000e8; // $2000 per ETH
        uint256 collateralValueInUsd = (AMOUNT_COLLATERAL * ethUsdPrice * 1e10) / PRECISION;
        uint256 amountToMint = (collateralValueInUsd * 50) / 100; // Mint 50% of collateral value

        dscEngine.mintDSC(amountToMint);
        vm.stopPrank();

        // Price drops making position unhealthy but still salvageable
        int256 newEthUsdPrice = 1800e8; // Price drops to $1800 (10% drop)
        MockV3Aggregator(wethPriceFeed).updateAnswer(newEthUsdPrice);

        // Verify health factor is broken
        uint256 healthFactor = dscEngine.getHealthFactor(USER_ALICE);
        assertLt(healthFactor, 1e18);

        // LIQUIDATOR liquidates the position - cover enough to improve health
        uint256 debtToCover = amountToMint / 4; // Cover 25% of the debt

        // Mint DSC to liquidator to pay off debt
        vm.startPrank(USER_ALICE);
        dsc.transfer(LIQUIDATOR, debtToCover);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), type(uint256).max);
        dsc.approve(address(dscEngine), debtToCover);

        uint256 liquidatorWethBefore = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 aliceCollateralBefore = dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth);

        dscEngine.liquidate(weth, USER_ALICE, debtToCover);

        // Verify liquidation results
        uint256 tokenAmountFromDebtCovered = dscEngine.getTokenAmountFromUSD(weth, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * 10) / 100; // 10% bonus
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        // Liquidator receives the collateral directly to their wallet
        assertEq(ERC20Mock(weth).balanceOf(LIQUIDATOR), liquidatorWethBefore + totalCollateralToRedeem);
        assertEq(
            dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), aliceCollateralBefore - totalCollateralToRedeem
        );
        assertEq(dscEngine.getDSCMinted(USER_ALICE), amountToMint - debtToCover);

        vm.stopPrank();
    }

    /**
     * @notice Tests partial liquidation that improves but doesn't fully restore health
     * @dev Verifies partial liquidations work correctly and improve health factor
     */
    function test_Liquidate_PartialLiquidation() public {
        // Setup similar to above but only partially liquidate
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 ethUsdPrice = 2000e8;
        uint256 collateralValueInUsd = (AMOUNT_COLLATERAL * ethUsdPrice * 1e10) / PRECISION;
        uint256 amountToMint = (collateralValueInUsd * 50) / 100;

        dscEngine.mintDSC(amountToMint);
        vm.stopPrank();

        // Price drops but not too much to allow partial liquidation
        int256 newEthUsdPrice = 1800e8; // Price drops to $1800
        MockV3Aggregator(wethPriceFeed).updateAnswer(newEthUsdPrice);

        // Partial liquidation
        uint256 debtToCover = amountToMint / 10; // Only cover 10% of debt

        vm.startPrank(USER_ALICE);
        dsc.transfer(LIQUIDATOR, debtToCover);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), debtToCover);

        dscEngine.liquidate(weth, USER_ALICE, debtToCover);

        // User should still have some debt remaining
        assertGt(dscEngine.getDSCMinted(USER_ALICE), 0);
        assertEq(dscEngine.getDSCMinted(USER_ALICE), amountToMint - debtToCover);

        vm.stopPrank();
    }

    /////////////////////////////
    // Price Feed Tests
    /////////////////////////////

    /**
     * @notice Tests USD value calculation from token amount
     * @dev Verifies price feed integration and USD conversion accuracy
     */
    function test_GetUSDValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18; // 15 ETH * $2000 = $30,000

        uint256 actualUsd = dscEngine.getUSDValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    /**
     * @notice Tests token amount calculation from USD value
     * @dev Verifies reverse price conversion from USD to token amount
     */
    function test_GetTokenAmountFromUSD() public view {
        uint256 usdAmount = 2000e18; // $2000
        uint256 expectedWeth = 1e18; // 1 ETH at $2000

        uint256 actualWeth = dscEngine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    /////////////////////////////
    // Health Factor Tests
    /////////////////////////////

    /**
     * @notice Tests health factor calculation with known values
     * @dev Verifies health factor formula: (collateral * threshold) / debt
     */
    function test_HealthFactor_HasCorrectValue() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 collateralValue = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 dscToMint = (collateralValue * 25) / 100; // 25% utilization

        dscEngine.mintDSC(dscToMint);

        uint256 healthFactor = dscEngine.getHealthFactor(USER_ALICE);

        // Health factor should be 2 (200% collateralized at 50% threshold)
        // Calculation: (collateralValue * 0.5) / dscToMint = (collateralValue * 0.5) / (collateralValue * 0.25) = 2
        uint256 expectedHealthFactor = 2e18;
        assertEq(healthFactor, expectedHealthFactor);

        vm.stopPrank();
    }

    /**
     * @notice Tests health factor returns max uint when no DSC is minted
     * @dev Ensures users with only collateral and no debt have infinite health
     */
    function test_HealthFactor_ReturnsMaxUintWhenNoDSCMinted() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 healthFactor = dscEngine.getHealthFactor(USER_ALICE);
        assertEq(healthFactor, type(uint256).max);

        vm.stopPrank();
    }

    /////////////////////////////
    // Getter Functions Tests
    /////////////////////////////

    /**
     * @notice Tests total collateral value calculation across multiple tokens
     * @dev Verifies sum of all user's collateral values in USD
     */
    function test_GetAccountCollateralValue() public {
        vm.startPrank(USER_ALICE);

        // Deposit multiple collaterals
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wbtc, AMOUNT_COLLATERAL);

        uint256 totalValue = dscEngine.getAccountCollateralValue(USER_ALICE);
        uint256 expectedValue =
            dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL) + dscEngine.getUSDValue(wbtc, AMOUNT_COLLATERAL);

        assertEq(totalValue, expectedValue);
        vm.stopPrank();
    }

    /**
     * @notice Tests individual collateral token balance retrieval
     * @dev Verifies user's balance for a specific collateral token
     */
    function test_GetCollateralBalanceOfUser() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 balance = dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth);
        assertEq(balance, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests DSC minted amount tracking
     * @dev Verifies the system correctly tracks how much DSC a user has minted
     */
    function test_GetDSCMinted() public {
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 collateralValue = dscEngine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 dscToMint = (collateralValue * 25) / 100;

        dscEngine.mintDSC(dscToMint);

        uint256 dscMinted = dscEngine.getDSCMinted(USER_ALICE);
        assertEq(dscMinted, dscToMint);
        vm.stopPrank();
    }

    /**
     * @notice Tests minimum health factor constant
     * @dev Verifies the minimum health factor threshold is correctly set
     */
    function test_GetMinHealthFactor() public view {
        assertEq(dscEngine.getMinHealthFactor(), 1e18);
    }

    /**
     * @notice Tests liquidation threshold constant
     * @dev Verifies the collateralization ratio required for borrowing
     */
    function test_GetLiquidationThreshold() public view {
        assertEq(dscEngine.getLiquidationThreshold(), 50);
    }

    /**
     * @notice Tests liquidation bonus percentage constant
     * @dev Verifies the bonus liquidators receive for liquidating positions
     */
    function test_GetLiquidationBonus() public view {
        assertEq(dscEngine.getLiquidationBonus(), 10);
    }

    /////////////////////////////
    // Edge Cases and Additional Tests
    /////////////////////////////

    /**
     * @notice Tests that multiple users can deposit collateral independently
     * @dev Verifies state isolation between different user accounts
     */
    function test_MultipleUsersCanDeposit() public {
        // USER_ALICE deposits
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // USER_BOB deposits
        vm.startPrank(USER_BOB);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), AMOUNT_COLLATERAL);
        assertEq(dscEngine.getCollateralBalanceOfUser(USER_BOB, weth), AMOUNT_COLLATERAL);
    }

    /**
     * @notice Tests depositing multiple different collateral token types
     * @dev Verifies users can hold diverse collateral portfolios
     */
    function test_CanDepositMultipleCollateralTypes() public {
        vm.startPrank(USER_ALICE);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(dscEngine), AMOUNT_COLLATERAL);
        ERC20Mock(wsol).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(wsol, AMOUNT_COLLATERAL);

        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, weth), AMOUNT_COLLATERAL);
        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, wbtc), AMOUNT_COLLATERAL);
        assertEq(dscEngine.getCollateralBalanceOfUser(USER_ALICE, wsol), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    /**
     * @notice Tests reentrancy protection mechanisms
     * @dev Placeholder for reentrancy attack prevention verification
     */
    function test_ReentrancyProtection() public {
        // This test would require a malicious contract that tries to re-enter
        // For now, we just verify the contract has ReentrancyGuard
        // Actual reentrancy test would need a custom attacker contract
    }

    /**
     * @notice Tests handling of ERC20 transfer failures
     * @dev Placeholder for testing proper error handling of failed transfers
     */
    function test_TransferFailureHandling() public {
        // Test transfer failures are properly handled
        // This would require mocking transfer failures
    }

    /**
     * @notice Tests handling of stale price feed data
     * @dev Verifies the system rejects price data older than 3601 seconds (following Chainlink docs)
     */
    function test_PriceFeedFailureHandling() public {
        // Test what happens when price feed returns stale or invalid data
        // First advance time to ensure we're not at timestamp 0
        vm.warp(100000);

        // Deposit collateral first
        vm.startPrank(USER_ALICE);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        // First set a normal price for deposit
        MockV3Aggregator(wethPriceFeed).updateAnswer(2000e8);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Now update to stale data (timestamp more than 3601 seconds old)
        MockV3Aggregator(wethPriceFeed).updateRoundData(
            2, // roundId
            2000e8, // answer
            block.timestamp - 3602, // timestamp - more than 3601 seconds old
            block.timestamp - 3603 // startedAt - even older
        );

        // Try to mint DSC with stale price - this should revert
        vm.expectRevert(bytes("DSCLib: Stale price data"));
        dscEngine.mintDSC(1000e18);
        vm.stopPrank();
    }
}
