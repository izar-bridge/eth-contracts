// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../core/interfaces/IBridgeProxy.sol";
import "../core/interfaces/IBridgeLogic.sol";
import "../libs/ZeroCopySink.sol";
import "../libs/ZeroCopySource.sol";
import "../libs/Utils.sol";
import "./interfaces/ILockProxy.sol";

// import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract LockProxyV1 is Ownable, Pausable, ILockProxy {
    using SafeERC20 for IERC20;

    struct TxArgs {
        bytes toAssetHash;
        bytes toAddress;
        uint256 amount;
    }

    address public bridgeProxy;
    mapping(address => mapping(uint64 => bytes)) public assetHashMap;
    mapping(uint64 => bytes) public proxyHashMap;

    event SetBridgeProxyEvent(address bridgeProxy);
    event LockEvent(
        address fromAssetHash,
        address fromAddress,
        uint64 toChainId,
        bytes toAssetHash,
        bytes toAddress,
        uint256 amount
    );
    event UnlockEvent(address toAssetHash, address toAddress, uint256 amount);
    event BindProxyEvent(uint64 toChainId, bytes targetProxyHash);
    event BindAssetEvent(
        address fromAssetHash,
        uint64 toChainId,
        bytes targetProxyHash,
        uint initialAmount
    );

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    modifier onlyBridgeProxy() {
        require(_msgSender() == bridgeProxy, "msg.sender is not bridgeProxy");
        _;
    }

    function setBridgeProxy(address _bridgeProxy) public onlyOwner {
        bridgeProxy = _bridgeProxy;
        emit SetBridgeProxyEvent(_bridgeProxy);
    }

    function lock(
        address fromAssetHash,
        uint16 toChainId,
        bytes memory toAddress,
        uint256 amount
    ) public payable returns (bool) {
        require(amount != 0, "!amount");

        require(
            _transferToContract(fromAssetHash, amount),
            "!_transferToContract"
        );

        bytes memory toAssetHash = assetHashMap[fromAssetHash][toChainId];
        require(toAssetHash.length != 0, "!toAssetHash");

        TxArgs memory txArgs = TxArgs({
            toAssetHash: toAssetHash,
            toAddress: toAddress,
            amount: amount
        });
        bytes memory txData = _serializeTxArgs(txArgs);

        IBridgeLogic logic = IBridgeLogic(IBridgeProxy(bridgeProxy).logic());

        bytes memory toProxyHash = proxyHashMap[toChainId];
        require(toProxyHash.length != 0, "!toProxyHash");
        logic.send(toChainId, toProxyHash, txData);

        emit LockEvent(
            fromAssetHash,
            _msgSender(),
            toChainId,
            toAssetHash,
            toAddress,
            amount
        );

        return true;
    }

    function onReceive(
        uint16 /*_srcChainID*/,
        bytes calldata _srcAddress,
        uint256 /*_nonce*/,
        bytes calldata _payload
    ) external onlyBridgeProxy returns (bool) {
        require(
            _srcAddress.length != 0,
            "from proxy contract address cannot be empty"
        );

        TxArgs memory args = _deserializeTxArgs(_payload);

        require(args.toAssetHash.length != 0, "toAssetHash cannot be empty");
        address toAssetHash = Utils.bytesToAddress(args.toAssetHash);

        require(args.toAddress.length != 0, "toAddress cannot be empty");
        address toAddress = Utils.bytesToAddress(args.toAddress);

        require(
            _transferFromContract(toAssetHash, toAddress, args.amount),
            "transfer asset from lock_proxy contract to toAddress failed!"
        );

        emit UnlockEvent(toAssetHash, toAddress, args.amount);
        return true;
    }

    function bindProxyHash(
        uint64 toChainId,
        bytes memory targetProxyHash
    ) public onlyOwner returns (bool) {
        proxyHashMap[toChainId] = targetProxyHash;
        emit BindProxyEvent(toChainId, targetProxyHash);
        return true;
    }

    function bindAssetHash(
        address fromAssetHash,
        uint64 toChainId,
        bytes memory toAssetHash
    ) public onlyOwner returns (bool) {
        assetHashMap[fromAssetHash][toChainId] = toAssetHash;
        emit BindAssetEvent(
            fromAssetHash,
            toChainId,
            toAssetHash,
            getBalanceFor(fromAssetHash)
        );
        return true;
    }

    function getBalanceFor(
        address fromAssetHash
    ) public view returns (uint256) {
        if (fromAssetHash == address(0)) {
            // return address(this).balance; // this expression would result in error: Failed to decode output: Error: insufficient data for uint256 type
            address selfAddr = address(this);
            return selfAddr.balance;
        } else {
            IERC20 erc20Token = IERC20(fromAssetHash);
            return erc20Token.balanceOf(address(this));
        }
    }

    function _transferFromContract(
        address toAssetHash,
        address toAddress,
        uint256 amount
    ) internal returns (bool) {
        if (
            toAssetHash == address(0x0000000000000000000000000000000000000000)
        ) {
            // toAssetHash === address(0) denotes contract needs to unlock ether to toAddress
            // convert toAddress from 'address' type to 'address payable' type, then actively transfer ether
            payable(address(uint160(toAddress))).transfer(amount);
        } else {
            // actively transfer amount of asset from lock_proxy contract to toAddress
            require(
                _transferERC20FromContract(toAssetHash, toAddress, amount),
                "transfer erc20 asset from lock_proxy contract to toAddress failed!"
            );
        }
        return true;
    }

    function _transferToContract(
        address fromAssetHash,
        uint256 amount
    ) internal returns (bool) {
        if (fromAssetHash == address(0)) {
            // fromAssetHash === address(0) denotes user choose to lock ether
            // passively check if the received msg.value equals amount
            require(msg.value != 0, "transferred ether cannot be zero!");
            require(
                msg.value == amount,
                "transferred ether is not equal to amount!"
            );
        } else {
            // make sure lockproxy contract will decline any received ether
            require(msg.value == 0, "there should be no ether transfer!");
            // actively transfer amount of asset from msg.sender to lock_proxy contract
            require(
                _transferERC20ToContract(
                    fromAssetHash,
                    _msgSender(),
                    address(this),
                    amount
                ),
                "transfer erc20 asset to lock_proxy contract failed!"
            );
        }
        return true;
    }

    function _transferERC20FromContract(
        address toAssetHash,
        address toAddress,
        uint256 amount
    ) internal returns (bool) {
        IERC20 erc20Token = IERC20(toAssetHash);
        //  require(erc20Token.transfer(toAddress, amount), "trasnfer ERC20 Token failed!");
        erc20Token.safeTransfer(toAddress, amount);
        return true;
    }

    function _transferERC20ToContract(
        address fromAssetHash,
        address fromAddress,
        address toAddress,
        uint256 amount
    ) internal returns (bool) {
        IERC20 erc20Token = IERC20(fromAssetHash);
        //  require(erc20Token.transferFrom(fromAddress, toAddress, amount), "trasnfer ERC20 Token failed!");
        erc20Token.safeTransferFrom(fromAddress, toAddress, amount);
        return true;
    }

    function _serializeTxArgs(
        TxArgs memory args
    ) internal pure returns (bytes memory) {
        bytes memory buff;
        buff = abi.encodePacked(
            ZeroCopySink.WriteVarBytes(args.toAssetHash),
            ZeroCopySink.WriteVarBytes(args.toAddress),
            ZeroCopySink.WriteUint255(args.amount)
        );
        return buff;
    }

    function _deserializeTxArgs(
        bytes memory valueBs
    ) internal pure returns (TxArgs memory) {
        TxArgs memory args;
        uint256 off = 0;
        (args.toAssetHash, off) = ZeroCopySource.NextVarBytes(valueBs, off);
        (args.toAddress, off) = ZeroCopySource.NextVarBytes(valueBs, off);
        (args.amount, off) = ZeroCopySource.NextUint255(valueBs, off);
        return args;
    }
}
