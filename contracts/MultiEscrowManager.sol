// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiEscrowManager {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    struct Escrow {
        address payable buyer;
        address payable seller;
        uint256 amount;
        bool isApproved;
        bool isReleased;
        uint256 deadline;
    }

    uint256 public escrowCount;
    mapping(uint256 => Escrow) public escrows;

    event EscrowCreated(uint256 indexed id, address indexed buyer, address indexed seller, uint256 amount);
    event FundsApproved(uint256 indexed id);
    event FundsReleased(uint256 indexed id);
    event EscrowRefunded(uint256 indexed id);
    event EscrowDisputed(uint256 indexed id);
    event DisputeResolved(uint256 indexed id, address winner);

    modifier onlyBuyer(uint256 _id) {
        require(msg.sender == escrows[_id].buyer, "Only buyer can call this");
        _;
    }

    modifier onlySeller(uint256 _id) {
        require(msg.sender == escrows[_id].seller, "Only seller can call this");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }

    function createEscrow(address payable _seller, uint256 _durationSeconds) external payable returns (uint256) {
        require(msg.value > 0, "Escrow must hold some value");
        require(_seller != address(0), "Invalid seller address");

        uint256 escrowId = escrowCount++;
        escrows[escrowId] = Escrow({
            buyer: payable(msg.sender),
            seller: _seller,
            amount: msg.value,
            isApproved: false,
            isReleased: false,
            deadline: block.timestamp + _durationSeconds
        });

        emit EscrowCreated(escrowId, msg.sender, _seller, msg.value);
        return escrowId;
    }

    function approveFunds(uint256 _id) external onlyBuyer(_id) {
        Escrow storage esc = escrows[_id];
        require(!esc.isApproved, "Already approved");
        require(!esc.isReleased, "Already released");

        esc.isApproved = true;
        emit FundsApproved(_id);
    }

    function releaseFunds(uint256 _id) external onlySeller(_id) {
        Escrow storage esc = escrows[_id];
        require(esc.isApproved, "Not approved");
        require(!esc.isReleased, "Already released");

        esc.isReleased = true;
        esc.seller.transfer(esc.amount);
        emit FundsReleased(_id);
    }

    function refundBuyer(uint256 _id) external onlyBuyer(_id) {
        Escrow storage esc = escrows[_id];
        require(!esc.isReleased, "Funds already released");
        require(block.timestamp > esc.deadline, "Escrow not expired yet");

        esc.isReleased = true;
        esc.buyer.transfer(esc.amount);
        emit EscrowRefunded(_id);
    }

    function raiseDispute(uint256 _id) external {
        Escrow storage esc = escrows[_id];
        require(msg.sender == esc.buyer || msg.sender == esc.seller, "Not participant");
        require(!esc.isReleased, "Escrow resolved");

        emit EscrowDisputed(_id);
    }

    function resolveDispute(uint256 _id, address payable _winner) external onlyAdmin {
        Escrow storage esc = escrows[_id];
        require(!esc.isReleased, "Escrow already resolved");
        require(_winner == esc.buyer || _winner == esc.seller, "Invalid winner");

        esc.isReleased = true;
        _winner.transfer(esc.amount);
        emit DisputeResolved(_id, _winner);
    }

    receive() external payable {
        revert("Direct transfers not allowed");
    }
}
