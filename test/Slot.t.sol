// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract SlotTest is Test {
    uint64 public sequenceNumber;
    uint32 public blobBaseFeeScalar;
    uint32 public baseFeeScalar;

    function setUp() public {}

    function testSlot() public {
        uint v = 123 | (456 << 64) | (789 << 96);
        assembly {
            sstore(sequenceNumber.slot, v)
        }

        // The first item in a storage slot is stored lower-order aligned.
        assertEq(sequenceNumber, 123);
        assertEq(blobBaseFeeScalar, 456);
        assertEq(baseFeeScalar, 789);
    }
}
