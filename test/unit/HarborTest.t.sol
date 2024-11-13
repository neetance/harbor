// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HarborFactory} from "../../src/factory/harborFactory.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {Pool} from "../../src/pool/pool.sol";
import {PoolManager} from "../../src/pool/poolManager.sol";
import {HarborDAO} from "../../src/governance/HarborDAO.sol";
import {Governor} from "../../src/governance/Governor.sol";
import {DeployHarbor} from "../../script/DeployHarbor.s.sol";
import {console} from "forge-std/console.sol";

contract HarborTest is Test {
    HarborFactory factory;
    MockToken token;
    HarborDAO dao;
    DeployHarbor deployer;

    function setUp() external {
        deployer = new DeployHarbor();
        (factory, token) = deployer.run();
        dao = HarborDAO(factory.getDAO());
    }

    //Helper functions

    function createPool() internal returns (Pool, PoolManager, address) {
        address fundManager = address(20);
        vm.prank(fundManager);
        (Pool pool, PoolManager manager) = factory.createNewPool(
            address(token)
        );
        return (pool, manager, fundManager);
    }

    function addLiquidity(
        PoolManager manager
    ) internal returns (address[] memory) {
        address[] memory LPs = new address[](5);
        for (uint256 i = 10; i < 15; i++) {
            address lp = address(uint160(i));
            token.mint(lp, 150);
            vm.startPrank(lp);
            token.approve(address(manager), 125);
            manager.addLiquidity(125);
            vm.stopPrank();
            LPs[i - 10] = lp;
        }

        return LPs;
    }

    //Tests

    function testCreatingNewPool() external {
        (Pool pool, PoolManager manager, address fm) = createPool();

        assertEq(pool.totalSupply(), 0);
        assertEq(factory.getPool(0), address(pool));
        assertEq(pool.getManager(), address(manager));
        assertEq(manager.isManager(fm), true);
        assertEq(uint256(manager.getTier(fm)), 0);
    }

    function testAddingLiquidity() external {
        (Pool pool, PoolManager manager, ) = createPool();
        address[] memory LPs = addLiquidity(manager);

        assertEq(pool.totalSupply(), 625);
        assertEq(token.balanceOf(address(pool)), 625);
        assertEq(pool.balanceOf(LPs[0]), 125);
        assertEq(token.balanceOf(LPs[0]), 25);
    }
}
