# SONM Frontend Integration Guide

## 🌐 Overview

Integration guide for connecting frontend applications with modernized SONM contracts.

## 📦 Prerequisites

```bash
# Install ethers.js or viem
npm install ethers@^6.0.0
# or
npm install viem@^2.0.0
```

## 🔌 Contract ABIs

ABIs are available in:
```
sonm-modern/out/
├── SNMToken.sol/SNMToken.json
├── ProfileRegistry.sol/ProfileRegistry.json
├── SONMMarketplace.sol/SONMMarketplace.json
├── SONMBlacklist.sol/SONMBlacklist.json
└── SONMOracle.sol/SONMOracle.json
```

## 💻 Example Integration (Ethers.js v6)

### 1. Setup Provider and Contracts

```typescript
import { ethers } from 'ethers';
import SNMTokenABI from './abi/SNMToken.json';
import MarketplaceABI from './abi/SONMMarketplace.json';
import RegistryABI from './abi/ProfileRegistry.json';

// Contract addresses (update after deployment)
const CONTRACTS = {
  sepolia: {
    token: '0x...',
    marketplace: '0x...',
    registry: '0x...',
    blacklist: '0x...',
    oracle: '0x...'
  }
};

class SONMClient {
  provider: ethers.Provider;
  signer: ethers.Signer;
  token: ethers.Contract;
  marketplace: ethers.Contract;
  registry: ethers.Contract;
  
  constructor(provider: ethers.Provider, signer: ethers.Signer, chainId: number) {
    this.provider = provider;
    this.signer = signer;
    
    const addresses = CONTRACTS[chainId === 11155111 ? 'sepolia' : 'mainnet'];
    
    this.token = new ethers.Contract(
      addresses.token,
      SNMTokenABI.abi,
      signer
    );
    
    this.marketplace = new ethers.Contract(
      addresses.marketplace,
      MarketplaceABI.abi,
      signer
    );
    
    this.registry = new ethers.Contract(
      addresses.registry,
      RegistryABI.abi,
      signer
    );
  }
}
```

### 2. Token Operations

```typescript
// Get token info
async function getTokenInfo(client: SONMClient) {
  const [name, symbol, decimals, totalSupply] = await Promise.all([
    client.token.name(),
    client.token.symbol(),
    client.token.decimals(),
    client.token.totalSupply()
  ]);
  
  return {
    name,
    symbol,
    decimals,
    totalSupply: ethers.formatUnits(totalSupply, decimals)
  };
}

// Get balance
async function getBalance(client: SONMClient, address: string) {
  const balance = await client.token.balanceOf(address);
  const decimals = await client.token.decimals();
  return ethers.formatUnits(balance, decimals);
}

// Approve tokens for marketplace
async function approveMarketplace(client: SONMClient, amount: string) {
  const decimals = await client.token.decimals();
  const parsedAmount = ethers.parseUnits(amount, decimals);
  
  const tx = await client.token.approve(
    await client.marketplace.getAddress(),
    parsedAmount
  );
  
  return await tx.wait();
}
```

### 3. Marketplace Operations

```typescript
// Place ASK order (supplier)
async function placeAskOrder(
  client: SONMClient,
  price: string,      // USD per hour * 10^18
  duration: number,   // seconds
  benchmarks: number[]
) {
  const priceWei = ethers.parseUnits(price, 18);
  
  const tx = await client.marketplace.placeOrder(
    2, // ORDER_ASK
    ethers.ZeroAddress, // no counterparty restriction
    duration,
    priceWei,
    [true, false], // netflags example
    1, // ANONYMOUS identity level
    ethers.ZeroAddress, // no blacklist
    ethers.encodeBytes32String(''),
    benchmarks
  );
  
  const receipt = await tx.wait();
  
  // Parse event for order ID
  const event = receipt?.logs.find(
    (log: any) => log.fragment?.name === 'OrderPlaced'
  );
  
  return event?.args?.[0]; // orderID
}

// Place BID order (consumer)
async function placeBidOrder(
  client: SONMClient,
  price: string,
  duration: number,
  benchmarks: number[]
) {
  // First approve tokens
  await approveMarketplace(client, '1000'); // Approve 1000 SNM
  
  const priceWei = ethers.parseUnits(price, 18);
  
  const tx = await client.marketplace.placeOrder(
    1, // ORDER_BID
    ethers.ZeroAddress,
    duration,
    priceWei,
    [true, false],
    1,
    ethers.ZeroAddress,
    ethers.encodeBytes32String(''),
    benchmarks
  );
  
  return await tx.wait();
}

// Get order info
async function getOrder(client: SONMClient, orderId: bigint) {
  const order = await client.marketplace.getOrder(orderId);
  
  return {
    id: orderId,
    orderType: order.orderType,
    status: order.orderStatus,
    author: order.author,
    price: ethers.formatUnits(order.price, 18),
    duration: Number(order.duration),
    benchmarks: order.benchmarks.map((b: bigint) => Number(b))
  };
}

// Open deal
async function openDeal(
  client: SONMClient,
  askId: bigint,
  bidId: bigint
) {
  const tx = await client.marketplace.openDeal(askId, bidId);
  const receipt = await tx.wait();
  
  const event = receipt?.logs.find(
    (log: any) => log.fragment?.name === 'DealOpened'
  );
  
  return event?.args?.[0]; // dealID
}

// Get deal info
async function getDeal(client: SONMClient, dealId: bigint) {
  const deal = await client.marketplace.getDeal(dealId);
  
  return {
    id: dealId,
    supplier: deal.supplierID,
    consumer: deal.consumerID,
    price: ethers.formatUnits(deal.price, 18),
    status: deal.status,
    startTime: new Date(Number(deal.startTime) * 1000),
    endTime: deal.endTime > 0 ? new Date(Number(deal.endTime) * 1000) : null
  };
}
```

### 4. Profile Registry

```typescript
// Get profile level
async function getProfileLevel(client: SONMClient, address: string) {
  const level = await client.registry.getProfileLevel(address);
  
  const levels = ['UNKNOWN', 'ANONYMOUS', 'REGISTERED', 'IDENTIFIED', 'PROFESSIONAL'];
  return levels[Number(level)];
}

// Create certificate (as validator)
async function createCertificate(
  client: SONMClient,
  owner: string,
  attributeType: bigint,
  value: string
) {
  const tx = await client.registry.createCertificate(
    owner,
    attributeType,
    ethers.toUtf8Bytes(value)
  );
  return await tx.wait();
}
```

## 🎨 React Hook Example

```typescript
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

export function useSONM() {
  const [client, setClient] = useState<SONMClient | null>(null);
  const [account, setAccount] = useState<string>('');
  
  useEffect(() => {
    async function init() {
      if (window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        const signer = await provider.getSigner();
        const network = await provider.getNetwork();
        
        const client = new SONMClient(provider, signer, Number(network.chainId));
        setClient(client);
        
        const address = await signer.getAddress();
        setAccount(address);
      }
    }
    
    init();
  }, []);
  
  return { client, account };
}

// Usage in component
function OrderList() {
  const { client, account } = useSONM();
  const [orders, setOrders] = useState([]);
  
  useEffect(() => {
    async function fetchOrders() {
      if (!client) return;
      
      // Get order count
      const count = await client.marketplace.ordersAmount();
      
      // Fetch each order
      const orderPromises = [];
      for (let i = 1; i <= Number(count); i++) {
        orderPromises.push(getOrder(client, BigInt(i)));
      }
      
      const allOrders = await Promise.all(orderPromises);
      setOrders(allOrders.filter(o => o.status === 2)); // Active orders
    }
    
    fetchOrders();
  }, [client]);
  
  return (
    <div>
      {orders.map(order => (
        <OrderCard key={order.id} order={order} />
      ))}
    </div>
  );
}
```

## 📱 Event Listening

```typescript
// Listen for new orders
function subscribeToOrders(client: SONMClient, callback: (orderId: bigint) => void) {
  client.marketplace.on('OrderPlaced', (orderId, event) => {
    callback(orderId);
  });
}

// Listen for new deals
function subscribeToDeals(client: SONMClient, callback: (dealId: bigint) => void) {
  client.marketplace.on('DealOpened', (dealId, supplier, consumer, event) => {
    callback(dealId);
  });
}

// Cleanup
function unsubscribe(client: SONMClient) {
  client.marketplace.removeAllListeners();
}
```

## 🔗 Next Steps

1. **Wallet Integration**: Add WalletConnect, Coinbase Wallet
2. **Error Handling**: Add user-friendly error messages
3. **Loading States**: Add skeleton screens and spinners
4. **Real-time Updates**: Use WebSocket provider for events
5. **Mobile Support**: Test on mobile wallets (MetaMask Mobile, Rainbow)

## 📚 Resources

- [Ethers.js Documentation](https://docs.ethers.io/v6/)
- [Viem Documentation](https://viem.sh/)
- [MetaMask Developer Docs](https://docs.metamask.io/)
