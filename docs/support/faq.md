# FAQ

## 🏪 General Marketplace

### What is this NFT marketplace?

This is a decentralized NFT marketplace built on Core that allows users to buy and sell NFTs with CORE. It features batch operations, creator royalties, and upgradeable smart contracts.

### Which blockchains are supported?

Currently, the marketplace supports Core mainnet and Core testnet. We might plan to expand to other EVM-compatible chains.

### What are the fees?

* **Platform Fee**: 2.5% of sale price
* **Creator Royalties**: 0.5% for Collections and up to 10% for Creators (set by creators)
* **Gas Fees**: Standard Core network fees

## 💰 Payments and Fees

### What payment methods are accepted?

Only CORE (Core's native currency) is accepted for purchases.

### How are royalties calculated?

Royalties are calculated as a percentage of the sale price and automatically distributed to creators according to the EIP-2981 standard.

### Can I get a refund?

All sales are final. NFT transactions on the blockchain cannot be reversed.

## 🎨 NFTs and Collections

### What NFT standards are supported?

The marketplace supports ERC-721 NFTs with optional EIP-2981 royalty support.

### Can I list NFTs from any collection?

You can list any ERC-721 NFT that you own, regardless of which collection it's from as long as the collection is verified on our Marketplace

### How long do listings last?

Listings have customizable expiration dates set by the seller. Expired listings are automatically inactive.

## 🔄 Trading Operations

### What are batch operations?

Batch operations allow you to buy or sell multiple NFTs in a single transaction, saving significantly on gas fees.

### How do I approve my NFT for sale?

Before listing, you must approve the marketplace contract to transfer your NFT using the `approve()` or `setApprovalForAll()` function.

### Can I cancel a listing?

Yes, you can cancel active listings at any time before they expire or are purchased.

## 🔧 Technical Questions

### What is contract upgradeability?

Some contracts use proxy patterns that allow for upgrades while preserving state and addresses. Upgrades are controlled by governance.

### How are transactions secured?

The contracts implement multiple security measures including reentrancy guards, access controls, and pause functionality.

### Where is metadata stored?

NFT metadata is typically stored on IPFS (InterPlanetary File System) with the hash referenced in the token URI.

## 🛠️ Troubleshooting

### Why did my transaction fail?

Common reasons include:

* Insufficient CORE balance
* NFT no longer available
* Listing expired
* Insufficient gas limit

### How do I check if my NFT is listed?

Call the `getListing()` function with your NFT contract address and token ID.

### What wallets are supported?

Any Web3 wallet that supports Ethereum, including MetaMask, Rabby, WalletConnect-compatible wallets, and hardware wallets.

## 📞 Getting Help

### How do I report a bug?

Please create an issue on our GitHub repository or open a ticket directly on our Discord with detailed information about the problem.

### Where can I get technical support?

Check our documentation, GitHub issues, or contact the development team through official channels.

### Is there a testnet version?

Yes, we maintain a testnet deployment on Core Testnet for testing purposes.
