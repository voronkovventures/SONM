// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title SONMOracle
 * @dev Modernized SONM Price Oracle
 * Original: Custom OracleUSD → Modern: Chainlink-compatible
 * 
 * Provides USD price feeds for SONM marketplace
 */
contract SONMOracle is Ownable, Pausable {
    
    // ============ Structs ============
    
    struct PriceData {
        uint256 price;      // Price in USD * 10^18
        uint256 timestamp;  // Last update timestamp
        uint256 decimals;   // Price decimals
    }
    
    // ============ State Variables ============
    
    /// @notice Authorized oracles
    mapping(address => bool) public oracles;
    
    /// @notice Price data per symbol
    mapping(bytes32 => PriceData) public prices;
    
    /// @notice Maximum price age (default: 1 hour)
    uint256 public maxPriceAge = 1 hours;
    
    /// @notice Minimum oracle count for consensus (if using multi-oracle)
    uint256 public minOracleCount = 1;
    
    /// @notice Marketplace contract
    address public marketplace;
    
    // ============ Events ============
    
    event PriceUpdated(
        bytes32 indexed symbol,
        uint256 price,
        uint256 timestamp,
        address indexed oracle
    );
    
    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    event MarketplaceSet(address indexed marketplace);
    event MaxPriceAgeUpdated(uint256 newAge);
    
    // ============ Errors ============
    
    error UnauthorizedOracle();
    error StalePrice();
    error InvalidPrice();
    error InvalidSymbol();
    error OnlyMarketplace();
    
    // ============ Modifiers ============
    
    modifier onlyOracle() {
        if (!oracles[msg.sender]) revert UnauthorizedOracle();
        _;
    }
    
    modifier onlyMarketplace() {
        if (msg.sender != marketplace) revert OnlyMarketplace();
        _;
    }
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        // Deployer is first oracle
        oracles[msg.sender] = true;
        emit OracleAdded(msg.sender);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Add authorized oracle
     * @param _oracle Oracle address
     */
    function addOracle(address _oracle) external onlyOwner {
        oracles[_oracle] = true;
        emit OracleAdded(_oracle);
    }
    
    /**
     * @notice Remove authorized oracle
     * @param _oracle Oracle address
     */
    function removeOracle(address _oracle) external onlyOwner {
        oracles[_oracle] = false;
        emit OracleRemoved(_oracle);
    }
    
    /**
     * @notice Set marketplace contract
     * @param _marketplace Marketplace address
     */
    function setMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
        emit MarketplaceSet(_marketplace);
    }
    
    /**
     * @notice Set maximum price age
     * @param _maxPriceAge New maximum age in seconds
     */
    function setMaxPriceAge(uint256 _maxPriceAge) external onlyOwner {
        maxPriceAge = _maxPriceAge;
        emit MaxPriceAgeUpdated(_maxPriceAge);
    }
    
    // ============ Price Feed Functions ============
    
    /**
     * @notice Update price for a symbol (oracle only)
     * @param _symbol Asset symbol (e.g., "SNM", "ETH")
     * @param _price Price in USD * 10^18
     */
    function updatePrice(bytes32 _symbol, uint256 _price) external onlyOracle whenNotPaused {
        if (_symbol == bytes32(0)) revert InvalidSymbol();
        if (_price == 0) revert InvalidPrice();
        
        prices[_symbol] = PriceData({
            price: _price,
            timestamp: block.timestamp,
            decimals: 18
        });
        
        emit PriceUpdated(_symbol, _price, block.timestamp, msg.sender);
    }
    
    /**
     * @notice Batch update prices
     * @param _symbols Array of symbols
     * @param _prices Array of prices
     */
    function updatePricesBatch(
        bytes32[] calldata _symbols,
        uint256[] calldata _prices
    ) external onlyOracle whenNotPaused {
        if (_symbols.length != _prices.length) revert InvalidPrice();
        
        for (uint256 i = 0; i < _symbols.length; i++) {
            if (_symbols[i] == bytes32(0)) continue;
            if (_prices[i] == 0) continue;
            
            prices[_symbols[i]] = PriceData({
                price: _prices[i],
                timestamp: block.timestamp,
                decimals: 18
            });
            
            emit PriceUpdated(_symbols[i], _prices[i], block.timestamp, msg.sender);
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get price for a symbol
     * @param _symbol Asset symbol
     * @return price Price in USD * 10^18
     * @return timestamp Last update timestamp
     */
    function getPrice(bytes32 _symbol) external view returns (uint256 price, uint256 timestamp) {
        PriceData memory data = prices[_symbol];
        if (block.timestamp - data.timestamp > maxPriceAge) revert StalePrice();
        return (data.price, data.timestamp);
    }
    
    /**
     * @notice Get price without staleness check
     * @param _symbol Asset symbol
     */
    function getPriceUnsafe(bytes32 _symbol) external view returns (uint256, uint256, uint256) {
        PriceData memory data = prices[_symbol];
        return (data.price, data.timestamp, data.decimals);
    }
    
    /**
     * @notice Check if price is stale
     * @param _symbol Asset symbol
     */
    function isPriceStale(bytes32 _symbol) external view returns (bool) {
        return block.timestamp - prices[_symbol].timestamp > maxPriceAge;
    }
    
    /**
     * @notice Get USD value for token amount
     * @param _symbol Token symbol
     * @param _amount Token amount
     * @return USD value
     */
    function getUSDValue(bytes32 _symbol, uint256 _amount) external view returns (uint256) {
        PriceData memory data = prices[_symbol];
        if (block.timestamp - data.timestamp > maxPriceAge) revert StalePrice();
        
        return (_amount * data.price) / 10**data.decimals;
    }
    
    // ============ Utility Functions ============
    
    /**
     * @notice String to bytes32 conversion
     */
    function stringToBytes32(string memory source) external pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        
        assembly {
            result := mload(add(source, 32))
        }
    }
    
    /**
     * @notice Bytes32 to string conversion
     */
    function bytes32ToString(bytes32 _bytes32) external pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}