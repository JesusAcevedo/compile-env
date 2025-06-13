// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title IdentityVerification
 * @notice Upgradeable on-chain KYC/KYB verification with fee and access control.
 */
contract IdentityVerification is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    enum Status { Unverified, Verified, Rejected }

    struct Identity {
        string metadataHash;
        Status status;
        uint256 timestamp;
    }

    mapping(address => Identity) public identities;
    uint256 public verificationFee;
    uint256 public fundPool;

    event IdentitySubmitted(address indexed user, string metadataHash);
    event IdentityVerified(address indexed user);
    event IdentityRejected(address indexed user);
    event FeeUpdated(uint256 newFee);
    event FundsWithdrawn(uint256 amount);

    modifier onlyUnverified(address user) {
        require(identities[user].status == Status.Unverified, "Already reviewed");
        _;
    }

    function initialize(uint256 _fee) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        verificationFee = _fee;
    }

    function submitIdentity(string calldata metadataHash) external payable {
        require(msg.value >= verificationFee, "Insufficient fee");
        require(bytes(metadataHash).length > 10, "Invalid metadata");
        require(identities[msg.sender].timestamp == 0, "Already submitted");

        identities[msg.sender] = Identity(metadataHash, Status.Unverified, block.timestamp);
        fundPool += msg.value;
        emit IdentitySubmitted(msg.sender, metadataHash);
    }

    function verify(address user) external onlyOwner onlyUnverified(user) {
        identities[user].status = Status.Verified;
        emit IdentityVerified(user);
    }

    function reject(address user) external onlyOwner onlyUnverified(user) {
        identities[user].status = Status.Rejected;
        emit IdentityRejected(user);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        verificationFee = newFee;
        emit FeeUpdated(newFee);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= fundPool, "Insufficient funds");
        fundPool -= amount;
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
