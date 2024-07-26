// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/lock_proxy/LockProxyV1.sol";

contract LockProxyTest is Test {
    address constant LockProxyAddr = 0x7c6445C8c805dB03D8C38fb6CD610072E329145B;

    function setUp() public {}

    function testOnReceive() public {
        uint256 fork = vm.createFork("https://rpc.sepolia.org/");
        vm.selectFork(fork);
        // vm.createSelectFork("https://rpc.sepolia.org/", 3540681);

        LockProxyV1 proxy = new LockProxyV1();
        vm.etch(LockProxyAddr, address(proxy).code);

        // bytes32 targetTx = 0xdb0a1b11753dae4f2e3ed91cb31902e3e157be1d84b92937f9ac009359a41849;
        // vm.transact(targetTx);
    }
}
