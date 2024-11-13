// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HarborFactory} from "../src/factory/harborFactory.sol";
import {MockToken} from "../test/mocks/MockToken.sol";

contract DeployHarbor is Script {
    function run() external returns (HarborFactory, MockToken) {
        vm.startBroadcast();
        HarborFactory factory = new HarborFactory();
        MockToken token = new MockToken();
        vm.stopBroadcast();

        return (factory, token);
    }
}
