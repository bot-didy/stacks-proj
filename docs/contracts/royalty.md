# Royalty System

## 📋 Overview

Comprehensive royalty management system supporting EIP-2981 standard and custom configurations.

## 🔧 Key Features

* **EIP-2981 Compliance**: Standard royalty interface
* **Flexible Configuration**: Per-token and collection-wide settings
* **Multi-recipient Support**: Split royalties among multiple creators
* **Automatic Distribution**: Seamless payment processing

## 👑 Royalty Configuration

### Default Royalties

Set collection-wide royalty percentages:

```solidity
// Set 0.5% default royalty
nft.setDefaultRoyalty(creator, 50); // 50 basis points = 0.5%
```

### Token-Specific Royalties

Override default for specific tokens:

```solidity
// Set 10% royalty for special token
nft.setTokenRoyalty(tokenId, artist, 1000);
```

## 📊 Royalty Calculation

### Standard Calculation

```solidity
function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external view returns (address receiver, uint256 royaltyAmount) {

    uint256 royalty = (salePrice * royaltyPercentage) / 10000;
    return (royaltyReceiver, royalty);
}
```

### Multi-recipient Splits

```solidity
struct RoyaltySplit {
    address recipient;
    uint96 percentage;  // Basis points
}

// Split 10% royalty between two creators
RoyaltySplit[] memory splits = [
    RoyaltySplit(artist1, 600),  // 6%
    RoyaltySplit(artist2, 400)   // 4%
];
```

## 🔄 Integration with Marketplace

### Automatic Royalty Processing

The marketplace automatically:

1. Queries royalty information using `royaltyInfo()`
2. Calculates royalty amount from sale price
3. Transfers royalty to creator(s)
4. Transfers remaining amount to seller

### Example Transaction Flow

```solidity
// Sale price: 1 CORE
// Royalty: 10% = 0.1 CORE to creator
// Platform fee: 2.5% = 0.025 CORE to platform
// Seller receives: 0.875 CORE
```

## 💡 Usage Examples

### Setting Up Creator Royalties

```solidity
// Collection creator sets 7.5% royalty
nft.setDefaultRoyalty(collectionCreator, 750);

// Individual artist overrides for their piece
nft.setTokenRoyalty(specialTokenId, individualArtist, 1000); // 10%
```

### Querying Royalty Information

```solidity
// Get royalty info for a sale
(address receiver, uint256 amount) = nft.royaltyInfo(tokenId, salePrice);

// Verify royalty compliance
bool isCompliant = nft.supportsInterface(type(IERC2981).interfaceId);
```

## 🚫 Limitations

* Maximum royalty: 10% (1000 basis points)
* Royalty recipients must be valid addresses
* Cannot exceed 100% total when using splits
