// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Auctionator
 * @dev Auction contract implementing all required features
 * @notice Implements an auction system.
 */
contract Auctionator {
    // Constants
    uint256 public constant MIN_BID_INCREASE_PERCENT = 5;
    uint256 public constant COMMISSION_PERCENT = 2;
    uint256 public constant EXTENSION_DURATION = 10 minutes;
    uint256 public constant EXTENSION_THRESHOLD = 10 minutes;

    // Public state variables
    address public immutable owner;
    uint256 public immutable initialDuration;
    uint256 public auctionEndTime;
    uint256 public highestBid;
    address public highestBidder;
    bool public auctionEnded;

    // Data structures
    struct Bid {
        address bidder;
        uint256 amount;
        bool withdrawn;
    }

    // Storage
    Bid[] public bidHistory;
    mapping(address => uint256) private _bidIndices;

    // Events
    event NewBid(address indexed bidder, uint256 amount, uint256 newEndTime);
    event AuctionExtended(uint256 newEndTime);
    event AuctionConcluded(address indexed winner, uint256 winningAmount);
    event FullWithdrawal(address indexed bidder, uint256 amount);
    event PartialWithdrawal(address indexed bidder, uint256 amount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenAuctionActive() {
        require(block.timestamp <= auctionEndTime, "Ended");
        require(!auctionEnded, "Manually ended");
        _;
    }

    modifier whenAuctionEnded() {
        require(block.timestamp > auctionEndTime || auctionEnded, "Still active");
        _;
    }

    modifier onlyNonWinner() {
        require(msg.sender != highestBidder, "Is winner");
        _;
    }

    /**
     * @dev Initializes the auction contract
     * @param durationInSeconds Initial auction duration in seconds
     * @notice Contract deployer becomes the owner
     */
    constructor(uint256 durationInSeconds) {
        require(durationInSeconds >= EXTENSION_THRESHOLD, "Short duration");

        owner = msg.sender;
        initialDuration = durationInSeconds;
        auctionEndTime = block.timestamp + durationInSeconds;
    }

    /**
     * @notice Allows participants to place bids
     * @dev Each new bid must be at least 5% higher than previous
     * @notice Extends auction by 10 minutes if placed within last 10 minutes
     */
    function placeBid() external payable whenAuctionActive {
        uint256 currentHighest = highestBid;
        uint256 minRequiredBid = currentHighest + (currentHighest * MIN_BID_INCREASE_PERCENT / 100);

        if (currentHighest == 0) {
            minRequiredBid = 0;
        }

        require(msg.value > minRequiredBid, "Too low");

        uint256 bidIndex = _bidIndices[msg.sender];
        if (bidIndex > 0) {
            Bid storage existingBid = bidHistory[bidIndex - 1];
            existingBid.amount += msg.value;
        } else {
            bidHistory.push(Bid({
                bidder: msg.sender,
                amount: msg.value,
                withdrawn: false
            }));
            _bidIndices[msg.sender] = bidHistory.length;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        bool extended = _extendAuctionIfNeeded();

        emit NewBid(msg.sender, msg.value, auctionEndTime);
        if (extended) {
            emit AuctionExtended(auctionEndTime);
        }
    }

    /**
     * @notice Concludes the auction and distributes funds
     * @dev Transfers winning amount (minus commission) to owner
     */
    function concludeAuction() external whenAuctionEnded {
        require(!auctionEnded, "Already done");

        auctionEnded = true;

        uint256 winningBid = highestBid;
        if (winningBid > 0) {
            uint256 commission = (winningBid * COMMISSION_PERCENT) / 100;
            uint256 ownerProceeds = winningBid - commission;
            payable(owner).transfer(ownerProceeds);
        }

        emit AuctionConcluded(highestBidder, winningBid);
    }

    /**
     * @notice Allows the owner to refund all non-winning participants
     * @dev Sends back each user's bid minus 2% commission
     */
    function withdrawFull() external onlyOwner whenAuctionEnded {
        for (uint256 i = 0; i < bidHistory.length; i++) {
            Bid storage bid = bidHistory[i];

            if (!bid.withdrawn && bid.bidder != highestBidder) {
                bid.withdrawn = true;
                uint256 refund = bid.amount - ((bid.amount * COMMISSION_PERCENT) / 100);
                payable(bid.bidder).transfer(refund);
                emit FullWithdrawal(bid.bidder, refund);
            }
        }
    }

    /**
     * @notice Allows partial withdrawal during auction
     * @param amountToWithdraw Amount to withdraw
     * @dev Remaining amount must cover user's last bid
     */
    function withdrawPartial(uint256 amountToWithdraw) external whenAuctionActive {
        require(amountToWithdraw > 0, "Zero amt");

        uint256 bidIndex = _bidIndices[msg.sender];
        require(bidIndex > 0, "No bids");

        Bid storage userBid = bidHistory[bidIndex - 1];
        uint256 requiredBalance = msg.sender == highestBidder ? highestBid : 0;

        require(userBid.amount > requiredBalance, "No excess");
        require(userBid.amount - amountToWithdraw >= requiredBalance, "Exceeds");

        userBid.amount -= amountToWithdraw;
        payable(msg.sender).transfer(amountToWithdraw);
        emit PartialWithdrawal(msg.sender, amountToWithdraw);
    }

    /**
     * @notice Gets winner information
     * @return winnerAddress Winner's address
     * @return winningAmount Winning bid amount
     */
    function getWinnerInfo() external view returns (address winnerAddress, uint256 winningAmount) {
        require(auctionEnded, "Not over");
        return (highestBidder, highestBid);
    }

    /**
     * @notice Gets complete bid history
     * @return Array of all bids placed
     */
    function getBidHistory() external view returns (Bid[] memory) {
        return bidHistory;
    }

    /**
     * @notice Gets remaining auction time
     * @return remainingTime Time left in seconds (0 if ended)
     */
    function getRemainingTime() external view returns (uint256 remainingTime) {
        return block.timestamp < auctionEndTime ? auctionEndTime - block.timestamp : 0;
    }

    /**
     * @dev Extends auction if remaining time <= 10 minutes
     * @return extended True if auction was extended
     */
    function _extendAuctionIfNeeded() private returns (bool extended) {
        if (auctionEndTime - block.timestamp <= EXTENSION_THRESHOLD) {
            auctionEndTime += EXTENSION_DURATION;
            return true;
        }
        return false;
    }

    receive() external payable {}
}
