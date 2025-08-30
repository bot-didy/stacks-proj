# Getting Started

## Prerequisites

Before you begin, ensure you have the following installed:

* **Node.js** (v16 or higher)
* **Git**
* **Foundry** (latest version)

## Installation

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone the Repository

```bash
git clone https://github.com/blockz-marketplace/smart-contracts.git
cd marketplace-blockz/smart-contracts
```

### 3. Install Dependencies

```bash
forge install
```

### 4. Set Up Environment Variables

Create a `.env` file:

```bash
cp .env.example .env
```

Fill in your environment variables:

```bash
# .env
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
RPC_URL=your_rpc_url
```

## Quick Test

Verify everything is working:

```bash
# Run tests
forge test

# Check test coverage
forge coverage

# Build contracts
forge build
```

## Project Structure

```
src/
├── contracts/          # Core marketplace contracts
│   ├── BlockzExchange/  # Main marketplace logic
│   ├── AssetManager/    # Payment and asset management
│   ├── NFTCollectible/  # NFT contract template
│   └── Royalty/         # Royalty management
├── archives/           # Archived/legacy contracts
test/                   # Test files
script/                 # Deployment scripts
docs/                   # Documentation
```

## Next Steps

* [📖 Contract Deployment Guide](deployment.md)
* [🧪 Testing Guide](testing.md)
* [🔗 Integration Guide](integration.md)
