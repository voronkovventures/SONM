// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ProfileRegistry
 * @dev Modernized SONM Profile Registry
 * Original: Solidity 0.4.x → Modern: Solidity 0.8.20
 * 
 * Manages identity levels, certificates, and validators
 */
contract ProfileRegistry is Ownable, Pausable {
    
    // ============ Enums ============
    
    enum IdentityLevel {
        UNKNOWN,
        ANONYMOUS,
        REGISTERED,
        IDENTIFIED,
        PROFESSIONAL
    }
    
    // ============ Structs ============
    
    struct Certificate {
        address from;
        address to;
        uint256 attributeType;
        bytes value;
        uint256 createdAt;
    }
    
    // ============ State Variables ============
    
    /// @notice SONM validator level (-1 in original, now using type int8)
    int8 public constant SONM_VALIDATOR_LEVEL = -1;
    
    /// @notice Certificate counter
    uint256 public certificatesCount;
    
    /// @notice Validator levels mapping
    mapping(address => int8) public validators;
    
    /// @notice Certificates storage
    mapping(uint256 => Certificate) public certificates;
    
    /// @notice Certificate values per owner and type
    mapping(address => mapping(uint256 => bytes)) public certificateValue;
    
    /// @notice Certificate count per owner and type
    mapping(address => mapping(uint256 => uint256)) public certificateCount;
    
    // ============ Events ============
    
    event ValidatorCreated(address indexed validator, int8 level);
    event ValidatorDeleted(address indexed validator);
    event CertificateCreated(
        uint256 indexed id,
        address indexed from,
        address indexed to,
        uint256 attributeType
    );
    event CertificateUpdated(uint256 indexed id);
    
    // ============ Errors ============
    
    error InvalidLevel();
    error ValidatorNotFound();
    error ValidatorAlreadyExists();
    error InvalidAttributeType();
    error EmptyValue();
    error CertificateNotFound();
    error Unauthorized();
    error ValueMismatch();
    
    // ============ Modifiers ============
    
    modifier onlySonm() {
        if (getValidatorLevel(msg.sender) != SONM_VALIDATOR_LEVEL) {
            revert Unauthorized();
        }
        _;
    }
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        validators[msg.sender] = SONM_VALIDATOR_LEVEL;
    }
    
    // ============ Validator Management ============
    
    /**
     * @notice Add a new validator (only SONM validators)
     * @param _validator Validator address
     * @param _level Validator level (must be > 0)
     */
    function addValidator(address _validator, int8 _level) 
        external 
        onlySonm 
        whenNotPaused 
        returns (address) 
    {
        if (_level <= 0) revert InvalidLevel();
        if (getValidatorLevel(_validator) != 0) revert ValidatorAlreadyExists();
        
        validators[_validator] = _level;
        emit ValidatorCreated(_validator, _level);
        return _validator;
    }
    
    /**
     * @notice Remove a validator (only SONM validators)
     * @param _validator Validator address
     */
    function removeValidator(address _validator) 
        external 
        onlySonm 
        whenNotPaused 
        returns (address) 
    {
        if (getValidatorLevel(_validator) <= 0) revert ValidatorNotFound();
        
        validators[_validator] = 0;
        emit ValidatorDeleted(_validator);
        return _validator;
    }
    
    /**
     * @notice Get validator level
     * @param _validator Validator address
     * @return Level of validator (0 if not exists, -1 for SONM, >0 for regular validators)
     */
    function getValidatorLevel(address _validator) public view returns (int8) {
        return validators[_validator];
    }
    
    // ============ Certificate Management ============
    
    /**
     * @notice Create a certificate
     * @param _owner Certificate owner
     * @param _type Attribute type
     * @param _value Certificate value
     */
    function createCertificate(
        address _owner, 
        uint256 _type, 
        bytes calldata _value
    ) external whenNotPaused {
        // Check authorization for attribute type
        if (_type >= 1100) {
            int8 attributeLevel = int8(int256((_type / 100) % 10));
            if (attributeLevel > getValidatorLevel(msg.sender)) {
                revert Unauthorized();
            }
        } else {
            if (_owner != msg.sender) revert Unauthorized();
        }
        
        // Check empty value
        if (_value.length == 0 || keccak256(_value) == keccak256("")) {
            revert EmptyValue();
        }
        
        bool isMultiple = _type / 1000 == 2;
        if (!isMultiple) {
            if (certificateCount[_owner][_type] == 0) {
                certificateValue[_owner][_type] = _value;
            } else {
                if (keccak256(getAttributeValue(_owner, _type)) != keccak256(_value)) {
                    revert ValueMismatch();
                }
            }
        }
        
        certificateCount[_owner][_type]++;
        certificatesCount++;
        certificates[certificatesCount] = Certificate(
            msg.sender,
            _owner,
            _type,
            _value,
            block.timestamp
        );
        
        emit CertificateCreated(certificatesCount, msg.sender, _owner, _type);
    }
    
    /**
     * @notice Remove a certificate
     * @param _id Certificate ID
     */
    function removeCertificate(uint256 _id) external whenNotPaused {
        Certificate storage crt = certificates[_id];
        
        if (crt.to != msg.sender && crt.from != msg.sender && getValidatorLevel(msg.sender) != SONM_VALIDATOR_LEVEL) {
            revert Unauthorized();
        }
        if (crt.value.length == 0) revert CertificateNotFound();
        
        certificateCount[crt.to][crt.attributeType]--;
        if (certificateCount[crt.to][crt.attributeType] == 0) {
            delete certificateValue[crt.to][crt.attributeType];
        }
        delete certificates[_id].value;
        
        emit CertificateUpdated(_id);
    }
    
    /**
     * @notice Get certificate details
     * @param _id Certificate ID
     */
    function getCertificate(uint256 _id) 
        external 
        view 
        returns (address from, address to, uint256 attributeType, bytes memory value, uint256 createdAt) 
    {
        Certificate storage crt = certificates[_id];
        return (crt.from, crt.to, crt.attributeType, crt.value, crt.createdAt);
    }
    
    /**
     * @notice Get attribute value for owner and type
     * @param _owner Owner address
     * @param _type Attribute type
     */
    function getAttributeValue(address _owner, uint256 _type) 
        public 
        view 
        returns (bytes memory) 
    {
        return certificateValue[_owner][_type];
    }
    
    /**
     * @notice Get attribute count for owner and type
     */
    function getAttributeCount(address _owner, uint256 _type) 
        external 
        view 
        returns (uint256) 
    {
        return certificateCount[_owner][_type];
    }
    
    /**
     * @notice Get profile identity level
     * @param _owner Owner address
     * @return Highest achieved identity level
     */
    function getProfileLevel(address _owner) external view returns (IdentityLevel) {
        if (getAttributeValue(_owner, 1401).length > 0) {
            return IdentityLevel.PROFESSIONAL;
        } else if (getAttributeValue(_owner, 1301).length > 0) {
            return IdentityLevel.IDENTIFIED;
        } else if (getAttributeValue(_owner, 1201).length > 0) {
            return IdentityLevel.REGISTERED;
        } else {
            return IdentityLevel.ANONYMOUS;
        }
    }
    
    // ============ Admin Functions ============
    
    function addSonmValidator(address _validator) external onlyOwner returns (bool) {
        validators[_validator] = SONM_VALIDATOR_LEVEL;
        emit ValidatorCreated(_validator, SONM_VALIDATOR_LEVEL);
        return true;
    }
    
    function removeSonmValidator(address _validator) external onlyOwner returns (bool) {
        if (getValidatorLevel(_validator) != SONM_VALIDATOR_LEVEL) revert ValidatorNotFound();
        validators[_validator] = 0;
        emit ValidatorDeleted(_validator);
        return true;
    }
}