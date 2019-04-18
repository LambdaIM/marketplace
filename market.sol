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
        address validator;
    }

    struct Order {
        address orderId;
        address owner;
        uint price;
        uint size;
        uint duration;
        uint createTime;
        uint mold; // 0 sell 1 buy
        uint peerId;
        uint sellSize;
    }

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
        uint peerId;
        uint amount;
    }

    struct Validator {
        address validatorAddress;
        uint256 ip;
        uint256 peerId;
    }

    constructor () public payable {

    }

    // ----------------------------------- validator data store   method  -----------------------------------------

    // validator data
    mapping(address => address[]) internal mappingValidatorToPledgeAddress;
    mapping(address => address) internal mappingPledgeAddressToValidatorAddress;
    mapping(address => PledgeMiner[]) internal mappingValidatorToPledge;
    Validator [] internal ValidatorList;

    // pledge validator
    function pledgeValidator(uint256 _ip, uint256 _peerId) external payable returns (bool) {
        address validatorAddress = msg.sender;
        Validator memory v = Validator({
            validatorAddress: validatorAddress,
            ip: _ip,
            peerId: _peerId
            });
        (bool flag, uint index, Validator memory validator) = findValidator(validatorAddress);
        if (!flag) {
            ValidatorList.push(v);
        } else {
            require(false, "you have pledge");
        }
    }

    function findValidator(address _validatorAddress) internal view returns (bool, uint, Validator) {
        uint length = ValidatorList.length;
        for (uint i=0; i<length; i++) {
            if (ValidatorList[i].validatorAddress == _validatorAddress) {
                return (true, i, ValidatorList[i]);
            }
        }
        Validator memory v = Validator(0, 0);
        return (false, 0, v);
    }

    function validatorRevert() external returns (bool) {
        address validatorAddress = msg.sender;
        (bool flag, uint index, Validator memory validator) = findValidator(validatorAddress);
        if (!flag) {
            require(false, "you have not pledge!");
        }
        // delete ValidatorList   delete mappingValidatorToPledgeAddress   delete mappingPledgeAddressToValidatorAddress
        removeValidatorFromList(validatorAddress);
        removeValidatorFromMappingValidatorToPledge(validatorAddress);
        // removeMappingPledgeAddressToValidatorAddress(validatorAddress);
    }

    function removeValidatorFromList(address _validatorAddress) internal {
        (bool flag, uint index, Validator memory validator) = findValidator(_validatorAddress);
        if (!flag) {
            require(false, "can not find validator in validatorList");
        }
        if (index >= ValidatorList.length) return;
        for (uint i = index; i<ValidatorList.length-1; i++){
            ValidatorList[i] = ValidatorList[i+1];
        }
        delete ValidatorList[ValidatorList.length-1];
        ValidatorList.length--;

    }
    function removeValidatorFromMappingValidatorToPledge(address _validatorAddress) internal {
        address[] storage pledgeList = mappingValidatorToPledgeAddress[_validatorAddress];
        for (uint i=0; i<pledgeList.length; i++) {
            delete mappingPledgeAddressToValidatorAddress[pledgeList[i]];
        }
        delete mappingValidatorToPledgeAddress[_validatorAddress];
    }

    // ----------------------------------- miner data store   method  -----------------------------------------
    // pledge miner data
    PledgeMiner[] internal PledgeMinerList;
    mapping(address => uint) internal PledgeIndex;

    // pledge miner
    function pledge(uint _size, uint _pledgeTime, uint pledgeMoney, address _validatorAddress, address _pledgeAddress) external payable returns (bool) {
        require(msg.value >= pledgeMoney, "you should pay enough LAMB");
        insertPledgeToValidator(_pledgeAddress, _validatorAddress);
        if (PledgeIndex[_pledgeAddress] == 0) {
            PledgeMiner memory p = PledgeMiner({
                owner: _pledgeAddress,
                money: pledgeMoney,
                useSize: 0,
                status: 0,
                pledgeTime: _pledgeTime,
                size: _size,
                validator: _validatorAddress
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

    function insertPledgeToValidator(address pledgeAddress, address _validatorAddress) internal {
        // validator address is not in ValidatorList
        (bool flag, uint index, Validator memory v) = findValidator(_validatorAddress);
        if (!flag) {
            require(false, "can not find validator in pledgeValidatorList");
        }
        address[] storage pledgeAddressList =  mappingValidatorToPledgeAddress[_validatorAddress];
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
            return;
        }
        for (uint i=0; i<length; i++) {
            if (pledgeAddressList[i] == pledgeAddress) {
                return;
            }
            if (i == length-1) {
                pledgeAddressList.push(pledgeAddress);
                return;
            }
        }
    }

    function removePledgeAddressFromValidator(address _pledgeAddress, address _validatorAddress) external {
        address[] storage pledgeAddressList = mappingValidatorToPledgeAddress[_validatorAddress];
        mappingPledgeAddressToValidatorAddress[_pledgeAddress] = 0;
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
        address[] storage pledgeAddressList = mappingValidatorToPledgeAddress[_validatorAddress];
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

    function pledgeRevert(uint _now, address minerAddress) external payable {
        uint pos = PledgeIndex[minerAddress];
        PledgeMiner memory miner = PledgeMinerList[pos - 1];
        require(miner.owner != address(0), "invail address");
        require(miner.status != 1, "status is unaviable, can not revert pledge");

        // miner.status = 1;
        // miner.pledgeTime = _now;

        delete PledgeIndex[minerAddress];
        removePledgeMiner(pos - 1);
        // TODO  handler PledgeIndex
        handlerPledgeIndex(pos);

        deleteMinerSellOrder(minerAddress);
        minerAddress.transfer(miner.money);
    }

    function handlerPledgeIndex(uint pos) internal {
        for (uint i=0; i<PledgeMinerList.length; i++) {
            address miner = PledgeMinerList[i].owner;
            uint index = PledgeIndex[miner];
            if (index > pos) {
                PledgeIndex[miner] = index - 1;
            }
        }
    }

    function removePledgeMiner(uint index) internal {
        if (index >= PledgeMinerList.length) return;

        for (uint i = index; i<PledgeMinerList.length-1; i++){
            PledgeMinerList[i] = PledgeMinerList[i+1];
        }
        delete PledgeMinerList[PledgeMinerList.length-1];
        PledgeMinerList.length--;
    }

    // ----------------------------------- sellOrder data store   method  -----------------------------------------
    // order data
    mapping(address => Order[]) internal StorageAddressOrder;
    Order [] internal SellOrderList;
    Order [] internal BuyOrderList; // save success match buy order;
    mapping(uint => Order[]) internal mappingPriceSellOrderList;
    uint[] internal priceList;

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
        delete StorageAddressOrder[_address];
        handlerMinerMatchOrder(_address);
    }

    function removeOrder(Order[] storage orderList, uint index) internal {
        if (index >= orderList.length) return;

        for (uint i = index; i<orderList.length-1; i++){
            orderList[i] = orderList[i+1];
        }
        delete orderList[orderList.length-1];
        orderList.length--;
    }

    // ----------------------------------- matchOrder data store   method  -----------------------------------------
    // matchOrder data
    MatchOrder [] internal MatchOrderList;
    mapping(address => MatchOrder) internal mappingOrderIdToMatchOrder;
    mapping(address => MatchOrder[]) internal mappingAddressToMatchOrder;

    function handlerMinerMatchOrder(address _address) internal {
        changeStatusMatchOrder(_address);
    }

    function changeStatusMatchOrder(address _address) internal {
        for (uint i=0; i<MatchOrderList.length; i++) {
            // address memory sellAddress = MatchOrderList[i].SellAddress;
            if (MatchOrderList[i].SellAddress == _address) {
                if (MatchOrderList[i].status == 1) {
                    MatchOrderList[i].status = 3;
                }
                if (mappingOrderIdToMatchOrder[MatchOrderList[i].orderId].status == 1) {
                    mappingOrderIdToMatchOrder[MatchOrderList[i].orderId].status = 3;
                }
                MatchOrder[] storage matchBuyOrderList = mappingAddressToMatchOrder[MatchOrderList[i].BuyAddress];
                for (uint j=0; j<matchBuyOrderList.length; j++) {
                    if (matchBuyOrderList[j].SellAddress == _address && matchBuyOrderList[j].status == 1) {
                        matchBuyOrderList[j].status = 3;
                    }
                }
                MatchOrder[] storage matchSellOrderList = mappingAddressToMatchOrder[_address];
                for (uint k=0; j<matchSellOrderList.length; k++) {
                    if (matchSellOrderList[k].status == 1) {
                        matchSellOrderList[k].status = 3;
                    }
                }
            }
        }
    }


    // function withdrawPledge(uint _now, address minerAddress) external {
    //     uint pos = PledgeIndex[minerAddress];
    //     PledgeMiner memory miner = PledgeMinerList[pos - 1];
    //     require(miner.owner != address(0), "invail address");
    //     require(miner.status == 1, "pledge is aviable");
    //     // TODO
    //     require((now - miner.pledgeTime) >= (90 * 1 days), "time is not satisfy");
    //     // require((_now - miner.pledgeTime) >= (90 * 1), "time is not satisfy");

    //     delete PledgeIndex[minerAddress];
    //     delete PledgeMinerList[pos - 1];
    //     minerAddress.transfer(miner.money);
    // }

    function createOrder(uint _size, uint _price, uint _duration, uint _mold, uint256 _peerId, uint _now, address _address) public payable {
        // if mold == 0  sell
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
                _peerId
            ));
        // create Order
        Order memory order = Order({
            orderId: address(orderId),
            owner: _address,
            price: _price,
            size: _size,
            mold: _mold,
            createTime: _now,
            duration: _duration * 1 days,
            peerId: _peerId,
            sellSize: _size
            });

        if (_mold == 0) {
            // sort list
            SellOrderList.push(order);
            saveOrderInformation(order);
            StorageAddressOrder[_address].push(order);
            PledgeMinerList[index - 1].useSize += _size;
        } else {
            executeOrder(order, _now, msg.value);
        }
    }

    function saveOrderInformation(Order memory order) internal {
        uint price = order.price;
        handlerPrice(price);
        handlerCreateOrderTime(price, order);
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

    function handlerCreateOrderTime(uint _price, Order memory _order) internal {
        Order [] storage createOrderList = mappingPriceSellOrderList[_price];
        uint length = createOrderList.length;
        if (length == 0) {
            createOrderList.push(_order);
        } else {
            for (uint i=0; i<length; i++) {
                if (createOrderList[i].createTime >= _order.createTime) {
                    for (uint j=length; j>i; j--) {
                        createOrderList[j] = createOrderList[j-1];
                        if (j == i+1) {
                            createOrderList[i] = _order;
                            return;
                        }
                    }
                }
                if (i == (length - 1)) {
                    createOrderList.push(_order);
                    return;
                }
            }
        }
    }

    function executeOrder(Order memory _order, uint _now, uint _money) public payable {
        address owner = _order.owner;
        uint price = _order.price;
        uint size = _order.size;
        uint duration = _order.duration;
        (Order memory order, uint findPrice) = findOrderByPriceOrSize(size, price, duration);
        require(order.owner != _order.owner, "not allow buy and sell one address");
        require (order.orderId != 0, "can not find match sell Order");
        systemOrder(_order, order, _now, _money);
    }

    function systemOrder(Order memory buyOrder, Order memory sellOrder, uint _now, uint _money) public payable {
        address buyAddress = buyOrder.owner;
        address sellAddress = sellOrder.owner;
        bytes32 orderId = keccak256(abi.encodePacked(
                buyAddress,
                sellAddress,
                buyOrder.price,
                buyOrder.size,
                _now
            ));
        uint buyMoney = (buyOrder.size * sellOrder.price * (buyOrder.duration / 1 days)) / 1024;
        uint divValue = _money - buyMoney;
        require(divValue >= 0, "money is not enough");
        if (divValue >= 0) {
            buyOrder.owner.transfer(divValue);
        }

        MatchOrder memory matchOrder = MatchOrder({
            orderId: address(orderId),
            SellAddress: sellAddress,
            BuyAddress: buyAddress,
            SellOrderId: sellOrder.orderId,
            BuyOrderId: buyOrder.orderId,
            size: buyOrder.size,
            price: sellOrder.price,
            createTime: _now,
            peerId: sellOrder.peerId,
            status: 0,
            endTime: _now + buyOrder.duration,
            settleTime: _now,
            amount: buyMoney
            });

        MatchOrderList.push(matchOrder);

        mappingOrderIdToMatchOrder[address(orderId)] = matchOrder;

        mappingAddressToMatchOrder[sellAddress].push(matchOrder);

        mappingAddressToMatchOrder[buyAddress].push(matchOrder);

        bytes32 buyBytes = bytes32(uint256(buyAddress) << 96);

        bytes32 sellBytes = bytes32(uint256(sellAddress) << 96);

        bytes32 orderIdBytes = bytes32(uint256(orderId) << 96);

        order(orderIdBytes, buyBytes, sellBytes, sellOrder.peerId);

        handerBuyOrder(buyOrder, BuyOrderList);
        handerSellOrder(buyOrder, sellOrder, SellOrderList);
        handerStorageAddressOrder(buyOrder, sellOrder);
        handerMappingSellOrderList(sellOrder.price, sellOrder.orderId, buyOrder.size, false);
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
                    if (orderList.length == 0) {
                        return;
                    }
                    removeOrder(orderList, i);
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

    function cancelOrder(address _orderId, address owner) external returns (Order memory) {
        (Order memory order, uint index) = findOrderByOrderId(owner, _orderId);
        require(owner == order.owner, "you are not have this order");
        // remove order from list;
        // add size to pledge
        removeOrder(SellOrderList, index);
        handerMappingSellOrderList(order.price, order.orderId, order.size, true);
        handerMappingSellOrderStorage(_orderId, owner);
        backOrderSizeToPledge(order);
    }

    function handerMappingSellOrderStorage(address _orderId, address owner) internal {
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

    function backOrderSizeToOrder(MatchOrder memory _matchOrder) internal {
        uint size = _matchOrder.size;
        address sellOrderId = _matchOrder.SellOrderId;
        address sellAddress = _matchOrder.SellAddress;
        uint price = _matchOrder.price;
        Order[] storage orderList = StorageAddressOrder[sellAddress];
        for (uint i=0; i<orderList.length; i++) {
            if (orderList[i].orderId == sellOrderId) {
                orderList[i].size += size;
            }
        }
        for (uint j=0; j<SellOrderList.length; j++) {
            if (SellOrderList[j].orderId == sellOrderId) {
                SellOrderList[j].size += size;
            }
        }
        Order[] storage priceOrderList = mappingPriceSellOrderList[price];
        for (uint k=0; k<priceOrderList.length; k++) {
            if (priceOrderList[k].orderId == sellOrderId) {
                priceOrderList[k].size += size;
            }
        }
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
        uint duration = order.endTime - order.createTime;
        uint transferMoney = order.amount * (div / 1 days) / (duration / 1 days);
        //        uint transferMoney = order.amount * (div / 60) / (duration / 1 days);
        // require(price != 0, "time is not enough");
        uint newSettleTime = settleTime - (div % 1 days);
        //        uint newSettleTime = settleTime - (div % 60);

        MatchOrderList[i].settleTime =  newSettleTime;
        MatchOrderList[i].status = 1;

        if (newSettleTime > order.endTime) {
            // delete matchOrder
            MatchOrderList[i].status = 2;

            updateOwnerToMatchOrderList(order.SellAddress, order.orderId, order.endTime, 2);

            updateOwnerToMatchOrderList(order.BuyAddress, order.orderId, order.endTime, 2);

            updateOrderIdToMatchOrderList(order.orderId, order.endTime, 2);

            backOrderSizeToOrder(order);

        } else {

            updateOwnerToMatchOrderList(order.SellAddress, order.orderId, newSettleTime, 1);

            updateOwnerToMatchOrderList(order.BuyAddress, order.orderId, newSettleTime, 1);

            updateOrderIdToMatchOrderList(order.orderId, newSettleTime, 1);

            // cancel send pdp reward
            sellOwner.transfer(transferMoney);
        }
    }


    // get pledge miner list interface
    function getPledgeMinerList(uint pageNum, uint showNum) external view returns (PledgeMiner[] memory) {
        if (pageNum == 0 && showNum == 0) {
            return PledgeMinerList;
        }
        uint start = (pageNum - 1) * showNum;
        uint end = pageNum * showNum;
        PledgeMiner[] memory result;
        uint length = PledgeMinerList.length;
        if (start > length) {
            return result;
        }
        if (end > length) {
            end = length;
        }
        result = new PledgeMiner[](end - start);
        for (uint i=start; i<end; i++) {
            result[i-start] = PledgeMinerList[i];
        }
        return result;
    }

    function getOrderListByAddress(address _address, uint pageNum, uint showNum) external view returns (Order[] memory) {
        Order[] memory orderList = StorageAddressOrder[_address];
        if (pageNum == 0 && showNum == 0) {
            return orderList;
        }

        uint start = (pageNum - 1) * showNum;
        uint end = pageNum * showNum;
        Order[] memory result;
        uint length = orderList.length;
        if (start > length) {
            return result;
        }
        if (end > length) {
            end = length;
        }
        result = new Order[](end - start);
        for (uint i=start; i<end; i++) {
            result[i-start] = orderList[i];
        }
        return result;
    }

    function filterMatchOrderListByFlag(MatchOrder[] memory list, address _address, uint flag) internal returns (MatchOrder[] memory) {
        if (flag == 2) {
            return list;
        }
        uint buyOrderNum = 0;
        uint sellOrderNum = 0;
        MatchOrder[] memory result;
        for (uint i=0; i<list.length; i++) {
            if (list[i].BuyAddress == _address) {
                buyOrderNum += 1;
            }
            if (list[i].SellAddress == _address) {
                sellOrderNum += 1;
            }
        }

        if (flag == 0) {
            result = new MatchOrder[](buyOrderNum);
            uint buyCount = 0;
            for (uint j=0; j<list.length; j++) {
                if (list[j].BuyAddress == _address) {
                    result[buyCount] = list[j];
                    buyCount += 1;
                }
            }
        } else {
            uint sellCount = 0;
            result = new MatchOrder[](sellOrderNum);
            for (uint k=0; k<list.length; k++) {
                if (list[j].SellAddress == _address) {
                    result[sellCount] = list[k];
                    sellCount += 1;
                }
            }
        }
        return result;
    }

    // flag 0 or 1    0 mean buy
    function getMatchOrderListByAddress(address _address, uint pageNum, uint showNum, uint flag) external returns (MatchOrder[] memory) {
        MatchOrder[] memory matchOrderList = mappingAddressToMatchOrder[_address];

        MatchOrder [] memory filterMatchOrderList = filterMatchOrderListByFlag(matchOrderList, _address, flag);

        if (pageNum == 0 && showNum == 0) {
            return filterMatchOrderList;
        }

        uint start = (pageNum - 1) * showNum;
        uint end = pageNum * showNum;
        MatchOrder[] memory result;
        uint length = filterMatchOrderList.length;
        if (start > length) {
            return result;
        }
        if (end > length) {
            end = length;
        }
        result = new MatchOrder[](end - start);
        for (uint index=start; index<end; index++) {
            result[index-start] = filterMatchOrderList[index];
        }
        return result;
    }

    function getMappingPriceSellOrderList(uint x) external view returns (Order[] memory) {
        return mappingPriceSellOrderList[x];
    }

    function getSellOrderList(uint pageNum, uint showNum) external view returns (Order[] memory) {
        if (pageNum == 0 && showNum == 0) {
            return SellOrderList;
        }
        uint start = (pageNum - 1) * showNum;
        uint end = pageNum * showNum;
        Order[] memory result;
        uint length = SellOrderList.length;
        if (start > length) {
            return result;
        }
        if (end > length) {
            end = length;
        }
        result = new Order[](end - start);
        for (uint i=start; i<end; i++) {
            result[i-start] = SellOrderList[i];
        }
        return result;
    }

    function getMatchOrderList(uint pageNum, uint showNum) external view returns (MatchOrder[] memory) {
        if (pageNum == 0 && showNum == 0) {
            return MatchOrderList;
        }
        uint start = (pageNum - 1) * showNum;
        uint end = pageNum * showNum;
        MatchOrder[] memory result;
        uint length = MatchOrderList.length;
        if (start > length) {
            return result;
        }
        if (end > length) {
            end = length;
        }
        result = new MatchOrder[](end - start);
        for (uint i=start; i<end; i++) {
            result[i-start] = MatchOrderList[i];
        }
        return result;
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

    function getValidatorPledgeListByValidatorAddress(address _validatorAddress) external view returns (PledgeMiner[]) {
        address[] storage pledgeAddressList =  mappingValidatorToPledgeAddress[_validatorAddress];
        uint length = pledgeAddressList.length;
        PledgeMiner[] memory list = new PledgeMiner[](length);
        for (uint i=0; i<length; i++) {
            PledgeMiner memory p = findPledgeFromList(pledgeAddressList[i]);
            list[i] = p;
        }
        return list;
    }

    function findPledgeFromList(address _pledgeAddress) internal view returns (PledgeMiner) {
        uint length = PledgeMinerList.length;
        for (uint i=0; i<length; i++) {
            if (PledgeMinerList[i].owner == _pledgeAddress) {
                return PledgeMinerList[i];
            }
        }
    }

    // libs
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

}
