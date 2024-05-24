// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/misc/MintAllERC20.sol";

contract DeployMintAllERC20 is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new MintAllERC20(vm.envString("ERC20_NAME"), vm.envString("ERC20_SYMBOL"), vm.envUint("ERC20_TOTAL"));
        vm.stopBroadcast();
    }
}
