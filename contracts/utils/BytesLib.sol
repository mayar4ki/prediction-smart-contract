// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

library BytesLib {
    function bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
}
