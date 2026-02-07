// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AgentTaskMarketplace} from "../src/AgentTaskMarketplace.sol";

/**
 * @title DeployAgentMarketplace
 * @dev Deployment script for Agent Task Marketplace
 */
contract DeployAgentMarketplace is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Sepolia deployed addresses from previous deployment
        address snmToken = 0xd777c3Fab6fe4a87aE9257c4993cede41A34c80d;
        address feeRecipient = deployer;
        
        console.log("Deploying Agent Task Marketplace...");
        console.log("Deployer:", deployer);
        console.log("Payment Token (SNM):", snmToken);
        
        vm.startBroadcast(deployerPrivateKey);
        
        AgentTaskMarketplace marketplace = new AgentTaskMarketplace(
            snmToken,
            feeRecipient
        );
        
        vm.stopBroadcast();
        
        console.log("Agent Task Marketplace deployed at:", address(marketplace));
        console.log("Platform fee:", marketplace.platformFeePercent(), "(2.5%)");
    }
}