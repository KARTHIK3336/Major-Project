// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Errors
error CrowdFunding__CampaignDoesNotExist();
error InputsCantBeNull();
error DeadlineShouldBeInFuture();
error AmountDonatedMustBeGreaterThanZero(uint minAmount, uint donatedAmount);
error DeadlineReached(uint campaignDeadline, uint timeRequested);

contract CrowdFunding {
    struct Campaign {
        address owner;
        string name;
        string category;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
        bool active;
    }

    event Action(
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    event DonationReceived(uint256 campaignId, address donor, uint256 amount);
    event FundsTransferred(uint256 campaignId, address recipient, uint256 amount);

    address public manager;
    mapping(uint256 => Campaign) public campaigns;
    uint256 public numberOfCampaigns;

    constructor() {
        manager = msg.sender;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Not owner");
        _;
    }

    modifier authorisedPerson(uint _id) {
        require(campaigns[_id].active, "Campaign does not exist");
        require(msg.sender == campaigns[_id].owner, "Not Authorised");
        _;
    }

    function createCampaign(
        string memory _name,
        string memory _title,
        string memory _category,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) public returns (uint256) {
        require(_deadline > block.timestamp, "Deadline should be in the future");

        Campaign storage campaign = campaigns[numberOfCampaigns];

        campaign.owner = msg.sender;
        campaign.name = _name;
        campaign.title = _title;
        campaign.category = _category;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;
        campaign.active = true;

        numberOfCampaigns++;

        return numberOfCampaigns - 1;
    }

    function donateToCampaign(uint256 _id) public payable {
        uint256 amount = msg.value;
        require(amount > 0, "Amount donated must be greater than zero");

        Campaign storage campaign = campaigns[_id];
        require(campaign.active, "Campaign does not exist");
        require(campaign.deadline > block.timestamp, "Deadline reached");

        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);
        campaign.amountCollected += amount;

        emit DonationReceived(_id, msg.sender, amount);

        // If the campaign reaches the target, transfer funds immediately
        if (campaign.amountCollected >= campaign.target) {
            uint256 amountToTransfer = campaign.amountCollected;
            campaign.amountCollected = 0; // Prevent reentrancy
            _payTo(campaign.owner, amountToTransfer);

            emit FundsTransferred(_id, campaign.owner, amountToTransfer);
        }
    }

    function deleteCampaign(uint256 _id) public authorisedPerson(_id) returns (bool) {
        Campaign storage campaign = campaigns[_id];
        require(campaign.active, "Campaign does not exist");

        if (campaign.amountCollected > 0) {
            _refundDonators(_id);
        }

        campaign.active = false;
        emit Action(_id, "Campaign Deleted", msg.sender, block.timestamp);

        return true;
    }

    function _refundDonators(uint _id) internal {
        Campaign storage campaign = campaigns[_id];

        for (uint i = 0; i < campaign.donators.length; i++) {
            address donator = campaign.donators[i];
            uint256 donationAmount = campaign.donations[i];

            campaign.donations[i] = 0;
            _payTo(donator, donationAmount);
        }

        campaign.amountCollected = 0;
        delete campaign.donators;
        delete campaign.donations;
    }

    function _payTo(address to, uint256 amount) internal {
        require(amount > 0, "Can't send 0");
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getDonators(uint256 _id) public view returns (address[] memory, uint256[] memory) {
        require(campaigns[_id].active, "Campaign does not exist");
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        uint activeCampaignsCount = 0;

        for (uint i = 0; i < numberOfCampaigns; i++) {
            if (campaigns[i].active) {
                activeCampaignsCount++;
            }
        }

        Campaign[] memory allCampaigns = new Campaign[](activeCampaignsCount);
        uint index = 0;

        for (uint i = 0; i < numberOfCampaigns; i++) {
            if (campaigns[i].active) {
                allCampaigns[index] = campaigns[i];
                index++;
            }
        }

        return allCampaigns;
    }
}
