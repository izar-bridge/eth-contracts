// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/core/BridgeData.sol";
import "../src/core/BridgeProxy.sol";
import "../src/core/BridgeLogic.sol";
import "../src/lock_proxy/LockProxyV1.sol";
import "../src/wrapper/WrapperV1.sol";

contract DeployAll is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BridgeProxy proxy = new BridgeProxy();

        uint16 ethChainID = 4;
        uint16 aleoChainID = 2;
        address[] memory keepers = new address[](2);
        keepers[0] = 0xffeE66e54107E16Ea5bBe3230c7BcCFcAeE03346;
        keepers[1] = 0xaF7B5837d93B5eD134BeA022378b8eB8e20452d0;
        BridgeData data = new BridgeData(ethChainID, address(proxy), keepers);

        BridgeLogic logic = new BridgeLogic(address(proxy), address(data));
        proxy.setData(address(data));
        proxy.upgradeLogic(address(logic));

        LockProxyV1 lockProxy = new LockProxyV1();
        lockProxy.setBridgeProxy(address(proxy));
        lockProxy.bindProxyHash(aleoChainID, "zkETH.zksync");
        lockProxy.bindAssetHash(
            address(0x0000000000000000000000000000000000000000),
            aleoChainID,
            "zkETH.zksync"
        );

        data.addWhiteListFrom(address(lockProxy));
        data.addWhiteListTo(address(lockProxy));

        WrapperV1 wrapper = new WrapperV1(
            vm.addr(deployerPrivateKey),
            vm.addr(deployerPrivateKey),
            ethChainID
        );
        wrapper.setLockProxy(address(lockProxy));

        vm.stopBroadcast();
    }
}
