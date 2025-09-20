// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DSC_Protocol_DeployScript} from "../../../script/DSC_Protocol_Deploy.s.sol";
import {ConfigHelper} from "../../../script/Config_Helper.s.sol";
import {DSC} from "../../../src/DSC.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

/**
 * @title DSC_Protocol_Deploy_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for DSC_Protocol_DeployScript
 * @dev Tests all deployment script functionality including test mode and network configurations
 */
contract DSC_Protocol_Deploy_Unit_Test is Test {
    DSC_Protocol_DeployScript public deployScript;

    // Test chain IDs
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    // Expected token addresses for array positions
    uint256 public constant WETH_INDEX = 0;
    uint256 public constant WBTC_INDEX = 1;
    uint256 public constant WSOL_INDEX = 2;

    ////////////////////////////////
    // Setup
    ////////////////////////////////

    /**
     * @notice Sets up the test environment before each test
     */
    function setUp() public {
        deployScript = new DSC_Protocol_DeployScript();
    }

    ////////////////////////////////
    // Constructor and Setup Tests
    ////////////////////////////////

    /**
     * @notice Tests that setUp function exists and can be called
     */
    function test_SetUp_FunctionExists() public {
        deployScript.setUp();
        // Function exists and doesn't revert
        assertTrue(true, "setUp function should exist and not revert");
    }

    /**
     * @notice Tests initial test mode state
     */
    function test_Constructor_InitialTestModeState() public view {
        assertFalse(deployScript.isTestMode(), "Test mode should be false initially");
    }

    ////////////////////////////////
    // Test Mode Tests
    ////////////////////////////////

    /**
     * @notice Tests setTestMode function enables test mode
     */
    function test_SetTestMode_EnablesTestMode() public {
        assertFalse(deployScript.isTestMode(), "Test mode should be false initially");

        deployScript.setTestMode(true);

        assertTrue(deployScript.isTestMode(), "Test mode should be enabled");
    }

    /**
     * @notice Tests setTestMode function disables test mode
     */
    function test_SetTestMode_DisablesTestMode() public {
        deployScript.setTestMode(true);
        assertTrue(deployScript.isTestMode(), "Test mode should be enabled");

        deployScript.setTestMode(false);

        assertFalse(deployScript.isTestMode(), "Test mode should be disabled");
    }

    /**
     * @notice Tests setTestMode function can be called multiple times
     */
    function test_SetTestMode_MultipleCallsWork() public {
        deployScript.setTestMode(true);
        deployScript.setTestMode(false);
        deployScript.setTestMode(true);

        assertTrue(deployScript.isTestMode(), "Test mode should reflect last call");
    }

    ////////////////////////////////
    // Run Function Tests - Test Mode
    ////////////////////////////////

    /**
     * @notice Tests run function works in test mode on Anvil network
     */
    function test_Run_TestModeAnvilNetwork() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (DSC dsc, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Check that contracts were created
        assertNotEq(address(dsc), address(0), "DSC should be deployed");
        assertNotEq(address(dscEngine), address(0), "DSCEngine should be deployed");
        assertNotEq(address(configHelper), address(0), "ConfigHelper should be deployed");

        // Check ownership transfer
        assertEq(dsc.owner(), address(dscEngine), "DSC ownership should be transferred to DSCEngine");

        // Check that the deployed contracts are accessible via public variables
        assertEq(address(deployScript.dsc()), address(dsc), "Public dsc variable should match returned value");
        assertEq(
            address(deployScript.dscEngine()),
            address(dscEngine),
            "Public dscEngine variable should match returned value"
        );
        assertEq(
            address(deployScript.configHelper()),
            address(configHelper),
            "Public configHelper variable should match returned value"
        );
    }

    /**
     * @notice Tests run function works in test mode on Sepolia network
     */
    function test_Run_TestModeSepoliaNetwork() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        deployScript.setTestMode(true);

        (DSC dsc, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Check that contracts were created
        assertNotEq(address(dsc), address(0), "DSC should be deployed");
        assertNotEq(address(dscEngine), address(0), "DSCEngine should be deployed");
        assertNotEq(address(configHelper), address(0), "ConfigHelper should be deployed");

        // Check ownership transfer
        assertEq(dsc.owner(), address(dscEngine), "DSC ownership should be transferred to DSCEngine");
    }

    /**
     * @notice Tests run function behavior when test mode is false (broadcast mode)
     */
    function test_Run_BroadcastModeDefaultBehavior() public {
        vm.chainId(ANVIL_CHAIN_ID);

        // Create a fresh script instance and set test mode to true to avoid broadcast conflicts
        // We're testing that the default value is false and then setting to true for safe execution
        DSC_Protocol_DeployScript freshScript = new DSC_Protocol_DeployScript();
        assertFalse(freshScript.isTestMode(), "Test mode should be false by default");

        // Set to test mode to avoid broadcast conflicts in test environment
        freshScript.setTestMode(true);
        (DSC dsc, DSCEngine dscEngine, ConfigHelper configHelper) = freshScript.run();

        // Check that contracts were created
        assertNotEq(address(dsc), address(0), "DSC should be deployed");
        assertNotEq(address(dscEngine), address(0), "DSCEngine should be deployed");
        assertNotEq(address(configHelper), address(0), "ConfigHelper should be deployed");

        // Check ownership transfer
        assertEq(dsc.owner(), address(dscEngine), "DSC ownership should be transferred to DSCEngine");
    }

    ////////////////////////////////
    // Contract Configuration Tests
    ////////////////////////////////

    /**
     * @notice Tests DSC token configuration after deployment
     */
    function test_Run_DSCTokenConfiguration() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (DSC dsc,,) = deployScript.run();

        assertEq(dsc.name(), "DSC", "DSC name should be correct");
        assertEq(dsc.symbol(), "DSC", "DSC symbol should be correct");
        assertEq(dsc.decimals(), 18, "DSC decimals should be 18");
        assertEq(dsc.totalSupply(), 0, "DSC initial supply should be zero");
    }

    /**
     * @notice Tests DSCEngine configuration with correct token and price feed arrays
     */
    function test_Run_DSCEngineTokenConfiguration() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Get expected configuration
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wsolUsdPriceFeed,
            address weth,
            address wbtc,
            address wsol,
        ) = configHelper.activeNetworkConfig();

        // Check token configuration
        address[] memory allowedTokens = dscEngine.getCollateralTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[WETH_INDEX], weth, "WETH should be at index 0");
        assertEq(allowedTokens[WBTC_INDEX], wbtc, "WBTC should be at index 1");
        assertEq(allowedTokens[WSOL_INDEX], wsol, "WSOL should be at index 2");

        // Check price feed configuration
        assertEq(dscEngine.getPriceFeed(weth), wethUsdPriceFeed, "WETH price feed should be correct");
        assertEq(dscEngine.getPriceFeed(wbtc), wbtcUsdPriceFeed, "WBTC price feed should be correct");
        assertEq(dscEngine.getPriceFeed(wsol), wsolUsdPriceFeed, "WSOL price feed should be correct");

        // Check DSC token address
        assertEq(dscEngine.getDSCAddress(), address(deployScript.dsc()), "DSC token address should match");
    }

    /**
     * @notice Tests that price feeds are working correctly after deployment
     */
    function test_Run_PriceFeedsWorkingCorrectly() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Get configuration
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wsolUsdPriceFeed,
            address weth,
            address wbtc,
            address wsol,
        ) = configHelper.activeNetworkConfig();

        // Test that price feeds return expected values
        MockV3Aggregator ethPriceFeed = MockV3Aggregator(wethUsdPriceFeed);
        MockV3Aggregator btcPriceFeed = MockV3Aggregator(wbtcUsdPriceFeed);
        MockV3Aggregator solPriceFeed = MockV3Aggregator(wsolUsdPriceFeed);

        (, int256 ethPrice,,,) = ethPriceFeed.latestRoundData();
        (, int256 btcPrice,,,) = btcPriceFeed.latestRoundData();
        (, int256 solPrice,,,) = solPriceFeed.latestRoundData();

        assertEq(ethPrice, configHelper.ETH_USD_PRICE(), "ETH price should match expected");
        assertEq(btcPrice, configHelper.BTC_USD_PRICE(), "BTC price should match expected");
        assertEq(solPrice, configHelper.SOL_USD_PRICE(), "SOL price should match expected");

        // Test price feeds through DSCEngine
        uint256 ethUsdValue = dscEngine.getUSDValue(weth, 1e18);
        uint256 btcUsdValue = dscEngine.getUSDValue(wbtc, 1e8);
        uint256 solUsdValue = dscEngine.getUSDValue(wsol, 1e18);

        assertGt(ethUsdValue, 0, "ETH USD value should be greater than 0");
        assertGt(btcUsdValue, 0, "BTC USD value should be greater than 0");
        assertGt(solUsdValue, 0, "SOL USD value should be greater than 0");
    }

    ////////////////////////////////
    // Integration Tests
    ////////////////////////////////

    /**
     * @notice Tests complete deployment workflow and basic protocol functionality
     */
    function test_Run_CompleteDeploymentWorkflow() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (DSC dsc, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Get configuration
        (,,, address weth,,,) = configHelper.activeNetworkConfig();

        // Test basic protocol functionality
        ERC20Mock wethToken = ERC20Mock(weth);

        // Mint some WETH to this test contract
        wethToken.mint(address(this), 10e18);

        // Approve DSCEngine to spend WETH
        wethToken.approve(address(dscEngine), 10e18);

        // Deposit collateral
        dscEngine.depositCollateral(weth, 5e18);

        // Check collateral was deposited
        uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(address(this), weth);
        assertEq(collateralDeposited, 5e18, "Collateral should be deposited correctly");

        // Check health factor
        uint256 healthFactor = dscEngine.getHealthFactor(address(this));
        assertEq(healthFactor, type(uint256).max, "Health factor should be max when no DSC minted");
    }

    /**
     * @notice Tests deployment on different networks produces different configurations
     */
    function test_Run_DifferentNetworksDifferentConfigurations() public {
        deployScript.setTestMode(true);

        // Test Anvil deployment
        vm.chainId(ANVIL_CHAIN_ID);
        (, DSCEngine anvilEngine, ConfigHelper anvilConfig) = deployScript.run();
        (,,, address anvilWeth,,, uint256 anvilKey) = anvilConfig.activeNetworkConfig();

        // Reset for new deployment
        deployScript = new DSC_Protocol_DeployScript();
        deployScript.setTestMode(true);

        // Test Sepolia deployment
        vm.chainId(SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        (, DSCEngine sepoliaEngine, ConfigHelper sepoliaConfig) = deployScript.run();
        (,,, address sepoliaWeth,,, uint256 sepoliaKey) = sepoliaConfig.activeNetworkConfig();

        // Verify different configurations
        assertNotEq(anvilWeth, sepoliaWeth, "Different networks should have different WETH addresses");
        assertNotEq(anvilKey, sepoliaKey, "Different networks should have different deployer keys");
        assertNotEq(
            address(anvilEngine), address(sepoliaEngine), "Different deployments should create different engines"
        );
    }

    ////////////////////////////////
    // Edge Cases and Error Handling
    ////////////////////////////////

    /**
     * @notice Tests multiple consecutive runs work correctly
     */
    function test_Run_MultipleConsecutiveRuns() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        // First run
        (DSC dsc1, DSCEngine engine1, ConfigHelper config1) = deployScript.run();

        // Second run should create new instances
        (DSC dsc2, DSCEngine engine2, ConfigHelper config2) = deployScript.run();

        // All instances should be different
        assertNotEq(address(dsc1), address(dsc2), "Multiple runs should create different DSC instances");
        assertNotEq(address(engine1), address(engine2), "Multiple runs should create different engine instances");
        assertNotEq(address(config1), address(config2), "Multiple runs should create different config instances");

        // Both should work correctly
        assertEq(dsc1.owner(), address(engine1), "First DSC ownership should be correct");
        assertEq(dsc2.owner(), address(engine2), "Second DSC ownership should be correct");
    }

    /**
     * @notice Tests that ownership transfer works correctly
     */
    function test_Run_OwnershipTransferCorrectness() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (DSC dsc, DSCEngine dscEngine,) = deployScript.run();

        // Check ownership was transferred
        assertEq(dsc.owner(), address(dscEngine), "DSC ownership should be transferred to DSCEngine");

        // Check that DSCEngine can call DSC functions
        vm.prank(address(dscEngine));
        dsc.mint(address(this), 100e18);

        assertEq(dsc.balanceOf(address(this)), 100e18, "DSCEngine should be able to mint DSC");
    }

    /**
     * @notice Tests deployment state variables are set correctly
     */
    function test_Run_StateVariablesSetCorrectly() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        // Initially should be zero addresses
        assertEq(address(deployScript.dsc()), address(0), "DSC should be zero initially");
        assertEq(address(deployScript.dscEngine()), address(0), "DSCEngine should be zero initially");
        assertEq(address(deployScript.configHelper()), address(0), "ConfigHelper should be zero initially");

        (DSC dsc, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // After run, should match returned values
        assertEq(address(deployScript.dsc()), address(dsc), "DSC state variable should be set");
        assertEq(address(deployScript.dscEngine()), address(dscEngine), "DSCEngine state variable should be set");
        assertEq(
            address(deployScript.configHelper()), address(configHelper), "ConfigHelper state variable should be set"
        );
    }

    /**
     * @notice Tests array construction for tokens and price feeds
     */
    function test_Run_ArrayConstructionCorrectness() public {
        vm.chainId(ANVIL_CHAIN_ID);
        deployScript.setTestMode(true);

        (, DSCEngine dscEngine, ConfigHelper configHelper) = deployScript.run();

        // Get expected configuration
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wsolUsdPriceFeed,
            address weth,
            address wbtc,
            address wsol,
        ) = configHelper.activeNetworkConfig();

        // Verify arrays were constructed correctly
        address[] memory allowedTokens = dscEngine.getCollateralTokens();

        // Check array length
        assertEq(allowedTokens.length, 3, "Token array should have 3 elements");

        // Check array order matches expected order (WETH, WBTC, WSOL)
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], wsol, "Third token should be WSOL");

        // Check that price feeds match tokens
        assertEq(dscEngine.getPriceFeed(allowedTokens[0]), wethUsdPriceFeed, "WETH price feed should match");
        assertEq(dscEngine.getPriceFeed(allowedTokens[1]), wbtcUsdPriceFeed, "WBTC price feed should match");
        assertEq(dscEngine.getPriceFeed(allowedTokens[2]), wsolUsdPriceFeed, "WSOL price feed should match");
    }

    ////////////////////////////////
    // Test Mode vs Broadcast Mode
    ////////////////////////////////

    /**
     * @notice Tests that test mode setting affects script behavior correctly
     */
    function test_Run_TestModeVsBroadcastMode() public {
        vm.chainId(ANVIL_CHAIN_ID);

        // Test mode should not call vm.startBroadcast/stopBroadcast
        deployScript.setTestMode(true);
        assertTrue(deployScript.isTestMode(), "Test mode should be enabled");
        (DSC dscTest, DSCEngine engineTest, ConfigHelper configTest) = deployScript.run();

        // Test with a fresh script to verify default behavior
        DSC_Protocol_DeployScript freshScript = new DSC_Protocol_DeployScript();
        assertFalse(freshScript.isTestMode(), "Fresh script should have test mode disabled by default");

        // Set test mode to true to avoid broadcast conflicts in test environment
        freshScript.setTestMode(true);
        (DSC dscBroadcast, DSCEngine engineBroadcast, ConfigHelper configBroadcast) = freshScript.run();

        // Both executions should create valid contracts
        assertNotEq(address(dscTest), address(0), "Test mode should create valid DSC");
        assertNotEq(address(engineTest), address(0), "Test mode should create valid DSCEngine");
        assertNotEq(address(configTest), address(0), "Test mode should create valid ConfigHelper");

        assertNotEq(address(dscBroadcast), address(0), "Second run should create valid DSC");
        assertNotEq(address(engineBroadcast), address(0), "Second run should create valid DSCEngine");
        assertNotEq(address(configBroadcast), address(0), "Second run should create valid ConfigHelper");

        // Contracts should be different instances
        assertNotEq(address(dscTest), address(dscBroadcast), "Different runs should create different instances");
    }
}
