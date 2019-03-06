pragma solidity ^0.4.24;
pragma experimental "ABIEncoderV2";

contract LambdaMatchOrder {

    // uint constant LAMBDA_MARKET_PRICE = 1 * 10**10; //  1M/day

    uint constant LAMBDA_MARKET_PRICE = 1;

    // uint constant LAMBDA_PLEDGE_PRICE = 10; // 1G

    uint constant LAMBDA_PLEDGE_PRICE = 1; // 1G

    uint constant MATCH_MINER_COUNT = 10;

    struct PledgeMiner {
        address owner;
        uint size;
        uint useSize;
        uint status; //  0 aviable 1 unaviable
        uint pledgeTime;
        uint money;
    }

    PledgeMiner[] internal PledgeMinerList;

    struct Order {
        address orderId;
        address owner;
        uint price;
        uint size;
        uint duration;
        uint createTime;
        uint mold; // 0 sell 1 buy
        uint ip;
    }

    mapping(address => Order[]) internal StorageAddressOrder;

    mapping(address => uint) internal PledgeIndex;

    struct MatchOrder {
        address orderId;
        address SellAddress;
        address BuyAddress;
        address SellOrderId;
        address BuyOrderId;
        uint price;
        uint size;
        uint createTime;
        uint endTime;
        uint settleTime;
        uint status; // 0 Not effective 1 effective 2 Invalid
        uint256 ip;
    }

    struct Validator {
        address validatorAddress;
        uint    money;
        uint256 ip;
    }

    Order [] internal SellOrderList;

    Order [] internal BuyOrderList; // save success match buy order;

    MatchOrder [] internal MatchOrderList;

    mapping(uint => Order[]) internal mappingPriceSellOrderList;

    mapping(address => MatchOrder) internal mappingOrderIdToMatchOrder;

    mapping(address => MatchOrder[]) internal mappingAddressToMatchOrder;

    mapping(address => address[]) internal mappingValidatorToPledge;

    mapping(address => address) internal mappingPledgeAddressToValidatorAddress;

    Validator [] internal ValidatorList;

    uint[] internal priceList;

    constructor () public payable {

    }

    // get pledge miner list interface
    function getPledgeMinerList() external view returns (PledgeMiner[] memory) {
        return PledgeMinerList;
    }

    function getOrderListByAddress(address _address) external view returns (Order[] memory) {
        return StorageAddressOrder[_address];
    }

    function getMatchOrderListByAddress(address _address) external view returns (MatchOrder[] memory) {
        return mappingAddressToMatchOrder[_address];
    }

    function getMappingPriceSellOrderList(uint x) external view returns (Order[] memory) {
        return mappingPriceSellOrderList[x];
    }

    function getSellOrderList() external view returns (Order[] memory) {
        return SellOrderList;
    }

    function getMatchOrderList() external view returns (MatchOrder[] memory) {
        return MatchOrderList;
    }

    function getMatchOrderByOrderId(address _orderId) external view returns (MatchOrder memory) {
        return mappingOrderIdToMatchOrder[_orderId];
    }

    function getPriceList() external view returns (uint[]) {
        return priceList;
    }

    function findValidatorByPledgeAddress(address _pledgeAddress) external view returns (Validator[]) {
        address pledgeAddress = _pledgeAddress;
        address validatorAddress = mappingPledgeAddressToValidatorAddress[pledgeAddress];
        if (validatorAddress == 0) {
            require(false, "can not find validator");
        }
        uint length = ValidatorList.length;
        Validator[] memory list = new Validator[](1);
        for (uint i=0; i<length; i++) {
            if (ValidatorList[i].validatorAddress == validatorAddress) {
                Validator v = ValidatorList[i];
                list[0] = v;
                return list;
            }
        }
        require(false, "can not find validator");
    }

    function quickSort(uint[] storage arr, int left, int right) internal{
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    function insertPledgeToValidator(address pledgeAddress, address _validatorAddress) internal {
        // validator address is not in ValidatorList
        bool flag = findValidator(_validatorAddress);
        if (!flag) {
            require(false, "can not find validator in pledgeValidatorList");
        }
        address[] storage pledgeAddressList =  mappingValidatorToPledge[_validatorAddress];
        address validator = mappingPledgeAddressToValidatorAddress[pledgeAddress];
        if (validator == 0) {
            mappingPledgeAddressToValidatorAddress[pledgeAddress] = _validatorAddress;
        }
        if (validator != _validatorAddress && validator != 0) {
            require(false, "you have enter a validator, can not enter other validator");
        }
        uint length = pledgeAddressList.length;
        if (length == 0) {
            pledgeAddressList.push(pledgeAddress);
        } else {
            for (uint i=0; i<length; i++) {
                if (pledgeAddressList[i] == pledgeAddress) {
                    return;
                }
            }
            pledgeAddressList.push(pledgeAddress);
        }
    }

    function removePlegdeAddressFromValidator(address _pledgeAddress, address _validatorAddress) external {
        address[] storage pledgeAddressList = mappingValidatorToPledge[_validatorAddress];
        uint length = pledgeAddressList.length;
        if (length == 0) {
            return;
        } else {
            (bool flag, uint index) = findPledgeFromValidator(_pledgeAddress, _validatorAddress);
            if (flag) {
                removePlegdeAddress(pledgeAddressList, index);
            }
        }

    }

    function findPledgeFromValidator(address _pledgeAddress, address _validatorAddress) internal view returns (bool, uint) {
        address[] storage pledgeAddressList = mappingValidatorToPledge[_validatorAddress];
        uint length = pledgeAddressList.length;
        for (uint i=0; i<length; i++) {
            if (pledgeAddressList[i] == _pledgeAddress) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function removePlegdeAddress(address[] storage pledgeAddressList, uint index) internal {
        if (index >= pledgeAddressList.length) return;

        for (uint i = index; i<pledgeAddressList.length-1; i++){
            pledgeAddressList[i] = pledgeAddressList[i+1];
        }
        delete pledgeAddressList[pledgeAddressList.length-1];
        pledgeAddressList.length--;
    }

    // pledge validator
    function pledgeValidator(uint _money, uint256 _ip) external payable returns (bool) {
        require(msg.value >= _money, "you should pay enough LAMB");
        address validatorAddress = msg.sender;
        Validator memory v = Validator({
            validatorAddress: validatorAddress,
            money: _money,
            ip: _ip
            });
        bool flag = findValidator(validatorAddress);
        if (!flag) {
            ValidatorList.push(v);
        }
    }

    function findValidator(address _validatorAddress) internal view returns (bool) {
        uint length = ValidatorList.length;
        for (uint i=0; i<length; i++) {
            if (ValidatorList[i].validatorAddress == _validatorAddress) {
                return true;
            }
        }
        return false;
    }

    // pledge miner
    function pledge(uint _size, uint _pledgeTime, uint _price, address _validatorAddress, address _pledgeAddress) external payable returns (bool) {
        uint pledgeMoney = _size * _price;
        require(msg.value >= pledgeMoney, "you should pay enough LAMB");
        insertPledgeToValidator(_pledgeAddress, _validatorAddress);
        if (PledgeIndex[_pledgeAddress] == 0) {
            PledgeMiner memory p = PledgeMiner({
                owner: _pledgeAddress,
                money: pledgeMoney,
                useSize: 0,
                status: 0,
                pledgeTime: _pledgeTime,
                size: _size
                });
            uint index = PledgeMinerList.push(p);
            PledgeIndex[_pledgeAddress] = index;
        } else {
            // update
            uint i = PledgeIndex[_pledgeAddress];
            PledgeMinerList[i - 1].money += pledgeMoney;
            PledgeMinerList[i - 1].size += _size;
            PledgeMinerList[i - 1].pledgeTime = _pledgeTime;
            PledgeMinerList[i - 1].status = 0;
        }
    }

    function pledgeRevert(uint _now) external {
        address minerAddress = msg.sender;
        uint pos = PledgeIndex[minerAddress];
        PledgeMiner storage miner = PledgeMinerList[pos - 1];
        require(miner.owner != address(0), "invail address");
        require(miner.status != 1, "status is unaviable, can not revert pledge");

        miner.status = 1;
        miner.pledgeTime = _now;

        deleteMinerSellOrder(minerAddress);
    }

    function deleteMinerSellOrder(address _address) internal {
        for (uint i=0; i<SellOrderList.length; i++) {
            if (SellOrderList[i].owner == _address) {
                removeOrder(SellOrderList, i);
            }
        }
        for (uint index=0; index<priceList.length; index++) {
            Order[] storage orderList = mappingPriceSellOrderList[priceList[index]];
            for (uint j=0; j<orderList.length; j++) {
                if (orderList[j].owner == _address) {
                    removeOrder(orderList, j);
                }
            }
        }
    }

    function withdrawPledge(uint _now) external {
        address minerAddress = msg.sender;
        uint pos = PledgeIndex[minerAddress];
        PledgeMiner memory miner = PledgeMinerList[pos - 1];
        require(miner.owner != address(0), "invail address");
        require(miner.status == 1, "pledge is aviable");
        // TODO
        require((now - miner.pledgeTime) >= (90 * 1 days), "time is not satisfy");
        // require((_now - miner.pledgeTime) >= (90 * 1), "time is not satisfy");

        delete PledgeIndex[minerAddress];
        delete PledgeMinerList[pos - 1];
        minerAddress.transfer(miner.money);
    }

    function createOrder(uint _size, uint _price, uint _duration, uint _mold, uint256 _ip, uint _now) public payable {
        // if mold == 0  sell
        address _address = msg.sender;
        uint index = PledgeIndex[_address];
        if (_mold == 0) {
            require(index != 0, "you should pledge sector");
            require(PledgeMinerList[index - 1].status == 0, "pledge status should aviable");
            require(_size > 0 && _size <= (PledgeMinerList[index - 1].size - PledgeMinerList[index - 1].useSize), "not enough sector");
        }
        require(_price > 0, "you just can sale product over 0");
        require(_mold == 0 || _mold == 1, "mold should 0 or 1");
        // create OrderId
        bytes32 orderId = keccak256(abi.encodePacked(
                _address,
                _now,
                _size,
                _price,
                _mold,
                _duration,
                _ip
            ));
        // create Order
        Order memory order = Order({
            orderId: address(orderId),
            owner: _address,
            price: _price,
            size: _size,
            mold: _mold,
            createTime: _now,
            duration: _duration,
            ip: _ip
            });

        if (_mold == 0) {
            // sort list
            SellOrderList.push(order);
            saveOrderInformation(order);
            StorageAddressOrder[_address].push(order);
            PledgeMinerList[index - 1].useSize += _size;
        } else {
            executeOrder(order, _now);
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
                    if (priceList.length > 1) quickSort(priceList, 0, int(priceList.length - 1));
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

    function executeOrder(Order memory _order, uint _now) public payable {
        address owner = _order.owner;
        uint price = _order.price;
        uint size = _order.size;
        uint duration = _order.duration;
        (Order memory order, uint findPrice) = findOrderByPriceOrSize(size, price, duration);
        require(order.owner != _order.owner, "not allow buy and sell one address");
        require (order.orderId != 0, "can not find match sell Order");
        systemOrder(_order, order, findPrice, _now);
    }

    function systemOrder(Order memory buyOrder, Order memory sellOrder, uint price, uint _now) internal {
        address buyAddress = buyOrder.owner;
        address sellAddress = sellOrder.owner;
        bytes32 orderId = keccak256(abi.encodePacked(
                buyAddress,
                sellAddress,
                buyOrder.price,
                buyOrder.size,
                _now
            ));

        MatchOrder memory matchOrder = MatchOrder({
            orderId: address(orderId),
            SellAddress: sellAddress,
            BuyAddress: buyAddress,
            SellOrderId: sellOrder.orderId,
            BuyOrderId: buyOrder.orderId,
            size: buyOrder.size,
            price: sellOrder.price,
            createTime: _now,
            ip: sellOrder.ip,
            status: 0,
            endTime: _now + buyOrder.duration,
            settleTime: _now
            });

        MatchOrderList.push(matchOrder);

        mappingOrderIdToMatchOrder[address(orderId)] = matchOrder;

        mappingAddressToMatchOrder[sellAddress].push(matchOrder);

        mappingAddressToMatchOrder[buyAddress].push(matchOrder);

        bytes32 buyBytes = bytes32(uint256(buyAddress) << 96);

        bytes32 sellBytes = bytes32(uint256(sellAddress) << 96);

        bytes32 orderIdBytes = bytes32(uint256(orderId) << 96);

        // order(orderIdBytes, buyBytes, sellBytes, sellOrder.ip);

        // uint divValue = msg.value - (buyOrder.size * sellOrder.price * (buyOrder.duration / 1 days));
        // require(divValue >= 0, "money is not enough");
        // msg.sender.transfer(divValue);

        handerBuyOrder(buyOrder, BuyOrderList);
        handerSellOrder(buyOrder, sellOrder, SellOrderList);
        handerStorageAddressOrder(buyOrder, sellOrder);
        handerMappingSellOrderList(price, sellOrder.orderId, buyOrder.size, false);
    }

    function handerStorageAddressOrder(Order memory _buyOrder, Order memory _sellOrder) internal {
        address orderId = _sellOrder.orderId;
        uint buySize = _buyOrder.size;
        Order[] memory orderList = StorageAddressOrder[_sellOrder.owner];
        for (uint i = 0; i < orderList.length; i++) {
            if (orderList[i].orderId == orderId) {
                StorageAddressOrder[_sellOrder.owner][i].size -= buySize;
            }
        }
    }

    function handerMappingSellOrderList(uint _price, address _orderId, uint size, bool flag) internal {
        Order[] storage orderList = mappingPriceSellOrderList[_price];
        for (uint i=0; i<orderList.length; i++) {
            if (orderList[i].orderId == _orderId) {
                if (flag) {
                    removeOrder(orderList, i);
                    if (orderList.length == 0) {
                        delete mappingPriceSellOrderList[_price];
                    }
                } else {
                    orderList[i].size -= size;
                }
            }
        }
    }

    function handerSellOrder(Order memory _buyOrder, Order memory _sellOrder, Order[] storage orderList) internal {
        address orderId = _sellOrder.orderId;
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

    function cancelOrder(address _orderId) external returns (Order memory) {
        address owner = msg.sender;
        (Order memory order, uint index) = findOrderByOrderId(owner, _orderId);
        require(owner == order.owner, "you are not have this order");
        // remove order from list;
        // add size to pledge
        removeOrder(SellOrderList, index);
        handerMappingSellOrderList(order.price, order.orderId, order.size, true);
        handerMappingSellOrderStorage(_orderId);
        backOrderSizeToPledge(order);
    }

    function handerMappingSellOrderStorage(address _orderId) internal {
        address owner = msg.sender;
        Order[] storage orderList = StorageAddressOrder[owner];
        for (uint i = 0; i < orderList.length; i++) {
            if (orderList[i].orderId == _orderId) {
                removeOrder(orderList, i);
            }
        }
    }

    function backOrderSizeToPledge(Order memory _order) internal {
        address seller = _order.owner;
        uint size = _order.size;

        uint index = PledgeIndex[seller];
        PledgeMiner storage miner = PledgeMinerList[index - 1];
        miner.useSize -= size;
    }

    function findOrderByOrderId(address owner, address _orderId) public view returns (Order memory, uint) {
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

    function findMatchOrderByOrderId (address _orderId) internal view returns (MatchOrder memory, uint) {
        for (uint i=0; i<MatchOrderList.length; i++) {
            if (MatchOrderList[i].orderId == _orderId) {
                return (MatchOrderList[i], i);
            }
        }
        require(false, 'can not find matchOrder');
    }

    function removeOrder(Order[] storage orderList, uint index) internal {
        if (index >= orderList.length) return;

        for (uint i = index; i<orderList.length-1; i++){
            orderList[i] = orderList[i+1];
        }
        delete orderList[orderList.length-1];
        orderList.length--;
    }

    // function removeMatchOrder(uint index) internal {
    //     if (index >= array.length) return;

    //     for (uint i = index; i<array.length-1; i++){
    //         array[i] = array[i+1];
    //     }
    //     delete array[array.length-1];
    //     array.length--;
    // }

    function updateOwnerToMatchOrderList(address owner, address _orderId, uint _time, uint status) internal {
        MatchOrder[] storage orderList = mappingAddressToMatchOrder[owner];
        for (uint i=0; i<orderList.length; i++) {
            if (_orderId == orderList[i].orderId) {
                orderList[i].status = status;
                orderList[i].settleTime = _time;
            }
        }
    }

    function updateOrderIdToMatchOrderList(address _orderId, uint _time, uint status) internal {
        MatchOrder storage order = mappingOrderIdToMatchOrder[_orderId];
        order.status = status;
        order.settleTime = _time;
    }

    function settle(address _orderId, uint _now) external {
        (MatchOrder memory order, uint i) = findMatchOrderByOrderId(_orderId);
        address sellOwner = order.SellAddress;
        require(sellOwner != address(0), "invail sell address");
        uint settleTime = _now;
        uint div = settleTime - order.settleTime;
        uint price = order.price * order.size * (div / 1 days);
        //        uint price = order.price * order.size * (div / 60);
        // require(price != 0, "time is not enough");
        uint newSettleTime = settleTime - (div % 1 days);
        //        uint newSettleTime = settleTime - (div % 60);

        MatchOrderList[i].settleTime =  newSettleTime;
        MatchOrderList[i].status = 1;

        if (newSettleTime > order.endTime) {
            // delete matchOrder
            delete MatchOrderList[i];

            updateOwnerToMatchOrderList(order.SellAddress, order.orderId, order.endTime, 2);

            updateOwnerToMatchOrderList(order.BuyAddress, order.orderId, order.endTime, 2);

            updateOrderIdToMatchOrderList(order.orderId, order.endTime, 2);

        } else {

            updateOwnerToMatchOrderList(order.SellAddress, order.orderId, newSettleTime, 1);

            updateOwnerToMatchOrderList(order.BuyAddress, order.orderId, newSettleTime, 1);

            updateOrderIdToMatchOrderList(order.orderId, newSettleTime, 1);

            sellOwner.transfer(price);
        }
    }

}
