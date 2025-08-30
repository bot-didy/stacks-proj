# Testing Guide

## 🧪 Test Suite Overview

Comprehensive testing strategy for the marketplace smart contracts.

### Test Framework

- **Foundry**: Primary testing framework
- **Forge**: Test runner and fuzzing tool
- **Gas Snapshots**: Performance monitoring
- **Coverage**: Test coverage reporting

## 🏃‍♂️ Running Tests

### Basic Test Commands

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run with maximum verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/BlockzExchange.t.sol

# Run specific test function
forge test --match-test testBuyItem
```

### Coverage Reports

```bash
# Generate coverage report
forge coverage

# Generate detailed HTML report
forge coverage --report lcov
genhtml lcov.info -o coverage/
```

## 📁 Test Structure

```
test/
├── unit/           # Unit tests for individual contracts
├── integration/    # Integration tests across contracts
├── fuzz/          # Fuzz testing for edge cases
├── utils/         # Test utilities and helpers
└── mocks/         # Mock contracts for testing
```

## 🎯 Test Categories

### Unit Tests

```solidity
contract BlockzExchangeTest is Test {
    function testListItem() public {
        // Test individual function
        vm.prank(seller);
        exchange.listItem(nftAddress, tokenId, price, duration);

        // Verify state change
        assertEq(exchange.getListing(nftAddress, tokenId).price, price);
    }
}
```

### Integration Tests

```solidity
function testFullPurchaseFlow() public {
    // List item
    vm.prank(seller);
    exchange.listItem(nftAddress, tokenId, price, duration);

    // Buy item
    vm.prank(buyer);
    exchange.buyItem{value: price}(nftAddress, tokenId);

    // Verify complete transaction
    assertEq(nft.ownerOf(tokenId), buyer);
}
```

### Fuzz Testing

```solidity
function testFuzzPricing(uint256 price) public {
    vm.assume(price > 0 && price < 1000 ether);

    vm.prank(seller);
    exchange.listItem(nftAddress, tokenId, price, duration);

    assertEq(exchange.getListing(nftAddress, tokenId).price, price);
}
```

## 🔧 Test Utilities

### Setup Functions

```solidity
function setUp() public {
    // Deploy contracts
    exchange = new BlockzExchange();
    nft = new NFTCollectible();

    // Setup accounts
    seller = makeAddr("seller");
    buyer = makeAddr("buyer");

    // Initial state
    vm.deal(buyer, 10 ether);
    nft.mint(seller, tokenId, "metadata");
}
```

### Helper Functions

```solidity
function listItem(address _seller, uint256 _tokenId, uint256 _price) internal {
    vm.prank(_seller);
    nft.approve(address(exchange), _tokenId);

    vm.prank(_seller);
    exchange.listItem(address(nft), _tokenId, _price, block.timestamp + 1 days);
}
```

## 📊 Test Metrics

### Expected Coverage

- **Statements**: > 95%
- **Functions**: > 95%
- **Branches**: > 90%
- **Lines**: > 95%

### Performance Benchmarks

- **Gas usage**: Optimized for common operations
- **Transaction limits**: Within block gas limits
- **Batch operations**: Efficient scaling
