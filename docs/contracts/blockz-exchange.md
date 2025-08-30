# BlockzExchange

The `BlockzExchange` is the core marketplace contract that handles NFT trading operations including offers, sales, and batch transactions.

## Overview

* **Contract Name**: `BlockzExchange`
* **Purpose**: NFT marketplace with batch operations and offer system
* **Upgradeable**: Yes (using OpenZeppelin's proxy pattern)
* **Network**: Ethereum mainnet compatible

## Key Features

### ✅ **Batch Operations**

* Buy multiple NFTs in a single transaction
* Accept multiple offers simultaneously
* Cancel multiple orders at once
* Limit: 20 operations per batch

### 🎯 **Offer System**

* Individual token offers
* Collection-wide offers
* Time-based expiration
* Signature-based validation

### 🔒 **Security Features**

* EIP-712 signature verification
* Reentrancy protection
* Pausable functionality
* Block range validation for signatures

## Main Functions

### Trading Functions

#### `batchBuyETH`

```solidity
function batchBuyETH(
    LibOrderV2.BatchOrder[] calldata batchOrders,
    bytes[] calldata signatures,
    uint256[] calldata positions
) external payable
```

**Purpose**: Purchase multiple NFTs with ETH payment **Parameters**:

* `batchOrders`: Array of batch orders containing NFT details
* `signatures`: Cryptographic signatures for each order
* `positions`: Specific NFT positions within each batch order

#### `acceptOfferBatch`

```solidity
function acceptOfferBatch(
    LibOrderV2.Offer[] calldata offers,
    bytes[] calldata signatures,
    LibOrderV2.Token[] calldata tokens,
    bytes[] calldata tokenSignatures
) external
```

**Purpose**: Accept multiple offers for NFTs you own **Requirements**:

* Must own the NFTs
* Valid signatures from buyers
* Offers must not be expired

### Administrative Functions

#### `setValidator`

```solidity
function setValidator(address _validator) external onlyOwner
```

**Purpose**: Set the trusted validator address for signature verification

#### `setBlockRange`

```solidity
function setBlockRange(uint256 _blockRange) external onlyOwner
```

**Purpose**: Set the time limit for signature validity (in blocks)

## Events

### `Redeem`

```solidity
event Redeem(
    address indexed collection,
    uint256 indexed tokenId,
    string salt,
    uint256 value
);
```

Emitted when an NFT is purchased.

### `AcceptOffer`

```solidity
event AcceptOffer(
    address indexed collection,
    uint256 indexed tokenId,
    address indexed buyer,
    string salt,
    uint256 bid
);
```

Emitted when an offer is accepted.

## Integration Example

```javascript
// Example: Buy NFT with ETH
const tx = await blockzExchange.batchBuyETH(
  [batchOrder], // Array of orders
  [signature], // Array of signatures
  [0], // Position in batch (0 = first item)
  { value: ethers.utils.parseEther("1.0") }
);
```

## Security Considerations

1. **Signature Validation**: All transactions require valid EIP-712 signatures
2. **Time Limits**: Signatures expire after `blockRange` blocks
3. **Reentrancy Protection**: All external calls are protected
4. **Access Control**: Admin functions restricted to contract owner

## Gas Optimization

* Batch operations save gas compared to individual transactions
* Efficient storage usage with mappings
* Optimized loops with minimal external calls

## Related Contracts

* [AssetManager](asset-manager.md) - Handles payments and fees
* [NFTCollectible](nft-collectible.md) - NFT contract template
* [Royalty System](royalty.md) - Creator royalty management
