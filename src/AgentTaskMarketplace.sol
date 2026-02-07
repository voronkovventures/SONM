// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AgentTaskMarketplace
 * @dev P2P Marketplace for AI Agents on SONM
 * Extension of SONM for task-based agent economy
 */
contract AgentTaskMarketplace is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Enums ============
    
    enum TaskStatus {
        OPEN,
        CLAIMED,
        IN_PROGRESS,
        SUBMITTED,
        VERIFIED,
        DISPUTED,
        CANCELLED
    }
    
    enum TaskType {
        COMPUTATION,
        DATA_PROCESSING,
        ANALYSIS,
        GENERATION,
        OTHER
    }
    
    // ============ Structs ============
    
    struct Task {
        bytes32 taskId;
        address requester;
        address executor;
        uint256 reward;
        uint256 deadline;
        TaskStatus status;
        TaskType taskType;
        string metadataURI;     // IPFS link to task details
        bytes32 resultHash;     // Hash of result
        string resultURI;       // IPFS link to result
        uint256 createdAt;
        uint256 completedAt;
        uint256 disputeWindow;  // Time to dispute after submission
    }
    
    struct AgentProfile {
        address agentAddress;
        string name;
        string[] skills;
        uint256 successRate;    // Percentage (0-10000 for 2 decimals)
        uint256 totalTasks;
        uint256 completedTasks;
        uint256 ratingSum;      // Sum of all ratings
        uint256 ratingCount;    // Number of ratings
        bool isActive;
        uint256 minReward;      // Minimum reward to accept task
        uint256 maxDeadline;    // Maximum deadline willing to accept
    }
    
    // ============ State Variables ============
    
    IERC20 public paymentToken;
    uint256 public platformFeePercent = 250; // 2.5%
    address public feeRecipient;
    uint256 public defaultDisputeWindow = 24 hours;
    
    mapping(bytes32 => Task) public tasks;
    mapping(address => AgentProfile) public agents;
    mapping(address => bytes32[]) public agentTasks;
    mapping(address => bytes32[]) public requesterTasks;
    mapping(bytes32 => mapping(address => bool)) public hasVoted; // For verification voting
    
    bytes32[] public allTaskIds;
    address[] public allAgents;
    
    // ============ Events ============
    
    event TaskCreated(
        bytes32 indexed taskId,
        address indexed requester,
        uint256 reward,
        TaskType taskType,
        uint256 deadline
    );
    
    event TaskClaimed(
        bytes32 indexed taskId,
        address indexed executor
    );
    
    event TaskSubmitted(
        bytes32 indexed taskId,
        bytes32 resultHash,
        string resultURI
    );
    
    event TaskVerified(
        bytes32 indexed taskId,
        address indexed verifier,
        bool accepted
    );
    
    event TaskCompleted(
        bytes32 indexed taskId,
        address indexed executor,
        uint256 reward
    );
    
    event TaskDisputed(
        bytes32 indexed taskId,
        address indexed disputer,
        string reason
    );
    
    event AgentRegistered(
        address indexed agent,
        string name,
        string[] skills
    );
    
    event AgentUpdated(
        address indexed agent,
        bool isActive,
        uint256 minReward,
        uint256 maxDeadline
    );
    
    event RatingSubmitted(
        bytes32 indexed taskId,
        address indexed agent,
        uint8 rating,
        string review
    );
    
    // ============ Errors ============
    
    error InvalidTaskId();
    error TaskNotOpen();
    error TaskNotClaimed();
    error TaskNotSubmitted();
    error DeadlinePassed();
    error InsufficientReward();
    error NotTaskRequester();
    error NotTaskExecutor();
    error AlreadyClaimed();
    error NotRegisteredAgent();
    error AgentNotActive();
    error InvalidRating();
    error DisputeWindowClosed();
    error TransferFailed();
    
    // ============ Constructor ============
    
    constructor(address _paymentToken, address _feeRecipient) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        feeRecipient = _feeRecipient;
    }
    
    // ============ Admin Functions ============
    
    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "Fee too high"); // Max 10%
        platformFeePercent = _feePercent;
    }
    
    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
    
    function setDefaultDisputeWindow(uint256 _window) external onlyOwner {
        defaultDisputeWindow = _window;
    }
    
    // ============ Agent Registration ============
    
    function registerAgent(
        string calldata _name,
        string[] calldata _skills,
        uint256 _minReward,
        uint256 _maxDeadline
    ) external whenNotPaused {
        agents[msg.sender] = AgentProfile({
            agentAddress: msg.sender,
            name: _name,
            skills: _skills,
            successRate: 0,
            totalTasks: 0,
            completedTasks: 0,
            ratingSum: 0,
            ratingCount: 0,
            isActive: true,
            minReward: _minReward,
            maxDeadline: _maxDeadline
        });
        
        allAgents.push(msg.sender);
        emit AgentRegistered(msg.sender, _name, _skills);
    }
    
    function updateAgent(
        bool _isActive,
        uint256 _minReward,
        uint256 _maxDeadline
    ) external {
        AgentProfile storage agent = agents[msg.sender];
        if (agent.agentAddress == address(0)) revert NotRegisteredAgent();
        
        agent.isActive = _isActive;
        agent.minReward = _minReward;
        agent.maxDeadline = _maxDeadline;
        
        emit AgentUpdated(msg.sender, _isActive, _minReward, _maxDeadline);
    }
    
    // ============ Task Management ============
    
    function createTask(
        TaskType _taskType,
        uint256 _reward,
        uint256 _deadline,
        string calldata _metadataURI
    ) external whenNotPaused nonReentrant returns (bytes32) {
        if (_deadline <= block.timestamp) revert DeadlinePassed();
        if (_reward == 0) revert InsufficientReward();
        
        // Generate unique task ID
        bytes32 taskId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            allTaskIds.length
        ));
        
        // Transfer reward to contract
        paymentToken.safeTransferFrom(msg.sender, address(this), _reward);
        
        tasks[taskId] = Task({
            taskId: taskId,
            requester: msg.sender,
            executor: address(0),
            reward: _reward,
            deadline: _deadline,
            status: TaskStatus.OPEN,
            taskType: _taskType,
            metadataURI: _metadataURI,
            resultHash: bytes32(0),
            resultURI: "",
            createdAt: block.timestamp,
            completedAt: 0,
            disputeWindow: 0
        });
        
        allTaskIds.push(taskId);
        requesterTasks[msg.sender].push(taskId);
        
        emit TaskCreated(taskId, msg.sender, _reward, _taskType, _deadline);
        
        return taskId;
    }
    
    function claimTask(bytes32 _taskId) external whenNotPaused {
        Task storage task = tasks[_taskId];
        AgentProfile storage agent = agents[msg.sender];
        
        if (task.taskId == bytes32(0)) revert InvalidTaskId();
        if (task.status != TaskStatus.OPEN) revert TaskNotOpen();
        if (task.deadline <= block.timestamp) revert DeadlinePassed();
        if (task.executor != address(0)) revert AlreadyClaimed();
        if (agent.agentAddress == address(0)) revert NotRegisteredAgent();
        if (!agent.isActive) revert AgentNotActive();
        if (task.reward < agent.minReward) revert InsufficientReward();
        if (task.deadline > block.timestamp + agent.maxDeadline) revert DeadlinePassed();
        
        task.executor = msg.sender;
        task.status = TaskStatus.CLAIMED;
        
        agentTasks[msg.sender].push(_taskId);
        
        emit TaskClaimed(_taskId, msg.sender);
    }
    
    function startWork(bytes32 _taskId) external {
        Task storage task = tasks[_taskId];
        
        if (task.status != TaskStatus.CLAIMED) revert TaskNotClaimed();
        if (task.executor != msg.sender) revert NotTaskExecutor();
        
        task.status = TaskStatus.IN_PROGRESS;
    }
    
    function submitResult(
        bytes32 _taskId,
        bytes32 _resultHash,
        string calldata _resultURI
    ) external {
        Task storage task = tasks[_taskId];
        
        if (task.status != TaskStatus.IN_PROGRESS && task.status != TaskStatus.CLAIMED) 
            revert TaskNotClaimed();
        if (task.executor != msg.sender) revert NotTaskExecutor();
        
        task.resultHash = _resultHash;
        task.resultURI = _resultURI;
        task.status = TaskStatus.SUBMITTED;
        task.disputeWindow = block.timestamp + defaultDisputeWindow;
        
        emit TaskSubmitted(_taskId, _resultHash, _resultURI);
    }
    
    // ============ Verification & Completion ============
    
    function verifyAndAccept(bytes32 _taskId, uint8 _rating, string calldata _review) 
        external 
        nonReentrant 
    {
        Task storage task = tasks[_taskId];
        AgentProfile storage agent = agents[task.executor];
        
        if (task.status != TaskStatus.SUBMITTED) revert TaskNotSubmitted();
        if (task.requester != msg.sender) revert NotTaskRequester();
        if (_rating < 1 || _rating > 5) revert InvalidRating();
        
        // Calculate fee
        uint256 fee = (task.reward * platformFeePercent) / 10000;
        uint256 executorReward = task.reward - fee;
        
        // Transfer to executor
        paymentToken.safeTransfer(task.executor, executorReward);
        
        // Transfer fee
        if (fee > 0 && feeRecipient != address(0)) {
            paymentToken.safeTransfer(feeRecipient, fee);
        }
        
        // Update task
        task.status = TaskStatus.VERIFIED;
        task.completedAt = block.timestamp;
        
        // Update agent stats
        agent.totalTasks++;
        agent.completedTasks++;
        agent.ratingSum += _rating;
        agent.ratingCount++;
        agent.successRate = (agent.completedTasks * 10000) / agent.totalTasks;
        
        emit TaskVerified(_taskId, msg.sender, true);
        emit TaskCompleted(_taskId, task.executor, executorReward);
        emit RatingSubmitted(_taskId, task.executor, _rating, _review);
    }
    
    function disputeTask(bytes32 _taskId, string calldata _reason) external {
        Task storage task = tasks[_taskId];
        
        if (task.status != TaskStatus.SUBMITTED) revert TaskNotSubmitted();
        if (task.requester != msg.sender) revert NotTaskRequester();
        if (block.timestamp > task.disputeWindow) revert DisputeWindowClosed();
        
        task.status = TaskStatus.DISPUTED;
        
        emit TaskDisputed(_taskId, msg.sender, _reason);
    }
    
    function cancelTask(bytes32 _taskId) external nonReentrant {
        Task storage task = tasks[_taskId];
        
        if (task.status != TaskStatus.OPEN) revert TaskNotOpen();
        if (task.requester != msg.sender) revert NotTaskRequester();
        
        // Refund requester
        paymentToken.safeTransfer(task.requester, task.reward);
        
        task.status = TaskStatus.CANCELLED;
    }
    
    // ============ View Functions ============
    
    function getTask(bytes32 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }
    
    function getAgentProfile(address _agent) external view returns (AgentProfile memory) {
        return agents[_agent];
    }
    
    function getAgentRating(address _agent) external view returns (uint256) {
        AgentProfile memory agent = agents[_agent];
        if (agent.ratingCount == 0) return 0;
        return agent.ratingSum / agent.ratingCount;
    }
    
    function getOpenTasks() external view returns (bytes32[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < allTaskIds.length; i++) {
            if (tasks[allTaskIds[i]].status == TaskStatus.OPEN) {
                count++;
            }
        }
        
        bytes32[] memory openTasks = new bytes32[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allTaskIds.length; i++) {
            if (tasks[allTaskIds[i]].status == TaskStatus.OPEN) {
                openTasks[index] = allTaskIds[i];
                index++;
            }
        }
        
        return openTasks;
    }
    
    function getAgentTasks(address _agent) external view returns (bytes32[] memory) {
        return agentTasks[_agent];
    }
    
    function getRequesterTasks(address _requester) external view returns (bytes32[] memory) {
        return requesterTasks[_requester];
    }
}