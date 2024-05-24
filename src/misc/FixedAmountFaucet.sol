// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FixedAmountFaucet is ReentrancyGuard {
    address token;
    uint256 amount;

    constructor(address _token, uint256 _amount) {
        token = _token;
        amount = _amount;
    }

    function drop() external nonReentrant {
        IERC20(token).transfer(msg.sender, amount);
    }

    function balance() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
