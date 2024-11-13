// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../pool/pool.sol";
import {PoolManager} from "../pool/poolManager.sol";
import {HarborDAO} from "../governance/HarborDAO.sol";

contract HarborFactory {
    event NewHarbor(address harborAddress, string name, string symbol);

    uint256 private poolCount;
    address private daoAddr;
    mapping(uint256 => address) private pools;

    constructor() {
        poolCount = 0;
        HarborDAO dao = new HarborDAO(address(this));
        daoAddr = address(dao);
    }

    /**
     * @dev Creates a new pool with the given token address and returns the pool and pool manager
     */

    function createNewPool(
        address tokenAddr
    ) public returns (Pool, PoolManager) {
        string memory name = string(abi.encodePacked("Harbor ", poolCount));
        string memory symbol = string(abi.encodePacked("HBR", poolCount));

        PoolManager manager = new PoolManager(
            msg.sender,
            tokenAddr,
            poolCount,
            address(this)
        );
        Pool pool = new Pool(name, symbol, tokenAddr, address(manager));

        pools[poolCount] = address(pool);
        poolCount++;

        return (pool, manager);
    }

    /**
     * @dev Returns the pool address mapped to the given poolId
     */

    function getPool(uint256 poolId) public view returns (address) {
        return pools[poolId];
    }

    /**
     * @dev Returns the DAO address
     */

    function getDAO() public view returns (address) {
        return daoAddr;
    }
}
