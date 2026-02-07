// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SNMToken
 * @dev Modernized SONM Token (SNM) - ERC20 with burn functionality
 * Original: Solidity 0.4.x → Modern: Solidity 0.8.20
 * 
 * Changes from original:
 * - Updated to Solidity 0.8.20
 * - Uses OpenZeppelin 5.x contracts
 * - Added burn functionality
 * - Proper constructor with Ownable pattern
 * - Immutable max supply
 */
contract SNMToken is ERC20, ERC20Burnable, Ownable {
    
    /// @notice Maximum token supply: 444 million SNM
    uint256 public constant MAX_SUPPLY = 444_000_000 * 10**18;
    
    /// @notice Emitted when tokens are minted (only before ownership renounced)
    event TokensMinted(address indexed to, uint256 amount);
    
    /**
     * @dev Constructor mints initial supply to deployer
     * @param initialSupply Initial amount to mint (can be 0 for gradual minting)
     */
    constructor(uint256 initialSupply) ERC20("SONM Token", "SNM") Ownable(msg.sender) {
        require(initialSupply <= MAX_SUPPLY, "SNM: initial supply exceeds max");
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }
    
    /**
     * @notice Mint new tokens (only owner)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "SNM: mint exceeds max supply");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @notice Get remaining mintable supply
     */
    function remainingMintableSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    /**
     * @notice Decimals override (18 is default, but explicit for clarity)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}