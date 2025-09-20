// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// =============================================================
//                       IMPORTS
// =============================================================
// DSC imports
import {IDSCEngine} from "./IDSCEngine.sol";
import {DSC} from "./DSC.sol";

// OpenZeppelin imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Chainlink imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author @vidalpaul
 * @notice Core engine for the Decentralized Stable Coin (DSC) system
 * @dev This contract manages collateral deposits, DSC minting/burning, and liquidations
 *
 * The system is designed to maintain a 1:1 peg with USD through overcollateralization.
 * Users can:
 * - Deposit collateral (supported ERC20 tokens)
 * - Mint DSC stablecoins against their collateral
 * - Redeem collateral by burning DS
 * - Liquidate undercollateralized positions
 *
 * @custom:security-contact security@dscprotocol.com
 */
contract DSCEngine is IDSCEngine, ReentrancyGuard {
    // =============================================================
    //                       ERRORS
    // =============================================================
    // Errors are defined in IDSCEngine interface

    // =============================================================
    //                       TYPES
    // =============================================================
    // Types/Structs/Enums are defined in IDSCEngine interface

    // =============================================================
    //                       STATE VARIABLES
    // =============================================================

    uint256 private constant MAX_SET_PRICE_FEEDS_ARRAY_LENGTH = 3;
    uint256 private constant MIN_COLLATERAL_TOKENS = 1;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    uint256 private s_activeCollateralCount;
    address[] private s_collateralTokens;

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_userToCollateralTokenToAmount;
    mapping(address user => uint256 dscAmountMinted)
        private s_userToDSCAmountMinted;

    DSC private immutable i_dsc;

    // =============================================================
    //                       EVENTS
    // =============================================================
    // Events are defined in IDSCEngine interface

    // =============================================================
    //                       MODIFIERS
    // =============================================================

    modifier addressIsNotZero(address _address) {
        require(_address != address(0), DSC_Engine_Address_CannotBeZero());
        _;
    }

    modifier collateralIsMapped(address _collateralToken) {
        require(
            s_priceFeeds[_collateralToken] != address(0),
            DSC_Engine_Collateral_CollateralNotAllowed()
        );
        _;
    }

    /**
     * @notice Ensures the provided amount is greater than zero
     * @param _amount The amount to validate
     */
    modifier moreThanZero(uint256 _amount) {
        require(_amount > 0, DSC_Engine_Uint256_MustBeGreaterThaZero());
        _;
    }

    /**
     * @notice Ensures arrays have matching lengths
     * @param _length1 First array length
     * @param _length2 Second array length
     */
    modifier matchingArrayLengths(uint256 _length1, uint256 _length2) {
        require(_length1 == _length2, DSC_Engine_Array_LengthsMustMatch());
        _;
    }

    /**
     * @notice Ensures array length is within acceptable bounds
     * @param _length Array length to validate
     */
    modifier validArrayLength(uint256 _length) {
        require(
            _length > 0 && _length <= MAX_SET_PRICE_FEEDS_ARRAY_LENGTH,
            DSC_Engine_Array_InvalidLength()
        );
        _;
    }

    /**
     * @notice Ensures minimum collateral tokens remain active
     */
    modifier maintainsMinimumCollateral() {
        require(
            s_activeCollateralCount > MIN_COLLATERAL_TOKENS,
            DSC_Engine_Collateral_CannotRemoveLastCollateral()
        );
        _;
    }

    /**
     * @notice Ensures no active collateral balance exists for token
     * @param _collateralToken The collateral token to check
     */
    modifier noActiveBalance(address _collateralToken) {
        require(
            IERC20(_collateralToken).balanceOf(address(this)) == 0,
            DSC_Engine_Collateral_HasActiveBalance()
        );
        _;
    }

    // =============================================================
    //                       CONSTRUCTOR
    // =============================================================
    /**
     * @notice Initializes the DSC Engine contract
     * @dev Sets up initial parameters and configurations
     */
    constructor(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds,
        address _dscAddress
    ) addressIsNotZero(_dscAddress) {
        i_dsc = DSC(_dscAddress);
        batchSetPriceFeeds(_collateralTokens, _priceFeeds);
    }

    // =============================================================
    //                       EXTERNAL FUNCTIONS
    // =============================================================

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
    ) external nonReentrant {
        depositCollateral(_collateralToken, _amountCollateral);
        mintDSC(_amountDSCToMint);
    }

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
    ) external moreThanZero(_amountCollateral) {
        burnDSC(_amountDSCToBurn);
        redeemCollateral(_collateralToken, _amountCollateral);
    }

    /**
     * @notice Burns DSC to improve health factor
     * @dev Destroys DSC tokens to reduce debt position
     * @param _amount The amount of DSC to burn
     */
    function burnDSC(uint256 _amount) public moreThanZero(_amount) {
        s_userToDSCAmountMinted[msg.sender] -= _amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), _amount);

        require(success, DSC_Engine_DSC_BurnFailed());

        i_dsc.burn(_amount);

        /*
         * @dev note to auditor: check if this is really necessary
         */
        _revertIfUnhealthy(msg.sender);
    }

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
    ) external {}

    /**
     * @notice Sets a price feed for a collateral token
     * @dev Validates addresses and emits PriceFeedSet event
     * @param _collateralToken The collateral token address
     * @param _priceFeed The price feed address
     */
    function setPriceFeed(
        address _collateralToken,
        address _priceFeed
    )
        public
        override
        addressIsNotZero(_collateralToken)
        addressIsNotZero(_priceFeed)
    {
        // If this is a new collateral token, add to array and increment counter
        if (s_priceFeeds[_collateralToken] == address(0)) {
            s_collateralTokens.push(_collateralToken);
            s_activeCollateralCount++;
        }

        s_priceFeeds[_collateralToken] = _priceFeed;
        emit DSC_Engine_PriceFeed_Set(_collateralToken, _priceFeed);
    }

    /**
     * @notice Removes a price feed for a collateral token
     * @dev Ensures minimum collateral tokens remain and no active balance exists
     * @param _collateralToken The collateral token to remove
     */
    function unsetPriceFeed(
        address _collateralToken
    )
        external
        override
        collateralIsMapped(_collateralToken)
        maintainsMinimumCollateral
        noActiveBalance(_collateralToken)
    {
        s_priceFeeds[_collateralToken] = address(0);
        s_activeCollateralCount--;

        // Remove from array
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            if (s_collateralTokens[i] == _collateralToken) {
                s_collateralTokens[i] = s_collateralTokens[
                    s_collateralTokens.length - 1
                ];
                s_collateralTokens.pop();
                break;
            }
        }

        emit DSC_Engine_PriceFeed_Unset(_collateralToken);
    }

    // =============================================================
    //                       PUBLIC FUNCTIONS
    // =============================================================

    /**
     * @notice Deposits collateral into the protocol
     * @dev Transfers collateral from the user to the protocol
     * @param _collateralToken The address of the ERC20 token to deposit as collateral
     * @param _amountCollateral The amount of collateral to deposit
     * @notice Follows CEI
     */
    function depositCollateral(
        address _collateralToken,
        uint256 _amountCollateral
    )
        public
        moreThanZero(_amountCollateral)
        collateralIsMapped(_collateralToken)
        nonReentrant
    {
        s_userToCollateralTokenToAmount[msg.sender][
            _collateralToken
        ] += _amountCollateral;

        emit DSC_Engine_Collateral_Deposited(
            msg.sender,
            _collateralToken,
            _amountCollateral
        );

        bool success = IERC20(_collateralToken).transferFrom(
            msg.sender,
            address(this),
            _amountCollateral
        );

        require(success == true, DSC_Engine_Collateral_TransferFailed());
    }

    /**
     * @notice Redeems collateral from the protocol
     * @dev Returns collateral to the user, must maintain health factor above threshold
     * @param _collateralToken The address of the ERC20 token to redeem
     * @param _amountCollateral The amount of collateral to redeem
     */
    function redeemCollateral(
        address _collateralToken,
        uint256 _amountCollateral
    )
        external
        collateralIsMapped(_collateralToken)
        moreThanZero(_amountCollateral)
        nonReentrant
    {
        s_userToCollateralTokenToAmount[msg.sender][
            _collateralToken
        ] -= _amountCollateral;

        emit DSC_Engine_Collateral_Redeemed(
            msg.sender,
            _collateralToken,
            _amountCollateral
        );

        bool success = IERC20(_collateralToken).transfer(
            msg.sender,
            _amountCollateral
        );

        require(success, DSC_Engine_Collateral_TransferFailed());

        _revertIfUnhealthy(msg.sender);
    }

    /**
     * @notice Mints DSC stablecoins
     * @dev User must have sufficient collateral to maintain health factor
     * @param _amountDSCToMint The amount of DSC to mint
     */

    function mintDSC(
        uint256 _amountDSCToMint
    ) public moreThanZero(_amountDSCToMint) nonReentrant returns (bool minted) {
        s_userToDSCAmountMinted[msg.sender] += _amountDSCToMint;

        _revertIfUnhealthy(msg.sender);

        minted = i_dsc.mint(msg.sender, _amountDSCToMint);

        require(minted, DSC_Engine_DSC_MintFailed());
    }

    /**
     * @notice Batch sets price feeds for multiple collateral tokens
     * @dev Validates array lengths and calls safeSetPriceFeed for each pair
     * @param _collateralTokens Array of collateral token addresses
     * @param _priceFeeds Array of price feed addresses
     */
    function batchSetPriceFeeds(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds
    )
        public
        override
        validArrayLength(_collateralTokens.length)
        matchingArrayLengths(_collateralTokens.length, _priceFeeds.length)
    {
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            setPriceFeed(_collateralTokens[i], _priceFeeds[i]);
        }
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================
    function _getAccountInformation(
        address _user
    )
        internal
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_userToDSCAmountMinted[_user];
        collateralValueInUSD = getAccountCollateralValue(_user);
    }

    function _revertIfUnhealthy(address _user) internal view {
        require(
            _healthFactor(_user) >= MIN_HEALTH_FACTOR,
            DSC_Engine_Health_UnhealthyPosition()
        );
    }

    function _healthFactor(
        address _user
    ) internal view returns (uint256 userHealthFactor) {
        (
            uint256 totalDSCMinted,
            uint256 collateralValueInUSD
        ) = _getAccountInformation(_user);

        return _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);
    }

    function _calculateHealthFactor(
        uint256 totalDSCMinted,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalDSCMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    // =============================================================
    //                       PRIVATE FUNCTIONS
    // =============================================================

    // =============================================================
    //                       VIEW & PURE FUNCTIONS
    // =============================================================

    /**
     * @notice Gets the health factor of a specific user
     * @dev Health factor determines if a position can be liquidated
     * @param _user The address of the user to check
     * @return healthFactor The calculated health factor (should be > 1e18 to avoid liquidation)
     */
    function getHealthFactor(
        address _user
    ) public view returns (uint256 healthFactor) {
        return _healthFactor(_user);
    }

    function getAccountCollateralValue(
        address _user
    ) public view returns (uint256 totalCollateralValueInUSD) {
        totalCollateralValueInUSD = 0;

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_userToCollateralTokenToAmount[_user][token];

            if (amount > 0) {
                totalCollateralValueInUSD += getUSDValue(token, amount);
            }
        }
    }

    function getUSDValue(
        address _collateralToken,
        uint256 _amount
    ) public view returns (uint256 usdValue) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_collateralToken]
        );

        (, int256 price, , , ) = priceFeed.latestRoundData();

        // The following code supposes the feed answers with 8 decimals place,
        // which is true for ETH/USD, BTC/USD, etc,
        // but may not be true for every single pair feed
        // so fix it: TODO!
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / 1e18;
    }
}
