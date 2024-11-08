// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract PoolManager {
    mapping(address => bool) private s_managers;
    address private immutable i_pool;
    address private immutable i_token;
    uint256 private immutable i_poolId;

    constructor(
        address pool,
        address manager,
        address tokenAddr,
        uint256 poolId
    ) {
        i_pool = pool;
        s_managers[manager] = true;
        i_token = tokenAddr;
        i_poolId = poolId;
    }
}
