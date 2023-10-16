// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./base/OwnerManagerWeight.sol";
import "./base/SignatureDecoder.sol";

interface IMultiSignatureWeight {
	function initialize(address[] memory _owners, uint256[] memory _weight, uint256 _weightThreshold) payable external;
}

/**
 * @title 基于权重值的多签
 * @author 0xE
 * @notice 支持ERC712的多签，本合约作为逻辑合约。
 */
contract MultiSignatureWeight is ReentrancyGuardUpgradeable, EIP712Upgradeable, OwnerManagerWeight, SignatureDecoder {
    using SafeERC20Upgradeable for IERC20Upgradeable;

	uint256 public nonce;

	bytes32 public constant ADD_OWNER_HASH =
		keccak256('AddOwner(address owner,address[] owners,uint256[] weights,uint256 nonce)');

	bytes32 public constant REMOVE_OWNER_HASH = 
		keccak256('RemoveOwner(address owner,address[] owners,uint256[] weights,uint256 nonce)');

	bytes32 public constant SWAP_OWNER_HASH = 
		keccak256('SwapOwner(address oldOwner,address newOwner,address[] owners,uint256[] weights,uint256 nonce)');

	bytes32 public constant CHANGE_WEIGHT_HASH =
		keccak256('ChangeWeight(address[] owners,uint256[] weights,uint256 nonce)');

	bytes32 public constant CHANGE_WEIGHT_THRESHOLD_HASH =
		keccak256('ChangeWeightThreshold(uint256 weightThreshold,uint256 nonce)');

	bytes32 public constant CANCEL_HASH = 
		keccak256('Cancel(uint256 nonce)');

	bytes32 public constant EXEC_TRANSFER_TOKEN_HASH = 
		keccak256('ExecTransferToken(address to,uint256 value,address paymentToken,uint256 nonce)');

	bytes32 public constant EXEC_CONTRACT_TRANSACTION_HASH = 
		keccak256('ExecContractTransaction(address to,uint256 value,bytes payload,uint256 nonce)');

	event ExecTransferEther(address indexed from, address indexed to, uint256 value);
	event ExecTransferERC20(address indexed from, address indexed to, address tokenAddress, uint256 value);
	event ExecContract(address indexed from, address indexed to, bytes data);
	event Cancel(uint256 nonce);

    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory _owners, uint256[] memory _weight, uint256 _weightThreshold) payable external initializer{
        __EIP712_init("MultiSignature", "1");
		setupOwners(_owners, _weight, _weightThreshold);
    }

	/**
	 * @notice 添加成员，并更新权重值
	 * @param owner 新增的成员地址
	 * @param _owners 新增成员后的地址数组
	 * @param _weights 地址数组中每个地址对应的权重值，之和需要等于100
	 * @param signatures 多签
	 * @param sigNumber 组成多签的签名个数
	 */
	function addOwnerChangeWeight(address owner, address[] memory _owners, uint256[] memory _weights, bytes memory signatures, uint256 sigNumber) external {
        bytes32 addOwnerHash = keccak256(
            abi.encode(ADD_OWNER_HASH, owner, keccak256(abi.encodePacked(_owners)), keccak256(abi.encodePacked(_weights)), nonce++)
        );

        bytes32 dataHash = _hashTypedDataV4(addOwnerHash);

		checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		addOwnerWithWeight(owner, _owners, _weights);
	}

	/**
	 * @notice 移除成员，并更新权重值
	 * @param prevOwner 移除成员的前驱节点
	 * @param owner 移除的成员
	 * @param _owners 移除后的成员数组
	 * @param _weights 成员数组对应的权重值
	 * @param signatures 多签
	 * @param sigNumber 组成多签的签名个数
	 */
	function removeOwnerChangeWeight(address prevOwner, address owner, address[] memory _owners, uint256[] memory _weights, bytes memory signatures, uint256 sigNumber) external {
		bytes32 removeOwnerHash = keccak256(
			abi.encode(REMOVE_OWNER_HASH, owner, keccak256(abi.encodePacked(_owners)), keccak256(abi.encodePacked(_weights)), nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(removeOwnerHash);

        checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		removeOwnerWithWeight(prevOwner, owner, _owners, _weights);
	}

	/**
	 * @notice 替换成员，并更新权重值
	 * @param prevOwner 被替换成员的前驱节点
	 * @param oldOwner 被替换的成员
	 * @param newOwner 新的成员
	 * @param _owners 新的成员地址数组
	 * @param _weights 对应的权重数组
	 * @param signatures 多签
	 * @param sigNumber 组成多签的个数
	 */
    function swapSigOwner(address prevOwner, address oldOwner, address newOwner, address[] memory _owners, uint256[] memory _weights, bytes memory signatures, uint256 sigNumber) external {
		bytes32 swapOwnerHash = keccak256(
			abi.encode(SWAP_OWNER_HASH, oldOwner, newOwner, keccak256(abi.encodePacked(_owners)), keccak256(abi.encodePacked(_weights)), nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(swapOwnerHash);

        checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		swapOwner(prevOwner, oldOwner, newOwner, _owners, _weights);
	}

	/**
	 * @notice 改变各个成员的权重值。
	 * @param _owners 成员数组
	 * @param _weights 成员数组对应的权重值数组
	 * @param signatures 多签
	 * @param sigNumber 签名的个数
	 */
	function alterWeight(address[] memory _owners, uint256[] memory _weights, bytes memory signatures, uint256 sigNumber) external {
		// 输入的成员数组的长度需要和当前成员的数量相同。
		require(_owners.length == ownerCount, "owners.length != owncer count");
		bytes32 changeWeightHash = keccak256(
			abi.encode(CHANGE_WEIGHT_HASH, keccak256(abi.encodePacked(_owners)), keccak256(abi.encodePacked(_weights)), nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(changeWeightHash);

        checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		changeWeight(_owners, _weights);
	}

	/**
	 * @notice 修改权重门限值，即通过多少权重，该签名通过
	 * @param _weightThreshold 新的权重门限值
	 * @param signatures 多签
	 * @param sigNumber 签名个数
	 */
	function alterWeightThreshold(uint256 _weightThreshold,bytes memory signatures, uint256 sigNumber) external {
		bytes32 changeWeightThresholdHash = keccak256(
			abi.encode(CHANGE_WEIGHT_THRESHOLD_HASH, _weightThreshold, nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(changeWeightThresholdHash);

		checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		changeWeightThreshold(_weightThreshold);
	}

	/**
	 * @notice 取消该nonce的交易，签名内容只需对nonce签名即可。
	 * @param signatures 多签
	 * @param sigNumber 多签个数
	 */
	function cancel(bytes memory signatures, uint256 sigNumber) external {
		bytes32 cancelHash = keccak256(
			abi.encode(CANCEL_HASH, nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(cancelHash);

		checkNSignaturesAndWeight(dataHash, signatures, sigNumber);
		
		emit Cancel(nonce - 1);
	}

	/**
	 * @notice 执行转账交易
	 * @param to 转账的目标地址
	 * @param value 转账的金额
	 * @param paymentToken 代币地址，若是原生代币则为0
	 * @param signatures 多签
	 * @param sigNumber 签名个数
	 */
    function execTransferToken(
        address to,
        uint256 value,
        address paymentToken,
        bytes memory signatures, 
        uint256 sigNumber
    ) external payable nonReentrant{
		bytes32 execTranscationHash = keccak256(
			abi.encode(EXEC_TRANSFER_TOKEN_HASH, to, value, paymentToken, nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(execTranscationHash);

		checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		if (paymentToken == address(0)) {
			require(to != address(0), "transfer to zero address");
            (bool success,) = payable(to).call{value: value}("");
            require(success, "transfer failed");
			emit ExecTransferEther(address(this), to, value);
		} else {
			IERC20Upgradeable token = IERC20Upgradeable(paymentToken);
			token.safeTransfer(to, value);
			emit ExecTransferERC20(address(this), to, paymentToken, value);
		}
	}

	/**
	 * @notice 调用合约交易
	 * @param to 调用的合约地址
	 * @param value 转账给该合约的数额
	 * @param payload 调用合约用到的数据
	 * @param signatures 多签
	 * @param sigNumber 多签个数
	 */
	function execContractTransaction(address to, uint256 value, bytes calldata payload, bytes memory signatures, uint256 sigNumber) external payable nonReentrant{
		require(payload.length != 0, "The payload cannot be empty");

		bytes32 execContractTransactionHash = keccak256(
			abi.encode(EXEC_CONTRACT_TRANSACTION_HASH, to, value, keccak256(abi.encodePacked(payload)), nonce++)
		);
		bytes32 dataHash = _hashTypedDataV4(execContractTransactionHash);

		checkNSignaturesAndWeight(dataHash, signatures, sigNumber);

		(bool success, bytes memory data) = payable(to).call{value: value}(payload);
		require(success, "exec failed");

		emit ExecContract(address(this), to, data);
	}

	// 一个签名按照rsv的顺序拼接
    function checkNSignaturesAndWeight(bytes32 dataHash, bytes memory signatures, uint256 requiredSignatures) public view {
        require(signatures.length >= requiredSignatures * 65, "sig length error");
        
        address lastOwner = address(0);
        address currentOwner;
        uint256 weightSum;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;

		for (i = 0; i < requiredSignatures; i++) {
			(v, r, s) = signatureSplit(signatures, i);
			currentOwner = ECDSAUpgradeable.recover(dataHash, v, r, s);
			require(currentOwner > lastOwner, "There is no ascending sort of addresses");
			require(owners[currentOwner] != address(0) && currentOwner != SENTINEL_OWNERS, "Not owners address");
            weightSum += weight[currentOwner]  ;
            lastOwner = currentOwner;
		}

        require(weightSum >= weightThreshold, "The weight value is insufficient");
	}

	receive() external payable {}

}

