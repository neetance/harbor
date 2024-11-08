// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/pool.sol";
import {PoolManager} from "../pool/poolManager.sol";

contract HarborFactory {
    event NewHarbor(address harborAddress, string name, string symbol);

    uint256 private poolCount;
    mapping(uint256 => address) private pools;

    constructor() {
        poolCount = 0;
    }

    function createNewPool(
        address tokenAddr
    ) public returns (Pool, PoolManager) {
        string memory name = string(abi.encodePacked("Harbor ", poolCount));
        string memory symbol = string(abi.encodePacked("HBR", poolCount));

        Pool pool = new Pool(name, symbol);
        PoolManager manager = new PoolManager(
            address(pool),
            msg.sender,
            tokenAddr,
            poolCount
        );

        pools[poolCount] = address(pool);
        poolCount++;

        return (pool, manager);
    }
}
