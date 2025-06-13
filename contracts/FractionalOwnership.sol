// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract FractionalOwnership is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address public propertyOwner;
    string public propertyDetails;
    uint256 public sharePrice;
    uint256 public platformFeeRate; // in basis points (e.g., 250 = 2.5%)
    address public feeCollector;

    event SharesPurchased(address indexed buyer, uint256 amount, uint256 fee);
    event OwnershipReset(string propertyDetails, uint256 sharePrice);

    modifier onlyPropertyOwner() {
        require(msg.sender == propertyOwner, "Not property owner");
        _;
    }

    function initialize(
        string memory name,
        string memory symbol,
        string memory _propertyDetails,
        uint256 _totalShares,
        uint256 _sharePrice,
        uint256 _platformFeeRate,
        address _feeCollector
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        propertyOwner = msg.sender;
        propertyDetails = _propertyDetails;
        sharePrice = _sharePrice;
        platformFeeRate = _platformFeeRate;
        feeCollector = _feeCollector;

        _mint(propertyOwner, _totalShares);
    }

    function buyShares(uint256 amount) external payable {
        uint256 totalPrice = sharePrice * amount;
        uint256 fee = (totalPrice * platformFeeRate) / 10000;

        require(msg.value >= totalPrice + fee, "Insufficient ETH for shares + fee");

        _transfer(propertyOwner, msg.sender, amount);

        payable(propertyOwner).transfer(totalPrice);
        payable(feeCollector).transfer(fee);

        emit SharesPurchased(msg.sender, amount, fee);
    }

    function resetProperty(string calldata _newDetails, uint256 _newSharePrice, uint256 _newTotalShares) external onlyOwner {
        propertyDetails = _newDetails;
        sharePrice = _newSharePrice;

        uint256 currentSupply = totalSupply();
        if (_newTotalShares > currentSupply) {
            _mint(propertyOwner, _newTotalShares - currentSupply);
        } else if (_newTotalShares < currentSupply) {
            _burn(propertyOwner, currentSupply - _newTotalShares);
        }

        emit OwnershipReset(_newDetails, _newSharePrice);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
