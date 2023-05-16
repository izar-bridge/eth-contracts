// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lock_proxy/interfaces/ILockProxy.sol";

contract WrapperV1 is Ownable, Pausable {
    using SafeERC20 for IERC20;

    uint public chainId;

    address public feeCollector;

    ILockProxy public lockProxy;

    event WrapperSpeedUp(
        address indexed fromAsset,
        bytes indexed txHash,
        address indexed sender,
        uint efee
    );
    event WrapperLock(
        address indexed fromAsset,
        address indexed sender,
        uint64 toChainId,
        bytes toAddress,
        uint net,
        uint fee
    );

    constructor(address _owner, address _collector, uint _chainId) {
        require(_owner != address(0) && _chainId != 0, "!legal");
        transferOwnership(_owner);
        chainId = _chainId;
        feeCollector = _collector;
    }

    function setFeeCollector(address _collector) external onlyOwner {
        require(_collector != address(0), "emtpy address");
        feeCollector = _collector;
    }

    function setLockProxy(address _lockProxy) external onlyOwner {
        require(_lockProxy != address(0));
        lockProxy = ILockProxy(_lockProxy);
        require(lockProxy.bridgeProxy() != address(0), "not lockproxy");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function extractFee(address token) external {
        require(msg.sender == feeCollector, "!feeCollector");
        if (token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IERC20(token).safeTransfer(
                feeCollector,
                IERC20(token).balanceOf(address(this))
            );
        }
    }

    function lock(
        address fromAsset,
        uint16 toChainId,
        bytes memory toAddress,
        uint amount,
        uint fee
    ) public payable whenNotPaused {
        require(toChainId != chainId && toChainId != 0, "!toChainId");
        require(toAddress.length != 0, "empty toAddress");
        address addr;
        assembly {
            addr := mload(add(toAddress, 0x14))
        }
        require(addr != address(0), "zero toAddress");

        _pull(fromAsset, amount);

        amount = _checkoutFee(fromAsset, amount, fee);

        _push(fromAsset, toChainId, toAddress, amount);

        emit WrapperLock(
            fromAsset,
            msg.sender,
            toChainId,
            toAddress,
            amount,
            fee
        );
    }

    function speedUp(
        address fromAsset,
        bytes memory txHash,
        uint fee
    ) public payable whenNotPaused {
        _pull(fromAsset, fee);
        emit WrapperSpeedUp(fromAsset, txHash, msg.sender, fee);
    }

    // take fee in the form of ether
    function _checkoutFee(
        address fromAsset,
        uint amount,
        uint fee
    ) internal view returns (uint) {
        if (fromAsset == address(0)) {
            require(msg.value >= amount, "insufficient ether");
            require(amount > fee, "amount less than fee");
            return amount - fee;
        } else {
            require(msg.value >= fee, "insufficient ether");
            return amount;
        }
    }

    function _pull(address fromAsset, uint amount) internal {
        if (fromAsset == address(0)) {
            require(msg.value == amount, "insufficient ether");
        } else {
            IERC20(fromAsset).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
    }

    function _push(
        address fromAsset,
        uint16 toChainId,
        bytes memory toAddress,
        uint amount
    ) internal {
        if (fromAsset == address(0)) {
            require(
                lockProxy.lock{value: amount}(
                    fromAsset,
                    toChainId,
                    toAddress,
                    amount
                ),
                "lock ether fail"
            );
        } else {
            IERC20(fromAsset).safeIncreaseAllowance(address(lockProxy), amount);
            require(
                lockProxy.lock(fromAsset, toChainId, toAddress, amount),
                "lock erc20 fail"
            );
        }
    }
}
