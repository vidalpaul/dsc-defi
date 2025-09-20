// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ConfigHelper} from "../../../script/Config_Helper.s.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

/**
 * @title Config_Helper_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for ConfigHelper script
 * @dev Tests all ConfigHelper functionality including network configurations
 */
contract Config_Helper_Unit_Test is Test {
    ConfigHelper public configHelper;

    // Test chain IDs
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    // Expected Sepolia addresses
    address public constant SEPOLIA_WETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_WBTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant SEPOLIA_WSOL_USD_PRICE_FEED = 0x4ffC43a60e009B551865A93d232E33Fce9f01507;
    address public constant SEPOLIA_WETH = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant SEPOLIA_WBTC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public constant SEPOLIA_WSOL = 0x2644980C2480EB8F31263d24189e2AA5e7f8f1D3;

    ////////////////////////////////
    // Constructor Tests
    ////////////////////////////////

    /**
     * @notice Tests constructor sets Sepolia config when on Sepolia network
     */
    function test_Constructor_SetsSepoliaConfigOnSepoliaNetwork() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        
        configHelper = new ConfigHelper();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wsolUsdPriceFeed, address weth, address wbtc, address wsol, uint256 deployerKey) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory config = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed,
            wsolUsdPriceFeed: wsolUsdPriceFeed,
            weth: weth,
            wbtc: wbtc,
            wsol: wsol,
            deployerKey: deployerKey
        });

        assertEq(config.wethUsdPriceFeed, SEPOLIA_WETH_USD_PRICE_FEED, "WETH price feed should match Sepolia");
        assertEq(config.wbtcUsdPriceFeed, SEPOLIA_WBTC_USD_PRICE_FEED, "WBTC price feed should match Sepolia");
        assertEq(config.wsolUsdPriceFeed, SEPOLIA_WSOL_USD_PRICE_FEED, "WSOL price feed should match Sepolia");
        assertEq(config.weth, SEPOLIA_WETH, "WETH token should match Sepolia");
        assertEq(config.wbtc, SEPOLIA_WBTC, "WBTC token should match Sepolia");
        assertEq(config.wsol, SEPOLIA_WSOL, "WSOL token should match Sepolia");
    }

    /**
     * @notice Tests constructor sets Anvil config when on non-Sepolia network
     */
    function test_Constructor_SetsAnvilConfigOnNonSepoliaNetwork() public {
        vm.chainId(ANVIL_CHAIN_ID);
        
        configHelper = new ConfigHelper();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wsolUsdPriceFeed, address weth, address wbtc, address wsol, uint256 deployerKey) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory config = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed,
            wsolUsdPriceFeed: wsolUsdPriceFeed,
            weth: weth,
            wbtc: wbtc,
            wsol: wsol,
            deployerKey: deployerKey
        });

        assertNotEq(config.wethUsdPriceFeed, address(0), "WETH price feed should be set");
        assertNotEq(config.wbtcUsdPriceFeed, address(0), "WBTC price feed should be set");
        assertNotEq(config.wsolUsdPriceFeed, address(0), "WSOL price feed should be set");
        assertNotEq(config.weth, address(0), "WETH token should be set");
        assertNotEq(config.wbtc, address(0), "WBTC token should be set");
        assertNotEq(config.wsol, address(0), "WSOL token should be set");
        assertEq(config.deployerKey, configHelper.DEFAULT_ANVIL_PRIVATE_KEY(), "Deployer key should be default Anvil key");
    }

    ////////////////////////////////
    // Constants Tests
    ////////////////////////////////

    /**
     * @notice Tests that all constants are set correctly
     */
    function test_Constants_AreSetCorrectly() public {
        configHelper = new ConfigHelper();
        
        assertEq(configHelper.DECIMALS(), 8, "Decimals should be 8");
        assertEq(configHelper.ETH_USD_PRICE(), 2000e8, "ETH price should be 2000e8");
        assertEq(configHelper.BTC_USD_PRICE(), 50000e8, "BTC price should be 50000e8");
        assertEq(configHelper.SOL_USD_PRICE(), 100e8, "SOL price should be 100e8");
        assertEq(configHelper.DEFAULT_ANVIL_PRIVATE_KEY(), 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, "Default Anvil private key should match");
    }

    ////////////////////////////////
    // getSepoliaEthConfig Tests
    ////////////////////////////////

    /**
     * @notice Tests getSepoliaEthConfig returns correct configuration
     */
    function test_GetSepoliaEthConfig_ReturnsCorrectConfiguration() public {
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        configHelper = new ConfigHelper();
        
        ConfigHelper.NetworkConfig memory sepoliaConfig = configHelper.getSepoliaEthConfig();

        assertEq(sepoliaConfig.wethUsdPriceFeed, SEPOLIA_WETH_USD_PRICE_FEED, "WETH price feed should match");
        assertEq(sepoliaConfig.wbtcUsdPriceFeed, SEPOLIA_WBTC_USD_PRICE_FEED, "WBTC price feed should match");
        assertEq(sepoliaConfig.wsolUsdPriceFeed, SEPOLIA_WSOL_USD_PRICE_FEED, "WSOL price feed should match");
        assertEq(sepoliaConfig.weth, SEPOLIA_WETH, "WETH token should match");
        assertEq(sepoliaConfig.wbtc, SEPOLIA_WBTC, "WBTC token should match");
        assertEq(sepoliaConfig.wsol, SEPOLIA_WSOL, "WSOL token should match");
    }

    /**
     * @notice Tests getSepoliaEthConfig can be called multiple times
     */
    function test_GetSepoliaEthConfig_MultipleCallsReturnSameData() public {
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        configHelper = new ConfigHelper();
        
        ConfigHelper.NetworkConfig memory config1 = configHelper.getSepoliaEthConfig();
        ConfigHelper.NetworkConfig memory config2 = configHelper.getSepoliaEthConfig();

        assertEq(config1.wethUsdPriceFeed, config2.wethUsdPriceFeed, "Configs should be identical");
        assertEq(config1.wbtcUsdPriceFeed, config2.wbtcUsdPriceFeed, "Configs should be identical");
        assertEq(config1.wsolUsdPriceFeed, config2.wsolUsdPriceFeed, "Configs should be identical");
        assertEq(config1.weth, config2.weth, "Configs should be identical");
        assertEq(config1.wbtc, config2.wbtc, "Configs should be identical");
        assertEq(config1.wsol, config2.wsol, "Configs should be identical");
    }

    ////////////////////////////////
    // getOrCreateAnvilEthConfig Tests
    ////////////////////////////////

    /**
     * @notice Tests getOrCreateAnvilEthConfig creates new configuration when activeNetworkConfig is empty
     */
    function test_GetOrCreateAnvilEthConfig_CreatesNewConfigurationWhenEmpty() public {
        configHelper = new ConfigHelper();
        
        ConfigHelper.NetworkConfig memory anvilConfig = configHelper.getOrCreateAnvilEthConfig();

        assertNotEq(anvilConfig.wethUsdPriceFeed, address(0), "WETH price feed should be created");
        assertNotEq(anvilConfig.wbtcUsdPriceFeed, address(0), "WBTC price feed should be created");
        assertNotEq(anvilConfig.wsolUsdPriceFeed, address(0), "WSOL price feed should be created");
        assertNotEq(anvilConfig.weth, address(0), "WETH token should be created");
        assertNotEq(anvilConfig.wbtc, address(0), "WBTC token should be created");
        assertNotEq(anvilConfig.wsol, address(0), "WSOL token should be created");
        assertEq(anvilConfig.deployerKey, configHelper.DEFAULT_ANVIL_PRIVATE_KEY(), "Deployer key should be default");
    }

    /**
     * @notice Tests getOrCreateAnvilEthConfig returns existing config when already set
     */
    function test_GetOrCreateAnvilEthConfig_ReturnsExistingConfigWhenAlreadySet() public {
        vm.chainId(ANVIL_CHAIN_ID);
        configHelper = new ConfigHelper();
        
        // First call should create config
        ConfigHelper.NetworkConfig memory firstConfig = configHelper.getOrCreateAnvilEthConfig();
        
        // Second call should return the same config
        ConfigHelper.NetworkConfig memory secondConfig = configHelper.getOrCreateAnvilEthConfig();

        assertEq(firstConfig.wethUsdPriceFeed, secondConfig.wethUsdPriceFeed, "Should return same WETH price feed");
        assertEq(firstConfig.wbtcUsdPriceFeed, secondConfig.wbtcUsdPriceFeed, "Should return same WBTC price feed");
        assertEq(firstConfig.wsolUsdPriceFeed, secondConfig.wsolUsdPriceFeed, "Should return same WSOL price feed");
        assertEq(firstConfig.weth, secondConfig.weth, "Should return same WETH token");
        assertEq(firstConfig.wbtc, secondConfig.wbtc, "Should return same WBTC token");
        assertEq(firstConfig.wsol, secondConfig.wsol, "Should return same WSOL token");
    }

    /**
     * @notice Tests that created mock contracts have correct properties
     */
    function test_GetOrCreateAnvilEthConfig_CreatedMocksHaveCorrectProperties() public {
        configHelper = new ConfigHelper();
        
        ConfigHelper.NetworkConfig memory anvilConfig = configHelper.getOrCreateAnvilEthConfig();

        // Test price feeds
        MockV3Aggregator ethPriceFeed = MockV3Aggregator(anvilConfig.wethUsdPriceFeed);
        MockV3Aggregator btcPriceFeed = MockV3Aggregator(anvilConfig.wbtcUsdPriceFeed);
        MockV3Aggregator solPriceFeed = MockV3Aggregator(anvilConfig.wsolUsdPriceFeed);

        assertEq(ethPriceFeed.decimals(), configHelper.DECIMALS(), "ETH price feed decimals should match");
        assertEq(btcPriceFeed.decimals(), configHelper.DECIMALS(), "BTC price feed decimals should match");
        assertEq(solPriceFeed.decimals(), configHelper.DECIMALS(), "SOL price feed decimals should match");

        (, int256 ethPrice, , , ) = ethPriceFeed.latestRoundData();
        (, int256 btcPrice, , , ) = btcPriceFeed.latestRoundData();
        (, int256 solPrice, , , ) = solPriceFeed.latestRoundData();

        assertEq(ethPrice, configHelper.ETH_USD_PRICE(), "ETH price should match constant");
        assertEq(btcPrice, configHelper.BTC_USD_PRICE(), "BTC price should match constant");
        assertEq(solPrice, configHelper.SOL_USD_PRICE(), "SOL price should match constant");

        // Test ERC20 tokens
        ERC20Mock wethToken = ERC20Mock(anvilConfig.weth);
        ERC20Mock wbtcToken = ERC20Mock(anvilConfig.wbtc);
        ERC20Mock wsolToken = ERC20Mock(anvilConfig.wsol);

        assertEq(wethToken.name(), "WETH", "WETH name should be correct");
        assertEq(wethToken.symbol(), "WETH", "WETH symbol should be correct");
        assertEq(wbtcToken.name(), "WBTC", "WBTC name should be correct");
        assertEq(wbtcToken.symbol(), "WBTC", "WBTC symbol should be correct");
        assertEq(wsolToken.name(), "WSOL", "WSOL name should be correct");
        assertEq(wsolToken.symbol(), "WSOL", "WSOL symbol should be correct");

        assertEq(wethToken.totalSupply(), 1000e8, "WETH total supply should be correct");
        assertEq(wbtcToken.totalSupply(), 1000e8, "WBTC total supply should be correct");
        assertEq(wsolToken.totalSupply(), 1000e8, "WSOL total supply should be correct");
    }

    ////////////////////////////////
    // Network Configuration Tests
    ////////////////////////////////

    /**
     * @notice Tests that different chain IDs result in different configurations
     */
    function test_NetworkConfig_DifferentChainIdsDifferentConfigs() public {
        // Test Sepolia configuration
        vm.chainId(SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        ConfigHelper sepoliaHelper = new ConfigHelper();
        (address wethUsdPriceFeedS, address wbtcUsdPriceFeedS, address wsolUsdPriceFeedS, address wethS, address wbtcS, address wsolS, uint256 deployerKeyS) = sepoliaHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory sepoliaConfig = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeedS,
            wbtcUsdPriceFeed: wbtcUsdPriceFeedS,
            wsolUsdPriceFeed: wsolUsdPriceFeedS,
            weth: wethS,
            wbtc: wbtcS,
            wsol: wsolS,
            deployerKey: deployerKeyS
        });

        // Test Anvil configuration
        vm.chainId(ANVIL_CHAIN_ID);
        ConfigHelper anvilHelper = new ConfigHelper();
        (address wethUsdPriceFeedA, address wbtcUsdPriceFeedA, address wsolUsdPriceFeedA, address wethA, address wbtcA, address wsolA, uint256 deployerKeyA) = anvilHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory anvilConfig = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeedA,
            wbtcUsdPriceFeed: wbtcUsdPriceFeedA,
            wsolUsdPriceFeed: wsolUsdPriceFeedA,
            weth: wethA,
            wbtc: wbtcA,
            wsol: wsolA,
            deployerKey: deployerKeyA
        });

        assertNotEq(sepoliaConfig.wethUsdPriceFeed, anvilConfig.wethUsdPriceFeed, "Price feeds should be different");
        assertNotEq(sepoliaConfig.weth, anvilConfig.weth, "Tokens should be different");
        assertNotEq(sepoliaConfig.deployerKey, anvilConfig.deployerKey, "Deployer keys should be different");
    }

    /**
     * @notice Tests that unknown chain ID defaults to Anvil configuration
     */
    function test_NetworkConfig_UnknownChainIdDefaultsToAnvil() public {
        vm.chainId(999999); // Unknown chain ID
        
        configHelper = new ConfigHelper();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wsolUsdPriceFeed, address weth, address wbtc, address wsol, uint256 deployerKey) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory config = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed,
            wsolUsdPriceFeed: wsolUsdPriceFeed,
            weth: weth,
            wbtc: wbtc,
            wsol: wsol,
            deployerKey: deployerKey
        });

        assertNotEq(config.wethUsdPriceFeed, address(0), "Should create mock price feeds");
        assertEq(config.deployerKey, configHelper.DEFAULT_ANVIL_PRIVATE_KEY(), "Should use default Anvil key");
    }

    ////////////////////////////////
    // Integration Tests
    ////////////////////////////////

    /**
     * @notice Tests complete workflow of getting network configuration
     */
    function test_Integration_CompleteWorkflow() public {
        vm.chainId(ANVIL_CHAIN_ID);
        configHelper = new ConfigHelper();
        
        // Get the active config
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address wsolUsdPriceFeed, address weth, address wbtc, address wsol, uint256 deployerKey) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory activeConfig = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed,
            wsolUsdPriceFeed: wsolUsdPriceFeed,
            weth: weth,
            wbtc: wbtc,
            wsol: wsol,
            deployerKey: deployerKey
        });
        
        // Verify all addresses are set
        assertNotEq(activeConfig.wethUsdPriceFeed, address(0), "WETH price feed should be set");
        assertNotEq(activeConfig.wbtcUsdPriceFeed, address(0), "WBTC price feed should be set");
        assertNotEq(activeConfig.wsolUsdPriceFeed, address(0), "WSOL price feed should be set");
        assertNotEq(activeConfig.weth, address(0), "WETH should be set");
        assertNotEq(activeConfig.wbtc, address(0), "WBTC should be set");
        assertNotEq(activeConfig.wsol, address(0), "WSOL should be set");
        assertTrue(activeConfig.deployerKey != 0, "Deployer key should be set");

        // Test that we can interact with the created contracts
        MockV3Aggregator priceFeed = MockV3Aggregator(activeConfig.wethUsdPriceFeed);
        ERC20Mock token = ERC20Mock(activeConfig.weth);
        
        assertEq(priceFeed.decimals(), 8, "Price feed should have correct decimals");
        assertEq(token.decimals(), 18, "Token should have correct decimals");
    }

    ////////////////////////////////
    // Edge Cases
    ////////////////////////////////

    /**
     * @notice Tests that activeNetworkConfig can be read multiple times
     */
    function test_EdgeCase_ActiveConfigMultipleReads() public {
        configHelper = new ConfigHelper();
        
        (address wethUsdPriceFeed1, address wbtcUsdPriceFeed1, address wsolUsdPriceFeed1, address weth1, address wbtc1, address wsol1, uint256 deployerKey1) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory config1 = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed1,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed1,
            wsolUsdPriceFeed: wsolUsdPriceFeed1,
            weth: weth1,
            wbtc: wbtc1,
            wsol: wsol1,
            deployerKey: deployerKey1
        });
        (address wethUsdPriceFeed2, address wbtcUsdPriceFeed2, address wsolUsdPriceFeed2, address weth2, address wbtc2, address wsol2, uint256 deployerKey2) = configHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory config2 = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeed2,
            wbtcUsdPriceFeed: wbtcUsdPriceFeed2,
            wsolUsdPriceFeed: wsolUsdPriceFeed2,
            weth: weth2,
            wbtc: wbtc2,
            wsol: wsol2,
            deployerKey: deployerKey2
        });

        assertEq(config1.wethUsdPriceFeed, config2.wethUsdPriceFeed, "Multiple reads should return same data");
        assertEq(config1.deployerKey, config2.deployerKey, "Multiple reads should return same data");
    }

    /**
     * @notice Tests behavior when switching between networks
     */
    function test_EdgeCase_NetworkSwitching() public {
        // Start with Anvil
        vm.chainId(ANVIL_CHAIN_ID);
        ConfigHelper anvilHelper = new ConfigHelper();
        (address wethUsdPriceFeedA, address wbtcUsdPriceFeedA, address wsolUsdPriceFeedA, address wethA, address wbtcA, address wsolA, uint256 deployerKeyA) = anvilHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory anvilConfig = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeedA,
            wbtcUsdPriceFeed: wbtcUsdPriceFeedA,
            wsolUsdPriceFeed: wsolUsdPriceFeedA,
            weth: wethA,
            wbtc: wbtcA,
            wsol: wsolA,
            deployerKey: deployerKeyA
        });

        // Switch to Sepolia
        vm.chainId(SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "1234567890123456789012345678901234567890123456789012345678901234");
        ConfigHelper sepoliaHelper = new ConfigHelper();
        (address wethUsdPriceFeedS, address wbtcUsdPriceFeedS, address wsolUsdPriceFeedS, address wethS, address wbtcS, address wsolS, uint256 deployerKeyS) = sepoliaHelper.activeNetworkConfig();
        ConfigHelper.NetworkConfig memory sepoliaConfig = ConfigHelper.NetworkConfig({
            wethUsdPriceFeed: wethUsdPriceFeedS,
            wbtcUsdPriceFeed: wbtcUsdPriceFeedS,
            wsolUsdPriceFeed: wsolUsdPriceFeedS,
            weth: wethS,
            wbtc: wbtcS,
            wsol: wsolS,
            deployerKey: deployerKeyS
        });

        // Configurations should be different
        assertNotEq(anvilConfig.wethUsdPriceFeed, sepoliaConfig.wethUsdPriceFeed, "Different networks should have different configs");
    }
}