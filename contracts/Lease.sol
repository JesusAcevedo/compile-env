// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Lease is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    enum LeaseStatus { Active, Terminated, Expired }

    struct LeaseAgreement {
        uint256 id;
        address lessor;
        address lessee;
        uint256 rent;
        uint256 deposit;
        uint256 startDate;
        uint256 endDate;
        LeaseStatus status;
    }

    uint256 public leaseCount;
    uint256 public leaseFee;
    uint256 public fundPool;

    mapping(uint256 => LeaseAgreement) public leases;
    mapping(address => uint256[]) public userLeases;

    event LeaseCreated(uint256 indexed id, address indexed lessor, address indexed lessee, uint256 rent);
    event LeaseTerminated(uint256 indexed id);
    event FundsDeposited(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier validLease(uint256 id) {
        require(id > 0 && id <= leaseCount, "Invalid lease ID");
        _;
    }

    modifier onlyActive(uint256 id) {
        require(leases[id].status == LeaseStatus.Active, "Lease is not active");
        _;
    }

    function initialize(uint256 _leaseFee) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        leaseFee = _leaseFee;
    }

    function createLease(
        address lessee,
        uint256 rent,
        uint256 deposit,
        uint256 duration
    ) external payable {
        require(msg.value >= leaseFee, "Insufficient lease fee");
        leaseCount++;
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + duration;
        leases[leaseCount] = LeaseAgreement(leaseCount, msg.sender, lessee, rent, deposit, startDate, endDate, LeaseStatus.Active);
        userLeases[msg.sender].push(leaseCount);
        fundPool += msg.value;
        emit LeaseCreated(leaseCount, msg.sender, lessee, rent);
    }

    function terminateLease(uint256 id) external onlyOwner validLease(id) onlyActive(id) {
        leases[id].status = LeaseStatus.Terminated;
        emit LeaseTerminated(id);
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
