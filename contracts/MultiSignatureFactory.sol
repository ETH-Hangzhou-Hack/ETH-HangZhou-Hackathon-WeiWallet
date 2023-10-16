// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./MultiSignatureWeight.sol";
import "./base/Register.sol";

/**
 * @title 多签合约工厂 - 通过此合约来部署创建新的多签钱包合约。
 * @notice 创建钱包的注册信息也是存储在本合约中。
 * @author 0xE
 */
contract MultiSignatureFactory is Register {
    /**
     * @notice 创建一个新的多签钱包合约实例事件。
     * @param instance 多签钱包合约实例地址
     * @param implemention 逻辑合约地址
     */
    event InstanceCreation(address indexed instance, address implemention);

    using Clones for address;

    /**
     * @notice 预测由本合约创建的多签钱包合约的地址。
     * @param _implemention 逻辑合约地址
     * @param salt 创建合约用到的盐。
     */
    function predictAddress(address _implemention, bytes32 salt) public view returns (address) {
        return _implemention.predictDeterministicAddress(salt);
    }
    
    /**
     * @notice 创建一个新的基于权重值的多签钱包合约。并在注册合约中存储本次创建的记录。
     * @param _implemention 基于权重值的多签逻辑合约。
     * @param _owners 多签初始成员列表。
     * @param _weight 多签初始权重值列表。
     * @param _weightThreshold 权重值的门限，即大于多少权重才能执行交易。
     * @param _saltNonce 可以是成员的nonce之和。
     */
    function createMSigWeight(
        address _implemention,
        address[] memory _owners,
        uint256[] memory _weight,
        uint256 _weightThreshold,
        uint256 _saltNonce
    ) public returns (address instance) {
        bytes32 salt = keccak256(abi.encodePacked(_owners, _weight, _saltNonce));
        instance = _implemention.cloneDeterministic(salt);
        IMultiSignatureWeight(instance).initialize(_owners, _weight, _weightThreshold);

        addWallet(msg.sender, instance);
        createWalletTime(instance, block.timestamp);
        createWalletSalt(instance, salt);

        emit InstanceCreation(instance, _implemention);
    }

    /**
     * @notice 返回当前部署合约的链ID。
     * @return 链ID类型为uint256。
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }
}