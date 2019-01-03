pragma solidity ^0.5.0;
pragma experimental "ABIEncoderV2";

contract LambdaMatchOrder {

    // uint constant LAMBDA_MARKET_PRICE = 1 * 10**10; //  1M/day

    uint constant LAMBDA_MARKET_PRICE = 1 ether;

    // uint constant LAMBDA_PLEDGE_PRICE = 10; // 1G

    uint constant LAMBDA_PLEDGE_PRICE = 1 ether; // 1G

    uint constant MATCH_MINER_COUNT = 10;

    struct PledgeMiner {
        address owner;
        uint size;
        uint useSize;
        uint status; //  0 aviable 1 unaviable
        uint pledgeTime;
        uint money;
    }

    PledgeMiner[] public PledgeMinerList;

    struct Order {
        bytes32 orderId;
        address payable owner;
        uint price;
        uint size;
        uint duration;
        uint createTime;
        uint mold; // 0 sell 1 buy
    }

    mapping(address => Order[]) public StorageAddressOrder;

    mapping(address => uint) public PledgeIndex;

    struct MatchOrder {
        bytes32 orderId;
        address payable SellAddress;
        address BuyAddress;
        bytes32 SellOrderId;
        bytes32 BuyOrderId;
        uint price;
        uint size;
        uint createTime;
        uint endTime;
        uint settleTime;
        uint status;
        bytes32 ip;
    }

    Order [] public SellOrderList;

    Order [] public BuyOrderList; // save success match buy order;

    MatchOrder [] public MatchOrderList;

    mapping(uint => Order[]) public mappingPriceSellOrderList;

    uint[] public priceList;

    constructor () public {

    }

    // get pledge miner list interface
    function getPledgeMinerList() external view returns (PledgeMiner[] memory) {
        return PledgeMinerList;
    }

    function getOrderListByAddress(address _address) external view returns (Order[] memory) {
        return StorageAddressOrder[_address];
    }

    function getMappingPriceSellOrderList(uint x) external view returns (Order[] memory) {
        return mappingPriceSellOrderList[x];
    }

    function getPriceList() external view returns (uint[] memory) {
        return priceList;
    }

    function quickSort(uint[] storage arr, uint left, uint right) internal {
        uint i = left;
        uint j = right;
        uint pivot = arr[left + (right - left) / 2];
        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (pivot < arr[j]) j--;
            if (i <= j) {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    // pledge miner
    function pledge(uint _size, uint _pledgeTime) external payable returns (bool) {
        uint pledgeMoney = _size * LAMBDA_PLEDGE_PRICE;
        require(msg.value >= pledgeMoney, "you should pay enough LAMB");
        if (PledgeIndex[msg.sender] == 0) {
            PledgeMiner memory p = PledgeMiner({
                owner: msg.sender,
                money: pledgeMoney,
                useSize: 0,
                status: 0,
                pledgeTime: _pledgeTime,
                size: _size
                });
            uint index = PledgeMinerList.push(p);
            PledgeIndex[msg.sender] = index;
        } else {
            // update
            uint i = PledgeIndex[msg.sender];
            PledgeMinerList[i - 1].money += pledgeMoney;
            PledgeMinerList[i - 1].size += _size;
            PledgeMinerList[i - 1].pledgeTime = now;
            PledgeMinerList[i - 1].status = 0;
        }
    }

    function pledgeRevert() external {
        address minerAddress = msg.sender;
        uint pos = PledgeIndex[minerAddress];
        PledgeMiner storage miner = PledgeMinerList[pos - 1];
        require(miner.owner != address(0));
        require(miner.status != 1);

        miner.status = 1;
        miner.pledgeTime = now;

        deleteMinerSellOrder(minerAddress);
    }

    function deleteMinerSellOrder(address _address) internal {
        for (uint i=0; i<SellOrderList.length; i++) {
            if (SellOrderList[i].owner == _address) {
                delete SellOrderList[i];
            }
        }
        for (uint i=0; i<priceList.length; i++) {
            Order[] storage orderList = mappingPriceSellOrderList[priceList[i]];
            for (uint j=0; j<orderList.length; j++) {
                if (orderList[j].owner == _address) {
                    delete orderList[j];
                }
            }
        }
    }

    function withdrawPledge() external {
        address payable minerAddress = msg.sender;
        uint pos = PledgeIndex[minerAddress];
        PledgeMiner memory miner = PledgeMinerList[pos - 1];
        require(miner.owner != address(0));
        require(miner.status == 1);
        require((now - miner.pledgeTime) >= (90 * 1 days));

        delete PledgeIndex[minerAddress];
        delete PledgeMinerList[pos - 1];
        minerAddress.transfer(miner.money);
    }

    function createOrder(uint _size, uint _price, uint _duration, uint _mold, bytes32 _ip) public payable {
        // if mold == 0  sell
        address payable _address = msg.sender;
        uint index = PledgeIndex[_address];
        if (_mold == 0) {
            require(index != 0);
            require(PledgeMinerList[index - 1].status == 0);
            require(_size > 0 && _size < (PledgeMinerList[index - 1].size - PledgeMinerList[index - 1].useSize));
        }
        require(_price > 0, "you just can sale product between 0 and 10");
        require(_mold == 0 || _mold == 1);
        // create OrderId
        bytes32 orderId = keccak256(abi.encodePacked(
                _address,
                now,
                _size,
                _price,
                _mold,
                _duration
            ));
        // create Order
        Order memory order = Order({
            orderId: orderId,
            owner: _address,
            price: _price,
            size: _size,
            mold: _mold,
            createTime: now,
            duration: _duration
            });

        if (_mold == 0) {
            // sort list
            SellOrderList.push(order);
            saveOrderInformation(order);
            StorageAddressOrder[_address].push(order);
            PledgeMinerList[index - 1].useSize += _size;
        } else {
            executeOrder(order, _ip);
        }
    }

    function saveOrderInformation(Order memory order) internal {
        uint price = order.price;
        handlerPrice(price);
        handlerPledgeTime(price, order);
    }

    function handlerPrice(uint _price) internal {
        uint length = priceList.length;
        if (length == 0) {
            priceList.push(_price);
        } else {
            for (uint i=0; i<length; i++) {
                if (priceList[i] == _price) {
                    return;
                }
                if (i == (length - 1)) {
                    priceList.push(_price);
                    if (priceList.length > 1) quickSort(priceList, 0, priceList.length - 1);
                }
            }
        }
    }

    function handlerPledgeTime(uint _price, Order memory _order) internal {
        Order [] storage pledgeTimeOrderList = mappingPriceSellOrderList[_price];
        uint length = pledgeTimeOrderList.length;
        if (length == 0) {
            pledgeTimeOrderList.push(_order);
        } else {
            for (uint i=0; i<length; i++) {
                if (pledgeTimeOrderList[i].createTime >= _order.createTime) {
                    for (uint j=length; j>i; j--) {
                        pledgeTimeOrderList[j] = pledgeTimeOrderList[j-1];
                        if (j == i+1) {
                            pledgeTimeOrderList[i] = _order;
                            return;
                        }
                    }
                }
                if (i == (length - 1)) {
                    pledgeTimeOrderList.push(_order);
                    return;
                }
            }
        }
    }

    function executeOrder(Order memory _order, bytes32 _ip) public {
        address owner = _order.owner;
        uint price = _order.price;
        uint size = _order.size;
        uint duration = _order.duration;
        (Order memory order, uint findPrice) = findOrderByPriceOrSize(size, price, duration);
        require (order.orderId != 0);
        systemOrder(_order, order, _ip, findPrice);
    }

    function systemOrder(Order memory buyOrder, Order memory sellOrder, bytes32 _ip, uint price) internal {
        address buyAddress = buyOrder.owner;
        address payable sellAddress = sellOrder.owner;
        bytes32 orderId = keccak256(abi.encodePacked(
                buyAddress,
                sellAddress,
                buyOrder.price,
                buyOrder.size,
                now
            ));
        MatchOrderList.push(MatchOrder({
            orderId: orderId,
            SellAddress: sellAddress,
            BuyAddress: buyAddress,
            SellOrderId: sellOrder.orderId,
            BuyOrderId: buyOrder.orderId,
            size: buyOrder.size,
            price: sellOrder.price,
            createTime: now,
            ip: _ip,
            status: 0,
            endTime: now,
            settleTime: now
            }));
        uint divValue = msg.value - (buyOrder.size * sellOrder.price * 1 ether);
        require(divValue >= 0);
        msg.sender.transfer(divValue);
        handerBuyOrder(buyOrder, BuyOrderList);
        handerSellOrder(buyOrder, sellOrder, SellOrderList);
        handerMappingSellOrderList(price, sellOrder.orderId, buyOrder.size, false);
    }

    function handerMappingSellOrderList(uint _price, bytes32 _orderId, uint size, bool flag) internal {
        Order[] storage orderList = mappingPriceSellOrderList[_price];
        for (uint i=0; i<orderList.length; i++) {
            if (orderList[i].orderId == _orderId) {
                flag ? orderList[i].size += size : orderList[i].size -= size;
            }
        }
    }

    function handerSellOrder(Order memory _buyOrder, Order memory _sellOrder, Order[] storage orderList) internal {
        bytes32 orderId = _sellOrder.orderId;
        uint buySize = _buyOrder.size;
        for (uint i=0; i<orderList.length; i++) {
            if (orderId == orderList[i].orderId) {
                // update order
                require(buySize <= orderList[i].size, 'no enough size');
                orderList[i].size -= buySize;
            }
        }
    }

    function handerBuyOrder(Order memory _order, Order[] storage orderList) internal {
        orderList.push(_order);
    }

    function cancelOrder(bytes32 _orderId) external returns (Order memory) {
        address owner = msg.sender;
        (Order memory order, uint index) = findOrderByOrderId(owner, _orderId);
        require(owner == order.owner);
        require(order.orderId != 0);
        // remove order from list;
        // add size to pledge
        delete SellOrderList[index];
        handerMappingSellOrderList(order.price, order.orderId, order.size, true);
        backOrderSizeToPledge(order);
    }

    function backOrderSizeToPledge(Order memory _order) internal {
        address seller = _order.owner;
        uint size = _order.size;

        uint index = PledgeIndex[seller];
        PledgeMiner storage miner = PledgeMinerList[index - 1];
        miner.useSize -= size;
    }

    function findOrderByOrderId(address owner, bytes32 _orderId) public view returns (Order memory, uint) {
        for (uint i=0; i<SellOrderList.length; i++) {
            if (SellOrderList[i].orderId == _orderId && SellOrderList[i].owner == owner) {
                return (SellOrderList[i], i);
            }
        }
        require(false, "can not find Order");
    }

    function findOrderByPriceOrSize(uint _size, uint _price, uint _duration) internal returns (Order memory, uint price) {
        for (uint i=0; i<priceList.length; i++) {
            if (priceList[i] <= _price) {
                uint findPrice = priceList[i];
                Order[] memory orderList = mappingPriceSellOrderList[findPrice];
                for (uint j=0; j<orderList.length; j++) {
                    if (_size <= orderList[j].size && _duration <= orderList[j].duration) {
                        return (orderList[j], findPrice);
                    }
                }
            }
        }
        require(false, 'can not find matched order');
    }

    function findMatchOrderByOrderId (bytes32 _orderId) internal view returns (MatchOrder memory, uint) {
        for (uint i=0; i<MatchOrderList.length; i++) {
            if (MatchOrderList[i].orderId == _orderId) {
                return (MatchOrderList[i], i);
            }
        }
        require(false, 'can not find matchOrder');
    }

    function settle(bytes32 _orderId) external {
        (MatchOrder memory order, uint i) = findMatchOrderByOrderId(_orderId);
        address payable sellOwner = order.SellAddress;
        require(sellOwner != address(0));
        uint settleTime = now;
        uint div = settleTime - order.settleTime;
        uint price = div * order.size * (div / 1 days);
        uint newSettleTime = settleTime - (div % 1 days);

        MatchOrderList[i].settleTime =  newSettleTime;
        MatchOrderList[i].status = 1;
        sellOwner.transfer(price);
    }

}