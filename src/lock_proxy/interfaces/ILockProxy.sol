// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILockProxy {
    function bridgeProxy() external view returns (address);

    function lock(
        address fromAssetHash,
        uint16 toChainId,
        bytes calldata toAddress,
        uint256 amount
    ) external payable returns (bool);
}
