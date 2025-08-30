# TestNFT Contract

## 📋 Overview

A simple ERC-721 NFT contract designed specifically for testing marketplace functionality and development workflows.

## 🔧 Key Features

- **Lightweight Implementation**: Minimal overhead for testing
- **Public Minting**: Open minting for easy test data generation
- **Batch Operations**: Efficient test scenario setup
- **Flexible Metadata**: Support for various metadata configurations

## 📚 Core Functions

### Minting Functions

#### `mint(address to, string memory tokenURI)`

Mints a new NFT to the specified address (owner only).

**Parameters:**

- `to`: Recipient address
- `tokenURI`: Metadata URI for the token

**Returns:**

- `uint256`: The newly minted token ID

**Requirements:**

- Caller must be contract owner

#### `publicMint(string memory tokenURI)`

Public minting function that allows anyone to mint NFTs for testing.

**Parameters:**

- `tokenURI`: Metadata URI for the token

**Returns:**

- `uint256`: The newly minted token ID

**Usage:**

```solidity
uint256 tokenId = testNFT.publicMint("test-metadata-uri");
```

#### `batchMint(address[] memory recipients, string[] memory tokenURIs)`

Mints multiple NFTs in a single transaction (owner only).

**Parameters:**

- `recipients`: Array of recipient addresses
- `tokenURIs`: Array of metadata URIs

**Requirements:**

- Arrays must have equal length
- Caller must be contract owner

### Metadata Functions

#### `setBaseURI(string memory baseURI)`

Sets the base URI for all tokens (owner only).

**Parameters:**

- `baseURI`: New base URI

#### `tokenURI(uint256 tokenId)`

Returns the complete metadata URI for a token.

**Logic:**

- If specific tokenURI is set: returns `baseURI + tokenURI`
- If only baseURI is set: returns standard `baseURI + tokenId`

### Utility Functions

#### `getCurrentTokenId()`

Returns the current token ID counter.

```solidity
uint256 nextTokenId = testNFT.getCurrentTokenId();
```

#### `totalSupply()`

Returns total number of minted tokens.

```solidity
uint256 supply = testNFT.totalSupply();
```

#### `exists(uint256 tokenId)`

Checks if a token exists.

```solidity
bool exists = testNFT.exists(tokenId);
```

## 📊 Events

```solidity
event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
```

Emitted when any NFT is minted.

## 💡 Testing Usage Examples

### Basic Test Setup

```javascript
// Deploy test NFT
const testNFT = await TestNFT.deploy(
  "Test Collection",
  "TEST",
  "https://test-metadata.com/"
);

// Mint test NFT
const tokenId = await testNFT.publicMint("metadata1.json");
```

### Marketplace Integration Testing

```javascript
// Setup test scenario
const seller = accounts[1];
const buyer = accounts[2];

// Mint NFT to seller
await testNFT.connect(owner).mint(seller.address, "test-uri");

// Approve marketplace
await testNFT.connect(seller).approve(exchange.address, tokenId);

// List on marketplace
await exchange
  .connect(seller)
  .listItem(testNFT.address, tokenId, price, duration);

// Buy from marketplace
await exchange
  .connect(buyer)
  .buyItem(testNFT.address, tokenId, { value: price });
```

### Batch Testing

```javascript
// Create multiple test NFTs
const recipients = [addr1, addr2, addr3];
const uris = ["uri1.json", "uri2.json", "uri3.json"];

await testNFT.batchMint(recipients, uris);

// Verify all minted
for (let i = 0; i < recipients.length; i++) {
  const tokenId = i + 1;
  expect(await testNFT.ownerOf(tokenId)).to.equal(recipients[i]);
}
```

## 🔒 Security Considerations

### Testing-Only Contract

⚠️ **Important**: This contract is designed for testing only and should never be used in production:

- Public minting allows anyone to create tokens
- Minimal access controls
- No economic incentives or protections

### Safe Testing Practices

- Use only on testnets or local development networks
- Clear test data between test runs
- Don't rely on this contract for production integrations

## 🧪 Integration with Test Suite

### Common Test Patterns

```javascript
describe("Marketplace with TestNFT", () => {
  beforeEach(async () => {
    // Deploy test contracts
    testNFT = await TestNFT.deploy("Test", "TEST", "");
    exchange = await Exchange.deploy(/* params */);

    // Mint test NFTs
    await testNFT.publicMint("metadata1");
    await testNFT.publicMint("metadata2");
  });

  it("should handle NFT sales", async () => {
    // Test marketplace functionality with TestNFT
  });
});
```

### Gas Testing

```javascript
// Measure gas usage with test NFTs
const tx = await exchange.buyItem(testNFT.address, tokenId, { value: price });
const receipt = await tx.wait();
console.log("Gas used:", receipt.gasUsed.toString());
```

## 📝 Configuration

### Constructor Parameters

```solidity
constructor(
    string memory name,      // "Test Collection"
    string memory symbol,    // "TEST"
    string memory baseURI    // "https://metadata.example.com/"
)
```

### Recommended Test Configuration

```javascript
const testConfig = {
  name: "Test NFT Collection",
  symbol: "TNFT",
  baseURI: "https://test-api.example.com/metadata/",
  initialSupply: 10,
  testAccounts: 5,
};
```

## 🔗 Related Documentation

- [Basic NFT Sale Example](../examples/basic-sale.md)
- [Testing Guide](../developers/testing.md)
- [Integration Guide](../developers/integration.md)
