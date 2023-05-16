// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Utils {
    function bytesToBytes32(
        bytes memory _bs
    ) internal pure returns (bytes32 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            // load 32 bytes from memory starting from position _bs + 0x20 since the first 0x20 bytes stores _bs length
            value := mload(add(_bs, 0x20))
        }
    }

    function bytesToAddress(
        bytes memory _bs
    ) internal pure returns (address addr) {
        require(_bs.length == 20, "bytes length does not match address");
        assembly {
            // for _bs, first word store _bs.length, second word store _bs.value
            // load 32 bytes from mem[_bs+20], convert it into Uint160, meaning we take last 20 bytes as addr (address).
            addr := mload(add(_bs, 0x14)) // data within slot is lower-order aligned: https://stackoverflow.com/questions/66819732/state-variables-in-storage-lower-order-aligned-what-does-this-sentence-in-the
        }
    }

    function addressToBytes(
        address _addr
    ) internal pure returns (bytes memory bs) {
        assembly {
            bs := mload(0x40)
            mstore(bs, 0x14)
            mstore(add(bs, 0x20), shl(96, _addr))
            mstore(0x40, add(bs, 0x40))
        }
    }

    function sliceToBytes32(
        bytes memory _bytes,
        uint256 _start
    ) internal pure returns (bytes32 result) {
        require(_bytes.length >= (_start + 32));
        assembly {
            result := mload(add(add(_bytes, 0x20), _start))
        }
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory tempBytes) {
        require(_bytes.length >= (_start + _length));

        assembly {
            switch iszero(_length)
            case 0 {
                tempBytes := mload(0x40)

                let lengthmod := and(_length, 31)
                let iz := iszero(lengthmod)

                let mc := add(add(tempBytes, lengthmod), mul(0x20, iz))
                let end := add(mc, _length)

                for {
                    let cc := add(
                        add(add(_bytes, lengthmod), mul(0x20, iz)),
                        _start
                    )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }
                mstore(tempBytes, _length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }
    }

    function bytesToUint256(
        bytes memory _bs
    ) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            value := mload(add(_bs, 0x20))
        }
    }

    function uint256ToBytes(
        uint256 _value
    ) internal pure returns (bytes memory bs) {
        assembly {
            bs := mload(0x40)
            mstore(bs, 0x20)
            mstore(add(bs, 0x20), _value)

            mstore(0x40, add(bs, 0x40))
        }
    }

    function containMAddresses(
        address[] memory _keepers,
        address[] memory _signers,
        uint256 _m
    ) internal pure returns (bool) {
        uint256 m = 0;
        for (uint256 i = 0; i < _signers.length; i++) {
            for (uint256 j = 0; j < _keepers.length; j++) {
                if (_signers[i] == _keepers[j]) {
                    m++;
                    if (j < _keepers.length) {
                        _keepers[j] = _keepers[_keepers.length - 1];
                    }
                    assembly {
                        mstore(_keepers, sub(mload(_keepers), 1))
                    }
                    break;
                }
            }
        }

        return m >= _m;
    }

    uint256 constant SIGNATURE_LEN = 65;

    function verifySigs(
        bytes32 hash,
        bytes memory _sigs,
        address[] memory _keepers,
        uint256 _m
    ) internal pure returns (bool) {
        uint256 sigCount = _sigs.length / SIGNATURE_LEN;
        address[] memory signers = new address[](sigCount);
        bytes32 r;
        bytes32 s;
        uint8 v;
        for (uint256 i = 0; i < sigCount; i++) {
            r = sliceToBytes32(_sigs, i * SIGNATURE_LEN);
            s = sliceToBytes32(_sigs, i * SIGNATURE_LEN + 32);
            v = uint8(_sigs[i * SIGNATURE_LEN + 64]);
            signers[i] = ecrecover(hash, v, r, s);
            if (signers[i] == address(0)) {
                return false;
            }
        }

        return containMAddresses(_keepers, signers, _m);
    }

    function dedupAddress(
        address[] memory _dup
    ) internal pure returns (address[] memory) {
        address[] memory dedup = new address[](_dup.length);
        uint256 idx = 0;
        bool dup;
        for (uint256 i = 0; i < _dup.length; i++) {
            dup = false;
            for (uint256 j = 0; j < dedup.length; j++) {
                if (_dup[i] == dedup[j]) {
                    dup = true;
                    break;
                }
            }
            if (!dup) {
                dedup[idx] = _dup[i];
                idx += 1;
            }
        }
        assembly {
            mstore(dedup, idx)
        }

        return dedup;
    }

    function equalStorage(
        bytes storage _preBytes,
        bytes memory _postBytes
    ) internal view returns (bool) {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes.slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(
                and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)),
                2
            )
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // fslot can contain both the length and contents of the array
                // if slength < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                // slength != 0
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes.slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint(mc < end) + cb == 2)
                        for {

                        } eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }
}
