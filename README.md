# eth contracts for izar bridge

The contracts can be divided into three layers:
1. [`src/core`](https://github.com/izar-bridge/eth-contracts/tree/main/src/core) contains the core logic of bridge, which supports arbitrary message passing between blockchains.
2. [`src/lock_proxy`](https://github.com/izar-bridge/eth-contracts/tree/main/src/lock_proxy) is layered on top of [`src/core`](https://github.com/izar-bridge/eth-contracts/tree/main/src/core) to implement asset bridging protocol.
3. [`src/wrapper`](https://github.com/izar-bridge/eth-contracts/tree/main/src/wrapper) is layered on top of [`src/lock_proxy`](https://github.com/izar-bridge/eth-contracts/tree/main/src/lock_proxy) to deduct fees from users using the bridge.

# workflow

1. The initiating tx(ethereum -> aleo) will call [`WrapperV1.lock`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/wrapper/WrapperV1.sol#L73), which after deducting fees calls [`LockProxyV1.lock`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/lock_proxy/LockProxyV1.sol#L61), which after locking the asset calls [`BridgeLogic.send`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/core/BridgeLogic.sol#L20).
2. The withdrawing tx(aleo -> ethereum) will call [`BridgeLogic.receivePayload`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/core/BridgeLogic.sol#L38), which after verifying signatures of keepers calls [`BridgeProxy.receivePayloadFromLogic`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/core/BridgeProxy.sol#L52), which then calls [`LockProxyV1.onReceive`](https://github.com/izar-bridge/eth-contracts/blob/f73a7c877bef580d8b15fd9100ec9c27305c7545/src/lock_proxy/LockProxyV1.sol#L102) to finally withdraw the locked asset.


# linea contract address
- BridgeProxy:		0xd73E1Accb6a22751FC0F6478c79bE83e9E544ac9
- BridgeData:		0x4afA839C8569220b80109634Ce2F2895e4c13943
- BridgeLogic:		0x654dDC5c45C59be6C2699DbCbAd0fA5Bd16F6eC0
- LockProxyV1:		0xd06Bcb4556f71cB3035891362A7e3d90e431551a
- WrapperV1:		0x26f8603fC1Da7D164c3fd353c816c3215Ef807a9
