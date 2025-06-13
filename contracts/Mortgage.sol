// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Mortgage is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Loan {
        uint256 amount;
        uint256 interestRate;
        uint256 term;
        uint256 balance;
        address borrower;
        bool active;
    }

    uint256 public loanCount;
    uint256 public processingFeeRate;

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;

    event LoanCreated(uint256 indexed id, address indexed borrower, uint256 amount, uint256 rate, uint256 term);
    event PaymentMade(uint256 indexed id, uint256 amount);
    event LoanRepaid(uint256 indexed id);

    function initialize(uint256 _feeRate) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        processingFeeRate = _feeRate; // Fee rate in basis points (e.g., 250 = 2.5%)
    }

    function createLoan(uint256 amount, uint256 interestRate, uint256 term) external payable {
        require(amount > 0 && interestRate > 0 && term > 0, "Invalid inputs");

        uint256 fee = (amount * processingFeeRate) / 10000;
        require(msg.value >= fee, "Fee not covered");

        loanCount++;
        loans[loanCount] = Loan(amount, interestRate, term, amount, msg.sender, true);
        borrowerLoans[msg.sender].push(loanCount);

        emit LoanCreated(loanCount, msg.sender, amount, interestRate, term);
    }

    function repayLoan(uint256 id) external payable {
        Loan storage loan = loans[id];
        require(loan.active && loan.borrower == msg.sender, "Unauthorized");
        require(msg.value > 0 && msg.value <= loan.balance, "Invalid payment");

        loan.balance -= msg.value;
        emit PaymentMade(id, msg.value);

        if (loan.balance == 0) {
            loan.active = false;
            emit LoanRepaid(id);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
    