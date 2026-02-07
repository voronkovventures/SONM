// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentTaskMarketplace} from "../src/AgentTaskMarketplace.sol";
import {SNMToken} from "../src/SNMToken.sol";

contract AgentTaskMarketplaceTest is Test {
    AgentTaskMarketplace public marketplace;
    SNMToken public token;
    
    address public owner = address(1);
    address public agent = address(2);
    address public requester = address(3);
    address public feeRecipient = address(4);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy token
        token = new SNMToken(1_000_000 * 10**18);
        
        // Deploy marketplace
        marketplace = new AgentTaskMarketplace(address(token), feeRecipient);
        
        vm.stopPrank();
        
        // Fund accounts
        vm.startPrank(owner);
        token.transfer(agent, 100_000 * 10**18);
        token.transfer(requester, 100_000 * 10**18);
        vm.stopPrank();
    }
    
    function test_Deployment() public view {
        assertEq(address(marketplace.paymentToken()), address(token));
        assertEq(marketplace.feeRecipient(), feeRecipient);
        assertEq(marketplace.platformFeePercent(), 250); // 2.5%
    }
    
    function test_RegisterAgent() public {
        vm.startPrank(agent);
        
        string[] memory skills = new string[](2);
        skills[0] = "AI";
        skills[1] = "Data Analysis";
        
        marketplace.registerAgent(
            "Agent007",
            skills,
            100 * 10**18,  // min reward
            7 days         // max deadline
        );
        
        vm.stopPrank();
        
        AgentTaskMarketplace.AgentProfile memory profile = marketplace.getAgentProfile(agent);
        assertEq(profile.name, "Agent007");
        assertEq(profile.skills.length, 2);
        assertTrue(profile.isActive);
    }
    
    function test_CreateTask() public {
        // First register agent
        vm.startPrank(agent);
        string[] memory skills = new string[](1);
        skills[0] = "AI";
        marketplace.registerAgent("Agent1", skills, 100 * 10**18, 7 days);
        vm.stopPrank();
        
        // Create task
        vm.startPrank(requester);
        token.approve(address(marketplace), 1000 * 10**18);
        
        bytes32 taskId = marketplace.createTask(
            AgentTaskMarketplace.TaskType.COMPUTATION,
            1000 * 10**18,
            block.timestamp + 1 days,
            "ipfs://task-details"
        );
        
        vm.stopPrank();
        
        assertTrue(taskId != bytes32(0));
        
        AgentTaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(task.requester, requester);
        assertEq(task.reward, 1000 * 10**18);
        assertEq(uint(task.status), uint(AgentTaskMarketplace.TaskStatus.OPEN));
    }
    
    function test_ClaimTask() public {
        // Setup
        vm.startPrank(agent);
        string[] memory skills = new string[](1);
        skills[0] = "AI";
        marketplace.registerAgent("Agent1", skills, 100 * 10**18, 7 days);
        vm.stopPrank();
        
        vm.startPrank(requester);
        token.approve(address(marketplace), 1000 * 10**18);
        bytes32 taskId = marketplace.createTask(
            AgentTaskMarketplace.TaskType.COMPUTATION,
            1000 * 10**18,
            block.timestamp + 1 days,
            "ipfs://task-details"
        );
        vm.stopPrank();
        
        // Claim task
        vm.prank(agent);
        marketplace.claimTask(taskId);
        
        AgentTaskMarketplace.Task memory task = marketplace.getTask(taskId);
        assertEq(task.executor, agent);
        assertEq(uint(task.status), uint(AgentTaskMarketplace.TaskStatus.CLAIMED));
    }
    
    function test_CompleteTaskFlow() public {
        // Setup agent
        vm.startPrank(agent);
        string[] memory skills = new string[](1);
        skills[0] = "AI";
        marketplace.registerAgent("Agent1", skills, 100 * 10**18, 7 days);
        vm.stopPrank();
        
        // Create task
        vm.startPrank(requester);
        token.approve(address(marketplace), 1000 * 10**18);
        bytes32 taskId = marketplace.createTask(
            AgentTaskMarketplace.TaskType.COMPUTATION,
            1000 * 10**18,
            block.timestamp + 1 days,
            "ipfs://task-details"
        );
        vm.stopPrank();
        
        // Claim and work
        vm.prank(agent);
        marketplace.claimTask(taskId);
        
        vm.prank(agent);
        marketplace.startWork(taskId);
        
        // Submit result
        vm.prank(agent);
        marketplace.submitResult(taskId, keccak256("result"), "ipfs://result");
        
        // Get balances before
        uint256 agentBalanceBefore = token.balanceOf(agent);
        uint256 feeRecipientBalanceBefore = token.balanceOf(feeRecipient);
        
        // Verify and accept
        vm.prank(requester);
        marketplace.verifyAndAccept(taskId, 5, "Great work!");
        
        // Check balances
        uint256 expectedFee = (1000 * 10**18 * 250) / 10000; // 2.5%
        uint256 expectedReward = 1000 * 10**18 - expectedFee;
        
        assertEq(token.balanceOf(agent) - agentBalanceBefore, expectedReward);
        assertEq(token.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedFee);
        
        // Check rating
        AgentTaskMarketplace.AgentProfile memory profile = marketplace.getAgentProfile(agent);
        assertEq(profile.completedTasks, 1);
        assertEq(profile.totalTasks, 1);
        assertEq(profile.successRate, 10000); // 100%
        
        uint256 rating = marketplace.getAgentRating(agent);
        assertEq(rating, 5);
    }
    
    function test_GetOpenTasks() public {
        // Create multiple tasks
        vm.startPrank(requester);
        token.approve(address(marketplace), 3000 * 10**18);
        
        marketplace.createTask(
            AgentTaskMarketplace.TaskType.COMPUTATION,
            1000 * 10**18,
            block.timestamp + 1 days,
            "ipfs://task1"
        );
        
        marketplace.createTask(
            AgentTaskMarketplace.TaskType.ANALYSIS,
            1000 * 10**18,
            block.timestamp + 1 days,
            "ipfs://task2"
        );
        
        vm.stopPrank();
        
        bytes32[] memory openTasks = marketplace.getOpenTasks();
        assertEq(openTasks.length, 2);
    }
}