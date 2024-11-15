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
            token.mint(lp, 150e18);
            vm.startPrank(lp);
            token.approve(address(manager), 125e18);
            manager.addLiquidity(125e18);
            vm.stopPrank();
            LPs[i - 10] = lp;
        }
        //uint256 withdrawalLimit = manager.getWithdrawalLimit();

        return (LPs);
    }

    function withdrawFunds(
        PoolManager manager,
        address fm,
        uint256 amount
    ) internal returns (uint256) {
        uint256 totalLiquidity = manager.getTotalLiquidity();

        vm.prank(fm);
        manager.withdrawFunds(amount);

        return totalLiquidity;
    }

    function returnFunds(
        PoolManager manager,
        address fm,
        uint256 amountReturning
    ) internal {
        vm.startPrank(fm);
        token.approve(address(manager), amountReturning);
        manager.returnFunds(amountReturning);
        vm.stopPrank();
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

        assertEq(pool.totalSupply(), 625e18);
        assertEq(token.balanceOf(address(pool)), 625e18);
        assertEq(pool.balanceOf(LPs[0]), 125e18);
        assertEq(token.balanceOf(LPs[0]), 25e18);
    }

    function testWithdrawingFundsRevertsIfNotManager() external {
        (, PoolManager manager, ) = createPool();
        addLiquidity(manager);

        vm.expectRevert(PoolManager.Not_Manager.selector);
        vm.prank(address(51));
        manager.withdrawFunds(125);
    }

    function testWithdrawingFundsRevertsIfExceedsAllowance() external {
        (, PoolManager manager, address fm) = createPool();
        addLiquidity(manager);

        uint256 withdrawalLimit = manager.getWithdrawalLimit(
            manager.getTier(fm)
        );
        console.log("Withdrawal limit: ", withdrawalLimit);

        vm.expectRevert(PoolManager.Withdrawal_Amount_Exceeds_Limit.selector);
        vm.prank(fm);
        manager.withdrawFunds(withdrawalLimit + 1);
    }

    function testWithdrawingFunds() external {
        (Pool pool, PoolManager manager, address fm) = createPool();
        uint256 withdrawalLimit = manager.getWithdrawalLimit(
            manager.getTier(fm)
        );
        addLiquidity(manager);
        withdrawFunds(manager, fm, withdrawalLimit);

        assertEq(manager.getAmountOwing(fm), withdrawalLimit);
        assertEq(token.balanceOf(address(pool)), 625e18 - withdrawalLimit);
        assertEq(token.balanceOf(fm), withdrawalLimit);
        assertEq(manager.getTotalLiquidity(), 625e18 - withdrawalLimit);
    }

    function testReturningFunds() external {
        // In case of loss

        (Pool pool, PoolManager manager, address fm) = createPool();
        addLiquidity(manager);
        uint256 withdrawalLimit = manager.getWithdrawalLimit(
            manager.getTier(fm)
        );
        uint256 totalLiquidity = manager.getTotalLiquidity();

        uint256 amountToWithdraw = withdrawalLimit - 5e18;
        uint256 amountReturning = amountToWithdraw - 10e18;
        withdrawFunds(manager, fm, amountToWithdraw);
        returnFunds(manager, fm, amountReturning);

        uint256 loss = amountToWithdraw - amountReturning;
        assertEq(manager.getAmountOwing(fm), loss);
        assertEq(token.balanceOf(address(pool)), totalLiquidity - loss);
        console.log("Price of lp: ", manager.getPriceOfLPToken());
    }
}
