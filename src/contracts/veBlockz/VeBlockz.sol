//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../BlockzMini/IBlockzMini.sol";
import "../BlockzOperator/IBlockzOperator.sol";

/**
* @title VeBLOCK
* @notice the users can simply stake and withdraw their NFTs for a specific period and earn rewards if it does not sell.
*/
contract VeBLOCKZ is ERC721HolderUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // Struct to store information about User's burned Blockz Mini NFTs
    struct UserBlockzMiniBoostInfo {
        // Total number of burned Blockz Mini NFTs
        uint256 totalBurnedBlockzMiniCount;
        // Total rarity level of burned Blockz Mini NFTs
        uint256 totalRarityLevel;
    }

    // Struct to store information about a user
    struct UserInfo {
        // Amount of BLOCK staked by the user
        uint256 amount;
        // Time of the last VeBLOCK claim, or the time of the first deposit if the user has not claimed yet
        uint256 lastRelease;
        uint256 rewardDebt;
        uint256 tokenRewardDebt;
        uint256 failedTokenBalance;
        uint256 failedBalance;
    }

    struct DQPool {
        uint256 multiplier;
        uint256 endedAt;
        uint256 withdrawDuration;
    }

    struct DQPoolItem {
        address owner;
        uint256 endedAt;
    }

    // Struct to store information about a user
    struct UserBlockzInfo {
        // Amount of Blockz staked by the user
        uint256 amount;
        uint256 rewardDebt;
    }

    // allows the whitelisted contracts.
    EnumerableSetUpgradeable.AddressSet private _whitelistedPlatforms;

    // The constant "WAD" represents the precision level for fixed point arithmetic, set to 10^18 for 18 decimal places precision.
    uint256 public constant WAD = 10**18;

    // Multiplier used to calculate the rarity level of Blockz Mini NFTs
    uint256 public rarityLevelMultiplier;

    // Total amount of BLOCK staked by all users  
    uint256 public totalStakedTokenAmount;

    // Contract representing the BLOCK token
    IERC20Upgradeable public blockzToken;

    // Contract representing the Blockz Mini collection
    IBlockzMini public blockzMiniCollection;

    // max veBLOCKZ to staked block ratio
    // Note if user has 10 block staked, they can only have a max of 10 * maxCap veBLOCKZ in balance
    uint256 public maxCap;

    // the rate of veBLOCK generated per second, per block staked
    uint256 public veBLOCKZgenerationRate;

    // the rate at which rewards in BLOCK are generated
    uint256 public rewardTokenGenerationRate;

    // user info mapping
    mapping(address => UserInfo) public users;

    // Stores information about a user's Blockz Mini boost
    mapping(address => UserBlockzMiniBoostInfo) public userBlockzMiniBoostInfos;

    // Balance of rewards at the last reward distribution
    uint256 public lastRewardBalance;
    // Accumulated rewards per share
    uint256 public accRewardPerShare;
    // Accumulated Token rewards per share
    uint256 public accTokenPerShare;
    // Timestamp of the last reward distribution
    uint256 public lastRewardTimestamp;
    // Precision used for Token reward calculations
    uint256 public ACC_TOKEN_REWARD_PRECISION;
    // Precision used for reward per share calculations
    uint256 public ACC_REWARD_PER_SHARE_PRECISION;


    // Balances of each address
    mapping(address => uint256) private _balances;
    // Allowances granted by each address to other addresses
	mapping(address => mapping(address => uint256)) private _allowances;
    // Total supply of the token
    uint256 private _totalSupply;
    // Name of the token
	string private _name;
    // Symbol of the token
	string private _symbol;

    mapping(address => uint256) public boostDuration;
    mapping(address => uint256) public earnedTotalBoost;
    uint256 public boostFee;
    mapping(address => uint256) public dqBoostDuration;
    mapping(address => mapping(uint256 => uint256)) public dqRarityLevels;
    mapping(address => mapping(uint256 => uint256)) public dqRarityPrices;
    mapping(address => DQPool) public dqPools;
    mapping(address => mapping(uint256 => DQPoolItem)) public dqPoolItems;
    address public admin;
    uint256 public totalBlockzSupply;
    uint256 public accBlockzRewardPerShare;
    mapping(address => UserBlockzInfo) public blockzUsers;
    mapping(uint256 => address) public blockzOwners;
    IBlockzMini public blockzCollection;
    uint256 public depositBlockzFee;
    IBlockzOperator public blockzOperator;

    event Deposit(address indexed user, uint256 amount);
    event DepositBLOCKZ(address indexed user, uint256 amount);
    event DepositBlockz(address indexed user, uint256 indexed tokenId);
    event WithdrawBlockz(address indexed user, uint256 indexed tokenId);
    event WithdrawBLOCKZ(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event ClaimBlockzReward(address indexed user, uint256 amount);
    event ClaimBLOCKZReward(address indexed user, uint256 amount);
    event ClaimedVeBLOCKZ(address indexed user, uint256 indexed amount);
    event MaxCapUpdated(uint256 cap);
    event BLOCKZGenerationRateUpdated(uint256 rate);
    event Burn(address indexed account, uint256 value);
	event Mint(address indexed beneficiary, uint256 value);
    event BurnBlockzMini(address indexed user, uint256 indexed tokenId, uint256 rarityLevel);
    event WhitelistAdded(address indexed platform);
    event WhitelistRemoved(address indexed platform);
    event BoostFeeSet(uint256 boostFee);
    event DqStake(address indexed user, address indexed collection, uint256 indexed tokenId, uint256 endedAt);
    event DqWithdraw(address indexed user, address indexed collection, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20Upgradeable _blockzToken) public initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __ERC721Holder_init_unchained();
        _name = "BlockzVeVBLOCKZ";
		_symbol = "veBLOCKZ";
        veBLOCKZgenerationRate = 6415343915343;
        rewardTokenGenerationRate = 77160493827160000;
        rarityLevelMultiplier = 1;
        maxCap = 100;
        blockzToken = _blockzToken;
        ACC_REWARD_PER_SHARE_PRECISION = 1e24;
        ACC_TOKEN_REWARD_PRECISION = 1e18;
    }
    receive() external payable {}

    /**
     * @dev pause contract, restricting certain operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause contract, enabling certain operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    /**
    * @notice  allows the owner to add a contract address to the whitelist.
    * @param _whitelist The address of the contract.
    */
    function addPlatform(address _whitelist) external onlyOwner {
        require(!_whitelistedPlatforms.contains(_whitelist), "Error: already whitelisted");
        _whitelistedPlatforms.add(_whitelist);
        emit WhitelistAdded(_whitelist);
    }

    /**
    * @notice allows the owner to remove a contract address to restrict.
    * @param _whitelist The address of the contract.
    */
    function removePlatform(address _whitelist) external onlyOwner {
        require(_whitelistedPlatforms.contains(_whitelist), "Error: not whitelisted");
        _whitelistedPlatforms.remove(_whitelist);
        emit WhitelistRemoved(_whitelist);
    }

    function setBlockzAddress(address _blockzCollection) external onlyOwner {
        blockzCollection = IBlockzMini(_blockzCollection);
    }

    function setBlockzOperator(address _blockzOperator) external onlyOwner {
        blockzOperator = IBlockzOperator(_blockzOperator);
    }

    function setDQRarityLevels(address _collection, uint256[] calldata _tokenIds, uint256[] calldata _rarityLevels) external {
        require(msg.sender == owner() || msg.sender == admin, "caller is not authorized");
        uint256 len = _tokenIds.length;
        for (uint256 i; i < len; ++i) {
            dqRarityLevels[_collection][_tokenIds[i]] = _rarityLevels[i];
        }
    }

    function setDQRarityPrices(address _collection, uint256[] calldata _rarityLevels, uint256[] calldata _prices) external onlyOwner {
        uint256 len = _rarityLevels.length;
        for (uint256 i; i < len; ++i) {
            dqRarityPrices[_collection][_rarityLevels[i]] = _prices[i];
        }
    }

    /**
	* @notice sets maxCap
    * @param _maxCap the new max ratio
    */
    function setMaxCap(uint256 _maxCap) external onlyOwner {
        maxCap = _maxCap;
        emit MaxCapUpdated(_maxCap);
    }

    /**
    * @notice Sets the reward BLOCKZ generation rate
    * @param _rewardTokenGenerationRate reward BLOCKZ generation rate
    */
    function setTokenGenerationRate(uint256 _rewardTokenGenerationRate) external onlyOwner {
        _updateTokenReward();
        rewardTokenGenerationRate = _rewardTokenGenerationRate;
        emit BLOCKZGenerationRateUpdated(_rewardTokenGenerationRate);
    }

    function setBoostFee(uint256 _boostFee) external onlyOwner {
        boostFee = _boostFee;
        emit BoostFeeSet(_boostFee);
    }

    function setDepositBlockzFee(uint256 _depositBlockzFee) external onlyOwner {
        depositBlockzFee = _depositBlockzFee;
    }

    function setDQConfiguration(address _collection, uint256 _duration, uint256 _withdrawDuration, uint256 _multiplier) external onlyOwner {
        dqPools[_collection].endedAt = block.timestamp + _duration;
        dqPools[_collection].multiplier = _multiplier;
        dqPools[_collection].withdrawDuration = _withdrawDuration;
    }

    /**
    * @notice Gets the balance of the contract
    */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @notice Gets the boosted generation rate for a user
    * @param _addr The address of the user
    */
    function getBoostedGenerationRate(address _addr) external view returns (uint256) {
        if ((users[_addr].lastRelease + boostDuration[_addr]) > block.timestamp) {
            if ((users[_addr].lastRelease + dqBoostDuration[_addr]) > block.timestamp) {
                return veBLOCKZgenerationRate * 5;
            } else {
                return veBLOCKZgenerationRate * 4;
            }
        } else {
            if ((users[_addr].lastRelease + dqBoostDuration[_addr]) > block.timestamp) {
                return veBLOCKZgenerationRate * 2;
            } else {
                return veBLOCKZgenerationRate;
            }
        }
    }

    /**
    * @notice Allows a user to deposit BLOCKZ tokens to earn rewards in veBLOCKZ
    * @param _amount The amount of BLOCKZ tokens to be deposited
    */
    function depositBLOCKZ(uint256 _amount) external nonReentrant whenNotPaused {
        // ensures that the call is not made from a smart contract, unless it is on the whitelist.
        _assertNotContract(msg.sender);

        require(_amount > 0, "Error: Deposit amount must be greater than zero");
        require(blockzToken.balanceOf(msg.sender) >= _amount, "Error: Insufficient balance to deposit the specified amount");

        if (users[msg.sender].amount > 0) {
            // if user exists, first, claim his veBLOCKZ
            _harvestVeBLOCKZ(msg.sender);
            // then, increment his holdings
            users[msg.sender].amount += _amount;
        } else {
            // add new user to mapping
            users[msg.sender].lastRelease = block.timestamp;
            users[msg.sender].amount = _amount;
        }
        totalStakedTokenAmount += _amount;

        emit DepositBLOCKZ(msg.sender, _amount);
        // Request block from user
        blockzToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
    * @notice Burns a blockzmini NFT to boost VeBLOCKZ generation rate for the sender.
    * @param _tokenId The unique identifier of the BlockzMini NFT being burned.
    */
    function burnBlockzMiniToBoostVeBLOCKZ(uint256 _tokenId) external payable whenNotPaused nonReentrant {
        // ensures that the call is not made from a smart contract, unless it is on the whitelist.
        _assertNotContract(msg.sender);
        require(blockzMiniCollection.ownerOf(_tokenId) == msg.sender, "The provided NFT does not belong to the sender");

        uint256 secondsElapsed = block.timestamp - users[msg.sender].lastRelease;

        if (secondsElapsed < boostDuration[msg.sender]) {
            require(msg.value >= boostFee, "insufficient payment");
        }

        _harvestVeBLOCKZ(msg.sender);

        blockzMiniCollection.burn(_tokenId);

        uint256 rarityLevel = blockzMiniCollection.getRarityLevel(_tokenId);
        boostDuration[msg.sender] += rarityLevel * 3600;
        emit BurnBlockzMini(msg.sender, _tokenId, rarityLevel);
    }

    function stakeDqItems(address _collection, uint256[] calldata _tokenIds) external payable whenNotPaused nonReentrant {
        // ensures that the call is not made from a smart contract, unless it is on the whitelist.
        _assertNotContract(msg.sender);
        uint256 len = _tokenIds.length;
        uint256 price;
        require(block.timestamp < dqPools[_collection].endedAt, "The boosting pool has expired, and NFT staking is no longer allowed.");
        for (uint256 i; i < len; ++i) {
            price += dqRarityPrices[_collection][dqRarityLevels[_collection][_tokenIds[i]]];
        }
        require(msg.value >= ((100 * price * balanceOf(msg.sender)) / _totalSupply), "Insufficient payment provided for staking the NFT(s).");

        _harvestVeBLOCKZ(msg.sender);

        for (uint256 i; i < len; ++i) {
            require(IBlockzMini(_collection).ownerOf(_tokenIds[i]) == msg.sender, "The provided NFT does not belong to the sender");
            IBlockzMini(_collection).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
            dqBoostDuration[msg.sender] += dqRarityLevels[_collection][_tokenIds[i]] * dqPools[_collection].multiplier * 1800;
            dqPoolItems[_collection][_tokenIds[i]].owner = msg.sender;
            dqPoolItems[_collection][_tokenIds[i]].endedAt = block.timestamp + dqPools[_collection].withdrawDuration;
            emit DqStake(msg.sender, _collection, _tokenIds[i], dqPoolItems[_collection][_tokenIds[i]].endedAt);
        }
    }

    function withdrawDqItems(address _collection, uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        _assertNotContract(msg.sender);
        uint256 len = _tokenIds.length;
        for (uint256 i; i < len; ++i) {
            require(dqPoolItems[_collection][_tokenIds[i]].owner == msg.sender, "The provided NFT does not belong to the sender");
            require(dqPoolItems[_collection][_tokenIds[i]].endedAt <= block.timestamp, "The provided NFT has not yet expired, and cannot be withdrawn from the boosting pool.");

            IBlockzMini(_collection).safeTransferFrom(address(this), msg.sender, _tokenIds[i]);
            delete dqPoolItems[_collection][_tokenIds[i]];
            emit DqWithdraw(msg.sender, _collection, _tokenIds[i]);
        }
    }

    /**
    * @notice Withdraws all the BLOCK deposit by the caller
    */
    function withdrawAllBLOCK() external nonReentrant whenNotPaused {
        require(users[msg.sender].amount > 0, "Error: amount to withdraw cannot be zero");
        require(blockzUsers[msg.sender].amount == 0, "Error: You must first unstake all of your The Blockzs NFTs to unstake your BLOCK.");
        _withdrawBLOCK(msg.sender, users[msg.sender].amount);
    }

    /**
    * @dev Allows the contract owner to withdraw all BLOCK tokens from a specific user's account in case of an emergency.
    * @param _receiver The address of the user whose BLOCK tokens will be withdrawn.
    */
    function emergencyWithdrawAllBLOCK(address _receiver) external onlyOwner {
        require(users[_receiver].amount > 0, "Error: amount to withdraw cannot be zero");
        require(blockzUsers[_receiver].amount == 0, "Error: You must first unstake all of your The Blockzs NFTs to unstake your BLOCK.");
        _withdrawBLOCK(_receiver, users[_receiver].amount);
    }

    /**
    * @notice Allows a user to withdraw a specified amount of BLOCK
    * @param _amount The amount of BLOCK to withdraw
    */
    function withdrawBLOCK(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Error: amount to withdraw cannot be zero");
        require(users[msg.sender].amount >= _amount, "Error: not enough balance");
        require(blockzUsers[msg.sender].amount == 0, "Error: You must first unstake all of your The Blockzs NFTs to unstake your BLOCK.");
        _withdrawBLOCK(msg.sender, _amount);
    }

    /**
    * @notice Harvests VeBLOCKZ rewards for the user
    * @param _receiver The address of the receiver
    */
    function harvestVeBLOCKZ(address _receiver) external nonReentrant whenNotPaused {
        require(users[_receiver].amount > 0, "Error: user has no stake");
        _harvestVeBLOCKZ(_receiver);
    }

    function withdrawBlockzs(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        // ensures that the call is not made from a smart contract, unless it is on the whitelist.
        _assertNotContract(msg.sender);
        _withdrawBlockz(msg.sender, _tokenIds);
    }

    function emergencyWithdrawBlockzs(address _receiver, uint256[] calldata _tokenIds) external onlyOwner {
        _withdrawBlockz(_receiver, _tokenIds);
    }

    /**
    * @notice This function allows the user to claim the rewards earned by their VeBLOCKZ holdings.
    * The rewards are calculated based on the current rewards per share and the user's VeBLOCKZ balance.
    * The user's reward debt is also updated to the latest rewards earned.
    * @param _receiver The address of the receiver
    */
    function _claimAllEarnings(address _receiver) internal {
        uint256 userVeBLOCKZBalance = balanceOf(_receiver);
        _updateReward();
        _updateTokenReward();

        UserInfo memory user = users[_receiver];
        uint256 _pending = ((userVeBLOCKZBalance * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt;

        uint256 _pendingTokenReward = ((userVeBLOCKZBalance * accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION) - user.tokenRewardDebt;

        uint256 _pendingBlockzReward = ((blockzUsers[_receiver].amount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - blockzUsers[_receiver].rewardDebt;

        uint256 failedBalance = users[_receiver].failedBalance;

        if (_pending > 0 || failedBalance > 0) {
            users[_receiver].rewardDebt = (userVeBLOCKZBalance * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;
            emit ClaimReward(_receiver, _pending);
            _claimEarnings(_receiver, _pending);
        }
        if (_pendingBlockzReward > 0) {
            blockzUsers[_receiver].rewardDebt = (blockzUsers[_receiver].amount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;
            emit ClaimBlockzReward(_receiver, _pendingBlockzReward);
            _claimEarnings(_receiver, _pendingBlockzReward);
        }
        if (_pendingTokenReward > 0) {
            users[_receiver].tokenRewardDebt = (userVeBLOCKZBalance * accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION;
            emit ClaimBlockzReward(_receiver, _pendingTokenReward);
            _claimTokenEarnings(_receiver, _pendingTokenReward);
        }
    }

    /**
    * @notice This function allows the user to claim the rewards earned by their VeBLOCKZ holdings.
    * The rewards are calculated based on the current rewards per share and the user's VeBLOCKZ balance.
    * The user's reward debt is also updated to the latest rewards earned.
    * @param _receiver The address of the receiver
    */
    function claimEarnings(address _receiver) external nonReentrant whenNotPaused {
        _claimAllEarnings(_receiver);
    }

    /**
    * @notice View function to see pending reward token
    * @param _user The address of the user
    * @return `_user`'s pending reward token
    */
    function pendingRewards(address _user) external view returns (uint256) {
        UserInfo memory user = users[_user];
        uint256 _totalVeBLOCKZ = _totalSupply;
        uint256 _accRewardTokenPerShare = accRewardPerShare;
        uint256 _rewardBalance = address(this).balance;

        if (_rewardBalance != lastRewardBalance && _totalVeBLOCKZ != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            if (totalBlockzSupply > 0) {
                uint256 tokenRewardPart = ((_accruedReward) * 8) / 10; // 80% of the reward is for the token
                _accRewardTokenPerShare += ((tokenRewardPart * ACC_REWARD_PER_SHARE_PRECISION) / _totalVeBLOCKZ);
            } else {
                _accRewardTokenPerShare += ((_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalVeBLOCKZ);
            }
        }

        uint256 currentBalance = balanceOf(_user);
        return ((currentBalance * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt;
    }

    /**
    * @notice View function to see pending reward token
    * @param _user The address of the user
    * @return `_user`'s pending reward token
    */
    function pendingBlockzRewards(address _user) external view returns (uint256) {
        UserBlockzInfo memory user = blockzUsers[_user];
        uint256 _accRewardTokenPerShare = accBlockzRewardPerShare;
        uint256 _rewardBalance = address(this).balance;

        if (_rewardBalance != lastRewardBalance && totalBlockzSupply != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            uint256 tokenRewardPart = ((_accruedReward) * 8) / 10;
            uint256 blockzRewardPart = _accruedReward - tokenRewardPart;

            _accRewardTokenPerShare += ((blockzRewardPart * ACC_REWARD_PER_SHARE_PRECISION) / totalBlockzSupply);
        }
        return ((user.amount * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt;
    }

    /**
    * @notice Calculates and returns the pending token rewards for a specific user.
    * @param _user the address of the user
    */
    function pendingTokenRewards(address _user) external view returns (uint256) {
        UserInfo memory user = users[_user];
        uint256 _userVeBLOCKZ = balanceOf(_user);
        uint256 _totalVeBLOCKZ = _totalSupply;
        if (_userVeBLOCKZ > 0) {
            uint256 secondsElapsed = block.timestamp - lastRewardTimestamp;
            uint256 tokenReward = secondsElapsed * rewardTokenGenerationRate;
            uint256 _accTokenPerShare = accTokenPerShare + ((tokenReward * ACC_TOKEN_REWARD_PRECISION) / _totalVeBLOCKZ);
            return ((_userVeBLOCKZ * _accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION) - user.tokenRewardDebt;
        }
        return 0;
    }

    /**
    * @notice Calculate the amount of veBLOCKZ that can be claimed by user
    * @param _addr The address of the user
    * @return amount of veBLOCKZ that can be claimed by user
    */
    function claimableVeBLOCKZ(address _addr) public view returns (uint256) {
        UserInfo storage user = users[_addr];

        // get seconds elapsed since last claim
        uint256 secondsElapsed = block.timestamp - user.lastRelease;

        // calculate pending amount
        // Math.mwmul used to multiply wad numbers

        uint256 pending = _wmul(user.amount, secondsElapsed * veBLOCKZgenerationRate);
        if (secondsElapsed > boostDuration[_addr]) {
            pending += _wmul(user.amount, boostDuration[_addr] * veBLOCKZgenerationRate * 3);
        } else {
            pending += _wmul(user.amount, secondsElapsed * veBLOCKZgenerationRate * 3);
        }

        if (secondsElapsed > dqBoostDuration[_addr]) {
            pending += _wmul(user.amount, dqBoostDuration[_addr] * veBLOCKZgenerationRate * 1);
        } else {
            pending += _wmul(user.amount, secondsElapsed * veBLOCKZgenerationRate * 1);
        }

        // get user's veBLOCKZ balance
        uint256 userVeBLOCKZBalance = balanceOf(_addr);



        // user vePTP balance cannot go above user.amount * maxCap
        uint256 maxVeBLOCKZCap = user.amount * maxCap;

        // first, check that user hasn't reached the max limit yet
        if (userVeBLOCKZBalance < maxVeBLOCKZCap) {
            // then, check if pending amount will make user balance overpass maximum amount
            if ((userVeBLOCKZBalance + pending) > maxVeBLOCKZCap) {
                return maxVeBLOCKZCap - userVeBLOCKZBalance;
            } else {
                return pending;
            }
        }
        return 0;
    }

        /**
	 * @notice Returns the name of the token.
     */
	function name() public view returns (string memory) {
		return _name;
	}

	/**
	 * @notice Returns the symbol of the token, usually a shorter version of the name.
     */
	function symbol() public view returns (string memory) {
		return _symbol;
	}

    /**
	* @notice See {IERC20-totalSupply}.
    */
	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	/**
	* @notice See {IERC20-balanceOf}.
    */
	function balanceOf(address account) public view returns (uint256) {
		return _balances[account];
	}

	/**
	* @notice Returns the number of decimals used to get its user representation.
    */
	function decimals() public pure returns (uint8) {
		return 18;
	}

    function _withdrawBLOCK(address _receiver, uint256 _amount) internal {
        UserInfo memory user = users[_receiver];
        UserBlockzInfo memory userBlockzInfo = blockzUsers[_receiver];
        // Reset the user's last release timestamp
        users[_receiver].lastRelease = block.timestamp;

        // Update the user's BLOCK balance by subtracting the withdrawn amount
        users[_receiver].amount = user.amount - _amount;
        // Update the total staked BLOCK amount
        totalStakedTokenAmount -= _amount;

        // Calculate the user's VEBLOCKZ balance that must be burned
        uint256 userVeBLOCKZBalance = balanceOf(_receiver);

        if (userVeBLOCKZBalance > 0) {
            // Update the rewards
            _updateReward();
            _updateTokenReward();

            // Calculate the pending rewards and BLOCK rewards
            uint256 _pending = ((userVeBLOCKZBalance * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt;

            uint256 _pendingTokenReward = ((userVeBLOCKZBalance * accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION) - user.tokenRewardDebt;

            uint256 currentBlockzRewardDebt = ((userBlockzInfo.amount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
            uint256 _pendingBlockzReward = currentBlockzRewardDebt - userBlockzInfo.rewardDebt;

            // Reset the user's reward and BLOCK reward debts
            users[_receiver].rewardDebt = 0;
            users[_receiver].tokenRewardDebt = 0;
            blockzUsers[_receiver].rewardDebt = currentBlockzRewardDebt;


            // Claim the rewards and BLOCK rewards if there is a pending amount
            if (_pending > 0) {
                emit ClaimReward(_receiver, _pending);
                _claimEarnings(_receiver, _pending);
            }
            if (_pendingBlockzReward > 0) {
                emit ClaimBlockzReward(_receiver, _pendingBlockzReward);
                _claimEarnings(_receiver, _pendingBlockzReward);
            }
            if (_pendingTokenReward > 0) {
                emit ClaimBlockzReward(_receiver, _pendingTokenReward);
                _claimTokenEarnings(_receiver, _pendingTokenReward);
            }

            // Burn the user's VEBLOCK balance
            _burn(_receiver, userVeBLOCKZBalance);
        }

        emit WithdrawBLOCKZ(_receiver, _amount);
        // Send the withdrawn BLOCK back to the user
        blockzToken.safeTransfer(_receiver, _amount);
    }

    /**
    * @notice Update reward variables
    */
    function _updateReward() internal {
        uint256 _totalVeBLOCKZ = _totalSupply;
        uint256 _rewardBalance = address(this).balance;

        if (_rewardBalance == lastRewardBalance || _totalVeBLOCKZ == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        if (totalBlockzSupply > 0) {
            uint256 tokenPartReward = ((_accruedReward * 8) / 10);
            uint256 blockzPartReward = _accruedReward - tokenPartReward;
            accRewardPerShare += ((tokenPartReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalVeBLOCKZ);
            accBlockzRewardPerShare += ((blockzPartReward * ACC_REWARD_PER_SHARE_PRECISION) / totalBlockzSupply);
        } else {
            accRewardPerShare += ((_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalVeBLOCKZ);
        }

        lastRewardBalance = _rewardBalance;
    }

    /**
    * @notice Updates the accTokenPerShare and lastRewardTimestamp value, which is used to calculate the rewards
    * users will earn when they harvest in the future.
    */
    function _updateTokenReward() internal {
        uint256 _totalVeBLOCKZ = _totalSupply;
        if (block.timestamp > lastRewardTimestamp && _totalVeBLOCKZ > 0) {

            uint256 secondsElapsed = block.timestamp - lastRewardTimestamp;
            uint256 tokenReward = secondsElapsed * rewardTokenGenerationRate;
            accTokenPerShare += ((tokenReward * ACC_TOKEN_REWARD_PRECISION) / _totalVeBLOCKZ);
        }
        lastRewardTimestamp = block.timestamp;
    }

    /**
    * This internal function _harvestVeBLOCKZ is used to allow the users to claim the VeBLOCKZ they are entitled to.
    * It calculates the amount of VeBLOCKZ that can be claimed based on the user's stake, updates the user's
    * last release time, deposits the VeBLOCKZ to the user's account, and mints new VeBLOCKZ tokens.
    *
    * @param _addr address of the user claiming VeBLOCKZ
    */
    function _harvestVeBLOCKZ(address _addr) internal {
        uint256 amount = claimableVeBLOCKZ(_addr);
        uint256 timeElapsed = block.timestamp - users[_addr].lastRelease;
        if (timeElapsed > boostDuration[_addr]) {
            boostDuration[_addr] = 0;
        } else {
            boostDuration[_addr] -= timeElapsed;
        }

        if (timeElapsed > dqBoostDuration[_addr]) {
            dqBoostDuration[_addr] = 0;
        } else {
            dqBoostDuration[_addr] -= timeElapsed;
        }

        // Update the user's last release time
        users[_addr].lastRelease = block.timestamp;

        // If the amount of VeBLOCKZ that can be claimed is greater than 0
        if (amount > 0) {
            // deposit the VeBLOCKZ to the user's account
            _depositVeBLOCKZ(_addr, amount);
            // mint new VeBLOCKZ tokens
            _mint(_addr, amount);
            emit ClaimedVeBLOCKZ(_addr, amount);
        }
    }

    function _depositVeBLOCKZ(address _user, uint256 _amount) internal {
        UserInfo memory user = users[_user];
        UserBlockzInfo memory userBlockzInfo = blockzUsers[_user];

        // Calculate the new balance after the deposit
        uint256 _previousAmount = balanceOf(_user);
        uint256 _newAmount = _previousAmount + _amount;

        // Update the reward variables
        _updateReward();
        _updateTokenReward();

        // Calculate the reward debt for the new balance
        uint256 _previousRewardDebt = user.rewardDebt;
        users[_user].rewardDebt = (_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;

        // Calculate the token reward debt for the new balance
        uint256 _previousTokenRewardDebt = user.tokenRewardDebt;
        users[_user].tokenRewardDebt = (_newAmount * accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION;

        // If the user had a non-zero balance before the deposit
        if (_previousAmount != 0) {
            // Calculate the pending reward for the previous balance
            uint256 _pending = ((_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - _previousRewardDebt;

            // If there is a pending reward, claim it
            if (_pending != 0) {
                emit ClaimReward(_user, _pending);
                _claimEarnings(_user, _pending);
            }

            // Calculate the pending token reward for the previous balance
            uint256 _pendingTokenReward = ((_previousAmount * accTokenPerShare) / ACC_TOKEN_REWARD_PRECISION) - _previousTokenRewardDebt;
            // If there is a pending token reward, claim it
            if (_pendingTokenReward != 0) {
                emit ClaimBlockzReward(_user, _pendingTokenReward);
                _claimTokenEarnings(_user, _pendingTokenReward);
            }
        }

        if (userBlockzInfo.amount > 0) {
            // Calculate the reward debt for the new balance
            uint256 _previousBlockzRewardDebt = userBlockzInfo.rewardDebt;
            uint256 currentBlockzRewardDebt = (userBlockzInfo.amount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;
            blockzUsers[_user].rewardDebt = currentBlockzRewardDebt;

            // Calculate the pending reward for the previous balance
            uint256 _pendingBlockzReward = currentBlockzRewardDebt - _previousBlockzRewardDebt;

            // If there is a pending reward, claim it
            if (_pendingBlockzReward != 0) {
                emit ClaimBlockzReward(_user, _pendingBlockzReward);
                _claimEarnings(_user, _pendingBlockzReward);
            }
        }

        emit Deposit(_user, _amount);
    }

    function depositBlockzs(uint256[] calldata _tokenIds) external payable nonReentrant whenNotPaused {
        uint256 len = _tokenIds.length;
        require(len <= 100, "exceeded the limits");
        require(balanceOf(msg.sender) * 10000 >= _totalSupply, "Insufficient power balance.");
        // ensures that the call is not made from a smart contract, unless it is on the whitelist.
        _assertNotContract(msg.sender);
        uint256 totalBlockzAmount;
        for (uint256 i; i < len; ++i) {
            uint256 blockzPower = blockzOperator.getBlockzPower(_tokenIds[i]);
            require(blockzPower > 0, "The provided NFT does not have blockz power");
            require(blockzCollection.ownerOf(_tokenIds[i]) == msg.sender, "The provided NFT does not belong to the sender");
            emit DepositBlockz(msg.sender, _tokenIds[i]);
            blockzCollection.transferFrom(msg.sender, address(this), _tokenIds[i]);
            blockzOwners[_tokenIds[i]] = msg.sender;
            totalBlockzAmount += blockzPower;
        }
        if (balanceOf(msg.sender) * 100 <= _totalSupply) {
            require(msg.value >= (depositBlockzFee * len), "Insufficient payment provided to deposit.");
        } else {
            uint256 precision = 100000;
            require(msg.value >= ((depositBlockzFee * len * precision) / ((100 * balanceOf(msg.sender) * precision) / _totalSupply)), "Insufficient payment provided to deposit.");
        }

        UserBlockzInfo memory userBlockzInfo = blockzUsers[msg.sender];
        UserInfo memory user = users[msg.sender];

        // Calculate the new balance after the deposit
        uint256 _previousAmount = userBlockzInfo.amount;
        uint256 _newAmount = _previousAmount + totalBlockzAmount;

        // Update the reward variables
        _updateReward();

        uint256 userVeBLOCKZBalance = balanceOf(msg.sender);
        uint256 currentRewardDebt = ((userVeBLOCKZBalance * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        uint256 _pending = currentRewardDebt - user.rewardDebt;
        users[msg.sender].rewardDebt = currentRewardDebt;

        if (_pending > 0) {
            emit ClaimReward(msg.sender, _pending);
            _claimEarnings(msg.sender, _pending);
        }


        // Calculate the reward debt for the new balance
        uint256 _previousBlockzRewardDebt = userBlockzInfo.rewardDebt;
        blockzUsers[msg.sender].rewardDebt = (_newAmount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;


        // If the user had a non-zero balance before the deposit
        if (_previousAmount != 0) {
            // Calculate the pending reward for the previous balance
            uint256 _pendingBlockzReward = ((_previousAmount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - _previousBlockzRewardDebt;

            // If there is a pending reward, claim it
            if (_pendingBlockzReward != 0) {
                emit ClaimBlockzReward(msg.sender, _pendingBlockzReward);
                _claimEarnings(msg.sender, _pendingBlockzReward);
            }
        }
        blockzUsers[msg.sender].amount += totalBlockzAmount;
        totalBlockzSupply += totalBlockzAmount;
    }

    function _withdrawBlockz(address _receiver, uint256[] memory _tokenIds) internal {
        uint256 len = _tokenIds.length;
        UserBlockzInfo memory userBlockzInfo = blockzUsers[_receiver];
        UserInfo memory user = users[_receiver];
        uint256 totalBlockzAmount;
        for (uint256 i; i < len; ++i) {
            uint256 blockzPower = blockzOperator.getBlockzPower(_tokenIds[i]);
            require(blockzPower > 0, "The provided NFT does not have blockz power");
            require(blockzOwners[_tokenIds[i]] == _receiver, "The provided NFT does not belong to the sender");
            emit WithdrawBlockz(_receiver, _tokenIds[i]);
            blockzCollection.transferFrom(address(this), _receiver, _tokenIds[i]);
            totalBlockzAmount += blockzPower;
            delete blockzOwners[_tokenIds[i]];
        }

        // Calculate the new balance after the deposit
        uint256 _previousAmount = userBlockzInfo.amount;
        uint256 _newAmount = _previousAmount - totalBlockzAmount;

        // Update the reward variables
        _updateReward();

        uint256 userVeBLOCKZBalance = balanceOf(_receiver);
        uint256 currentRewardDebt = ((userVeBLOCKZBalance * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        uint256 _pending = currentRewardDebt - user.rewardDebt;
        users[_receiver].rewardDebt = currentRewardDebt;

        if (_pending > 0) {
            emit ClaimReward(_receiver, _pending);
            _claimEarnings(_receiver, _pending);
        }

        uint256 _previousBlockzRewardDebt = userBlockzInfo.rewardDebt;
        blockzUsers[_receiver].rewardDebt = (_newAmount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION;

        uint256 _pendingBlockzReward = ((_previousAmount * accBlockzRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - _previousBlockzRewardDebt;

        // If there is a pending reward, claim it
        if (_pendingBlockzReward != 0) {
            emit ClaimBlockzReward(_receiver, _pendingBlockzReward);
            _claimEarnings(_receiver, _pendingBlockzReward);
        }

        blockzUsers[_receiver].amount -= totalBlockzAmount;
        totalBlockzSupply -= totalBlockzAmount;
    }

    /**
    * @notice Transfers a specified amount of Ethers from the contract to a user.
    * @dev If the specified amount is greater than the contract's Ether balance,
    * the remaining balance will be stored as failedBalance for the user, to be sent in future transactions.
    * @param _receiver The address of the recipient of the BLOCK tokens.
    * @param _amount The amount of Ethers to be transferred.
    */
    function _claimEarnings(address _receiver, uint256 _amount) internal {
        address payable to = payable(_receiver);

        // get the current balance of the reward contract
        uint256 _rewardBalance = address(this).balance;
        _amount += users[_receiver].failedBalance;

        // check if the amount to be claimed is greater than the reward balance
        if (_amount > _rewardBalance) {
            // if yes, deduct the entire reward balance from the lastRewardBalance and transfer it to the user
            lastRewardBalance -= _rewardBalance;

            users[_receiver].failedBalance = _amount - _rewardBalance;

            if (_rewardBalance > 0) {
                (bool success, ) = to.call{value: _rewardBalance}("");
                require(success, "claim earning is failed");
            }
        } else {
            // if not, deduct the amount to be claimed from the lastRewardBalance and transfer it to the user
            lastRewardBalance -= _amount;
            users[_receiver].failedBalance = 0;
            (bool success, ) = to.call{value: _amount}("");
            require(success, "claim earning is failed");
        }
    }

    /**
    * @notice Transfers a specified amount of BLOCK tokens from the contract to a user.
    * @dev If the specified amount is greater than the contract's BLOCK balance,
    * the remaining balance will be stored as failedTokenBalance for the user, to be sent in future transactions.
    * @param _receiver The address of the recipient of the BLOCK tokens.
    * @param _amount The amount of BLOCK tokens to be transferred.
    */
    function _claimTokenEarnings(address _receiver, uint256 _amount) internal {
        uint256 _totalBalance = blockzToken.balanceOf(address(this)) - totalStakedTokenAmount;
        _amount += users[_receiver].failedTokenBalance;
        if (_amount > _totalBalance) {
            users[_receiver].failedTokenBalance = _amount - _totalBalance;
            if (_totalBalance > 0) {
                blockzToken.safeTransfer(_receiver, _totalBalance);
            }
        } else {
            users[_receiver].failedTokenBalance = 0;
            blockzToken.safeTransfer(_receiver, _amount);
        }
    }

    /**
    * @notice This function asserts that the address provided in the parameter is not a smart contract. 
    * If it is a smart contract, it verifies that it is included in the list of approved platforms.
    * @param _addr the address to be checked
    */
    function _assertNotContract(address _addr) private view {
        if (_addr != tx.origin) {
            require(_whitelistedPlatforms.contains(_addr), 'Error: Unauthorized smart contract access');
        }
    }



    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
	function _mint(address account, uint256 amount) internal {
		require(account != address(0), "ERC20: mint to the zero address");

		_beforeTokenTransfer(address(0), account, amount);

		_totalSupply += amount;
		_balances[account] += amount;
		emit Mint(account, amount);

		_afterTokenOperation(account, _balances[account]);
	}

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
	function _burn(address account, uint256 amount) internal {
		require(account != address(0), "ERC20: burn from the zero address");

		_beforeTokenTransfer(account, address(0), amount);

		uint256 accountBalance = _balances[account];
		require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
		unchecked {
			_balances[account] = accountBalance - amount;
		}
		_totalSupply -= amount;

		emit Burn(account, amount);

		_afterTokenOperation(account, _balances[account]);
	}

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
	function _beforeTokenTransfer(address from, address to, uint256 amount) internal {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
	function _afterTokenOperation(address account, uint256 newBalance) internal {}

    /**
    * performs a rounded multiplication of two uint256 values `x` and `y` 
    * by first multiplying them and then adding `WAD / 2` to the result before dividing by `WAD`.
    * The `WAD` constant is used as a divisor to control the precision of the result. 
    * The final result is rounded to the nearest integer towards zero,
    * if the result is exactly halfway between two integers it will be rounded to the nearest integer towards zero.
    */
    function _wmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return ((x * y) + (WAD / 2)) / WAD;
    }
}