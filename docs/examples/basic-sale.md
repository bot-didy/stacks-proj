# Basic NFT Sale

## 📋 Overview

Step-by-step example of listing and selling an NFT on the marketplace.

## 🎯 Scenario

Alice wants to sell her NFT to Bob for 1 CORE.

## 📝 Prerequisites

* Alice owns NFT with tokenId `123`
* Bob has at least 1 CORE
* Contracts are deployed and configured

## 🔄 Step-by-Step Process

### Step 1: Alice Approves the Marketplace

```solidity
// Alice approves the marketplace to transfer her NFT
nft.approve(marketplaceAddress, 123);
```

**Frontend Integration:**

```javascript
// Using ethers.js
const approveTx = await nftContract
  .connect(alice)
  .approve(marketplaceAddress, 123);
await approveTx.wait();
```

### Step 2: Alice Lists Her NFT

```solidity
// List NFT for 1 ETH with 7-day expiration
uint256 price = 1 ether;
uint256 expiration = block.timestamp + 7 days;

exchange.listItem(nftAddress, 123, price, expiration);
```

**Frontend Integration:**

```javascript
const price = ethers.utils.parseEther("1.0");
const expiration = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60; // 7 days

const listTx = await exchangeContract
  .connect(alice)
  .listItem(nftAddress, 123, price, expiration);
await listTx.wait();
```

### Step 3: Bob Purchases the NFT

```solidity
// Bob buys the NFT by sending 1 ETH
exchange.buyItem{value: 1 ether}(nftAddress, 123);
```

**Frontend Integration:**

```javascript
const buyTx = await exchangeContract
  .connect(bob)
  .buyItem(nftAddress, 123, { value: price });
await buyTx.wait();
```

## 💰 Payment Breakdown

For a 1 ETH sale with 0.5% creator royalty and 2.5% platform fee:

* **Sale Price**: 1.0 CORE
* **Creator Royalty**: 0.05 CORE (0.5%)
* **Platform Fee**: 0.025 CORE (2.5%)
* **Alice Receives**: 0.925 CORE

## 📊 Events Emitted

### When Listed

```solidity
event ItemListed(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed seller,
    uint256 price,
    uint256 expiration
);
```

### When Purchased

```solidity
event ItemBought(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed buyer,
    uint256 price
);
```

## 🔍 Verification

After the transaction:

```javascript
// Verify ownership transfer
const newOwner = await nftContract.ownerOf(123);
console.log(newOwner === bob.address); // true

// Check Alice's ETH balance increased
const aliceBalance = await alice.getBalance();
console.log(ethers.utils.formatEther(aliceBalance));
```

## ⚠️ Error Handling

Common issues and solutions:

```javascript
try {
  await exchangeContract.buyItem(nftAddress, tokenId, { value: price });
} catch (error) {
  if (error.message.includes("Item not listed")) {
    console.log("NFT is not currently for sale");
  } else if (error.message.includes("Insufficient payment")) {
    console.log("Price has changed or insufficient ETH sent");
  } else if (error.message.includes("Listing expired")) {
    console.log("Listing has expired");
  }
}
```
