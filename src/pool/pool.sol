// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    error Not_Manager();

    address private immutable i_manager;
    address private immutable i_token;

    constructor(
        string memory name,
        string memory symbol,
        address _token,
        address _manager
    ) ERC20(name, symbol) {
        i_manager = _manager;
        i_token = _token;
    }

    modifier onlyManager() {
        if (msg.sender != i_manager) revert Not_Manager();
        _;
    }

    /**
     * @dev Mints the given amount of lp tokens to the given address
     */

    function mint(address to, uint256 amount) external onlyManager {
        _mint(to, amount);
    }

    /**
     * @dev Burns the given amount of lp tokens from the given address
     */

    function burn(address from, uint256 amount) external onlyManager {
        _burn(from, amount);
    }

    /**
     * @dev Transfers the given amount of tokens to the given address
     */

    function transferTokens(uint256 amount, address to) external onlyManager {
        ERC20(i_token).transfer(to, amount);
    }

    /**
     * @dev Returns the manager address
     */

    function getManager() public view returns (address) {
        return i_manager;
    }
}
