// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./FundingRecipient.sol";

contract CrowdFund {
    error CrowdFund__AlreadyCompleted();
    error CrowdFund__DeadlineNotReached();
    error CrowdFund__GoalAlreadyReached();
    error CrowdFund__GoalNotReached();
    error CrowdFund__NoContribution();
    error CrowdFund__WithdrawFailed();
    error CrowdFund__ExecuteFailed();

    FundingRecipient public fundingRecipient;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalContributions;
    mapping(address => uint256) public contributions;

    event Contributed(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed contributor, uint256 amount);
    event Executed(uint256 totalAmount);

    modifier notCompleted() {
        if (fundingRecipient.completed()) revert CrowdFund__AlreadyCompleted();
        _;
    }

    constructor(address fundingRecipientAddress) {
        fundingRecipient = FundingRecipient(fundingRecipientAddress);
        goal = 1 ether;
        deadline = block.timestamp + 30 days;
    }

    function contribute() public payable notCompleted {
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function withdraw() public notCompleted {
        if (block.timestamp < deadline) revert CrowdFund__DeadlineNotReached();
        if (totalContributions >= goal) revert CrowdFund__GoalAlreadyReached();
        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert CrowdFund__NoContribution();
        contributions[msg.sender] = 0;
        totalContributions -= amount;
        (bool sent,) = msg.sender.call{value: amount}("");
        if (!sent) revert CrowdFund__WithdrawFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function execute() public notCompleted {
        if (totalContributions < goal) revert CrowdFund__GoalNotReached();
        uint256 amount = address(this).balance;
        (bool sent,) = payable(address(fundingRecipient)).call{value: amount}("");
        if (!sent) revert CrowdFund__ExecuteFailed();
        fundingRecipient.complete();
        emit Executed(amount);
    }

    receive() external payable {
        contribute();
    }

    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}