# Blockz Smart Contracts Documentation

This repository contains the smart contracts for the blockz NFT marketplace platform. Below is a detailed description of each contract's purpose and functionality.

## 🏗️ Current Active Contracts

The marketplace is built with a minimal, efficient set of core contracts focused on NFT trading functionality:

### BlockzExchange

**Purpose**: Core marketplace contract for NFT trading operations.

- Handles NFT listings and purchases
- Processes buy/sell orders with batch operations
- Manages offers and accepts them efficiently
- Integrates with AssetManager for secure payments
- Supports EIP-712 signature verification for off-chain orders

**Example Use Case**:

```solidity
// Accept multiple offers in a single transaction
exchange.acceptOfferBatch(offers, signatures, tokens, tokenSignatures);

// Execute batch purchases
exchange.batchBuy(batchOrders, signatures, positions);
```

### AssetManager

**Purpose**: Manages financial transactions and asset transfers within the platform.

- Handles deposits and withdrawals of native tokens (ETH/AVAX)
- Manages bidding wallets for users
- Processes payments for NFT purchases with royalty distribution
- Handles platform fee collection and distribution
- Supports whitelisted platforms for integration

**Example Use Case**:

```solidity
// Deposit AVAX to bidding wallet
assetManager.deposit{value: 1 ether}();

// Process marketplace payments with automatic royalty distribution
assetManager.payMPBatch(paymentInfoArray);
```

### NFTCollectible

**Purpose**: Template contract for NFT collections with marketplace integration.

- Full ERC-721 implementation with enumerable extension
- Integrated royalty support (EIP-2981 compliant)
- Flexible metadata management (IPFS and HTTP support)
- Owner-controlled minting with custom royalty settings
- Optimized for marketplace trading

**Example Use Case**:

```solidity
// Mint NFT with custom metadata and royalties
nft.mint("ipfs://QmHash", royaltiesArray);

// Set collection-wide base URI
nft.setBaseTokenURI("https://metadata.example.com/");
```

### Royalty System

**Purpose**: Comprehensive royalty management supporting multiple distribution models.

- EIP-2981 standard compliance for broad marketplace support
- Support for multiple royalty recipients per token
- Collection-wide and token-specific royalty configurations
- Automatic royalty calculation and distribution
- Gas-optimized royalty processing

**Example Use Case**:

```solidity
// Set default collection royalty
royalty.setDefaultRoyalties(royaltyArray);

// Query royalty information for marketplace integration
(receiver, amount) = royalty.royaltyInfo(tokenId, salePrice);
```

### TestNFT

**Purpose**: Simple ERC-721 contract for testing and development.

- Lightweight NFT implementation for testing marketplace features
- Public minting functionality for easy testing
- Batch minting capabilities for test data generation
- Configurable metadata management

**Example Use Case**:

```solidity
// Public mint for testing
testNFT.publicMint("test-metadata-uri");

// Batch mint for test scenarios
testNFT.batchMint(recipients, tokenURIs);
```

## 🔧 Contract Interactions

### Marketplace Trading Flow

1. **NFT Listing**: Owner approves `BlockzExchange` and creates listing
2. **Purchase Processing**: `BlockzExchange` coordinates with `AssetManager` for payments
3. **Payment Distribution**: `AssetManager` handles royalties, fees, and seller payments
4. **NFT Transfer**: Secure transfer to buyer with full event logging

### Key Features

- **Batch Operations**: Process multiple NFTs in single transactions for gas efficiency
- **Signature-Based Trading**: Off-chain order creation with on-chain settlement
- **Flexible Royalties**: Support for complex royalty structures
- **Upgradeable Architecture**: Proxy pattern for critical contracts
- **Security First**: Comprehensive access controls and pause mechanisms

## 📁 Archive Contracts

The following contracts represent previous iterations or planned features that are currently archived:

<details>
<summary>Click to view archived contracts</summary>

### Platform Contracts (Archived)

- **Launchpad**: NFT collection launches with allowlist/public phases
- **VRFCoordinator**: Chainlink VRF integration for randomness
- **BlockzCollection**: Previous NFT collection implementation
- **ERC721Dummy**: Legacy test contract

### Advanced Trading (Archived)

- **BlockzLending**: NFT-backed lending functionality
- **DutchAuctionMarketplace**: Dutch auction mechanism
- **AuctionMarketplace**: Traditional auction system
- **Marketplace**: Previous marketplace implementation
- **PaymentManager**: Legacy payment processing
- **OfferPool/ListingPool**: Previous offer management

### Governance (Archived)

- **BlockzGovernanceToken**: Platform governance token
- **VeArt**: Vote-escrowed staking mechanism

### Utility (Archived)

- **BlockzOperator**: Administrative operations
- **BlockzMini**: Companion NFT collection

</details>

## Getting Started

1. Install dependencies:

```bash
forge install
```

2. Compile contracts:

```bash
forge build
```

3. Run tests:

```bash
forge test
```

## 🔒 Security Considerations

- All contracts use OpenZeppelin's battle-tested implementations
- Comprehensive reentrancy protection across all financial operations
- Pausable functionality for emergency situations
- Role-based access controls for administrative functions
- EIP-712 signature verification for secure off-chain interactions

## 🚀 Deployment

The contracts are designed for deployment on EVM-compatible networks. See the [deployment guide](docs/DEPLOY_README.md) for detailed deployment procedures.

## 📚 Documentation

- [📖 Smart Contract Documentation](docs/)
- [🏗️ Architecture Overview](docs/architecture/)
- [👩‍💻 Developer Guide](docs/developers/)
- [💡 Usage Examples](docs/examples/)

## License

MIT License - see LICENSE file for details
