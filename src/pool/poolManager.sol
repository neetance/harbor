// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pool} from "./pool.sol";
import {HarborFactory} from "../factory/harborFactory.sol";

contract PoolManager {
    error Insufficient_Balance();
    error Not_Manager();
    error Withdrawal_Amount_Exceeds_Limit();

    event LiquidityAdded(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed fundManager, uint256 amount);

    enum Tier {
        T1,
        T2,
        T3
    }

    mapping(address => bool) private s_managers;
    mapping(address => Tier) private s_tiers;
    mapping(Tier => uint256) private s_allowances; //determines the maximum percentage of the total liquidity that a fund manager is allowed to withdraw based on their tier

    address private immutable i_token;
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
    }

    modifier onlyFundManager(address caller) {
        if (!s_managers[caller]) revert Not_Manager();
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
     *
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
        uint256 amountToTransfer = (amount * getTotalLiquidity()) /
            pool.totalSupply();

        pool.withdrawLiquidity(amountToTransfer, msg.sender);
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

        Pool pool = Pool(i_factory.getPool(i_poolId));
        pool.withdrawLiquidity(amount, msg.sender);

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev returns the total liquidity in the pool
     */

    function getTotalLiquidity() public view returns (uint256) {
        Pool pool = Pool(i_factory.getPool(i_poolId));
        return ERC20(i_token).balanceOf(address(pool));
    }

    function getWithdrawalLimit(Tier tier) public view returns (uint256) {
        uint256 totalLiquidity = getTotalLiquidity();
        uint256 allowancePerc = s_allowances[tier];

        uint256 withdrawalLimit = (allowancePerc * totalLiquidity) / 100;
        return withdrawalLimit;
    }
}
