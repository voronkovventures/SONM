# SONM Sepolia Testnet Deployment

## 🚀 Quick Deploy

### 1. Fund Deployment Wallet

**Address:** `0x4F1566fcEde9FC7Ee523D7110EF6E2e58ab9CEA7`

Get Sepolia ETH from:
- https://sepoliafaucet.com/ (0.5 ETH/day)
- https://faucet.quicknode.com/ethereum/sepolia
- https://www.alchemy.com/faucets/ethereum-sepolia

### 2. Deploy

```bash
# Set environment
export RPC_URL=https://ethereum-sepolia.publicnode.com
export PRIVATE_KEY=<your-private-key-with-0x-prefix>

# Deploy all contracts
forge script script/Deploy.s.sol:DeploySONM \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 3. Verify Contracts

If not auto-verified:
```bash
forge verify-contract \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  <contract-address> \
  src/SNMToken.sol:SNMToken
```

## 📋 Expected Gas Costs

| Contract | Estimated Gas | Sepolia ETH |
|----------|--------------|-------------|
| SNMToken | 1,200,000 | ~0.001 |
| ProfileRegistry | 900,000 | ~0.001 |
| SONMMarketplace | 2,500,000 | ~0.002 |
| **Total** | **~4.6M** | **~0.004 ETH** |

## 🔗 Sepolia Resources

- **Explorer:** https://sepolia.etherscan.io
- **RPC:** https://ethereum-sepolia.publicnode.com
- **Chain ID:** 11155111
- **Currency:** SepoliaETH

## 📊 Post-Deployment

After deployment, save the contract addresses to:
- `.env` file
- Frontend config
- Go backend config

Example `.env`:
```bash
SONM_TOKEN=0x...
SONM_REGISTRY=0x...
SONM_MARKETPLACE=0x...
SONM_CHAIN_ID=11155111
SONM_RPC_URL=https://ethereum-sepolia.publicnode.com
```
