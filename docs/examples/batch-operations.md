# Batch Operations Example

## 📋 Overview

Demonstrating efficient batch operations for multiple NFT transactions.

## 🎯 Scenario

Bob wants to purchase 5 NFTs in a single transaction to save on gas costs.

## 📝 Prerequisites

- 5 NFTs are listed for sale (token IDs: 101, 102, 103, 104, 105)
- Bob has sufficient ETH for all purchases
- All NFTs are from the same collection

## 🔄 Batch Purchase Process

### Step 1: Prepare Purchase Data

```javascript
const purchases = [
  {
    nftAddress: nftContract.address,
    tokenId: 101,
    price: ethers.utils.parseEther("0.5"),
  },
  {
    nftAddress: nftContract.address,
    tokenId: 102,
    price: ethers.utils.parseEther("0.8"),
  },
  {
    nftAddress: nftContract.address,
    tokenId: 103,
    price: ethers.utils.parseEther("1.2"),
  },
  {
    nftAddress: nftContract.address,
    tokenId: 104,
    price: ethers.utils.parseEther("0.3"),
  },
  {
    nftAddress: nftContract.address,
    tokenId: 105,
    price: ethers.utils.parseEther("2.0"),
  },
];

// Calculate total value
const totalValue = purchases.reduce(
  (sum, purchase) => sum.add(purchase.price),
  ethers.BigNumber.from(0)
);
```

### Step 2: Execute Batch Purchase

```solidity
// Contract function for batch purchases
function buyItems(PurchaseData[] calldata purchases) external payable {
    uint256 totalRequired = 0;

    for (uint256 i = 0; i < purchases.length; i++) {
        // Validate each listing
        Listing memory listing = listings[purchases[i].nftAddress][purchases[i].tokenId];
        require(listing.active, "Item not listed");
        require(listing.expiration > block.timestamp, "Listing expired");

        totalRequired += listing.price;

        // Process each purchase
        _processPurchase(purchases[i].nftAddress, purchases[i].tokenId, listing);
    }

    require(msg.value >= totalRequired, "Insufficient payment");
}
```

**Frontend Integration:**

```javascript
const batchPurchaseTx = await exchangeContract.connect(bob).buyItems(
  purchases.map((p) => ({
    nftAddress: p.nftAddress,
    tokenId: p.tokenId,
  })),
  { value: totalValue }
);

await batchPurchaseTx.wait();
```

## 📊 Gas Comparison

### Individual Transactions

```
Transaction 1: ~150,000 gas
Transaction 2: ~150,000 gas
Transaction 3: ~150,000 gas
Transaction 4: ~150,000 gas
Transaction 5: ~150,000 gas
Total: ~750,000 gas
```

### Batch Transaction

```
Batch Purchase: ~400,000 gas
Savings: ~350,000 gas (47% reduction)
```

## 🔄 Batch Listing Example

Sellers can also list multiple NFTs efficiently:

```javascript
const listings = [
  {
    tokenId: 201,
    price: ethers.utils.parseEther("1.0"),
    duration: 7 * 24 * 60 * 60,
  },
  {
    tokenId: 202,
    price: ethers.utils.parseEther("1.5"),
    duration: 7 * 24 * 60 * 60,
  },
  {
    tokenId: 203,
    price: ethers.utils.parseEther("2.0"),
    duration: 7 * 24 * 60 * 60,
  },
];

// First approve all NFTs
await nftContract.setApprovalForAll(exchangeContract.address, true);

// Then batch list
const batchListTx = await exchangeContract.connect(alice).listItems(
  nftContract.address,
  listings.map((l) => l.tokenId),
  listings.map((l) => l.price),
  listings.map((l) => Math.floor(Date.now() / 1000) + l.duration)
);
```

## 💰 Payment Distribution

For batch purchases, payments are distributed individually:

```
NFT 101: 0.5 ETH → Creator (0.05 ETH) + Platform (0.0125 ETH) + Seller (0.4375 ETH)
NFT 102: 0.8 ETH → Creator (0.08 ETH) + Platform (0.02 ETH) + Seller (0.7 ETH)
... and so on for each NFT
```

## 📊 Events Emitted

Batch operations emit individual events for each item:

```solidity
// For each purchase in the batch
event ItemBought(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed buyer,
    uint256 price
);

// Additional batch-specific event
event BatchPurchase(
    address indexed buyer,
    uint256 itemCount,
    uint256 totalValue
);
```

## ⚠️ Error Handling

```javascript
try {
  await exchangeContract.buyItems(purchases, { value: totalValue });
} catch (error) {
  if (error.message.includes("Item not listed")) {
    console.log("One or more NFTs are no longer listed");
  } else if (error.message.includes("Insufficient payment")) {
    console.log("Total payment is insufficient");
  } else if (error.message.includes("Listing expired")) {
    console.log("One or more listings have expired");
  }
}
```

## 💡 Best Practices

1. **Validate Before Batch**: Check all listings are still active
2. **Gas Estimation**: Estimate gas for large batches
3. **Partial Success**: Consider implementing partial execution for failed items
4. **Event Monitoring**: Listen for individual item events to track success
