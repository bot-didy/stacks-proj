# Royalty Setup

## 📋 Overview

Complete guide for setting up creator royalties in the NFT marketplace.

## 🎯 Scenario

An artist wants to configure different royalty rates for their NFT collection.

## 👑 Default Collection Royalty

### Setting 0.5% Default Royalty

```solidity
// Set 0.5% royalty for the entire collection
nft.setDefaultRoyalty(artistAddress, 50); // 50 basis points = 0.5%
```

**Frontend Integration:**

```javascript
const royaltyTx = await nftContract.connect(artist).setDefaultRoyalty(
  artistAddress,
  50 // 0.5%
);
await royaltyTx.wait();
```

## 🎨 Token-Specific Royalties

### Premium Artwork with Higher Royalty

```solidity
// Set 10% royalty for a special piece
uint256 premiumTokenId = 42;
nft.setTokenRoyalty(premiumTokenId, artistAddress, 1000); // 10%
```

### Collaborative Artwork with Split Royalties

For artworks with multiple creators, use a royalty splitter:

```solidity
// Deploy RoyaltySplitter contract
address[] memory recipients = [artist1, artist2, curator];
uint256[] memory shares = [60, 30, 10]; // Percentages

RoyaltySplitter splitter = new RoyaltySplitter(recipients, shares);

// Set royalty to splitter contract
nft.setTokenRoyalty(collaborativeTokenId, address(splitter), 800); // 8% total
```

## 📊 Royalty Information Query

### Checking Royalty Details

```javascript
// Query royalty for a specific sale
const salePrice = ethers.utils.parseEther("2.0");
const [receiver, royaltyAmount] = await nftContract.royaltyInfo(
  tokenId,
  salePrice
);

console.log("Royalty receiver:", receiver);
console.log("Royalty amount:", ethers.utils.formatEther(royaltyAmount));
```

### Verifying EIP-2981 Compliance

```javascript
// Check if contract supports EIP-2981
const IERC2981_INTERFACE_ID = "0x2a55205a";
const supportsRoyalty = await nftContract.supportsInterface(
  IERC2981_INTERFACE_ID
);
console.log("Supports EIP-2981:", supportsRoyalty);
```

## 💰 Marketplace Integration

The marketplace automatically handles royalty distribution:

```solidity
function _processPurchase(address nftAddress, uint256 tokenId, uint256 salePrice) internal {
    // Query royalty information
    (address royaltyRecipient, uint256 royaltyAmount) = IERC2981(nftAddress)
        .royaltyInfo(tokenId, salePrice);

    // Calculate fees
    uint256 platformFee = (salePrice * platformFeePercentage) / 10000;
    uint256 sellerAmount = salePrice - royaltyAmount - platformFee;

    // Distribute payments
    if (royaltyAmount > 0) {
        payable(royaltyRecipient).transfer(royaltyAmount);
    }
    payable(platformTreasury).transfer(platformFee);
    payable(seller).transfer(sellerAmount);
}
```

## 🔄 Updating Royalties

### Changing Default Royalty

```javascript
// Artist decides to reduce default royalty to 3%
const updateTx = await nftContract.connect(artist).setDefaultRoyalty(
  artistAddress,
  300 // 3%
);
await updateTx.wait();
```

### Removing Token-Specific Royalty

```solidity
// Reset to default royalty by setting to 0
nft.resetTokenRoyalty(tokenId);
```

## 📈 Royalty Analytics

### Tracking Royalty Earnings

```javascript
// Listen for royalty payments
exchangeContract.on(
  "RoyaltyPaid",
  (nftAddress, tokenId, recipient, amount, event) => {
    console.log(
      `Royalty paid: ${ethers.utils.formatEther(amount)} ETH to ${recipient}`
    );
  }
);

// Calculate total royalties earned
const filter = exchangeContract.filters.RoyaltyPaid(null, null, artistAddress);
const events = await exchangeContract.queryFilter(filter);

const totalRoyalties = events.reduce((sum, event) => {
  return sum.add(event.args.amount);
}, ethers.BigNumber.from(0));

console.log(
  "Total royalties earned:",
  ethers.utils.formatEther(totalRoyalties)
);
```

## ⚠️ Important Considerations

### Maximum Royalty Limits

```solidity
uint256 public constant MAX_ROYALTY_PERCENTAGE = 1000; // 10%

modifier validRoyalty(uint96 royaltyPercentage) {
    require(royaltyPercentage <= MAX_ROYALTY_PERCENTAGE, "Royalty too high");
    _;
}
```

### Gas Optimization

* Set default royalties during contract deployment
* Minimize token-specific overrides
* Use royalty splitters for complex distributions

### Legal Considerations

* Royalty enforcement varies by jurisdiction
* Consider terms of service for royalty compliance
* Secondary markets may not honor royalties
