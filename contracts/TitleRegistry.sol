// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TitleRegistry is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Title {
        string titleId;
        address currentOwner;
        string propertyDetails;
        uint256 registeredAt;
    }

    mapping(string => Title) private titles;
    uint256 public registrationFee; // in wei
    address public feeCollector;

    event TitleRegistered(string indexed titleId, address indexed owner, string propertyDetails);
    event TitleTransferred(string indexed titleId, address indexed from, address indexed to);
    event FeeUpdated(uint256 newFee);
    event CollectorUpdated(address newCollector);

    function initialize(uint256 _fee, address _collector) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        registrationFee = _fee;
        feeCollector = _collector;
    }

    function registerTitle(string calldata titleId, string calldata propertyDetails) external payable {
        require(titles[titleId].registeredAt == 0, "Already registered");
        require(msg.value >= registrationFee, "Insufficient fee");
        titles[titleId] = Title(titleId, msg.sender, propertyDetails, block.timestamp);
        payable(feeCollector).transfer(msg.value);
        emit TitleRegistered(titleId, msg.sender, propertyDetails);
    }

    function transferTitle(string calldata titleId, address to) external {
        require(titles[titleId].currentOwner == msg.sender, "Not title owner");
        titles[titleId].currentOwner = to;
        emit TitleTransferred(titleId, msg.sender, to);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
        emit FeeUpdated(newFee);
    }

    function updateCollector(address newCollector) external onlyOwner {
        feeCollector = newCollector;
        emit CollectorUpdated(newCollector);
    }

    function getTitle(string calldata titleId) external view returns (Title memory) {
        return titles[titleId];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
