# Integration Guide

## 🔌 Frontend Integration

Guide for integrating the marketplace contracts with your frontend application.

### Web3 Setup

#### Install Dependencies

```bash
npm install ethers @rainbow-me/rainbowkit wagmi
```

#### Contract ABIs

```javascript
import { BlockzExchangeABI } from "./abis/BlockzExchange.json";
import { NFTCollectibleABI } from "./abis/NFTCollectible.json";

const contract = new ethers.Contract(
  contractAddress,
  BlockzExchangeABI,
  signer
);
```

### Basic Operations

#### List an NFT

```javascript
async function listNFT(tokenId, price, duration) {
  // First approve the marketplace
  await nftContract.approve(exchangeAddress, tokenId);

  // List the item
  const tx = await exchangeContract.listItem(
    nftAddress,
    tokenId,
    ethers.utils.parseEther(price.toString()),
    Math.floor(Date.now() / 1000) + duration
  );

  await tx.wait();
}
```

#### Buy an NFT

```javascript
async function buyNFT(tokenId) {
  const listing = await exchangeContract.getListing(nftAddress, tokenId);

  const tx = await exchangeContract.buyItem(nftAddress, tokenId, {
    value: listing.price,
  });

  await tx.wait();
}
```

#### Batch Operations

```javascript
async function buyMultipleNFTs(purchases) {
  const totalValue = purchases.reduce(
    (sum, p) => sum.add(p.price),
    ethers.BigNumber.from(0)
  );

  const tx = await exchangeContract.buyItems(
    purchases.map((p) => ({ nftAddress: p.nftAddress, tokenId: p.tokenId })),
    { value: totalValue }
  );

  await tx.wait();
}
```

### Event Handling

#### Listen for Events

```javascript
// Listen for new listings
exchangeContract.on(
  "ItemListed",
  (nftAddress, tokenId, seller, price, event) => {
    console.log("New listing:", { nftAddress, tokenId, seller, price });
  }
);

// Listen for purchases
exchangeContract.on(
  "ItemBought",
  (nftAddress, tokenId, buyer, price, event) => {
    console.log("Item sold:", { nftAddress, tokenId, buyer, price });
  }
);
```

### Error Handling

#### Common Error Cases

```javascript
try {
  await buyNFT(tokenId);
} catch (error) {
  if (error.code === "INSUFFICIENT_FUNDS") {
    alert("Insufficient ETH balance");
  } else if (error.message.includes("Item not listed")) {
    alert("This item is no longer available");
  } else {
    alert("Transaction failed: " + error.message);
  }
}
```

## 📱 Mobile Integration

### React Native

```javascript
import { ethers } from "ethers";
import WalletConnect from "@walletconnect/client";

// WalletConnect integration
const connector = new WalletConnect({
  bridge: "https://bridge.walletconnect.org",
});
```

### Web3Modal

```javascript
import Web3Modal from "web3modal";

const web3Modal = new Web3Modal({
  network: "mainnet",
  cacheProvider: true,
  providerOptions: {
    // Configure providers
  },
});
```

## 🧪 Testing Integration

### Contract Testing

```javascript
describe("Marketplace Integration", () => {
  it("should list and buy NFT", async () => {
    // Mint NFT
    await nft.mint(seller.address, tokenId, "metadata");

    // Approve marketplace
    await nft.connect(seller).approve(exchange.address, tokenId);

    // List item
    await exchange
      .connect(seller)
      .listItem(nft.address, tokenId, price, duration);

    // Buy item
    await exchange
      .connect(buyer)
      .buyItem(nft.address, tokenId, { value: price });

    // Verify ownership transfer
    expect(await nft.ownerOf(tokenId)).to.equal(buyer.address);
  });
});
```
