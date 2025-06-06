// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Auctionator
 * @dev Auction contract implementing all required features
 * @notice Implements an auction system.
 */
contract Auctionator {
    // Public state variables
    address public immutable owner;
    uint256 public auctionEndTime;
    uint256 public immutable initialDuration;
    uint256 public highestBid;
    address public highestBidder;
    bool public auctionEnded;

    // Constants
    uint256 public constant MIN_BID_INCREASE_PERCENT = 5;
    uint256 public constant COMMISSION_PERCENT = 2;
    uint256 public constant EXTENSION_DURATION = 10 minutes;
    uint256 public constant EXTENSION_THRESHOLD = 10 minutes;

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
        require(msg.sender == owner, "Caller is not the auction owner");
        _;
    }

    modifier whenAuctionActive() {
        require(block.timestamp <= auctionEndTime, "Auction has concluded");
        require(!auctionEnded, "Auction was manually concluded");
        _;
    }

    modifier whenAuctionEnded() {
        require(block.timestamp > auctionEndTime || auctionEnded, "Auction still active");
        _;
    }

    modifier onlyNonWinner() {
        require(msg.sender != highestBidder, "Winner cannot perform this action");
        _;
    }

    /**
     * @dev Initializes the auction contract
     * @param durationInSeconds Initial auction duration in seconds
     * @notice Contract deployer becomes the owner
     */
    constructor(uint256 durationInSeconds) {
        require(durationInSeconds >= EXTENSION_THRESHOLD, "Duration too short");
        
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
        require(msg.value > 0, "Bid value must be positive");

        // Calculate minimum required bid
        uint256 minRequiredBid = highestBid + (highestBid * MIN_BID_INCREASE_PERCENT / 100);
        
        // First bid has no minimum
        if (highestBid == 0) {
            minRequiredBid = 0;
        }

        require(
            msg.value > minRequiredBid,
            "Bid must exceed current highest by at least 5%"
        );

        // Record the bid
        uint256 bidIndex = _bidIndices[msg.sender];
        if (bidIndex > 0) {
            // Existing bidder - update their bid
            Bid storage existingBid = bidHistory[bidIndex - 1];
            existingBid.amount += msg.value;
        } else {
            // New bidder
            bidHistory.push(Bid({
                bidder: msg.sender,
                amount: msg.value,
                withdrawn: false
            }));
            _bidIndices[msg.sender] = bidHistory.length;
        }

        // Update highest bid
        highestBid = msg.value;
        highestBidder = msg.sender;

        // Extend auction if needed
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
        require(!auctionEnded, "Auction already concluded");
        
        auctionEnded = true;

        if (highestBid > 0) {
            uint256 commission = (highestBid * COMMISSION_PERCENT) / 100;
            uint256 ownerProceeds = highestBid - commission;
            
            payable(owner).transfer(ownerProceeds);
        }

        emit AuctionConcluded(highestBidder, highestBid);
    }

    /**
     * @notice Allows losers to withdraw full bids
     * @dev Only available after auction concludes
     */
    function withdrawFull() external whenAuctionEnded onlyNonWinner {
        uint256 bidIndex = _bidIndices[msg.sender];
        require(bidIndex > 0, "No bids placed by caller");

        Bid storage userBid = bidHistory[bidIndex - 1];
        require(!userBid.withdrawn, "Funds already withdrawn");

        userBid.withdrawn = true;
        uint256 amount = userBid.amount;

        payable(msg.sender).transfer(amount);
        emit FullWithdrawal(msg.sender, amount);
    }

    /**
     * @notice Allows partial withdrawal during auction
     * @param amountToWithdraw Amount to withdraw
     * @dev Remaining amount must cover user's last bid
     */
    function withdrawPartial(uint256 amountToWithdraw) external whenAuctionActive {
        require(amountToWithdraw > 0, "Withdrawal amount must be positive");

        uint256 bidIndex = _bidIndices[msg.sender];
        require(bidIndex > 0, "No bids placed by caller");

        Bid storage userBid = bidHistory[bidIndex - 1];
        
        uint256 minRequiredBalance = (msg.sender == highestBidder) ? highestBid : 0;
        
        require(
            userBid.amount > minRequiredBalance,
            "No excess funds available"
        );
        
        require(
            userBid.amount - amountToWithdraw >= minRequiredBalance,
            "Withdrawal exceeds available excess"
        );

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
        require(auctionEnded, "Auction not yet concluded");
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