// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}
