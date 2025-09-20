// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DSC (Decentralized Stable Coin)
 * @author @vidalpaul
 * @notice This contract implements a decentralized stablecoin with controlled minting and burning capabilities
 * @dev Extends ERC20Burnable for burn functionality and Ownable for access control
 * @custom:security-contact security@example.com
 */
contract DSC is ERC20Burnable, Ownable {
    /// @notice Thrown when attempting to burn zero tokens
    error DSC_Burn_AmountCannotBeZero();

    /// @notice Thrown when attempting to burn more tokens than the sender's balance
    error DSC_Burn_AmountCannotBeMoreThanBalance();

    /// @notice Thrown when attempting to mint tokens to the zero address
    error DSC_Mint_RecipientCannotBeZeroAddress();

    /// @notice Thrown when attempting to mint zero tokens
    error DSC_Mint_AmountCannotBeZero();

    /**
     * @notice Initializes the DSC token with name "DSC" and symbol "DSC"
     * @dev Sets the deployer as the initial owner
     */
    constructor() ERC20("DSC", "DSC") Ownable(msg.sender) {}

    /**
     * @notice Burns a specified amount of tokens from the caller's balance
     * @dev Only callable by the contract owner. Includes safety checks for amount validity
     * @param _amount The amount of tokens to burn (must be > 0 and <= sender's balance)
     * @custom:throws DSC_Burn_AmountCannotBeZero if _amount is 0
     * @custom:throws DSC_Burn_AmountCannotBeMoreThanBalance if _amount exceeds sender's balance
     */
    function burn(uint256 _amount) public override onlyOwner {
        require(_amount > 0, DSC_Burn_AmountCannotBeZero());
        require(
            _amount <= balanceOf(msg.sender),
            DSC_Burn_AmountCannotBeMoreThanBalance()
        );
        super.burn(_amount);
    }

    /**
     * @notice Mints new tokens to a specified address
     * @dev Only callable by the contract owner. Includes safety checks for recipient and amount
     * @param _to The address that will receive the minted tokens
     * @param _amount The amount of tokens to mint
     * @return bool Returns true if the mint operation is successful
     * @custom:throws DSC_Mint_AmountCannotBeZero if _amount is 0
     * @custom:throws DSC_Mint_RecipientCannotBeZeroAddress if _to is the zero address
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        require(_amount > 0, DSC_Mint_AmountCannotBeZero());
        require(_to != address(0), DSC_Mint_RecipientCannotBeZeroAddress());
        _mint(_to, _amount);
        return true;
    }
}
