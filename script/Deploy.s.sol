// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SNMToken} from "../src/SNMToken.sol";
import {ProfileRegistry} from "../src/ProfileRegistry.sol";
import {SONMMarketplace} from "../src/SONMMarketplace.sol";

/**
 * @title DeploySONM
 * @dev Deployment script for SONM modernized contracts
 * 
 * Run with:
 * forge script script/Deploy.s.sol:DeploySONM --rpc-url <RPC_URL> --broadcast --verify
 * 
 * For local testing:
 * forge script script/Deploy.s.sol:DeploySONM --fork-url http://localhost:8545 --broadcast
 */
contract DeploySONM is Script {
    
    // Configuration
    uint256 public constant INITIAL_SUPPLY = 444_000_000 * 10**18; // 444M SNM
    uint256 public constant BENCHMARKS_QTY = 12;
    uint256 public constant NETFLAGS_QTY = 5;
    
    // Deployed contracts
    SNMToken public token;
    ProfileRegistry public registry;
    SONMMarketplace public marketplace;
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying SONM Contracts...");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy SNM Token
        token = new SNMToken(INITIAL_SUPPLY);
        console.log("SNM Token deployed at:", address(token));
        console.log("  - Name:", token.name());
        console.log("  - Symbol:", token.symbol());
        console.log("  - Total Supply:", token.totalSupply() / 10**18, "SNM");
        
        // 2. Deploy Profile Registry
        registry = new ProfileRegistry();
        console.log("Profile Registry deployed at:", address(registry));
        
        // 3. Deploy Marketplace
        marketplace = new SONMMarketplace(
            address(token),
            address(registry),
            BENCHMARKS_QTY,
            NETFLAGS_QTY
        );
        console.log("SONM Marketplace deployed at:", address(marketplace));
        console.log("  - Benchmarks:", BENCHMARKS_QTY);
        console.log("  - Netflags:", NETFLAGS_QTY);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", block.chainid);
        console.log("SNMToken:", address(token));
        console.log("ProfileRegistry:", address(registry));
        console.log("SONMMarketplace:", address(marketplace));
        console.log("==========================");
        
        // Save deployment info
        _saveDeployment();
    }
    
    function _saveDeployment() internal {
        string memory json = "{";
        json = string.concat(json, '"chainId":', vm.toString(block.chainid), ",");
        json = string.concat(json, '"token":"', vm.toString(address(token)), '",');
        json = string.concat(json, '"registry":"', vm.toString(address(registry)), '",');
        json = string.concat(json, '"marketplace":"', vm.toString(address(marketplace)), '"');
        json = string.concat(json, "}");
        
        string memory filename = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".json"
        );
        
        vm.writeFile(filename, json);
        console.log("Deployment saved to:", filename);
    }
}

/**
 * @title DeployToAnvil
 * @dev Quick deployment to local Anvil node for testing
 */
contract DeployToAnvil is Script {
    function run() external {
        // Anvil default private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        SNMToken token = new SNMToken(444_000_000 * 10**18);
        ProfileRegistry registry = new ProfileRegistry();
        SONMMarketplace marketplace = new SONMMarketplace(
            address(token),
            address(registry),
            12,
            5
        );
        
        vm.stopBroadcast();
        
        console.log("Local deployment complete!");
        console.log("Token:", address(token));
        console.log("Registry:", address(registry));
        console.log("Marketplace:", address(marketplace));
    }
}