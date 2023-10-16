// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract SignatureDecoder {
    // 把签名解码为`uint8 v, bytes32 r, bytes32 s`。签名使用的是{bytes32 r}{bytes32 s}{uint8 v}的紧凑编码，所以uint8并没有填充到32个字节。
    function signatureSplit(bytes memory signatures, uint256 pos) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            // 数据是大端存储的，从0x41开始读取低位数据，往前读32个字节取出，从而会读取到s的部分数据。
            // 所以需要和0xff与，与1 and的部分将不变，从而保留了最后一个字节v。
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }
}
