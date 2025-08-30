# NFTCollectible Contract

## 📋 Overview

ERC-721 compliant NFT contract with marketplace integration and royalty support.

## 🔧 Key Features

- **ERC-721 Standard**: Full NFT functionality
- **Royalty Support**: EIP-2981 implementation
- **Marketplace Integration**: Optimized for trading
- **Metadata Management**: IPFS and HTTP support

## 📚 Core Functions

### Minting Functions

#### `mint(address to, uint256 tokenId, string memory uri)`

Mints a new NFT.

**Parameters:**

- `to`: Recipient address
- `tokenId`: Unique token identifier
- `uri`: Metadata URI

**Requirements:**

- Caller must have MINTER_ROLE
- Token ID must not exist

#### `safeMint(address to, string memory uri)`

Safely mints NFT with auto-incremented ID.

### Standard ERC-721 Functions

All standard ERC-721 functions are supported:

- `transferFrom()`
- `safeTransferFrom()`
- `approve()`
- `setApprovalForAll()`

## 👑 Royalty System

### `setDefaultRoyalty(address receiver, uint96 feeNumerator)`

Sets default royalty for all tokens.

**Parameters:**

- `receiver`: Royalty recipient
- `feeNumerator`: Royalty percentage (basis points)

### `setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)`

Sets royalty for specific token.

## 📊 Events

```solidity
event RoyaltySet(uint256 indexed tokenId, address indexed receiver, uint96 feeNumerator);
event MetadataUpdate(uint256 indexed tokenId, string uri);
```

## 💡 Usage Examples

### Basic Minting

```solidity
// Mint NFT to creator
nft.mint(creator, tokenId, "ipfs://QmHash");

// Set 10% royalty
nft.setTokenRoyalty(tokenId, creator, 1000);
```
