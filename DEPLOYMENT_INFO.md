# SONM Modern Deployment

## Wallet Information
- **Address:** 0x4F1566fcEde9FC7Ee523D7110EF6E2e58ab9CEA7
- **Network:** Sepolia Testnet (Chain ID: 11155111)
- **Status:** Awaiting funding

## Get Sepolia ETH

### Faucets (выбери один):
1. **Sepolia Faucet** (0.5 ETH/day)
   https://sepoliafaucet.com/
   
2. **Alchemy Faucet** (0.5 ETH/day)
   https://sepoliafaucet.com/
   
3. **QuickNode Faucet**
   https://faucet.quicknode.com/ethereum/sepolia

### Как получить:
1. Перейди по ссылке
2. Введи адрес: `0x4F1566fcEde9FC7Ee523D7110EF6E2e58ab9CEA7`
3. Запроси ETH
4. Подожди 1-2 минуты
5. Проверь баланс

## Deploy Commands

```bash
# Set environment
export PRIVATE_KEY=<your-private-key-with-0x-prefix>
export RPC_URL=https://ethereum-sepolia.publicnode.com

# Deploy
cd /root/.openclaw/workspace/sonm-analysis/sonm-modern
forge script script/Deploy.s.sol:DeploySONM \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

## Expected Output
```
SNM Token deployed at: 0x...
Profile Registry deployed at: 0x...
SONM Marketplace deployed at: 0x...
```
