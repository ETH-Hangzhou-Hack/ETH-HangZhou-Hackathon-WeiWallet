// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 注册合约，记录用户创建过的多签钱包地址。
 * @author 0xE
 * @dev 使用链表来处理地址集合，并且使用用户地址当作循环链表的头节点。
 */
contract Register {
    // 用户地址=>地址1=>地址2...=>指回用户地址，形成循环链表。
    mapping(address => address) internal walletLink;

    mapping(address => uint256) public createTime;
    mapping(address => bytes32) public createSalt;

    /**
     * @notice 给创建出的多签钱包进行创建时间赋值。
     * @param wallet 创建的多签钱包地址。
     * @param time 创建时间戳。
     */
    function createWalletTime(address wallet, uint256 time) internal {
        require(wallet != address(0), "user address is 0");
        createTime[wallet] = time;
    }

    /**
     * @notice 给创建出的多签钱包记录创建时用到的salt值。
     * @param wallet 创建的多签钱包地址。
     * @param salt 创建时用到的salt值。
     */
    function createWalletSalt(address wallet, bytes32 salt) internal {
        require(wallet != address(0), "user address is 0");
        createSalt[wallet] = salt;
    }

    /**
     * @notice 添加某个地址的多签钱包
     * @param user 用户地址
     * @param wallet 创建的多签钱包地址
     */
    function addWallet(address user, address wallet) internal {
        require(user != address(0), "user address is 0");
        require(wallet != address(0) && wallet != user, "wallet address error");
        require(walletLink[wallet] == address(0), "wallet is already added");
        if (walletLink[user] == address(0)) walletLink[user] = user;
        // 头插法添加钱包地址。
        walletLink[wallet] = walletLink[user];
        walletLink[user] = wallet;
    }

    /**
     * @notice 取出指定用户的创建的钱包地址，倒序取出，即第0个是最新创建的钱包地址。
     * @dev 当取出的地址不足pageSize时，返回的数组将是实际的数组长度。
     * @param user 需要查询的用户地址
     * @param start 开始查询的起始位置
     * @param pageSize 这次查询的数量
     * @return array 返回查询结果
     * @return next 当未查询完，该值指向下一页的首地址，用来下次调用该函数作为start参数用。
     */
    function getWalletPaginated(address user, address start, uint256 pageSize) external view returns (address[] memory array, address next) {
        require(pageSize > 0, "pageSize error");
        // 用page size初始化最大的数组大小。
        array = new address[](pageSize);

        uint256 walletCount = 0;
        next = walletLink[start];
        while (next != address(0) && next != user && walletCount < pageSize) {
            array[walletCount] = next;
            next = walletLink[next];
            walletCount++;
        }

        if (next != user) {
            next = array[walletCount - 1];
        }
        // 直接把数组的长度前缀修改成真实值。
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(array, walletCount)
        }
    }
}










