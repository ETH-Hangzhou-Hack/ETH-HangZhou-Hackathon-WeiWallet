// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 管理多签钱包的owner成员和权重值。
 * @dev 使用链表管理多签钱包的owner成员，相对于动态数组使用更高效。
 *      此外，对于输入的新的权重列表，只进行基础检查，不对成员是否按照新增加的或移除的后的列表与之前的成员列表做对比，
 *      不然代码性能会下降。考虑到新增与移除成员也需要多签的输入，所以该列表的安全性由多签维护。
 * @author 0xE
 */
abstract contract OwnerManagerWeight {
    event ChangeWeight(address[] owners, uint256[] weight);
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangeWeightThreshold(uint256 weightThreshold);

    address internal constant SENTINEL_OWNERS = address(0x1);

    mapping(address => address) internal owners;
    uint256 public ownerCount;

    mapping (address => uint256) internal weight;

    uint256 public weightThreshold;

    /**
     * @notice 设置合约的初始化存储。
     * @param _owners 多签人地址列表
     * @param _weight 权重列表
     */
    function setupOwners(address[] memory _owners, uint256[] memory _weight, uint256 _weightThreshold) internal {
        checkWeight(_owners, _weight);

        require(_weightThreshold > 0 && _weightThreshold <= 100, "threshold error");

        address currentOwner = SENTINEL_OWNERS;

        for (uint256 i = 0; i < _owners.length; ++i) {
            address owner = _owners[i];
            require(owner != address(0) && owner != SENTINEL_OWNERS && owner != address(this) && currentOwner != owner, "address error");
            require(owners[owner] == address(0), "address has a back node");

            weight[owner] = _weight[i];

            owners[currentOwner] = owner;
            currentOwner = owner;
        }
        owners[currentOwner] = SENTINEL_OWNERS;

        ownerCount = _owners.length;
        weightThreshold = _weightThreshold;
    }

    /**
     * @notice 新增一个成员地址，并且修改各个地址的权重值。
     * @param owner 新增加的拥有者。
     * @param _owners 新增地址后的新成员的拥有者列表。
     * @param _weight 他们对应的权重值。
     */
    function addOwnerWithWeight(address owner, address[] memory _owners, uint256[] memory _weight) internal {
        checkWeight(_owners, _weight);

        require(owner != address(0) && owner != SENTINEL_OWNERS && owner != address(this), "address error");
        require(owners[owner] == address(0), "address has a back node");

        // 头插法插入新的结点。
        owners[owner] = owners[SENTINEL_OWNERS];
        owners[SENTINEL_OWNERS] = owner;
        ownerCount++;

        emit AddedOwner(owner);

        _changeWeight(_owners, _weight);
    }

    /**
     * @notice 移除成员，并修改各个成员的权重。
     * @param prevOwner 移除的成员的前驱节点。
     * @param owner 需要移除的成员。
     * @param _owners 移除后的成员列表。
     * @param _weight 各个成员的权重。
     */
    function removeOwnerWithWeight(address prevOwner, address owner, address[] memory _owners, uint256[] memory _weight) internal {
        checkWeight(_owners, _weight);

        require(owner != address(0) && owner != SENTINEL_OWNERS, "owner error");
        require(owners[prevOwner] == owner, "prevOwner error");

        owners[prevOwner] = owners[owner];
        owners[owner] = address(0);
        ownerCount--;
        emit RemovedOwner(owner);

        weight[owner] = 0;

        _changeWeight(_owners, _weight);
    }

    /**
     * @notice 替换成员，并修改各个成员的权重值。
     * @param prevOwner 需要被替换的成员的前驱节点。
     * @param oldOwner 需要被替换的成员。
     * @param newOwner 新的成员。
     * @param _owners 交换后的成员列表。
     * @param _weight 各个成员的权重。
     */
    function swapOwner(address prevOwner, address oldOwner, address newOwner, address[] memory _owners, uint256[] memory _weight) internal {
        checkWeight(_owners, _weight);

        require(newOwner != address(0) && newOwner != SENTINEL_OWNERS && newOwner != address(this), "newOwner error");
        require(owners[newOwner] == address(0), "newOwner has a back node");
        require(oldOwner != address(0) && oldOwner != SENTINEL_OWNERS, "oldOwner error");
        require(owners[prevOwner] == oldOwner, "prevOwner error");

        owners[newOwner] = owners[oldOwner];
        owners[prevOwner] = newOwner;
        owners[oldOwner] = address(0);
        emit RemovedOwner(oldOwner);
        emit AddedOwner(newOwner);

        _changeWeight(_owners, _weight);
    }

    /**
     * @notice 改变成员的权重值。
     * @param _owners 成员的地址列表。
     * @param _weight 各个成员的权重。
     */
    function changeWeight(address[] memory _owners, uint256[] memory _weight) internal {
        checkWeight(_owners, _weight);
        _changeWeight(_owners, _weight);
    }

    /**
     * @notice 改变权重门限值。
     * @param _weightThreshold 新的权重门限值。
     */
    function changeWeightThreshold(uint256 _weightThreshold) internal {
        require(_weightThreshold > 0 && _weightThreshold <= 100, "threshold error");
        weightThreshold = _weightThreshold;

        emit ChangeWeightThreshold(_weightThreshold);
    }

    /**
     * @notice 查询单个成员的权重值。
     * @param _owners 查询的成员地址。
     */
    function getWeight(address _owners) public view returns(uint256 _weight) {
        _weight = weight[_owners];
    }

    // 检查输入的权重值之和是否等于100。
    function checkWeight(address[] memory _owners, uint256[] memory _weight) pure internal {
        require(_owners.length == _weight.length, "The two arrays are not equal in length.");
        uint256 weightSum;
        for(uint256 i = 0; i < _weight.length; ++i){
            weightSum += _weight[i];
        }
        require(weightSum == 100, "The sum of the weights needs to be equal to 100");
    }

    /**
     * @notice 返回输入的owner是否是多签的owner。
     * @return 返回布尔值。
     */
    function isOwner(address owner) public view returns (bool) {
        // 只要owner地址不是哨兵地址，并且有后驱节点就是Safe的owner。
        return owner != SENTINEL_OWNERS && owners[owner] != address(0);
    }

    /**
     * @notice 返回所有的成员地址。
     * @return 成员地址数组。
     */
    function getOwners() public view returns (address[] memory) {
        // 用owner count创建数组大小。
        address[] memory array = new address[](ownerCount);

        // 填充返回数组。
        uint256 index = 0;
        // 从头结点后的后驱结点开始遍历。直到遍历回到头结点。
        address currentOwner = owners[SENTINEL_OWNERS];
        while (currentOwner != SENTINEL_OWNERS) {
            array[index] = currentOwner;
            currentOwner = owners[currentOwner];
            index++;
        }
        return array;
    }

    function _changeWeight(address[] memory _owners, uint256[] memory _weight) private {
        for (uint256 i = 0; i < _owners.length; ++i) {
            weight[_owners[i]] = _weight[i];
        }

        emit ChangeWeight(_owners, _weight);
    }
}