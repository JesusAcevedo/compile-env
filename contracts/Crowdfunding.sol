// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Crowdfunding is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct Project {
        address creator;
        uint256 goal;
        uint256 pledged;
        uint256 startTime;
        uint256 endTime;
        bool claimed;
    }

    uint256 public projectCount;
    mapping(uint256 => Project) public projects;
    mapping(address => mapping(uint256 => uint256)) public pledged;

    uint256 public feePercent; // fee in basis points (e.g. 250 = 2.5%)
    address public feeRecipient;

    event ProjectCreated(uint256 id, address indexed creator, uint256 goal, uint256 startTime, uint256 endTime);
    event Pledged(uint256 indexed id, address indexed pledger, uint256 amount);
    event Unpledged(uint256 indexed id, address indexed pledger, uint256 amount);
    event Claimed(uint256 indexed id);
    event Refunded(uint256 indexed id, address indexed pledger, uint256 amount);

    function initialize(address _feeRecipient, uint256 _feePercent) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        require(_feePercent <= 1000, "Fee too high"); // max 10%
        feeRecipient = _feeRecipient;
        feePercent = _feePercent;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createProject(uint256 _goal, uint256 _duration) external {
        require(_goal > 0, "Goal must be > 0");
        require(_duration > 0, "Duration must be > 0");

        uint256 id = ++projectCount;
        projects[id] = Project({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            claimed: false
        });

        emit ProjectCreated(id, msg.sender, _goal, block.timestamp, block.timestamp + _duration);
    }

    function pledge(uint256 _id) external payable {
        Project storage project = projects[_id];
        require(block.timestamp < project.endTime, "Funding period over");

        project.pledged += msg.value;
        pledged[msg.sender][_id] += msg.value;

        emit Pledged(_id, msg.sender, msg.value);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        Project storage project = projects[_id];
        require(block.timestamp < project.endTime, "Funding period over");
        require(pledged[msg.sender][_id] >= _amount, "Insufficient pledged");

        project.pledged -= _amount;
        pledged[msg.sender][_id] -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Unpledge transfer failed");

        emit Unpledged(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external {
        Project storage project = projects[_id];
        require(msg.sender == project.creator, "Not creator");
        require(block.timestamp >= project.endTime, "Funding not ended");
        require(project.pledged >= project.goal, "Goal not met");
        require(!project.claimed, "Already claimed");

        project.claimed = true;

        uint256 fee = (project.pledged * feePercent) / 10000;
        uint256 payout = project.pledged - fee;

        (bool sentFee, ) = feeRecipient.call{value: fee}("");
        require(sentFee, "Fee transfer failed");

        (bool sentPayout, ) = project.creator.call{value: payout}("");
        require(sentPayout, "Payout transfer failed");

        emit Claimed(_id);
    }

    function refund(uint256 _id) external {
        Project storage project = projects[_id];
        require(block.timestamp >= project.endTime, "Funding not ended");
        require(project.pledged < project.goal, "Goal met");

        uint256 amount = pledged[msg.sender][_id];
        require(amount > 0, "Nothing to refund");

        pledged[msg.sender][_id] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(_id, msg.sender, amount);
    }
}
