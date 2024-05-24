// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/misc/FixedAmountFaucet.sol";

contract DeployFixedAmountFaucet is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new FixedAmountFaucet(vm.envAddress("FAUCET_TOKEN"), vm.envUint("FAUCET_AMOUNT"));
        vm.stopBroadcast();
    }
}
