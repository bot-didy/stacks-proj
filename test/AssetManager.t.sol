// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/contracts/AssetManager/AssetManager.sol";
import "../src/contracts/AssetManager/IAssetManager.sol";
import "../src/contracts/veBlockz/VeBlockz.sol";
import "../src/contracts/BlockzGovernanceToken/BlockzGovernanceToken.sol";
import "../src/contracts/NFTCollectible/NFTCollectible.sol";
import "../src/contracts/Royalty/LibRoyalty.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract AssetManagerTest is Test {
    AssetManager public assetManager;
    VeBLOCKZ public veART;
    BlockzGovernanceToken public blockzGovernanceToken;
    NFTCollectible public nftCollectible;
    ProxyAdmin public proxyAdmin;

    address public owner;
    address public admin;
    address public platform1;
    address public platform2;
    address public user1;
    address public user2;
    address public royaltyReceiver;
    address public treasury;

    // Constants for testing
    uint96 public constant DEFAULT_PROTOCOL_FEE = 250; // 2.5%
    uint96 public constant DEFAULT_ROYALTY = 500; // 5%
    uint256 public constant TEST_TOKEN_ID_1 = 1;
    uint256 public constant TEST_TOKEN_ID_2 = 2;

    event Fund(address indexed user, uint256 amount, bool isExternal);
    event TransferFrom(address indexed user, address indexed to, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, bool isExternal);
    event FailedTransfer(address indexed receiver, uint256 amount);
    event WithdrawnFailedBalance(uint256 amount);
    event WithdrawnPendingRoyalty(uint256 amount);

    function setUp() public {
        // Setup accounts
        owner = address(this);
        admin = makeAddr("admin");
        platform1 = makeAddr("platform1");
        platform2 = makeAddr("platform2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        royaltyReceiver = makeAddr("royaltyReceiver");
        treasury = makeAddr("treasury");

        // Fund accounts with ETH
        vm.deal(address(this), 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(platform1, 100 ether);
        vm.deal(platform2, 100 ether);

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin();

        // Deploy BlockzGovernanceToken
        blockzGovernanceToken = new BlockzGovernanceToken("Test Rock", "TROCK");
        
        // Deploy VeArt with proxy
        VeBLOCKZ veARTImpl = new VeBLOCKZ();
        bytes memory veARTData = abi.encodeWithSelector(
            VeBLOCKZ.initialize.selector, 
            IERC20Upgradeable(address(blockzGovernanceToken))
        );
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

        // Configure AssetManager
        assetManager.setPlatformFeeReceiver(address(veART));
        assetManager.setAdmin(admin);
        assetManager.addPlatform(platform1);
        assetManager.setProtocolFee(platform1, DEFAULT_PROTOCOL_FEE);

        // Deploy and setup NFT collection
        LibRoyalty.Royalty[] memory royalties = new LibRoyalty.Royalty[](0);
        nftCollectible = new NFTCollectible("Test NFT", "TNFT", royalties);
        nftCollectible.mint("", royalties); // tokenId: 1
        nftCollectible.mint("", royalties); // tokenId: 2
        nftCollectible.mint("", royalties); // tokenId: 3
        
        // Transfer NFTs to users for testing
        nftCollectible.transferFrom(address(this), user1, TEST_TOKEN_ID_1);
        nftCollectible.transferFrom(address(this), user2, TEST_TOKEN_ID_2);
        
        // Approve AssetManager to transfer NFTs
        vm.prank(user1);
        nftCollectible.setApprovalForAll(address(assetManager), true);
        vm.prank(user2);
        nftCollectible.setApprovalForAll(address(assetManager), true);
    }

    // ===== INITIALIZATION TESTS =====

    function test_Initialize() public {
        // Should not be able to initialize again
        vm.expectRevert("Initializable: contract is already initialized");
        assetManager.initialize();
    }

    function test_InitialState() public {
        assertEq(assetManager.owner(), owner);
        assertEq(assetManager.admin(), admin);
        assertEq(assetManager.platformFeeReceiver(), address(veART));
        assertFalse(assetManager.paused());
        assertEq(assetManager.pendingFee(), 0);
    }

    // ===== ACCESS CONTROL TESTS =====

    function test_SetAdmin_OnlyOwner() public {
        address newAdmin = makeAddr("newAdmin");
        
        // Owner can set admin
        assetManager.setAdmin(newAdmin);
        assertEq(assetManager.admin(), newAdmin);
        
        // Non-owner cannot set admin
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.setAdmin(newAdmin);
    }

    function test_SetAdmin_ZeroAddress() public {
        vm.expectRevert("Given address must be a non-zero address");
        assetManager.setAdmin(address(0));
    }

    function test_SetVeArtAddress_OnlyOwner() public {
        address newVeArt = makeAddr("newVeArt");
        
        // Owner can set VeArt address
        assetManager.setPlatformFeeReceiver(newVeArt);
        assertEq(assetManager.platformFeeReceiver(), newVeArt);
        
        // Non-owner cannot set VeArt address
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.setPlatformFeeReceiver(newVeArt);
    }

    function test_SetVeArtAddress_ZeroAddress() public {
        vm.expectRevert("Given address must be a non-zero address");
        assetManager.setPlatformFeeReceiver(address(0));
    }

    // ===== PAUSE/UNPAUSE TESTS =====

    function test_PauseUnpause_OnlyOwner() public {
        // Initially unpaused
        assertFalse(assetManager.paused());
        
        // Owner can pause
        assetManager.pause();
        assertTrue(assetManager.paused());
        
        // Owner can unpause
        assetManager.unpause();
        assertFalse(assetManager.paused());
        
        // Non-owner cannot pause
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.pause();
    }

    function test_FunctionsWhenPaused() public {
        assetManager.pause();
        
        // Deposit should revert when paused
        vm.expectRevert("Pausable: paused");
        assetManager.deposit{value: 1 ether}();
        
        // Withdraw should revert when paused
        vm.expectRevert("Pausable: paused");
        assetManager.withdraw(1 ether);
    }

    // ===== PLATFORM MANAGEMENT TESTS =====

    function test_AddPlatform() public {
        address newPlatform = makeAddr("newPlatform");
        
        assetManager.addPlatform(newPlatform);
        
        // Platform should be able to call platform-only functions
        vm.deal(newPlatform, 1 ether);
        vm.prank(newPlatform);
        assetManager.deposit{value: 1 ether}(user1);
        
        assertEq(assetManager.biddingWallets(user1), 1 ether);
    }

    function test_AddPlatform_ZeroAddress() public {
        vm.expectRevert("Given address must be a non-zero address");
        assetManager.addPlatform(address(0));
    }

    function test_AddPlatform_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.addPlatform(makeAddr("newPlatform"));
    }

    function test_AddPlatform_AlreadyWhitelisted() public {
        vm.expectRevert("already whitelisted");
        assetManager.addPlatform(platform1);
    }

    function test_RemovePlatform() public {
        assetManager.removePlatform(platform1);
        
        // Platform should no longer be able to call platform-only functions
        vm.expectRevert("not allowed");
        vm.prank(platform1);
        assetManager.deposit{value: 1 ether}(user1);
    }

    function test_RemovePlatform_NotWhitelisted() public {
        address notWhitelisted = makeAddr("notWhitelisted");
        vm.expectRevert("not whitelisted");
        assetManager.removePlatform(notWhitelisted);
    }

    function test_RemovePlatform_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.removePlatform(platform1);
    }

    // ===== PROTOCOL FEE TESTS =====

    function test_SetProtocolFee() public {
        uint96 newFee = 300; // 3%
        assetManager.setProtocolFee(platform1, newFee);
        assertEq(assetManager.protocolFees(platform1), newFee);
    }

    function test_SetProtocolFee_OnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        assetManager.setProtocolFee(platform1, 300);
    }

    // ===== ROYALTY MANAGEMENT TESTS =====

    function test_SetCollectionRoyalty_ByOwner() public {
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
        
        (bool isEnabled, address receiver, uint96 percentage) = assetManager.royalties(address(nftCollectible));
        assertTrue(isEnabled);
        assertEq(receiver, royaltyReceiver);
        assertEq(percentage, DEFAULT_ROYALTY);
    }

    function test_SetCollectionRoyalty_ByAdmin() public {
        vm.prank(admin);
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
        
        (bool isEnabled, address receiver, uint96 percentage) = assetManager.royalties(address(nftCollectible));
        assertTrue(isEnabled);
        assertEq(receiver, royaltyReceiver);
        assertEq(percentage, DEFAULT_ROYALTY);
    }

    function test_SetCollectionRoyalty_Unauthorized() public {
        vm.expectRevert("not authorized");
        vm.prank(user1);
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
    }

    // ===== DEPOSIT TESTS =====

    function test_Deposit_Self() public {
        uint256 depositAmount = 1 ether;
        
        vm.expectEmit(true, true, true, true);
        emit Fund(address(this), depositAmount, false);
        
        assetManager.deposit{value: depositAmount}();
        
        assertEq(assetManager.biddingWallets(address(this)), depositAmount);
        assertEq(address(assetManager).balance, depositAmount);
    }

    function test_Deposit_ForUser() public {
        uint256 depositAmount = 2 ether;
        
        vm.expectEmit(true, true, true, true);
        emit Fund(user1, depositAmount, true);
        
        vm.prank(platform1);
        assetManager.deposit{value: depositAmount}(user1);
        
        assertEq(assetManager.biddingWallets(user1), depositAmount);
        assertEq(address(assetManager).balance, depositAmount);
    }

    function test_Deposit_ForUser_OnlyPlatform() public {
        vm.expectRevert("not allowed");
        vm.prank(user1);
        assetManager.deposit{value: 1 ether}(user2);
    }

    function test_Deposit_MultipleTimes() public {
        assetManager.deposit{value: 1 ether}();
        assetManager.deposit{value: 2 ether}();
        
        assertEq(assetManager.biddingWallets(address(this)), 3 ether);
        assertEq(address(assetManager).balance, 3 ether);
    }

    // ===== WITHDRAWAL TESTS =====

    function test_Withdraw() public {
        // First deposit
        assetManager.deposit{value: 5 ether}();
        
        uint256 withdrawAmount = 2 ether;
        uint256 initialBalance = address(this).balance;
        
        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(this), withdrawAmount, false);
        
        assetManager.withdraw(withdrawAmount);
        
        assertEq(assetManager.biddingWallets(address(this)), 3 ether);
        assertEq(address(this).balance, initialBalance + withdrawAmount);
    }

    function test_Withdraw_InsufficientBalance() public {
        assetManager.deposit{value: 1 ether}();
        
        vm.expectRevert("Balance is insufficient for a withdrawal");
        assetManager.withdraw(2 ether);
    }

    function test_Withdraw_ZeroBalance() public {
        vm.expectRevert("Balance is insufficient for a withdrawal");
        assetManager.withdraw(1 ether);
    }

    // ===== TRANSFER TESTS =====

    function test_TransferFrom() public {
        uint256 transferAmount = 1 ether;
        
        // Setup: user1 has balance
        vm.prank(platform1);
        assetManager.deposit{value: 5 ether}(user1);
        
        vm.expectEmit(true, true, true, true);
        emit TransferFrom(user1, user2, transferAmount);
        
        vm.prank(platform1);
        assetManager.transferFrom(user1, user2, transferAmount);
        
        assertEq(assetManager.biddingWallets(user1), 4 ether);
        assertEq(assetManager.biddingWallets(user2), 1 ether);
    }

    function test_TransferFrom_InsufficientBalance() public {
        vm.prank(platform1);
        assetManager.deposit{value: 1 ether}(user1);
        
        vm.expectRevert("Insufficient balance");
        vm.prank(platform1);
        assetManager.transferFrom(user1, user2, 2 ether);
    }

    function test_TransferFrom_OnlyPlatform() public {
        vm.expectRevert("not allowed");
        vm.prank(user1);
        assetManager.transferFrom(user1, user2, 1 ether);
    }

    // ===== MARKETPLACE BATCH PAYMENT TESTS =====

    function test_PayMPBatch_SinglePayment() public {
        uint256 price = 1 ether;
        uint256 fee = (price * DEFAULT_PROTOCOL_FEE) / 10000; // 2.5%
        uint256 transferAmount = price - fee;
        
        // Setup: buyer has balance
        vm.prank(platform1);
        assetManager.deposit{value: price}(user2);
        
        // Create payment info
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: price
        });
        
        vm.expectEmit(true, true, true, true);
        emit TransferFrom(user2, user1, transferAmount);
        
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
        
        assertEq(assetManager.biddingWallets(user2), 0);
        assertEq(assetManager.biddingWallets(user1), transferAmount);
        assertEq(assetManager.pendingFee(), fee);
        assertEq(nftCollectible.ownerOf(TEST_TOKEN_ID_1), user2);
    }

    function test_PayMPBatch_WithRoyalty() public {
        uint256 price = 1 ether;
        uint256 fee = (price * DEFAULT_PROTOCOL_FEE) / 10000;
        uint256 royaltyAmount = (price * DEFAULT_ROYALTY) / 10000;
        uint256 transferAmount = price - fee - royaltyAmount;
        
        // Setup royalty
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
        
        // Setup: buyer has balance
        vm.prank(platform1);
        assetManager.deposit{value: price}(user2);
        
        // Create payment info
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: price
        });
        
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
        
        assertEq(assetManager.biddingWallets(user1), transferAmount);
        assertEq(assetManager.pendingFee(), fee);
        assertEq(assetManager.pendingRoyalties(address(nftCollectible)), royaltyAmount);
    }

    function test_PayMPBatch_InsufficientBalance() public {
        // Create payment info with price higher than user's balance
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: 1 ether
        });
        
        vm.expectRevert("Insufficient balance");
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
    }

    function test_PayMPBatch_OnlyPlatform() public {
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: 1 ether
        });
        
        vm.expectRevert("not allowed");
        vm.prank(user1);
        assetManager.payMPBatch(payments);
    }

    // ===== LENDING PAYMENT TESTS =====

    function test_PayLendingBatch() public {
        uint256 amount = 1 ether;
        uint256 fee = (amount * DEFAULT_PROTOCOL_FEE) / 10000;
        uint256 transferAmount = amount - fee;
        
        // Setup: lender has balance
        vm.prank(platform1);
        assetManager.deposit{value: amount}(user1);
        
        // Create lending payment info
        IAssetManager.LendingPaymentInfo[] memory payments = new IAssetManager.LendingPaymentInfo[](1);
        payments[0] = IAssetManager.LendingPaymentInfo({
            lender: user1,
            previousLender: address(0),
            borrower: user2,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_2,
            amount: amount,
            repaymentAmount: 0
        });
        
        vm.expectEmit(true, true, true, true);
        emit TransferFrom(user1, user2, transferAmount);
        
        vm.prank(platform1);
        assetManager.payLendingBatch(payments);
        
        assertEq(assetManager.biddingWallets(user1), 0);
        assertEq(assetManager.biddingWallets(user2), transferAmount);
        assertEq(assetManager.pendingFee(), fee);
        assertEq(nftCollectible.ownerOf(TEST_TOKEN_ID_2), platform1);
    }

    function test_PayLendingBatch_WithRepayment() public {
        uint256 lendAmount = 1 ether;
        uint256 repayAmount = 0.5 ether; // Make repayment smaller than received amount
        uint256 fee = (lendAmount * DEFAULT_PROTOCOL_FEE) / 10000;
        uint256 transferAmount = lendAmount - fee;
        
        // Setup: lender and borrower have balances
        vm.prank(platform1);
        assetManager.deposit{value: lendAmount}(user1);
        vm.prank(platform1);
        assetManager.deposit{value: repayAmount}(user2);
        
        address previousLender = makeAddr("previousLender");
        
        // Create lending payment info with repayment
        IAssetManager.LendingPaymentInfo[] memory payments = new IAssetManager.LendingPaymentInfo[](1);
        payments[0] = IAssetManager.LendingPaymentInfo({
            lender: user1,
            previousLender: previousLender,
            borrower: user2,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_2,
            amount: lendAmount,
            repaymentAmount: repayAmount
        });
        
        vm.prank(platform1);
        assetManager.payLendingBatch(payments);
        
        assertEq(assetManager.biddingWallets(user1), 0);
        // user2 initially has 0.5 ether, receives (1 ether - fee) = 0.975 ether, pays 0.5 ether
        // Final balance = 0.5 + 0.975 - 0.5 = 0.975 ether
        assertEq(assetManager.biddingWallets(user2), transferAmount);
        assertEq(assetManager.biddingWallets(previousLender), repayAmount);
        assertEq(assetManager.pendingFee(), fee);
    }

    // ===== LENDING REPAY TESTS =====

    function test_LendingRepayBatch() public {
        uint256 repayAmount = 1.1 ether;
        
        // Setup: borrower has balance and platform owns the NFT
        vm.prank(platform1);
        assetManager.deposit{value: repayAmount}(user2);
        
        // Transfer NFT to platform first (simulate lending scenario)
        vm.prank(user2);
        nftCollectible.transferFrom(user2, platform1, TEST_TOKEN_ID_2);
        
        // Platform approves AssetManager to transfer NFT back
        vm.prank(platform1);
        nftCollectible.setApprovalForAll(address(assetManager), true);
        
        // Create lending repay info
        IAssetManager.LendingPaymentInfo[] memory payments = new IAssetManager.LendingPaymentInfo[](1);
        payments[0] = IAssetManager.LendingPaymentInfo({
            lender: user1,
            previousLender: address(0),
            borrower: user2,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_2,
            amount: repayAmount,
            repaymentAmount: 0
        });
        
        vm.expectEmit(true, true, true, true);
        emit TransferFrom(user2, user1, repayAmount);
        
        vm.prank(platform1);
        assetManager.lendingRepayBatch(payments);
        
        assertEq(assetManager.biddingWallets(user2), 0);
        assertEq(assetManager.biddingWallets(user1), repayAmount);
        assertEq(nftCollectible.ownerOf(TEST_TOKEN_ID_2), user2);
    }

    // ===== DUTCH AUCTION TESTS =====

    function test_DutchPay() public {
        uint256 bid = 2 ether;
        uint256 endPrice = 1 ether;
        uint256 fee = ((bid - endPrice) * 5000) / 10000; // 50% of difference
        uint256 transferAmount = bid - fee;
        
        // Setup: bidder has balance
        vm.prank(platform1);
        assetManager.deposit{value: bid}(user2);
        
        // Transfer NFT to platform for auction and approve AssetManager
        vm.prank(user1);
        nftCollectible.transferFrom(user1, platform1, TEST_TOKEN_ID_1);
        vm.prank(platform1);
        nftCollectible.setApprovalForAll(address(assetManager), true);
        
        vm.prank(platform1);
        assetManager.dutchPay(
            address(nftCollectible),
            TEST_TOKEN_ID_1,
            user2, // bidder
            user1, // lender
            bid,
            endPrice
        );
        
        assertEq(assetManager.biddingWallets(user2), 0);
        assertEq(assetManager.biddingWallets(user1), transferAmount);
        assertEq(assetManager.pendingFee(), fee);
        assertEq(nftCollectible.ownerOf(TEST_TOKEN_ID_1), user2);
    }

    // ===== PENDING FEES TESTS =====

    function test_WithdrawPendingFee() public {
        // Setup: create some fees
        uint256 price = 1 ether;
        vm.prank(platform1);
        assetManager.deposit{value: price}(user2);
        
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: price
        });
        
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
        
        uint256 expectedFee = (price * DEFAULT_PROTOCOL_FEE) / 10000;
        assertEq(assetManager.pendingFee(), expectedFee);
        
        uint256 initialVeArtBalance = address(veART).balance;
        
        assetManager.withdrawPendingFee();
        
        assertEq(assetManager.pendingFee(), 0);
        assertEq(address(veART).balance, initialVeArtBalance + expectedFee);
    }

    // ===== PENDING ROYALTIES TESTS =====

    function test_WithdrawRoyaltyAmount() public {
        uint256 price = 1 ether;
        
        // Setup royalty
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
        
        // Create transaction that generates royalty
        vm.prank(platform1);
        assetManager.deposit{value: price}(user2);
        
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: price
        });
        
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
        
        uint256 expectedRoyalty = (price * DEFAULT_ROYALTY) / 10000;
        assertEq(assetManager.pendingRoyalties(address(nftCollectible)), expectedRoyalty);
        
        uint256 initialBalance = royaltyReceiver.balance;
        
        vm.expectEmit(true, true, true, true);
        emit WithdrawnPendingRoyalty(expectedRoyalty);
        
        assetManager.withdrawRoyaltyAmount(address(nftCollectible));
        
        assertEq(assetManager.pendingRoyalties(address(nftCollectible)), 0);
        assertEq(royaltyReceiver.balance, initialBalance + expectedRoyalty);
    }

    function test_WithdrawRoyaltyAmount_NoCredits() public {
        vm.expectRevert("no credits to withdraw");
        assetManager.withdrawRoyaltyAmount(address(nftCollectible));
    }

    function test_WithdrawRoyaltyAmount_NoReceiver() public {
        // Create some pending royalty first through normal flow
        uint256 price = 1 ether;
        
        // Setup royalty with receiver initially
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            royaltyReceiver,
            DEFAULT_ROYALTY,
            true
        );
        
        // Create transaction that generates royalty
        vm.prank(platform1);
        assetManager.deposit{value: price}(user2);
        
        IAssetManager.PaymentInfo[] memory payments = new IAssetManager.PaymentInfo[](1);
        payments[0] = IAssetManager.PaymentInfo({
            buyer: user2,
            seller: user1,
            collection: address(nftCollectible),
            tokenId: TEST_TOKEN_ID_1,
            price: price
        });
        
        vm.prank(platform1);
        assetManager.payMPBatch(payments);
        
        // Now remove the receiver
        assetManager.setCollectionRoyalty(
            address(nftCollectible),
            address(0),
            DEFAULT_ROYALTY,
            true
        );
        
        vm.expectRevert("receiver must be set");
        assetManager.withdrawRoyaltyAmount(address(nftCollectible));
    }

    // ===== FAILED TRANSFER TESTS =====

    function test_WithdrawFailedCredits() public {
        // Fund the contract first
        vm.deal(address(assetManager), 2 ether);
        
        // Find the storage slot for failedTransferBalance mapping
        // According to storage layout inspection, failedTransferBalance is at slot 208
        uint256 mapSlot = 208; // failedTransferBalance is at slot 208
        bytes32 slot = keccak256(abi.encode(user1, mapSlot));
        
        // Set the failed transfer balance
        vm.store(address(assetManager), slot, bytes32(uint256(1 ether)));
        
        uint256 initialBalance = user1.balance;
        
        vm.prank(user1);
        assetManager.withdrawFailedCredits(user1);
        
        assertEq(user1.balance, initialBalance + 1 ether);
        
        // Verify the failed transfer balance was reset
        assertEq(assetManager.failedTransferBalance(user1), 0);
    }

    function test_WithdrawFailedCredits_NoCredits() public {
        vm.expectRevert("no credits to withdraw");
        vm.prank(user1);
        assetManager.withdrawFailedCredits(user1);
    }

    // ===== NFT TRANSFER TESTS =====

    function test_NftTransferFrom() public {
        vm.prank(platform1);
        assetManager.nftTransferFrom(user1, user2, address(nftCollectible), TEST_TOKEN_ID_1);
        
        assertEq(nftCollectible.ownerOf(TEST_TOKEN_ID_1), user2);
    }

    function test_NftTransferFrom_OnlyPlatform() public {
        vm.expectRevert("not allowed");
        vm.prank(user1);
        assetManager.nftTransferFrom(user1, user2, address(nftCollectible), TEST_TOKEN_ID_1);
    }

    function test_BatchTransfer() public {
        // Setup: give this contract additional NFTs and approve AssetManager
        nftCollectible.mint("", new LibRoyalty.Royalty[](0)); // tokenId: 4
        nftCollectible.mint("", new LibRoyalty.Royalty[](0)); // tokenId: 5
        nftCollectible.setApprovalForAll(address(assetManager), true);
        
        address[] memory collections = new address[](2);
        collections[0] = address(nftCollectible);
        collections[1] = address(nftCollectible);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 4;
        tokenIds[1] = 5;
        
        assetManager.batchTransfer(collections, tokenIds, user1);
        
        assertEq(nftCollectible.ownerOf(4), user1);
        assertEq(nftCollectible.ownerOf(5), user1);
    }

    function test_BatchTransfer_InputMismatch() public {
        address[] memory collections = new address[](2);
        uint256[] memory tokenIds = new uint256[](1);
        
        vm.expectRevert("addresses and tokenIds inputs does not match");
        assetManager.batchTransfer(collections, tokenIds, user1);
    }

    function test_BatchTransfer_ExceedsLimit() public {
        address[] memory collections = new address[](51);
        uint256[] memory tokenIds = new uint256[](51);
        
        vm.expectRevert("exceeded the limits");
        assetManager.batchTransfer(collections, tokenIds, user1);
    }

    // ===== VIEW FUNCTIONS TESTS =====

    function test_Balance() public view {
        // This test just calls the balance function, no need for modification
        assetManager.balance();
    }

    // ===== HELPER FUNCTIONS =====

    // Receive function to accept ETH transfers
    receive() external payable {}
} 