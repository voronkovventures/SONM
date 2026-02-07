// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SNMToken} from "../src/SNMToken.sol";
import {ProfileRegistry} from "../src/ProfileRegistry.sol";
import {SONMMarketplace} from "../src/SONMMarketplace.sol";

contract SONMTest is Test {
    SNMToken public token;
    ProfileRegistry public registry;
    SONMMarketplace public marketplace;
    
    address public owner = address(1);
    address public supplier = address(2);
    address public consumer = address(3);
    address public validator = address(4);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy token with full supply
        token = new SNMToken(444_000_000 * 10**18);
        
        // Deploy registry
        registry = new ProfileRegistry();
        
        // Deploy marketplace
        marketplace = new SONMMarketplace(
            address(token),
            address(registry),
            12, // benchmarks quantity
            5   // netflags quantity
        );
        
        vm.stopPrank();
        
        // Fund accounts
        vm.startPrank(owner);
        token.transfer(supplier, 1_000_000 * 10**18);
        token.transfer(consumer, 1_000_000 * 10**18);
        vm.stopPrank();
    }
    
    function test_TokenDeployment() public view {
        assertEq(token.name(), "SONM Token");
        assertEq(token.symbol(), "SNM");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 444_000_000 * 10**18);
        assertEq(token.MAX_SUPPLY(), 444_000_000 * 10**18);
    }
    
    function test_ProfileRegistryDeployment() public view {
        assertEq(registry.owner(), owner);
        // Owner should be SONM validator (level -1)
        assertEq(registry.getValidatorLevel(owner), -1);
    }
    
    function test_AddValidator() public {
        vm.startPrank(owner);
        registry.addValidator(validator, 1);
        vm.stopPrank();
        
        assertEq(registry.getValidatorLevel(validator), 1);
    }
    
    function test_MarketplaceDeployment() public view {
        assertEq(address(marketplace.token()), address(token));
        assertEq(address(marketplace.profileRegistry()), address(registry));
        assertEq(marketplace.owner(), owner);
    }
    
    function test_PlaceAskOrder() public {
        vm.startPrank(supplier);
        
        bool[] memory netflags = new bool[](2);
        netflags[0] = true;
        netflags[1] = false;
        
        uint64[] memory benchmarks = new uint64[](3);
        benchmarks[0] = 1000;
        benchmarks[1] = 2000;
        benchmarks[2] = 3000;
        
        uint256 orderId = marketplace.placeOrder(
            SONMMarketplace.OrderType.ORDER_ASK,
            address(0), // no counterparty restriction
            3600, // 1 hour duration
            100 * 10**18, // price per hour
            netflags,
            ProfileRegistry.IdentityLevel.ANONYMOUS,
            address(0), // no blacklist
            bytes32(0),
            benchmarks
        );
        
        vm.stopPrank();
        
        assertEq(orderId, 1);
        
        SONMMarketplace.Order memory order = marketplace.getOrder(orderId);
        assertEq(order.author, supplier);
        assertEq(uint(order.orderType), uint(SONMMarketplace.OrderType.ORDER_ASK));
    }
    
    function test_PlaceBidOrder() public {
        // Approve tokens for marketplace
        vm.startPrank(consumer);
        token.approve(address(marketplace), 1000 * 10**18);
        
        bool[] memory netflags = new bool[](2);
        uint64[] memory benchmarks = new uint64[](3);
        
        uint256 orderId = marketplace.placeOrder(
            SONMMarketplace.OrderType.ORDER_BID,
            address(0),
            3600,
            100 * 10**18,
            netflags,
            ProfileRegistry.IdentityLevel.ANONYMOUS,
            address(0),
            bytes32(0),
            benchmarks
        );
        
        vm.stopPrank();
        
        assertEq(orderId, 1);
        
        // Check that tokens were locked
        assertEq(token.balanceOf(address(marketplace)), 100 * 10**18);
    }
    
    function test_WorkerManagement() public {
        // Master announces worker
        vm.prank(owner);
        marketplace.announceWorker(supplier);
        
        // Worker confirms master
        vm.prank(supplier);
        marketplace.confirmWorker(owner);
        
        assertEq(marketplace.masterOf(supplier), owner);
        assertTrue(marketplace.isMaster(owner));
    }
}