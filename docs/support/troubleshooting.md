# Troubleshooting Guide

## 🛠️ Common Issues and Solutions

### Deployment Issues

#### "Insufficient funds for intrinsic transaction cost"

**Cause**: Not enough ETH/AVAX for gas fees in deployment account.

**Solutions**:

- Fund the deployment account with sufficient native tokens
- Use `--gas-limit` and `--gas-price` flags to adjust gas settings
- Check network gas price and adjust accordingly

```bash
# Check balance
cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL

# Deploy with custom gas settings
forge script DeployBlockzExchange.s.sol --gas-limit 3000000 --gas-price 25000000000
```

#### "Create2 deploy failed"

**Cause**: Contract already deployed at the same address or insufficient gas.

**Solutions**:

- Use `--force` flag to overwrite existing deployment
- Change salt in deployment script for different address
- Increase gas limit for complex deployments

#### "Verification failed"

**Cause**: Etherscan API issues or contract compilation mismatch.

**Solutions**:

- Wait 1-2 minutes and retry verification
- Ensure Etherscan API key is valid and has sufficient credits
- Check that contract source matches deployed bytecode

```bash
# Manual verification
forge verify-contract $CONTRACT_ADDRESS src/contracts/BlockzExchange/BlockzExchange.sol:BlockzExchange --etherscan-api-key $ETHERSCAN_API_KEY --chain-id $CHAIN_ID
```

### Testing Issues

#### "Test reverted with reason: VM Exception"

**Cause**: Usually insufficient setup or wrong test parameters.

**Solutions**:

- Ensure proper contract setup in `setUp()` function
- Check that test accounts have sufficient balances
- Verify contract permissions and approvals

```solidity
function setUp() public {
    // Proper setup example
    vm.deal(buyer, 10 ether);
    vm.deal(seller, 10 ether);

    nft.mint(seller, tokenId, "metadata");
    vm.prank(seller);
    nft.approve(address(exchange), tokenId);
}
```

#### "Gas estimation failed"

**Cause**: Transaction would revert or gas limit too low.

**Solutions**:

- Check transaction prerequisites (approvals, balances, etc.)
- Use `.gas()` modifier to increase gas limit
- Debug with `forge test -vvv` for detailed traces

### Smart Contract Interactions

#### "NFT transfer failed"

**Possible Causes**:

- NFT not approved for marketplace contract
- NFT already transferred or doesn't exist
- Contract is paused

**Solutions**:

```solidity
// Check approval status
bool isApproved = nft.getApproved(tokenId) == address(exchange) ||
                  nft.isApprovedForAll(owner, address(exchange));

// Grant approval
nft.approve(address(exchange), tokenId);
// OR for all tokens
nft.setApprovalForAll(address(exchange), true);
```

#### "Signature verification failed"

**Possible Causes**:

- Wrong private key used for signing
- Block range expired
- Invalid signature format

**Solutions**:

```javascript
// Verify EIP-712 signature creation
const domain = {
  name: "Blockz",
  version: "1",
  chainId: network.chainId,
  verifyingContract: exchangeAddress,
};

const signature = await signer._signTypedData(domain, types, order);
```

#### "Insufficient payment"

**Cause**: Not enough ETH sent with transaction or price changed.

**Solutions**:

- Check current listing price before purchase
- Add buffer for gas estimation differences
- Use exact amount from `getListing()` call

```javascript
const listing = await exchange.getListing(nftAddress, tokenId);
await exchange.buyItem(nftAddress, tokenId, {
  value: listing.price,
});
```

### Integration Issues

#### "Frontend not connecting to contracts"

**Possible Causes**:

- Wrong contract addresses in frontend config
- Wrong network or RPC URL
- ABI mismatch between frontend and deployed contracts

**Solutions**:

- Verify contract addresses match deployment output
- Check network ID matches between wallet and config
- Regenerate ABIs after contract changes

```javascript
// Verify contract connection
const code = await provider.getCode(contractAddress);
if (code === "0x") {
  console.error("Contract not deployed at this address");
}
```

#### "MetaMask transaction rejected"

**Possible Causes**:

- User rejected transaction
- Insufficient gas limit estimated
- Nonce issues

**Solutions**:

- Implement user-friendly error messages
- Manually set gas limit if estimation fails
- Reset account in MetaMask if nonce issues persist

### Performance Issues

#### "Transaction taking too long"

**Possible Causes**:

- Low gas price on network congestion
- Complex batch operations
- Network issues

**Solutions**:

- Increase gas price for faster confirmation
- Break large batch operations into smaller chunks
- Monitor network status and gas tracker

#### "High gas costs"

**Solutions**:

- Use batch operations instead of individual transactions
- Optimize transaction timing for lower network congestion
- Consider Layer 2 solutions for frequent operations

## 🔧 Debugging Tools

### Foundry Debug Commands

```bash
# Detailed test output
forge test -vvv

# Gas profiling
forge test --gas-report

# Specific test debugging
forge test --match-test testFunctionName -vvv

# Coverage analysis
forge coverage
```

### Web3 Debugging

```javascript
// Check transaction details
const tx = await provider.getTransaction(txHash);
const receipt = await provider.getTransactionReceipt(txHash);

// Decode revert reason
try {
  await contract.functionCall();
} catch (error) {
  console.log("Revert reason:", error.reason);
}
```

### Contract State Debugging

```bash
# Check contract state
cast call $CONTRACT_ADDRESS "owner()" --rpc-url $RPC_URL
cast call $CONTRACT_ADDRESS "paused()" --rpc-url $RPC_URL

# Check balances
cast call $ASSET_MANAGER "biddingWallets(address)(uint256)" $USER_ADDRESS --rpc-url $RPC_URL
```

## 📞 Getting Help

### Before Seeking Help

1. **Check logs**: Review transaction receipts and event logs
2. **Verify setup**: Ensure all prerequisites are met
3. **Test isolation**: Try to reproduce with minimal test case
4. **Documentation**: Review relevant contract documentation

### How to Report Issues

Include the following information:

- **Network**: Which network (mainnet, testnet, local)
- **Transaction hash**: If applicable
- **Contract addresses**: All relevant contract addresses
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happened
- **Steps to reproduce**: Minimal reproduction steps

### Contact Channels

- **GitHub Issues**: For bugs and feature requests
- **Documentation**: Check FAQ and guides first
- **Development Team**: Through official project channels

## 🔍 Advanced Debugging

### Using Tenderly for Transaction Analysis

1. Copy transaction hash from failed transaction
2. Import transaction into Tenderly
3. Use step-by-step debugging to identify issue
4. Check state changes and error messages

### Local Debugging with Anvil

```bash
# Fork mainnet for testing
anvil --fork-url $MAINNET_RPC_URL

# Use specific block for consistent testing
anvil --fork-url $MAINNET_RPC_URL --fork-block-number 18000000
```

### Event Analysis

```javascript
// Filter and analyze events
const filter = exchange.filters.Redeem(nftAddress, tokenId);
const events = await exchange.queryFilter(filter, fromBlock, toBlock);
console.log("Purchase events:", events);
```
