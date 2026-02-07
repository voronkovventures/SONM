// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SNMToken} from "./SNMToken.sol";
import {ProfileRegistry} from "./ProfileRegistry.sol";

/**
 * @title SONMMarketplace
 * @dev Modernized SONM Marketplace for decentralized computing resources
 * Original: Solidity 0.4.x → Modern: Solidity 0.8.20
 */
contract SONMMarketplace is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Enums ============
    
    enum DealStatus {
        STATUS_UNKNOWN,
        STATUS_ACCEPTED,
        STATUS_CLOSED
    }
    
    enum OrderType {
        ORDER_UNKNOWN,
        ORDER_BID,
        ORDER_ASK
    }
    
    enum OrderStatus {
        UNKNOWN,
        ORDER_INACTIVE,
        ORDER_ACTIVE
    }
    
    enum RequestStatus {
        REQUEST_UNKNOWN,
        REQUEST_CREATED,
        REQUEST_CANCELED,
        REQUEST_REJECTED,
        REQUEST_ACCEPTED
    }
    
    enum BlacklistPerson {
        BLACKLIST_NOBODY,
        BLACKLIST_WORKER,
        BLACKLIST_MASTER
    }
    
    // ============ Structs ============
    
    struct Deal {
        uint64[] benchmarks;
        address supplierID;
        address consumerID;
        address masterID;
        uint256 askID;
        uint256 bidID;
        uint256 duration;
        uint256 price; // usd * 10^-18
        uint256 startTime;
        uint256 endTime;
        DealStatus status;
        uint256 blockedBalance;
        uint256 totalPayout;
        uint256 lastBillTS;
    }
    
    struct Order {
        OrderType orderType;
        OrderStatus orderStatus;
        address author;
        address counterparty;
        uint256 duration;
        uint256 price;
        bool[] netflags;
        ProfileRegistry.IdentityLevel identityLevel;
        address blacklist;
        bytes32 tag;
        uint64[] benchmarks;
        uint256 frozenSum;
        uint256 dealID;
    }
    
    struct ChangeRequest {
        uint256 dealID;
        OrderType requestType;
        uint256 price;
        uint256 duration;
        RequestStatus status;
    }
    
    // ============ State Variables ============
    
    uint256 public constant MAX_BENCHMARKS_VALUE = 2 ** 63;
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_LOCK_PERIOD = 1 days;
    
    IERC20 public token;
    ProfileRegistry public profileRegistry;
    
    uint256 public ordersAmount;
    uint256 public dealAmount;
    uint256 public requestsAmount;
    uint256 public benchmarksQuantity;
    uint256 public netflagsQuantity;
    
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Deal) public deals;
    mapping(address => uint256[]) public dealsID;
    mapping(uint256 => ChangeRequest) public requests;
    mapping(uint256 => uint256[2]) public actualRequests;
    mapping(address => address) public masterOf;
    mapping(address => bool) public isMaster;
    mapping(address => mapping(address => bool)) public masterRequest;
    
    // ============ Events ============
    
    event OrderPlaced(uint256 indexed orderID, OrderType orderType, address indexed author, uint256 price);
    event OrderUpdated(uint256 indexed orderID, OrderStatus status);
    event OrderCancelled(uint256 indexed orderID);
    
    event DealOpened(
        uint256 indexed dealID,
        address indexed supplier,
        address indexed consumer,
        uint256 price,
        uint256 duration
    );
    event DealUpdated(uint256 indexed dealID, DealStatus status);
    event DealClosed(uint256 indexed dealID);
    
    event Billed(uint256 indexed dealID, uint256 paidAmount, uint256 remaining);
    
    event DealChangeRequestSet(uint256 indexed changeRequestID, uint256 indexed dealID, RequestStatus status);
    event DealChangeRequestUpdated(uint256 indexed changeRequestID, RequestStatus status);
    
    event WorkerAnnounced(address indexed worker, address indexed master);
    event WorkerConfirmed(address indexed worker, address indexed master);
    event WorkerRemoved(address indexed worker, address indexed master);
    
    event NumBenchmarksUpdated(uint256 newNum);
    event NumNetflagsUpdated(uint256 newNum);
    
    // ============ Errors ============
    
    error InvalidOrderType();
    error InvalidIdentityLevel();
    error InvalidBenchmarks();
    error InvalidNetflags();
    error OrderNotFound();
    error OrderNotActive();
    error Unauthorized();
    error InsufficientAllowance();
    error InvalidDuration();
    error InvalidPrice();
    error InvalidCounterparty();
    error DealNotFound();
    error DealNotActive();
    error WorkerAlreadyRegistered();
    error WorkerNotRegistered();
    error MasterNotConfirmed();
    error InvalidChangeRequest();
    error TransferFailed();
    error BenchmarkValueTooHigh();
    error InvalidNetflagsLength();
    error InvalidBenchmarksLength();
    error OrderAlreadyHasDeal();
    error InsufficientBalance();
    
    // ============ Constructor ============
    
    constructor(
        address _token,
        address _profileRegistry,
        uint256 _benchmarksQuantity,
        uint256 _netflagsQuantity
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        profileRegistry = ProfileRegistry(_profileRegistry);
        benchmarksQuantity = _benchmarksQuantity;
        netflagsQuantity = _netflagsQuantity;
    }
    
    // ============ Order Functions ============
    
    /**
     * @notice Place a new order (BID or ASK)
     */
    function placeOrder(
        OrderType _orderType,
        address _counterparty,
        uint256 _duration,
        uint256 _price,
        bool[] calldata _netflags,
        ProfileRegistry.IdentityLevel _identityLevel,
        address _blacklist,
        bytes32 _tag,
        uint64[] calldata _benchmarks
    ) external whenNotPaused nonReentrant returns (uint256) {
        if (_orderType != OrderType.ORDER_BID && _orderType != OrderType.ORDER_ASK) {
            revert InvalidOrderType();
        }
        if (_identityLevel < ProfileRegistry.IdentityLevel.ANONYMOUS) {
            revert InvalidIdentityLevel();
        }
        if (_netflags.length > netflagsQuantity) {
            revert InvalidNetflagsLength();
        }
        if (_benchmarks.length > benchmarksQuantity) {
            revert InvalidBenchmarksLength();
        }
        
        for (uint256 i = 0; i < _benchmarks.length; i++) {
            if (_benchmarks[i] >= MAX_BENCHMARKS_VALUE) {
                revert BenchmarkValueTooHigh();
            }
        }
        
        uint256 lockedSum = 0;
        
        if (_orderType == OrderType.ORDER_BID) {
            if (_duration == 0) {
                lockedSum = calculatePayment(_price, MIN_DURATION);
            } else if (_duration < MAX_LOCK_PERIOD) {
                lockedSum = calculatePayment(_price, _duration);
            } else {
                lockedSum = calculatePayment(_price, MAX_LOCK_PERIOD);
            }
            
            if (token.allowance(msg.sender, address(this)) < lockedSum) {
                revert InsufficientAllowance();
            }
            
            token.safeTransferFrom(msg.sender, address(this), lockedSum);
        }
        
        ordersAmount++;
        
        orders[ordersAmount] = Order({
            orderType: _orderType,
            orderStatus: OrderStatus.ORDER_ACTIVE,
            author: msg.sender,
            counterparty: _counterparty,
            duration: _duration,
            price: _price,
            netflags: _netflags,
            identityLevel: _identityLevel,
            blacklist: _blacklist,
            tag: _tag,
            benchmarks: _benchmarks,
            frozenSum: lockedSum,
            dealID: 0
        });
        
        emit OrderPlaced(ordersAmount, _orderType, msg.sender, _price);
        
        return ordersAmount;
    }
    
    /**
     * @notice Cancel an order and refund locked funds
     */
    function cancelOrder(uint256 _orderID) external whenNotPaused nonReentrant {
        Order storage order = orders[_orderID];
        
        if (order.author != msg.sender) revert Unauthorized();
        if (order.orderStatus != OrderStatus.ORDER_ACTIVE) revert OrderNotActive();
        if (order.dealID != 0) revert OrderAlreadyHasDeal();
        
        order.orderStatus = OrderStatus.ORDER_INACTIVE;
        
        if (order.orderType == OrderType.ORDER_BID && order.frozenSum > 0) {
            token.safeTransfer(msg.sender, order.frozenSum);
        }
        
        emit OrderCancelled(_orderID);
    }
    
    // ============ Deal Functions ============
    
    /**
     * @notice Open a deal between BID and ASK orders
     */
    function openDeal(uint256 _askID, uint256 _bidID) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        Order storage ask = orders[_askID];
        Order storage bid = orders[_bidID];
        
        // Validation logic would go here
        // (omitted for brevity, but includes price matching, benchmarks, etc.)
        
        dealAmount++;
        
        deals[dealAmount] = Deal({
            benchmarks: ask.benchmarks,
            supplierID: ask.author,
            consumerID: bid.author,
            masterID: masterOf[ask.author],
            askID: _askID,
            bidID: _bidID,
            duration: ask.duration < bid.duration ? ask.duration : bid.duration,
            price: ask.price,
            startTime: block.timestamp,
            endTime: 0,
            status: DealStatus.STATUS_ACCEPTED,
            blockedBalance: bid.frozenSum,
            totalPayout: 0,
            lastBillTS: block.timestamp
        });
        
        ask.dealID = dealAmount;
        bid.dealID = dealAmount;
        ask.orderStatus = OrderStatus.ORDER_INACTIVE;
        bid.orderStatus = OrderStatus.ORDER_INACTIVE;
        
        dealsID[ask.author].push(dealAmount);
        dealsID[bid.author].push(dealAmount);
        
        emit DealOpened(dealAmount, ask.author, bid.author, ask.price, deals[dealAmount].duration);
        
        return dealAmount;
    }
    
    /**
     * @notice Close a deal
     */
    function closeDeal(uint256 _dealID) external whenNotPaused nonReentrant {
        Deal storage deal = deals[_dealID];
        
        if (deal.status != DealStatus.STATUS_ACCEPTED) revert DealNotActive();
        if (deal.consumerID != msg.sender && deal.supplierID != msg.sender) revert Unauthorized();
        
        _bill(_dealID);
        
        deal.status = DealStatus.STATUS_CLOSED;
        deal.endTime = block.timestamp;
        
        uint256 remaining = deal.blockedBalance - deal.totalPayout;
        if (remaining > 0) {
            token.safeTransfer(deal.consumerID, remaining);
        }
        
        emit DealClosed(_dealID);
    }
    
    /**
     * @notice Bill for deal usage
     */
    function bill(uint256 _dealID) external whenNotPaused nonReentrant {
        Deal storage deal = deals[_dealID];
        if (deal.status != DealStatus.STATUS_ACCEPTED) revert DealNotActive();
        _bill(_dealID);
    }
    
    function _bill(uint256 _dealID) internal {
        Deal storage deal = deals[_dealID];
        
        uint256 period = block.timestamp - deal.lastBillTS;
        uint256 payout = calculatePayment(deal.price, period);
        
        if (payout > deal.blockedBalance - deal.totalPayout) {
            payout = deal.blockedBalance - deal.totalPayout;
        }
        
        if (payout > 0) {
            deal.totalPayout += payout;
            deal.lastBillTS = block.timestamp;
            token.safeTransfer(deal.supplierID, payout);
            emit Billed(_dealID, payout, deal.blockedBalance - deal.totalPayout);
        }
    }
    
    /**
     * @notice Calculate payment for given price and duration
     */
    function calculatePayment(uint256 _price, uint256 _duration) public pure returns (uint256) {
        return (_price * _duration) / 1 hours;
    }
    
    // ============ Worker Management ============
    
    /**
     * @notice Announce worker for a master
     */
    function announceWorker(address _worker) external whenNotPaused {
        if (masterOf[_worker] != address(0)) revert WorkerAlreadyRegistered();
        masterRequest[_worker][msg.sender] = true;
        emit WorkerAnnounced(_worker, msg.sender);
    }
    
    /**
     * @notice Confirm master by worker
     */
    function confirmWorker(address _master) external whenNotPaused {
        if (!masterRequest[msg.sender][_master]) revert MasterNotConfirmed();
        masterOf[msg.sender] = _master;
        isMaster[_master] = true;
        emit WorkerConfirmed(msg.sender, _master);
    }
    
    /**
     * @notice Remove worker from master
     */
    function removeWorker(address _worker) external whenNotPaused {
        if (masterOf[_worker] != msg.sender) revert Unauthorized();
        masterOf[_worker] = address(0);
        isMaster[msg.sender] = false;
        emit WorkerRemoved(_worker, msg.sender);
    }
    
    // ============ Admin Functions ============
    
    function setBenchmarksQuantity(uint256 _newNum) external onlyOwner {
        benchmarksQuantity = _newNum;
        emit NumBenchmarksUpdated(_newNum);
    }
    
    function setNetflagsQuantity(uint256 _newNum) external onlyOwner {
        netflagsQuantity = _newNum;
        emit NumNetflagsUpdated(_newNum);
    }
    
    function setProfileRegistry(address _newRegistry) external onlyOwner {
        profileRegistry = ProfileRegistry(_newRegistry);
    }
    
    // ============ View Functions ============
    
    function getDeal(uint256 _dealID) external view returns (Deal memory) {
        return deals[_dealID];
    }
    
    function getOrder(uint256 _orderID) external view returns (Order memory) {
        return orders[_orderID];
    }
    
    function getDealsByAddress(address _addr) external view returns (uint256[] memory) {
        return dealsID[_addr];
    }
}