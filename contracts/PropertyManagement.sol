// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PropertyManagement is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    struct Property {
        uint256 id;
        string location;
        address manager;
        uint256 rent;
        bool isRented;
    }

    uint256 public propertyCount;
    uint256 public maintenanceFeeBps;
    uint256 public fundPool;

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public managedProperties;

    event PropertyAdded(uint256 id, string location, address indexed manager, uint256 rent);
    event RentCollected(uint256 id, address indexed from, uint256 amount);
    event MaintenanceFeeCollected(uint256 id, uint256 fee);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier onlyManager(uint256 propertyId) {
        require(properties[propertyId].manager == msg.sender, "Not manager");
        _;
    }

    function initialize(uint256 _maintenanceFeeBps) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        maintenanceFeeBps = _maintenanceFeeBps;
    }

    function addProperty(string calldata location, uint256 rent) external {
        propertyCount++;
        properties[propertyCount] = Property(propertyCount, location, msg.sender, rent, false);
        managedProperties[msg.sender].push(propertyCount);
        emit PropertyAdded(propertyCount, location, msg.sender, rent);
    }

    function collectRent(uint256 propertyId) external payable nonReentrant {
        Property storage prop = properties[propertyId];
        require(!prop.isRented, "Already rented");
        require(msg.value >= prop.rent, "Insufficient rent");

        uint256 fee = (msg.value * maintenanceFeeBps) / 10000;
        fundPool += fee;

        payable(prop.manager).transfer(msg.value - fee);
        prop.isRented = true;

        emit RentCollected(propertyId, msg.sender, msg.value);
        emit MaintenanceFeeCollected(propertyId, fee);
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= fundPool, "Insufficient pool");
        fundPool -= amount;
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
