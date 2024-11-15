// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pool} from "./pool.sol";
import {HarborFactory} from "../factory/harborFactory.sol";
import {Governor} from "../governance/Governor.sol";

contract PoolManager {
    error Insufficient_Balance();
    error Not_Manager();
    error Withdrawal_Amount_Exceeds_Limit();
    error Forbidden_Caller();

    event LiquidityAdded(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed fundManager, uint256 amount);
    event FundsReturned(address indexed fundManager, uint256 amount);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event TierSet(address indexed manager, Tier indexed tier);
    event RewardPercentageSet(uint256 percentage);
    event AllowanceSet(Tier indexed tier, uint256 allowance);

    enum Tier {
        T1,
        T2,
        T3
    }

    mapping(address => bool) private s_managers;
    mapping(address => uint256) private s_owing;
    mapping(address => Tier) private s_tiers;
    mapping(Tier => uint256) private s_allowances; //determines the maximum percentage of the total liquidity that a fund manager is allowed to withdraw based on their tier
    mapping(Tier => uint256) private s_maxAllowances;
    mapping(Tier => uint256) private s_minAllowances;

    uint256 public constant MAX_REWARD_PERCENTAGE = 25;
    uint256 public constant MIN_REWARD_PERCENTAGE = 15;

    uint256 private s_rewardPercentage = 20;

    address private immutable i_token;
    address private immutable i_governor;
    uint256 private immutable i_poolId;
    HarborFactory private immutable i_factory;

    constructor(
        address manager,
        address tokenAddr,
        uint256 poolId,
        address factoryAddr
    ) {
        s_managers[manager] = true;
        s_tiers[manager] = Tier.T1;
        i_token = tokenAddr;
        i_poolId = poolId;
        i_factory = HarborFactory(factoryAddr);

        s_allowances[Tier.T1] = 8;
        s_allowances[Tier.T2] = 15;
        s_allowances[Tier.T3] = 25;

        s_maxAllowances[Tier.T1] = 10;
        s_maxAllowances[Tier.T2] = 20;
        s_maxAllowances[Tier.T3] = 30;

        s_minAllowances[Tier.T1] = 5;
        s_minAllowances[Tier.T2] = 11;
        s_minAllowances[Tier.T3] = 21;

        Governor governor = new Governor(poolId, factoryAddr, address(this));
        i_governor = address(governor);
    }

    modifier onlyFundManager(address caller) {
        if (!s_managers[caller]) revert Not_Manager();
        _;
    }

    modifier onlyGov(address caller) {
        if (caller != i_governor) revert Forbidden_Caller();
        _;
    }

    /**
     * @dev Adds 'amount' amount of tokens as liquidity to the pool
     * NOTE The user must approve the pool manager contract to spend the tokens before calling this function
     */

    function addLiquidity(uint256 amount) public {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        ERC20(i_token).transferFrom(msg.sender, address(pool), amount);
        pool.mint(msg.sender, amount);

        emit LiquidityAdded(msg.sender, amount);
    }

    /**
     * @dev Burns 'amount' amount of lp tokens from the user's account, calculates the amount of tokens to be
     *      transferred to the users based on the current liquidity and total supply and then returns them back
     *      to the user
     * NOTE Reverts if users try to withdraw more than their current lp token balance
     */

    function withdrawLiquidity(uint256 amount) public {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        uint256 balance = pool.balanceOf(msg.sender);

        if (balance < amount) revert Insufficient_Balance();

        pool.burn(msg.sender, amount);
        uint256 amountToTransfer = amount * getPriceOfLPToken();

        pool.transferTokens(amountToTransfer, msg.sender);
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Lets a fund manager withdraw 'amount' amount of tokens from the liquidity pool for investing
     * NOTE Reverts if the amount is higer than the manager's tier limt
     */

    function withdrawFunds(uint256 amount) public onlyFundManager(msg.sender) {
        Tier tier = s_tiers[msg.sender];
        uint256 maxAmount = getWithdrawalLimit(tier);

        if (amount > maxAmount) revert Withdrawal_Amount_Exceeds_Limit();

        s_owing[msg.sender] += amount;
        Pool pool = Pool(i_factory.getPool(i_poolId));
        pool.transferTokens(amount, msg.sender);

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Returns the funds borrowed by the fund manager to the pool. In case of profit, the fund manager's cut
     *      is calculated and transferred to the fund manager
     * NOTE The fund manager must approve the pool manager contract to spend the tokens before calling this function
     */

    function returnFunds(uint256 amount) public onlyFundManager(msg.sender) {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        uint256 owing = s_owing[msg.sender];

        if (amount > owing) {
            s_owing[msg.sender] = 0;
            uint256 profit = amount - owing;
            uint256 fundManagersCut = (profit * s_rewardPercentage) / 100;

            ERC20(i_token).transferFrom(msg.sender, address(pool), amount);
            pool.transferTokens(fundManagersCut, msg.sender);
        } else {
            s_owing[msg.sender] -= amount;
            ERC20(i_token).transferFrom(msg.sender, address(pool), amount);
        }

        emit FundsReturned(msg.sender, amount);
    }

    /**
     * @dev Adds a new fund manager to the pool manager contract
     * NOTE Only the governance contract can call this function
     */

    function addFundManager(address manager) external onlyGov(msg.sender) {
        s_managers[manager] = true;
        s_tiers[manager] = Tier.T1;
        emit ManagerAdded(manager);
    }

    /**
     * @dev Removes a fund manager from the pool manager contract
     * NOTE Only the governance contract can call this function
     */

    function removeFundManager(address manager) external onlyGov(msg.sender) {
        s_managers[manager] = false;
        emit ManagerRemoved(manager);
    }

    /**
     * @dev Changes the tier of a fund manager
     * NOTE Only the governance contract can call this function
     */

    function setTier(address manager, Tier tier) external onlyGov(msg.sender) {
        s_tiers[manager] = tier;
        emit TierSet(manager, tier);
    }

    /**
     * @dev Changes the reward percentage for the fund managers
     * NOTE Only the governance contract can call this function
     */

    function setRewardPercentage(
        uint256 percentage
    ) external onlyGov(msg.sender) {
        s_rewardPercentage = percentage;
        emit RewardPercentageSet(percentage);
    }

    /**
     * @dev Changes the allowance for a fund manager's tier
     * NOTE Only the governance contract can call this function
     */

    function setAllowance(
        Tier tier,
        uint256 allowance
    ) external onlyGov(msg.sender) {
        s_allowances[tier] = allowance;
        emit AllowanceSet(tier, allowance);
    }

    /**
     * @dev returns the total liquidity in the pool
     */

    function getTotalLiquidity() public view returns (uint256) {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        return ERC20(i_token).balanceOf(address(pool));
    }

    /**
     * @dev returns the max withdrawal limit based on the fund manager's tier
     */

    function getWithdrawalLimit(Tier tier) public view returns (uint256) {
        uint256 totalLiquidity = getTotalLiquidity();
        uint256 allowancePerc = s_allowances[tier];

        uint256 withdrawalLimit = (allowancePerc * totalLiquidity) / 100;
        return withdrawalLimit;
    }

    /**
     * @dev returns the reward percentage for the fund managers based on the tier
     */

    function getCurrentAllowance(Tier tier) public view returns (uint256) {
        return s_allowances[tier];
    }

    /**
     * @dev returns the max reward percentage for a perticular tier
     */

    function getMaxAllownace(Tier tier) public view returns (uint256) {
        return s_maxAllowances[tier];
    }

    /**
     * @dev returns the min reward percentage for a perticular tier
     */

    function getMinAllownace(Tier tier) public view returns (uint256) {
        return s_minAllowances[tier];
    }

    /**
     * @dev returns the reward percentage for the fund managers
     */

    function getRewardPercentage() public view returns (uint256) {
        return s_rewardPercentage;
    }

    /**
     * @dev returns true if the address is a fund manager, false otherwise
     */

    function isManager(address manager) public view returns (bool) {
        return s_managers[manager];
    }

    /**
     * @dev returns the tier of the fund manager
     */

    function getTier(address manager) public view returns (Tier) {
        if (!s_managers[manager]) revert Not_Manager();
        return s_tiers[manager];
    }

    /**
     * @dev returns the amount of tokens owed by the fund manager
     */

    function getAmountOwing(address manager) public view returns (uint256) {
        return s_owing[manager];
    }

    /**
     * @dev returns the address of the governance contract
     */

    function getGovAddr() public view returns (address) {
        return i_governor;
    }

    /**
     * @dev returns the address of the token contract
     */

    function getPriceOfLPToken() public view returns (uint256) {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        return (((getTotalLiquidity() * 1e18) / pool.totalSupply()));
    }
}
