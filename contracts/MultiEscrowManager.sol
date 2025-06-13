// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";


contract MultiEscrowManager is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    enum EscrowStatus { Created, Approved, Released, Refunded, Disputed }

    struct Escrow {
        address payable buyer;
        address payable seller;
        uint256 amount;
        uint256 deadline;
        uint256 createdAt;
        EscrowStatus status;
    }

    uint256 public escrowCount;
    uint256 public platformFeeBps;
    uint256 public cancelFeeBps;
    uint256 public constant MAX_CANCEL_FEE_BPS = 500;
    uint256 public constant CANCEL_WINDOW = 72 hours;
    bytes32 public termsHash;
    address public feeCollector;

    mapping(uint256 => Escrow) public escrows;
    mapping(address => bytes32) public acceptedTerms;

    event EscrowCreated(uint256 indexed id, address indexed buyer, address indexed seller, uint256 amount, uint256 fee);
    event FundsApproved(uint256 indexed id);
    event FundsReleased(uint256 indexed id);
    event EscrowRefunded(uint256 indexed id, uint256 fee);
    event EscrowDisputed(uint256 indexed id);
    event DisputeResolved(uint256 indexed id, address winner);
    event PlatformFeeUpdated(uint256 newFeeBps);
    event CancelFeeUpdated(uint256 newCancelFeeBps);
    event TermsUpdated(bytes32 newHash);

    modifier onlyEscrowBuyer(uint256 id) {
        require(escrows[id].buyer == msg.sender, "Not buyer");
        _;
    }

    modifier onlyEscrowSeller(uint256 id) {
        require(escrows[id].seller == msg.sender, "Not seller");
        _;
    }

    modifier validEscrow(uint256 id) {
        require(id > 0 && id <= escrowCount, "Invalid escrow ID");
        _;
    }

    function initialize(address _feeCollector, uint256 _platformFeeBps, uint256 _cancelFeeBps, bytes32 _termsHash) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        platformFeeBps = _platformFeeBps;
        cancelFeeBps = _cancelFeeBps;
        termsHash = _termsHash;
        feeCollector = _feeCollector;
    }

    function acceptTerms(bytes32 _hash) external {
        require(_hash == termsHash, "Invalid terms");
        acceptedTerms[msg.sender] = _hash;
    }

    function createEscrow(address payable _seller, uint256 _deadline) external payable nonReentrant {
        require(msg.value > 0, "Must send funds");
        require(acceptedTerms[msg.sender] == termsHash, "Terms not accepted");

        escrowCount++;
        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 net = msg.value - fee;

        escrows[escrowCount] = Escrow({
            buyer: payable(msg.sender),
            seller: _seller,
            amount: net,
            deadline: _deadline,
            createdAt: block.timestamp,
            status: EscrowStatus.Created
        });

        payable(feeCollector).transfer(fee);
        emit EscrowCreated(escrowCount, msg.sender, _seller, net, fee);
    }

    function approveEscrow(uint256 id) external onlyEscrowBuyer(id) validEscrow(id) {
        require(escrows[id].status == EscrowStatus.Created, "Invalid status");
        escrows[id].status = EscrowStatus.Approved;
        emit FundsApproved(id);
    }

    function releaseEscrow(uint256 id) external validEscrow(id) {
        Escrow storage e = escrows[id];
        require(e.status == EscrowStatus.Approved, "Not approved");
        require(msg.sender == e.buyer || msg.sender == owner(), "Not authorized");

        e.status = EscrowStatus.Released;
        e.seller.transfer(e.amount);
        emit FundsReleased(id);
    }

    function refundEscrow(uint256 id) external validEscrow(id) onlyEscrowBuyer(id) {
        Escrow storage e = escrows[id];
        require(e.status == EscrowStatus.Created, "Invalid status");
        require(block.timestamp <= e.createdAt + CANCEL_WINDOW, "Too late to cancel");

        e.status = EscrowStatus.Refunded;
        uint256 fee = (e.amount * cancelFeeBps) / 10000;
        payable(feeCollector).transfer(fee);
        e.buyer.transfer(e.amount - fee);
        emit EscrowRefunded(id, fee);
    }

    function disputeEscrow(uint256 id) external validEscrow(id) {
        Escrow storage e = escrows[id];
        require(msg.sender == e.buyer || msg.sender == e.seller, "Not party to escrow");
        require(e.status == EscrowStatus.Approved, "Invalid status");

        e.status = EscrowStatus.Disputed;
        emit EscrowDisputed(id);
    }

    function resolveDispute(uint256 id, address winner) external onlyOwner validEscrow(id) {
        Escrow storage e = escrows[id];
        require(e.status == EscrowStatus.Disputed, "Not disputed");

        e.status = EscrowStatus.Released;
        payable(winner).transfer(e.amount);
        emit DisputeResolved(id, winner);
    }

    function updatePlatformFee(uint256 newBps) external onlyOwner {
        require(newBps <= 1000, "Too high");
        platformFeeBps = newBps;
        emit PlatformFeeUpdated(newBps);
    }

    function updateCancelFee(uint256 newBps) external onlyOwner {
        require(newBps <= MAX_CANCEL_FEE_BPS, "Too high");
        cancelFeeBps = newBps;
        emit CancelFeeUpdated(newBps);
    }

    function updateTermsHash(bytes32 newHash) external onlyOwner {
        termsHash = newHash;
        emit TermsUpdated(newHash);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
