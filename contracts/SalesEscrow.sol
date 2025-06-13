// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SalesEscrow is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    enum EscrowStatus { Pending, Completed, Refunded }

    struct Escrow {
        address buyer;
        address seller;
        uint256 amount;
        EscrowStatus status;
    }

    uint256 public escrowCount;
    uint256 public platformFeePercent;
    address public feeCollector;

    mapping(uint256 => Escrow) public escrows;

    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 amount);
    event EscrowCompleted(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);
    event FeeCollectorUpdated(address indexed newCollector);
    event PlatformFeeUpdated(uint256 newFeePercent);

    modifier validEscrow(uint256 escrowId) {
        require(escrowId > 0 && escrowId <= escrowCount, "Invalid escrow ID");
        _;
    }

    modifier onlyPending(uint256 escrowId) {
        require(escrows[escrowId].status == EscrowStatus.Pending, "Escrow not pending");
        _;
    }

    function initialize(uint256 _platformFeePercent, address _feeCollector) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        require(_feeCollector != address(0), "Invalid fee collector");
        require(_platformFeePercent <= 100, "Fee too high");
        platformFeePercent = _platformFeePercent;
        feeCollector = _feeCollector;
    }

    function createEscrow(address seller) external payable returns (uint256) {
        require(seller != address(0), "Invalid seller address");
        require(msg.value > 0, "Amount must be greater than 0");

        escrowCount++;
        escrows[escrowCount] = Escrow({
            buyer: msg.sender,
            seller: seller,
            amount: msg.value,
            status: EscrowStatus.Pending
        });

        emit EscrowCreated(escrowCount, msg.sender, seller, msg.value);
        return escrowCount;
    }

    function completeEscrow(uint256 escrowId) external validEscrow(escrowId) onlyPending(escrowId) {
        Escrow storage esc = escrows[escrowId];
        require(msg.sender == esc.buyer, "Only buyer can complete");

        uint256 fee = (esc.amount * platformFeePercent) / 100;
        uint256 sellerAmount = esc.amount - fee;

        esc.status = EscrowStatus.Completed;
        payable(esc.seller).transfer(sellerAmount);
        payable(feeCollector).transfer(fee);

        emit EscrowCompleted(escrowId);
    }

    function refundEscrow(uint256 escrowId) external validEscrow(escrowId) onlyPending(escrowId) {
        Escrow storage esc = escrows[escrowId];
        require(msg.sender == owner() || msg.sender == esc.seller, "Unauthorized");

        esc.status = EscrowStatus.Refunded;
        payable(esc.buyer).transfer(esc.amount);

        emit EscrowRefunded(escrowId);
    }

    function updateFeeCollector(address newCollector) external onlyOwner {
        require(newCollector != address(0), "Invalid address");
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    function updatePlatformFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Fee too high");
        platformFeePercent = newFeePercent;
        emit PlatformFeeUpdated(newFeePercent);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
