pragma solidity ^0.4.24;
pragma experimental "ABIEncoderV2";

contract LambdaMatchOrder {

    uint LAMBDA_TOKEN = 10**18;

    mapping(address => StorageDetail) internal mappingAddressForStorageDetail;

    struct StorageDetail {
        uint PledgeTotalSize;
        uint UseSize;
    }

    constructor () public payable {

    }

    function validatorPledge() external payable {

    }

    function validatorRevert(uint money) external payable {
        msg.sender.transfer(money);
    }

    function pledge(address mAddress, uint pledgeSize) external payable {
        StorageDetail storage detail = mappingAddressForStorageDetail[mAddress];
        detail.PledgeTotalSize += pledgeSize;
    }

    function pledgeRevert(address minerAddress, uint revertMoney) external payable {
        minerAddress.transfer(revertMoney);
        delete mappingAddressForStorageDetail[minerAddress];
    }

    function createSellOrder(address mAddress, uint size) public {
        StorageDetail storage detail = mappingAddressForStorageDetail[mAddress];
        detail.UseSize += size;
    }

    function createOrder() public payable {

    }

    function cancelOrder(address mAddress, uint size) external {
        StorageDetail storage detail = mappingAddressForStorageDetail[mAddress];
        detail.UseSize -= size;
    }

    function settle(address minerAddress, uint settleMoney) external payable {
        minerAddress.transfer(settleMoney);
    }

}
