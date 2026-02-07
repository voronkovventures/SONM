# SONM Modernized

> Modernized version of SONM (Supercomputer Organized by Network Mining) smart contracts  
> Solidity 0.4.x → 0.8.20 | OpenZeppelin 5.x | Foundry

## 🚀 Overview

This is a complete modernization of the SONM decentralized fog computing platform smart contracts. The original contracts were written in Solidity 0.4.x (2017-2018 era) and have been updated to modern standards.

### Key Improvements

| Feature | Original | Modernized |
|---------|----------|------------|
| Solidity Version | 0.4.x | 0.8.20 |
| OpenZeppelin | 2.x | 5.x |
| Custom Errors | ❌ No | ✅ Yes (cheaper gas) |
| SafeERC20 | ❌ Manual | ✅ OpenZeppelin |
| ReentrancyGuard | ❌ No | ✅ Yes |
| NatSpec Docs | ❌ No | ✅ Full coverage |
| Foundry Tests | ❌ No | ✅ Comprehensive |

## 📁 Contracts

### Core Contracts

```
src/
├── SNMToken.sol           # ERC20 utility token (444M max supply)
├── ProfileRegistry.sol    # Identity & certificate management
└── SONMMarketplace.sol    # Orderbook, deals, billing
```

### SNMToken
- ERC20 with burn functionality
- Max supply: 444 million SNM
- Mintable by owner (until renounced)
- 18 decimals

### ProfileRegistry
- Identity levels: Anonymous → Registered → Identified → Professional
- Certificate management system
- Validator hierarchy with SONM-level validators

### SONMMarketplace
- **Orders**: ASK (supplier) and BID (consumer)
- **Deals**: Matched orders with on-chain billing
- **Worker Management**: Master-worker relationships
- **Features**: Pausable, Reentrancy protection

## 🛠️ Development

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd sonm-modern

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run tests with gas report
forge test --gas-report
```

## 🧪 Testing

### Run All Tests
```bash
forge test -v
```

### Run Specific Test
```bash
forge test --match-test test_PlaceAskOrder -v
```

### Gas Report
```bash
forge test --gas-report
```

## 📦 Deployment

### Local Testing (Anvil)

```bash
# Start local node
anvil

# Deploy in another terminal
forge script script/Deploy.s.sol:DeployToAnvil --fork-url http://localhost:8545 --broadcast
```

### Testnet/Mainnet

```bash
# Set environment variables
export PRIVATE_KEY=<your-private-key>
export RPC_URL=<your-rpc-url>

# Deploy
forge script script/Deploy.s.sol:DeploySONM --rpc-url $RPC_URL --broadcast --verify
```

## 📊 Gas Optimization

The modernized contracts use:
- Custom errors instead of strings (saves ~50 gas per revert)
- Efficient storage packing
- `via-ir` compiler optimization
- 200 optimizer runs

## 🔒 Security

### Audit Checklist
- [x] Reentrancy protection on all external calls
- [x] SafeERC20 for token transfers
- [x] Access control (Ownable)
- [x] Pausable functionality
- [x] Integer overflow protection (Solidity 0.8.x built-in)
- [x] Custom errors for better UX

## 📖 Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SONM MARKETPLACE                  │
├─────────────────────────────────────────────────────┤
│                                                      │
│   ┌─────────────┐        ┌─────────────┐           │
│   │   SUPPLIER  │        │   CONSUMER  │           │
│   │  (Worker)   │◄──────►│   (User)    │           │
│   └──────┬──────┘        └──────┬──────┘           │
│          │                      │                   │
│          └──────────┬───────────┘                   │
│                     │                               │
│            ┌────────▼────────┐                      │
│            │  MARKETPLACE    │                      │
│            │  - Place Order  │                      │
│            │  - Match Deals  │                      │
│            │  - Bill Usage   │                      │
│            └────────┬────────┘                      │
│                     │                               │
│   ┌─────────────────┼─────────────────┐            │
│   │                 │                 │            │
│   ▼                 ▼                 ▼            │
│ ┌──────┐      ┌──────────┐      ┌──────────┐      │
│ │ SNM  │      │ Profile  │      │  Deal    │      │
│ │Token │      │ Registry │      │ Storage  │      │
│ └──────┘      └──────────┘      └──────────┘      │
└─────────────────────────────────────────────────────┘
```

## 🔄 Migration from Original

### Original → Modern Mapping

| Original (0.4.x) | Modern (0.8.20) | Notes |
|-----------------|-----------------|-------|
| `SNM.sol` | `SNMToken.sol` | Added burn, improved mint |
| `ProfileRegistry.sol` | `ProfileRegistry.sol` | Custom errors, better validation |
| `Market.sol` | `SONMMarketplace.sol` | ReentrancyGuard, SafeERC20 |
| `Blacklist.sol` | (TBD) | Planned for v2 |
| `OracleUSD.sol` | (TBD) | Use Chainlink instead |

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- Original SONM team for the pioneering work in decentralized computing
- OpenZeppelin for secure contract libraries
- Foundry team for excellent development tooling

## 📞 Contact

For questions about the modernization:
- GitHub Issues
- Telegram: @voronkov_ventures

---

**Disclaimer**: This is an educational/modernization project. Use at your own risk.