# 🪙 DSC Protocol - Decentralized Stable Coin

> **⚠️ EDUCATIONAL PURPOSE ONLY**  
> This codebase is a learning exercise for building DeFi solutions with algorithmic stablecoins. It has **NOT** been audited and should **NEVER** be used in production environments.

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue)
![Foundry](https://img.shields.io/badge/Foundry-Latest-green)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Test Coverage](https://img.shields.io/badge/Coverage-95%25-brightgreen)

*Building the future of decentralized finance, one smart contract at a time*

</div>

## 🚀 What is DSC Protocol?

DSC (Decentralized Stable Coin) is an **educational implementation** of an overcollateralized algorithmic stablecoin protocol. Think of it as a simplified version of MakerDAO's DAI, designed to teach the fundamentals of:

- 🏦 **Collateralized Debt Positions (CDPs)**
- 📊 **Oracle-based price feeds**
- ⚖️ **Liquidation mechanisms**
- 🔒 **DeFi security patterns**
- 🧪 **Property-based testing**

### 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DSC Token     │◄───│   DSC Engine    │────┤ Price Oracles   │
│  (ERC20)        │    │ (Core Logic)    │    │ (Chainlink)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                               │
                               ▼
                    ┌─────────────────┐
                    │   Collateral    │
                    │ (WETH, WBTC,    │
                    │  WSOL)          │
                    └─────────────────┘
```

## ✨ Protocol Features

### Core Characteristics
1. **Relative Stability**: Anchored/Pegged to USD $1.00
   - Using Chainlink price feeds
   - Exchange function for WETH & WBTC → $$$

2. **Stability Mechanism**: Algorithmic (Decentralized)
   - Overcollateralized minting
   - Automated liquidation system

3. **Collateral Type**: Exogenous (Crypto)
   - Ethereum (WETH)
   - Bitcoin (WBTC)
   - Solana (WSOL)

### Technical Features
- 🎯 **Overcollateralized Stability** - Maintain >150% collateral ratio
- 🔄 **Multi-Collateral Support** - WETH, WBTC, WSOL
- 📈 **Real-time Price Feeds** - Chainlink oracle integration
- ⚡ **Instant Liquidations** - Automated liquidation system
- 🛡️ **Security First** - Comprehensive testing and analysis tools
- 🔧 **Modular Design** - Clean, upgradeable architecture

## 🛠️ Technology Stack

- **Smart Contracts**: Solidity ^0.8.30
- **Development Framework**: Foundry
- **Oracle Provider**: Chainlink
- **Security Tools**: Slither, Aderyn, Echidna, Solhint
- **Testing**: Unit, Integration, Invariant, Property-based
- **Networks**: Anvil (local), Sepolia (testnet)

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed:
- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for security tools)
- [Python](https://www.python.org/) (for Slither)
- [Rust](https://rustup.rs/) (for Aderyn)

### Installation

```bash
# Clone the repository
git clone https://github.com/vidalpaul/dsc-defi.git
cd dsc-defi

# Install Foundry dependencies
forge install

# Install security tools (optional)
./scripts/install-security-tools.sh

# Build the project
forge build
```

## 🧪 Testing

We've implemented comprehensive testing with **95%+ coverage**:

```bash
# Run all tests
make test

# Run specific test suites
make test-unit        # Unit tests
make test-invariant   # Invariant tests

# Generate coverage report
make coverage

# Run security analysis
make security
```

### Test Coverage by Component

| Component | Lines | Statements | Branches | Functions |
|-----------|-------|------------|----------|-----------|
| **DSC Token** | 100% | 100% | 100% | 100% |
| **DSC Engine** | 95%+ | 95%+ | 90%+ | 95%+ |
| **DSC Library** | 100% | 100% | 100% | 100% |
| **Scripts** | 100% | 100% | 95%+ | 100% |

## 🌐 Sepolia Testnet Deployment

### Getting Testnet Tokens

Before deploying to Sepolia, you'll need testnet ETH and tokens:

#### 1. **Sepolia ETH** 🚰
Get free Sepolia ETH from these faucets:
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- [Chainlink Sepolia Faucet](https://faucets.chain.link/sepolia)
- [Infura Sepolia Faucet](https://www.infura.io/faucet/sepolia)

#### 2. **Testnet Tokens** 🪙
The protocol uses these testnet tokens (automatically deployed):
- **WETH**: `0xdd13E55209Fd76AfE204dBda4007C227904f0a81`
- **WBTC**: `0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063`
- **WSOL**: `0x2644980C2480EB8F31263d24189e2AA5e7f8f1D3`

### Environment Setup

Create a `.env` file in the project root:

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your details
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Deploy to Sepolia

```bash
# Deploy the complete protocol
make deploy-sepolia

# Or use forge directly
forge script script/DSC_Protocol_Deploy.s.sol:DSC_Protocol_DeployScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

### Interact with the Protocol

Once deployed, you can interact with the protocol:

```bash
# Example: Deposit collateral and mint DSC
cast send $DSC_ENGINE_ADDRESS \
    "depositCollateralAndMintDSC(address,uint256,uint256)" \
    $WETH_ADDRESS \
    1000000000000000000 \
    500000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

## 📖 How to Use DSC Protocol

### 1. **Deposit Collateral** 💰
```solidity
// Deposit 1 WETH as collateral
dscEngine.depositCollateral(wethAddress, 1 ether);
```

### 2. **Mint DSC** 🏭
```solidity
// Mint 1000 DSC tokens (ensure health factor > 1)
dscEngine.mintDSC(1000 ether);
```

### 3. **Check Health Factor** 📊
```solidity
// Monitor your position health
uint256 healthFactor = dscEngine.getHealthFactor(userAddress);
// If healthFactor < 1e18, position can be liquidated!
```

### 4. **Redeem Collateral** 🔄
```solidity
// Burn DSC first, then redeem collateral
dscEngine.burnDSC(500 ether);
dscEngine.redeemCollateral(wethAddress, 0.5 ether);
```

## 🛡️ Security Features

This educational protocol includes comprehensive security measures:

### Automated Security Tools
- **Slither**: Static analysis for common vulnerabilities
- **Aderyn**: Advanced DeFi-specific security scanning
- **Echidna**: Property-based testing with 8 critical invariants
- **Solhint**: Code quality and style enforcement

### Key Security Invariants
1. ✅ Protocol must remain overcollateralized
2. ✅ User health factors ≥ 1.0 (except during liquidation)
3. ✅ DSC total supply ≤ total collateral value
4. ✅ Accurate collateral accounting
5. ✅ Price feed manipulation resistance

### Run Security Analysis
```bash
# Complete security audit
make security

# Individual tools
make slither    # Static analysis
make aderyn     # DeFi security scan
make echidna    # Property testing
make solhint    # Code quality
```

## 📚 Learning Resources

This project demonstrates key DeFi concepts:

### Smart Contract Patterns
- **Access Control**: OpenZeppelin's Ownable pattern
- **Reentrancy Protection**: ReentrancyGuard implementation
- **Oracle Integration**: Chainlink price feeds
- **Safe Math**: Built-in overflow protection (Solidity ^0.8.0)

### DeFi Mechanics
- **Collateralization**: Over-collateralized lending
- **Liquidations**: Automated liquidation incentives
- **Price Oracles**: External price data integration
- **Stablecoin Mechanisms**: Algorithmic price stability

### Testing Strategies
- **Unit Testing**: Individual function testing
- **Integration Testing**: Multi-contract interactions
- **Invariant Testing**: Protocol-level invariants
- **Property-Based Testing**: Fuzzing with random inputs

## 🏗️ Project Structure

```
dsc-defi/
├── src/
│   ├── DSC.sol              # ERC20 stablecoin implementation
│   ├── DSCEngine.sol        # Core protocol logic
│   └── DSCLib.sol           # Shared utility functions
├── script/
│   ├── Config_Helper.s.sol  # Network configuration
│   └── DSC_Protocol_Deploy.s.sol # Deployment script
├── test/
│   ├── unit/                # Unit tests
│   ├── echidna/             # Property-based tests
│   └── mocks/               # Mock contracts
├── security-reports/        # Security analysis output
├── Makefile                 # Build and test commands
└── README.md               # This file
```

## 🎯 Educational Goals

By studying this codebase, you'll learn:

1. **DeFi Protocol Architecture** 🏗️
   - How stablecoins maintain their peg
   - Collateralized debt position mechanics
   - Liquidation system design

2. **Smart Contract Security** 🛡️
   - Common vulnerabilities and mitigations
   - Comprehensive testing strategies
   - Security analysis tools usage

3. **Oracle Integration** 📊
   - Chainlink price feed implementation
   - Oracle manipulation attack prevention
   - Price data validation

4. **Advanced Solidity** ⚡
   - Library pattern usage
   - Complex state management
   - Gas optimization techniques

## 🤝 Contributing

This is an educational project! Contributions are welcome:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow the existing code style
- Add comprehensive tests for new features
- Run security analysis before submitting
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

**THIS CODE IS FOR EDUCATIONAL PURPOSES ONLY**

- 🚫 **Not Production Ready**: This code has not undergone professional security audits
- 🎓 **Learning Tool**: Designed to teach DeFi concepts and smart contract development
- 💡 **Experimental**: May contain bugs, vulnerabilities, or design flaws
- 🔒 **Use at Your Own Risk**: Authors are not responsible for any losses

## 🙏 Acknowledgments

This project was built as a learning exercise inspired by:
- [MakerDAO](https://makerdao.com/) - The original DeFi stablecoin protocol
- [Chainlink](https://chain.link/) - Decentralized oracle networks
- [OpenZeppelin](https://openzeppelin.com/) - Secure smart contract libraries
- [Foundry](https://getfoundry.sh/) - Fast, portable, and modular toolkit

## 📞 Support

If you're using this for learning and need help:
- 📚 Check the [documentation](./docs/)
- 🐛 Open an [issue](https://github.com/vidalpaul/dsc-defi/issues)
- 💬 Start a [discussion](https://github.com/vidalpaul/dsc-defi/discussions)

---

<div align="center">

**Happy Learning! 🚀**

*"In DeFi we trust, but always verify"* ✨

Made with ❤️ for the DeFi community

</div>