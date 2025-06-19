// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DisputeResolution is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    enum DisputeStatus { Open, Resolved, Rejected }

    struct Dispute {
        uint256 id;
        address initiator;
        address respondent;
        string reason;
        string resolution;
        DisputeStatus status;
        uint256 timestamp;
    }

    uint256 public disputeCount;
    uint256 public arbitrationFee;
    uint256 public fundPool;

    mapping(uint256 => Dispute) public disputes;
    mapping(address => uint256[]) public userDisputes;

    event DisputeFiled(uint256 indexed id, address indexed initiator, address indexed respondent, string reason);
    event DisputeResolved(uint256 indexed id, string resolution);
    event DisputeRejected(uint256 indexed id);
    event FundsDeposited(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier validDispute(uint256 id) {
        require(id > 0 && id <= disputeCount, "Invalid dispute ID");
        _;
    }

    modifier onlyOpen(uint256 id) {
        require(disputes[id].status == DisputeStatus.Open, "Dispute not open");
        _;
    }

    function initialize(uint256 _fee) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        arbitrationFee = _fee;
    }

    function fileDispute(address respondent, string calldata reason) external payable {
        require(msg.value >= arbitrationFee, "Insufficient fee");
        disputeCount++;
        disputes[disputeCount] = Dispute(disputeCount, msg.sender, respondent, reason, "", DisputeStatus.Open, block.timestamp);
        userDisputes[msg.sender].push(disputeCount);
        fundPool += msg.value;
        emit DisputeFiled(disputeCount, msg.sender, respondent, reason);
    }

    function resolveDispute(uint256 id, string calldata resolution) external onlyOwner validDispute(id) onlyOpen(id) {
        disputes[id].status = DisputeStatus.Resolved;
        disputes[id].resolution = resolution;
        emit DisputeResolved(id, resolution);
    }

    function rejectDispute(uint256 id) external onlyOwner validDispute(id) onlyOpen(id) {
        disputes[id].status = DisputeStatus.Rejected;
        emit DisputeRejected(id);
    }

    function depositFunds() external payable {
        fundPool += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= fundPool, "Insufficient pool");
        fundPool -= amount;
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
