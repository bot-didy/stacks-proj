# AssetManager

## 📋 Overview

The AssetManager contract handles fee collection, distribution, and treasury management for the marketplace.

## 🔧 Key Features

* **Fee Management**: Platform fee collection and distribution
* **Treasury Operations**: Secure fund management
* **Payment Processing**: CORE payment handling
* **Access Control**: Role-based permission system

## 📚 Functions

### Public Functions

#### `collectFees(uint256 amount)`

Collects platform fees from transactions.

**Parameters:**

* `amount`: Fee amount to collect

**Requirements:**

* Caller must have COLLECTOR\_ROLE
* Amount must be > 0

#### `distributeFees(address[] recipients, uint256[] amounts)`

Distributes collected fees to recipients.

**Parameters:**

* `recipients`: Array of recipient addresses
* `amounts`: Array of distribution amounts

### Administrative Functions

#### `setPlatformFee(uint256 feeBps)`

Sets the platform fee percentage.

**Parameters:**

* `feeBps`: Fee in basis points (e.g., 250 = 2.5%)

**Requirements:**

* Caller must have ADMIN\_ROLE
* Fee must be ≤ MAX\_PLATFORM\_FEE

#### `setTreasury(address newTreasury)`

Updates the treasury address.

**Parameters:**

* `newTreasury`: New treasury address

## 📊 Events

```solidity
event FeesCollected(uint256 amount, address indexed collector);
event FeesDistributed(address[] recipients, uint256[] amounts);
event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
event TreasuryUpdated(address oldTreasury, address newTreasury);
```

## 🔒 Access Control

* **ADMIN\_ROLE**: Contract administration
* **COLLECTOR\_ROLE**: Fee collection operations
* **DISTRIBUTOR\_ROLE**: Fee distribution operations

## 💡 Usage Examples

### Basic Fee Collection

```solidity
// Collect 2.5% platform fee
uint256 fee = (totalAmount * 250) / 10000;
assetManager.collectFees(fee);
```

### Fee Distribution

```solidity
address[] memory recipients = [treasury, creator];
uint256[] memory amounts = [platformFee, royalty];
assetManager.distributeFees(recipients, amounts);
```
