// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IDSCEngine
 * @author @vidalpaul
 * @notice Interface for the DSC (Decentralized Stable Coin) Engine contract
 * @dev This interface defines the core functionality for managing collateral and DSC minting/burning
 */
interface IDSCEngine {
    // =============================================================
    //                       ERRORS
    // =============================================================
    error DSC_Engine_Uint256_MustBeGreaterThaZero();
    error DSC_Engine_Collateral_CollateralNotAllowed();
    error DSC_Engine_Address_CannotBeZero();
    error DSC_Engine_Array_LengthsMustMatch();
    error DSC_Engine_Array_InvalidLength();

    // =============================================================
    //                       TYPES
    // =============================================================

    // =============================================================
    //                       EVENTS
    // =============================================================
    event DSC_Engine_PriceFeedSet(
        address indexed collateralToken,
        address indexed priceFeed
    );

    // =============================================================
    //                       FUNCTIONS SIGNATURES
    // =============================================================
    /**
     * @notice Deposits collateral into the protocol
     * @dev Transfers collateral from the user to the protocol
     * @param _collateralToken The address of the ERC20 token to deposit as collateral
     * @param _amountCollateral The amount of collateral to deposit
     */
    function safedDepositCollateral(
        address _collateralToken,
        uint256 _amountCollateral
    ) external;

    /**
     * @notice Redeems collateral from the protocol
     * @dev Returns collateral to the user, must maintain health factor above threshold
     * @param _collateralToken The address of the ERC20 token to redeem
     * @param _amountCollateral The amount of collateral to redeem
     */
    function redeemCollateral(
        address _collateralToken,
        uint256 _amountCollateral
    ) external;

    /**
     * @notice Mints DSC stablecoins
     * @dev User must have sufficient collateral to maintain health factor
     * @param _amountDSCToMint The amount of DSC to mint
     */
    function mintDSC(uint256 _amountDSCToMint) external;

    /**
     * @notice Deposits collateral and mints DSC in a single transaction
     * @dev Combines depositCollateral and mintDSC for gas efficiency
     * @param _collateralToken The address of the ERC20 token to deposit as collateral
     * @param _amountCollateral The amount of collateral to deposit
     * @param _amountDSCToMint The amount of DSC to mint
     */
    function depositCollateralAndMintDSC(
        address _collateralToken,
        uint256 _amountCollateral,
        uint256 _amountDSCToMint
    ) external;

    /**
     * @notice Redeems collateral by burning DSC
     * @dev Burns DSC and returns proportional collateral to the user
     * @param _collateralToken The address of the ERC20 token to redeem
     * @param _amountCollateral The amount of collateral to redeem
     * @param _amountDSCToBurn The amount of DSC to burn
     */
    function redeemCollateralForDSC(
        address _collateralToken,
        uint256 _amountCollateral,
        uint256 _amountDSCToBurn
    ) external;

    /**
     * @notice Burns DSC to improve health factor
     * @dev Destroys DSC tokens to reduce debt position
     * @param _amount The amount of DSC to burn
     */
    function burnDSC(uint256 _amount) external;

    /**
     * @notice Liquidates an undercollateralized position
     * @dev Allows liquidators to repay debt and receive collateral at a discount
     * @param _collateralToken The address of the collateral token to liquidate
     * @param _user The address of the user to liquidate
     * @param _debtToCover The amount of DSC debt to cover
     */
    function liquidate(
        address _collateralToken,
        address _user,
        uint256 _debtToCover
    ) external;

    /**
     * @notice Gets the health factor of a specific user
     * @dev Health factor determines if a position can be liquidated
     * @param _user The address of the user to check
     * @return healthFactor The calculated health factor (should be > 1e18 to avoid liquidation)
     */
    function getHealthFactor(address _user) external view returns (uint256);

    function safeBatchSetPriceFeeds(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds
    ) external;

    function safeSetPriceFeed(
        address _collateralToken,
        address _priceFeed
    ) external;

    function safeUnsetPriceFeed(address _collateralToken) external;
}
