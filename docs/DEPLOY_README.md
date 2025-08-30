# BlockzExchange Deployment Guide

This guide explains how to deploy the BlockzExchange contract using the Foundry deployment script.

## Prerequisites

1. **Foundry installed**: Make sure you have Foundry installed on your system
2. **Environment variables**: Set up the required environment variables
3. **Network configuration**: Configure your target network in foundry.toml

## Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Required: Private key for deployment (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Optional: Validator address (defaults to deployer address if not set)
VALIDATOR_ADDRESS=0x1234567890123456789012345678901234567890

# Optional: Block range for token signature validation (defaults to 40)
BLOCK_RANGE=40

# RPC URL for the network you want to deploy to
RPC_URL=https://your-rpc-endpoint.com

# Optional: Etherscan API key for contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Deployment Options

### Option 1: Full Deployment (Recommended)

This deploys both BlockzExchange and AssetManager contracts with all configurations:

```bash
# Load environment variables
source .env

# Deploy to local network (Anvil)
forge script script/DeployBlockzExchange.s.sol:DeployBlockzExchange --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (example: Sepolia)
forge script script/DeployBlockzExchange.s.sol:DeployBlockzExchange --rpc-url $RPC_URL --broadcast --verify

# Deploy to mainnet (be careful!)
forge script script/DeployBlockzExchange.s.sol:DeployBlockzExchange --rpc-url $RPC_URL --broadcast --verify --slow
```

### Option 2: Minimal Deployment

This deploys only the BlockzExchange contract (useful if AssetManager is already deployed):

```bash
# Deploy minimal version
forge script script/DeployBlockzExchange.s.sol:DeployBlockzExchange --sig "deployMinimal()" --rpc-url $RPC_URL --broadcast
```

## What Gets Deployed

### Full Deployment:

1. **ProxyAdmin**: Manages proxy upgrades
2. **AssetManager Implementation**: The logic contract for AssetManager
3. **AssetManager Proxy**: The proxy contract for AssetManager
4. **BlockzExchange Implementation**: The logic contract for BlockzExchange
5. **BlockzExchange Proxy**: The proxy contract for BlockzExchange

### Post-Deployment Configuration:

- AssetManager is configured to accept BlockzExchange as a platform
- BlockzExchange is configured with the AssetManager address
- Validator address is set on BlockzExchange
- Block range is set on BlockzExchange

## Network Configuration

Add your target network to `foundry.toml`:

```toml
[rpc_endpoints]
sepolia = "${RPC_URL}"
mainnet = "https://mainnet.infura.io/v3/your-key"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

## Verification

To verify contracts after deployment:

```bash
# Verify the proxy contracts
forge verify-contract <PROXY_ADDRESS> src/contracts/BlockzExchange/BlockzExchange.sol:BlockzExchangeV2 --chain-id <CHAIN_ID> --etherscan-api-key $ETHERSCAN_API_KEY

# Verify the implementation contracts
forge verify-contract <IMPLEMENTATION_ADDRESS> src/contracts/BlockzExchange/BlockzExchange.sol:BlockzExchangeV2 --chain-id <CHAIN_ID> --etherscan-api-key $ETHERSCAN_API_KEY
```

## 🔄 Contract Upgrades

The BlockzExchange contract uses OpenZeppelin's **Transparent Proxy Pattern** for upgrades:

### How Upgrades Work

- **Proxy Contract**: Never changes, holds all state and forwards calls
- **Implementation Contract**: Contains the logic, can be upgraded
- **ProxyAdmin**: Controls upgrades, owned by deployer initially

When you upgrade:

- ✅ All state is preserved (orders, fills, configurations)
- ✅ Same contract address for users
- ✅ All existing approvals remain valid
- ✅ No downtime required

### Upgrade Prerequisites

Add these environment variables for upgrades:

```bash
# Required for upgrades
PROXY_ADMIN_ADDRESS=0x1234567890123456789012345678901234567890
BLOCKZ_EXCHANGE_PROXY_ADDRESS=0x0987654321098765432109876543210987654321
```

### Performing an Upgrade

#### Simple Upgrade (Recommended)

```bash
# Check current state first
forge script script/UpgradeBlockzExchange.s.sol:UpgradeBlockzExchange \
  --sig "checkCurrentImplementation()" \
  --rpc-url $RPC_URL

# Perform the upgrade
forge script script/UpgradeBlockzExchange.s.sol:UpgradeBlockzExchange \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

#### Upgrade with Initialization

```bash
forge script script/UpgradeBlockzExchange.s.sol:UpgradeBlockzExchange \
  --sig "upgradeAndCall()" \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

### Post-Upgrade Verification

```bash
# Verify the upgrade was successful
forge script script/UpgradeBlockzExchange.s.sol:UpgradeBlockzExchange \
  --sig "checkCurrentImplementation()" \
  --rpc-url $RPC_URL

# Test basic functionality
cast call $BLOCKZ_EXCHANGE_PROXY_ADDRESS "validator()" --rpc-url $RPC_URL
cast call $BLOCKZ_EXCHANGE_PROXY_ADDRESS "blockRange()" --rpc-url $RPC_URL
```

### ⚠️ Upgrade Safety Considerations

1. **Test Thoroughly**: Always test on testnet first
2. **Backup State**: Document current contract state
3. **Code Review**: Have your new implementation audited
4. **Access Control**: Verify you control the ProxyAdmin
5. **Gas Estimation**: Ensure sufficient funds for upgrade

## Security Considerations

1. **Private Key Security**: Never commit your private key to version control
2. **Validator Address**: Ensure the validator address is secure and controlled
3. **Proxy Admin**: The proxy admin has upgrade rights - secure this address properly
4. **Testing**: Always test on testnets before mainnet deployment

## Troubleshooting

### Common Issues:

1. **"Insufficient funds"**: Ensure your deployment account has enough ETH for gas
2. **"Invalid signature"**: Check that your private key is correct and doesn't include "0x" prefix
3. **"Contract already deployed"**: Use `--force` flag or deploy to a different address
4. **"Verification failed"**: Wait a few minutes and try verification again
5. **"Deployer is not the ProxyAdmin owner"**: Check who owns the ProxyAdmin
6. **"New implementation is the same as current"**: Your contract hasn't changed

### Gas Optimization:

- Use `--slow` flag for lower gas prices on mainnet
- Set gas limit with `--gas-limit` if needed
- Use `--gas-price` to set specific gas price

## Example Full Deployment Command

```bash
forge script script/DeployBlockzExchange.s.sol:DeployBlockzExchange \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --slow \
  --gas-limit 3000000
```

## Post-Deployment

After successful deployment, save the contract addresses and update your frontend/backend configuration with:

- BlockzExchange Proxy Address
- AssetManager Proxy Address
- ProxyAdmin Address (for future upgrades)

The deployment script will output all these addresses at the end of execution.
