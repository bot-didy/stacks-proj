// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/contracts/BlockzExchange/BlockzExchange.sol";
import "../src/contracts/AssetManager/AssetManager.sol";
import "../src/contracts/veBlockz/VeBlockz.sol";
import "../src/contracts/BlockzGovernanceToken/BlockzGovernanceToken.sol";
import "../src/contracts/NFTCollectible/NFTCollectible.sol";
import "../src/contracts/BlockzExchange/lib/LibOrder.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract ExchangeTest is Test {
    using LibOrderV2 for *;

    string private constant SIGNING_DOMAIN = "Blockz";
    string private constant SIGNATURE_VERSION = "1";

    // Fixed timestamp to match JavaScript tests - using a more recent timestamp
    uint256 private constant FIXED_TIMESTAMP = 1700000000; // More recent timestamp

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    BlockzExchange public exchange;
    AssetManager public assetManager;
    VeBLOCKZ public veART;
    BlockzGovernanceToken public blockzGovernanceToken;
    NFTCollectible public nftCollectible;
    ProxyAdmin public proxyAdmin;

    address public owner;
    address public seller;
    address public buyer;
    address public externalWallet;
    address public validator;
    
    // Private keys for signing
    uint256 public sellerPrivateKey;
    uint256 public buyerPrivateKey;
    uint256 public validatorPrivateKey;

    function setUp() public {
        // Setup accounts with private keys
        owner = address(this);
        sellerPrivateKey = 0x1;
        seller = vm.addr(sellerPrivateKey);
        
        buyerPrivateKey = 0x2;
        buyer = vm.addr(buyerPrivateKey);
        
        externalWallet = makeAddr("externalWallet");
        
        validatorPrivateKey = 0x3;
        validator = vm.addr(validatorPrivateKey);

        // Set block timestamp to our fixed timestamp to avoid underflow
        vm.warp(FIXED_TIMESTAMP);

        // Fund the test contract and buyer with ETH
        vm.deal(address(this), 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(seller, 100 ether);

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin();

        // Deploy contracts
        blockzGovernanceToken = new BlockzGovernanceToken("Test Rock", "TROCK");
        
        // Deploy VeArt with proxy
        VeBLOCKZ veARTImpl = new VeBLOCKZ();
        bytes memory veARTData = abi.encodeWithSelector(VeBLOCKZ.initialize.selector, IERC20Upgradeable(address(blockzGovernanceToken)));
        TransparentUpgradeableProxy veARTProxy = new TransparentUpgradeableProxy(
            address(veARTImpl),
            address(proxyAdmin),
            veARTData
        );
        veART = VeBLOCKZ(payable(address(veARTProxy)));

        // Deploy AssetManager with proxy
        AssetManager assetManagerImpl = new AssetManager();
        bytes memory assetManagerData = abi.encodeWithSelector(AssetManager.initialize.selector);
        TransparentUpgradeableProxy assetManagerProxy = new TransparentUpgradeableProxy(
            address(assetManagerImpl),
            address(proxyAdmin),
            assetManagerData
        );
        assetManager = AssetManager(payable(address(assetManagerProxy)));
        assetManager.setPlatformFeeReceiver(address(veART));

        // Deploy Exchange with proxy
        BlockzExchange exchangeImpl = new BlockzExchange();
        bytes memory exchangeData = abi.encodeWithSelector(BlockzExchange.initialize.selector);
        TransparentUpgradeableProxy exchangeProxy = new TransparentUpgradeableProxy(
            address(exchangeImpl),
            address(proxyAdmin),
            exchangeData
        );
        exchange = BlockzExchange(payable(address(exchangeProxy)));

        exchange.setAssetManager(address(assetManager));
        exchange.setValidator(validator);

        assetManager.addPlatform(address(exchange));

        // Deploy and setup NFT collection
        LibRoyalty.Royalty[] memory royalties = new LibRoyalty.Royalty[](0);
        vm.prank(seller);
        nftCollectible = new NFTCollectible("Blockz", "SLV", royalties);
        vm.startPrank(seller);
        nftCollectible.mint("", royalties); // tokenId: 1
        nftCollectible.mint("", royalties); // tokenId: 2
        nftCollectible.mint("", royalties); // tokenId: 3
        nftCollectible.setApprovalForAll(address(exchange), true);
        nftCollectible.setApprovalForAll(address(assetManager), true);
        vm.stopPrank();
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                TYPE_HASH,
                keccak256(bytes(SIGNING_DOMAIN)),
                keccak256(bytes(SIGNATURE_VERSION)),
                block.chainid,
                address(exchange)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function signOrder(LibOrderV2.BatchOrder memory batchOrder, uint256 privateKey) internal view returns (bytes memory) {
        // Get the hash of the order data
        bytes32 structHash = LibOrderV2.hash(batchOrder);
        
        // Get the final EIP-712 hash
        bytes32 digest = _hashTypedDataV4(structHash);
        
        // Sign the hash with the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // Return the signature
        return abi.encodePacked(r, s, v);
    }

    // Helper function to create batch order with custom price
    function createBatchOrderWithPrice(uint256 price) internal view returns (LibOrderV2.BatchOrder memory) {
        LibOrderV2.Order[] memory orders = new LibOrderV2.Order[](1);
        orders[0] = LibOrderV2.Order({
            nftContractAddress: address(nftCollectible),
            salt: "test_salt",
            tokenId: 1,
            price: price,
            duration: 6 * 30 * 24 * 60 * 60, // Match JavaScript duration
            startedAt: FIXED_TIMESTAMP // Use fixed timestamp
        });

        return LibOrderV2.BatchOrder({
            salt: "test_batch_salt",
            seller: seller,
            orders: orders
        });
    }

    // Helper function to create batch order with custom token ID
    function createBatchOrderWithTokenId(uint256 tokenId) internal view returns (LibOrderV2.BatchOrder memory) {
        LibOrderV2.Order[] memory orders = new LibOrderV2.Order[](1);
        orders[0] = LibOrderV2.Order({
            nftContractAddress: address(nftCollectible),
            salt: "test_salt",
            tokenId: tokenId,
            price: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60, // Match JavaScript duration
            startedAt: FIXED_TIMESTAMP // Use fixed timestamp
        });

        return LibOrderV2.BatchOrder({
            salt: "test_batch_salt",
            seller: seller,
            orders: orders
        });
    }

    // Helper function to create token voucher
    function createTokenVoucher(
        uint256 tokenId,
        string memory salt,
        string memory traits,
        address owner
    ) internal view returns (LibOrderV2.Token memory) {
        return LibOrderV2.Token({
            tokenId: tokenId,
            blockNumber: block.number,
            sender: owner,
            nftContractAddress: address(nftCollectible),
            uuid: "test_uuid",
            salt: salt,
            traits: traits
        });
    }

    // Helper function to sign token voucher
    function signTokenVoucher(
        LibOrderV2.Token memory token,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = LibOrderV2.hashToken(token);
        bytes32 digest = _hashTypedDataV4(structHash);
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // Helper function to create offer
    function createOffer() internal view returns (LibOrderV2.Offer memory) {
        return LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "test_salt",
            traits: "allItems", // Match JavaScript trait name
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60, // Match JavaScript duration
            size: 1,
            startedAt: FIXED_TIMESTAMP, // Use fixed timestamp
            isCollectionOffer: true
        });
    }

    // Helper function to create offer with custom bid
    function createOfferWithBid(uint256 bid) internal view returns (LibOrderV2.Offer memory) {
        return LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "test_salt",
            traits: "allItems", // Match JavaScript trait name
            tokenId: 1,
            bid: bid,
            duration: 6 * 30 * 24 * 60 * 60, // Match JavaScript duration
            size: 1,
            startedAt: FIXED_TIMESTAMP, // Use fixed timestamp
            isCollectionOffer: true
        });
    }

    // Helper function to sign offer
    function signOffer(LibOrderV2.Offer memory offer, uint256 privateKey) internal view returns (bytes memory) {
        bytes32 structHash = LibOrderV2.hashOffer(offer);
        bytes32 digest = _hashTypedDataV4(structHash);
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_CancelOrder() public {
        // Setup order
        LibOrderV2.BatchOrder[] memory orders = new LibOrderV2.BatchOrder[](1);
        orders[0] = createBatchOrderWithPrice(1 ether);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signOrder(orders[0], sellerPrivateKey);
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        
        // Set block range as owner
        exchange.setBlockRange(40);

        // Debug logging
        address recoveredSigner = exchange._validate(orders[0], signatures[0]);
        console.log("Recovered signer:", recoveredSigner);
        console.log("Expected seller:", seller);
        console.log("Msg.sender:", msg.sender);
        
        // Try to cancel with wrong signer
        vm.prank(buyer);
        vm.expectRevert("only signer");
        exchange.batchCancelOrder(orders, signatures, indices);
        
        // Cancel with correct signer
        vm.prank(seller);
        vm.recordLogs();
        exchange.batchCancelOrder(orders, signatures, indices);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1); // Check CancelOrder event was emitted
        
        // Try to cancel again
        vm.prank(seller);
        vm.expectRevert("order has already redeemed or cancelled");
        exchange.batchCancelOrder(orders, signatures, indices);
    }

    function test_Buy() public {
        // Setup order
        LibOrderV2.BatchOrder[] memory orders = new LibOrderV2.BatchOrder[](1);
        orders[0] = createBatchOrderWithPrice(1 ether);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signOrder(orders[0], sellerPrivateKey);
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        // Test buying when paused
        exchange.pause();
        vm.prank(buyer);
        vm.expectRevert("Pausable: paused");
        exchange.batchBuy(orders, signatures, indices);
        exchange.unpause();

        // Set block range
        exchange.setBlockRange(40);

        // Cancel order first
        vm.prank(seller);
        exchange.batchCancelOrder(orders, signatures, indices);

        // Try to buy cancelled order
        vm.prank(buyer);
        vm.expectRevert("order has already redeemed or cancelled");
        exchange.batchBuy(orders, signatures, indices);

        // Create order with zero price
        LibOrderV2.BatchOrder[] memory zeroOrders = new LibOrderV2.BatchOrder[](1);
        zeroOrders[0] = createBatchOrderWithPrice(0);
        bytes[] memory zeroSignatures = new bytes[](1);
        zeroSignatures[0] = signOrder(zeroOrders[0], sellerPrivateKey);

        // Try to buy zero price order
        vm.prank(buyer);
        vm.expectRevert("non existent order");
        exchange.batchBuy(zeroOrders, zeroSignatures, indices);

        // Create new valid order with different salt for testing buying own order
        LibOrderV2.BatchOrder[] memory ownOrders = new LibOrderV2.BatchOrder[](1);
        LibOrderV2.Order[] memory ownOrderArray = new LibOrderV2.Order[](1);
        ownOrderArray[0] = LibOrderV2.Order({
            nftContractAddress: address(nftCollectible),
            salt: "own_order_salt",
            tokenId: 1,
            price: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            startedAt: FIXED_TIMESTAMP
        });
        ownOrders[0] = LibOrderV2.BatchOrder({
            salt: "own_batch_salt",
            seller: seller,
            orders: ownOrderArray
        });
        bytes[] memory ownSignatures = new bytes[](1);
        ownSignatures[0] = signOrder(ownOrders[0], sellerPrivateKey);

        // Try to buy own order
        vm.prank(seller);
        vm.expectRevert("signer cannot redeem own coupon");
        exchange.batchBuy(ownOrders, ownSignatures, indices);

        // Create new valid order with different salt for testing insufficient balance
        LibOrderV2.BatchOrder[] memory validOrders = new LibOrderV2.BatchOrder[](1);
        LibOrderV2.Order[] memory validOrderArray = new LibOrderV2.Order[](1);
        validOrderArray[0] = LibOrderV2.Order({
            nftContractAddress: address(nftCollectible),
            salt: "valid_order_salt",
            tokenId: 1,
            price: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            startedAt: FIXED_TIMESTAMP
        });
        validOrders[0] = LibOrderV2.BatchOrder({
            salt: "valid_batch_salt",
            seller: seller,
            orders: validOrderArray
        });
        bytes[] memory validSignatures = new bytes[](1);
        validSignatures[0] = signOrder(validOrders[0], sellerPrivateKey);

        // Try to buy without sufficient balance
        vm.prank(buyer);
        vm.expectRevert("Insufficient balance");
        exchange.batchBuy(validOrders, validSignatures, indices);

        // Approve NFT transfer
        vm.prank(seller);
        nftCollectible.setApprovalForAll(address(assetManager), true);

        // Buy with ETH
        vm.prank(buyer);
        exchange.batchBuyETH{value: 1 ether}(validOrders, validSignatures, indices);

        // Verify NFT transfer
        assertEq(nftCollectible.ownerOf(1), buyer);

        // Test buying with deposited balance
        // Create new order for token ID 2 with different salt
        LibOrderV2.BatchOrder[] memory order2 = new LibOrderV2.BatchOrder[](1);
        LibOrderV2.Order[] memory order2Array = new LibOrderV2.Order[](1);
        order2Array[0] = LibOrderV2.Order({
            nftContractAddress: address(nftCollectible),
            salt: "token2_order_salt",
            tokenId: 2,
            price: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            startedAt: FIXED_TIMESTAMP
        });
        order2[0] = LibOrderV2.BatchOrder({
            salt: "token2_batch_salt",
            seller: seller,
            orders: order2Array
        });
        bytes[] memory signatures2 = new bytes[](1);
        signatures2[0] = signOrder(order2[0], sellerPrivateKey);

        // Deposit ETH for buyer
        vm.prank(buyer);
        assetManager.deposit{value: 1 ether}();

        // Buy using deposited balance
        vm.prank(buyer);
        exchange.batchBuy(order2, signatures2, indices);

        // Verify second NFT transfer
        assertEq(nftCollectible.ownerOf(2), buyer);
    }

    function test_AcceptOffer() public {
        // Create offer from buyer
        LibOrderV2.Offer[] memory offerOrders = new LibOrderV2.Offer[](1);
        offerOrders[0] = createOffer();
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = signOffer(offerOrders[0], buyerPrivateKey);

        // Create token validation from validator
        LibOrderV2.Token[] memory tokenVouchers = new LibOrderV2.Token[](1);
        tokenVouchers[0] = createTokenVoucher(1, offerOrders[0].salt, "allItems", seller);
        bytes[] memory tokenSignatures = new bytes[](1);
        tokenSignatures[0] = signTokenVoucher(tokenVouchers[0], validatorPrivateKey);

        // Test accepting offer when paused
        exchange.pause();
        vm.expectRevert("Pausable: paused");
        exchange.acceptOfferBatch(offerOrders, offerSignatures, tokenVouchers, tokenSignatures);
        exchange.unpause();

        // Test with invalid token signature
        vm.prank(seller);
        vm.expectRevert("token signature is not valid");
        exchange.acceptOfferBatch(offerOrders, offerSignatures, tokenVouchers, offerSignatures); // Using offer signatures instead of token signatures

        // Test accepting with mismatched salt - create offer with different salt
        LibOrderV2.Offer[] memory wrongSaltOffers = new LibOrderV2.Offer[](1);
        wrongSaltOffers[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "wrong_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory wrongSaltOfferSignatures = new bytes[](1);
        wrongSaltOfferSignatures[0] = signOffer(wrongSaltOffers[0], buyerPrivateKey);

        LibOrderV2.Token[] memory wrongSaltVouchers = new LibOrderV2.Token[](1);
        wrongSaltVouchers[0] = createTokenVoucher(1, "different_salt", "allItems", seller);
        bytes[] memory wrongSaltSignatures = new bytes[](1);
        wrongSaltSignatures[0] = signTokenVoucher(wrongSaltVouchers[0], validatorPrivateKey);

        vm.prank(seller);
        vm.expectRevert("salt does not match");
        exchange.acceptOfferBatch(wrongSaltOffers, wrongSaltOfferSignatures, wrongSaltVouchers, wrongSaltSignatures);

        // Test buyer accepting their own offer
        vm.prank(buyer);
        vm.expectRevert("signer cannot redeem own coupon");
        exchange.acceptOfferBatch(offerOrders, offerSignatures, tokenVouchers, tokenSignatures);

        // Test accepting zero price offer - create new offer with different salt
        LibOrderV2.Offer[] memory zeroOfferOrders = new LibOrderV2.Offer[](1);
        zeroOfferOrders[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "zero_offer_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 0,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory zeroOfferSignatures = new bytes[](1);
        zeroOfferSignatures[0] = signOffer(zeroOfferOrders[0], buyerPrivateKey);

        // Create matching token voucher for zero offer test
        LibOrderV2.Token[] memory zeroTokenVouchers = new LibOrderV2.Token[](1);
        zeroTokenVouchers[0] = createTokenVoucher(1, zeroOfferOrders[0].salt, "allItems", seller);
        bytes[] memory zeroTokenSignatures = new bytes[](1);
        zeroTokenSignatures[0] = signTokenVoucher(zeroTokenVouchers[0], validatorPrivateKey);

        vm.prank(seller);
        vm.expectRevert("non existent offer");
        exchange.acceptOfferBatch(zeroOfferOrders, zeroOfferSignatures, zeroTokenVouchers, zeroTokenSignatures);

        // Test with wrong token owner - create new offer with different salt
        LibOrderV2.Offer[] memory wrongOwnerOffers = new LibOrderV2.Offer[](1);
        wrongOwnerOffers[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "wrong_owner_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory wrongOwnerOfferSignatures = new bytes[](1);
        wrongOwnerOfferSignatures[0] = signOffer(wrongOwnerOffers[0], buyerPrivateKey);

        LibOrderV2.Token[] memory wrongOwnerVouchers = new LibOrderV2.Token[](1);
        wrongOwnerVouchers[0] = createTokenVoucher(1, wrongOwnerOffers[0].salt, "allItems", externalWallet);
        bytes[] memory wrongOwnerSignatures = new bytes[](1);
        wrongOwnerSignatures[0] = signTokenVoucher(wrongOwnerVouchers[0], validatorPrivateKey);

        vm.prank(seller);
        vm.expectRevert("token signature does not belong to msg.sender");
        exchange.acceptOfferBatch(wrongOwnerOffers, wrongOwnerOfferSignatures, wrongOwnerVouchers, wrongOwnerSignatures);

        // Set block range and test expired token signature - create new offer with different salt
        exchange.setBlockRange(40);
        
        LibOrderV2.Offer[] memory expiredOffers = new LibOrderV2.Offer[](1);
        expiredOffers[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "expired_offer_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory expiredOfferSignatures = new bytes[](1);
        expiredOfferSignatures[0] = signOffer(expiredOffers[0], buyerPrivateKey);

        LibOrderV2.Token[] memory expiredVouchers = new LibOrderV2.Token[](1);
        expiredVouchers[0] = createTokenVoucher(1, expiredOffers[0].salt, "allItems", seller);
        bytes[] memory expiredSignatures = new bytes[](1);
        expiredSignatures[0] = signTokenVoucher(expiredVouchers[0], validatorPrivateKey);

        // Advance block number to make token expired (blockNumber + blockRange < current block)
        vm.roll(42); // token.blockNumber (1) + blockRange (40) = 41, so block 42 makes it expired

        vm.prank(seller);
        vm.expectRevert("token signature has been expired");
        exchange.acceptOfferBatch(expiredOffers, expiredOfferSignatures, expiredVouchers, expiredSignatures);

        // Create new token voucher with current block - create new offer with different salt
        LibOrderV2.Offer[] memory traitsOffers = new LibOrderV2.Offer[](1);
        traitsOffers[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "traits_offer_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory traitsOfferSignatures = new bytes[](1);
        traitsOfferSignatures[0] = signOffer(traitsOffers[0], buyerPrivateKey);

        LibOrderV2.Token[] memory currentTokenVouchers = new LibOrderV2.Token[](1);
        currentTokenVouchers[0] = createTokenVoucher(1, traitsOffers[0].salt, "allItems", seller);
        bytes[] memory currentTokenSignatures = new bytes[](1);
        currentTokenSignatures[0] = signTokenVoucher(currentTokenVouchers[0], validatorPrivateKey);

        // Test with wrong traits
        LibOrderV2.Token[] memory wrongTraitsVouchers = new LibOrderV2.Token[](1);
        wrongTraitsVouchers[0] = createTokenVoucher(1, traitsOffers[0].salt, "wrong_traits", seller);
        bytes[] memory wrongTraitsSignatures = new bytes[](1);
        wrongTraitsSignatures[0] = signTokenVoucher(wrongTraitsVouchers[0], validatorPrivateKey);

        vm.prank(seller);
        vm.expectRevert("traits does not match");
        exchange.acceptOfferBatch(traitsOffers, traitsOfferSignatures, wrongTraitsVouchers, wrongTraitsSignatures);

        // Setup for successful acceptance - create final offer with different salt
        LibOrderV2.Offer[] memory finalOffers = new LibOrderV2.Offer[](1);
        finalOffers[0] = LibOrderV2.Offer({
            nftContractAddress: address(nftCollectible),
            buyer: buyer,
            salt: "final_offer_salt",
            traits: "allItems",
            tokenId: 1,
            bid: 1 ether,
            duration: 6 * 30 * 24 * 60 * 60,
            size: 1,
            startedAt: FIXED_TIMESTAMP,
            isCollectionOffer: true
        });
        bytes[] memory finalOfferSignatures = new bytes[](1);
        finalOfferSignatures[0] = signOffer(finalOffers[0], buyerPrivateKey);

        LibOrderV2.Token[] memory finalTokenVouchers = new LibOrderV2.Token[](1);
        finalTokenVouchers[0] = createTokenVoucher(1, finalOffers[0].salt, "allItems", seller);
        bytes[] memory finalTokenSignatures = new bytes[](1);
        finalTokenSignatures[0] = signTokenVoucher(finalTokenVouchers[0], validatorPrivateKey);

        vm.prank(seller);
        nftCollectible.setApprovalForAll(address(assetManager), true);
        vm.prank(buyer);
        assetManager.deposit{value: 1 ether}();

        // Accept offer successfully
        vm.prank(seller);
        vm.recordLogs();
        exchange.acceptOfferBatch(finalOffers, finalOfferSignatures, finalTokenVouchers, finalTokenSignatures);

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 3); // AcceptOffer, TransferFrom, and Transfer events

        // Verify NFT transfer
        assertEq(nftCollectible.ownerOf(1), buyer);
    }

    function test_PreventInitializeMultipleTimes() public {
        // Try to initialize the exchange contract again
        vm.expectRevert("Initializable: contract is already initialized");
        exchange.initialize();
    }

    function test_SetAssetManager() public {
        // Test setting asset manager to external wallet
        exchange.setAssetManager(externalWallet);
        assertEq(exchange.assetManager(), externalWallet);

        // Test non-owner cannot set asset manager
        vm.prank(seller);
        vm.expectRevert("Ownable: caller is not the owner");
        exchange.setAssetManager(address(assetManager));

        // Test cannot set zero address
        vm.expectRevert("Given address must be a non-zero address");
        exchange.setAssetManager(address(0));
    }

    function test_SetValidator() public {
        // Test setting validator to external wallet
        exchange.setValidator(externalWallet);
        assertEq(exchange.validator(), externalWallet);

        // Test non-owner cannot set validator
        vm.prank(seller);
        vm.expectRevert("Ownable: caller is not the owner");
        exchange.setValidator(address(assetManager));

        // Test cannot set zero address
        vm.expectRevert("Given address must be a non-zero address");
        exchange.setValidator(address(0));
    }

    function test_PauseAndUnpause() public {
        // Initial state should be unpaused
        assertEq(exchange.paused(), false);

        // Test pause functionality
        exchange.pause();
        assertEq(exchange.paused(), true);

        // Test unpause functionality  
        exchange.unpause();
        assertEq(exchange.paused(), false);

        // Test non-owner cannot pause
        vm.prank(seller);
        vm.expectRevert("Ownable: caller is not the owner");
        exchange.pause();

        // Test non-owner cannot unpause
        vm.prank(seller);
        vm.expectRevert("Ownable: caller is not the owner");
        exchange.unpause();
    }

    function test_SetBlockRange() public {
        uint256 minimumPriceLimit = 40;
        
        // Test setting block range
        exchange.setBlockRange(minimumPriceLimit);
        assertEq(exchange.blockRange(), minimumPriceLimit);

        // Test non-owner cannot set block range
        vm.prank(seller);
        vm.expectRevert("Ownable: caller is not the owner");
        exchange.setBlockRange(minimumPriceLimit);
    }

    function test_GetChainId() public {
        // Test getting chain ID (default Foundry chain ID is 31337)
        assertEq(exchange.getChainId(), 31337);
    }
} 