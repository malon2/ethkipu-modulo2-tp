# Auctionator Smart Contract
![Solidity](https://img.shields.io/badge/Solidity-0.8.0-green)

A decentralized auction smart contract built with Solidity. It supports competitive bidding with automatic time extensions, event logging, and secure refund mechanisms for non-winning participants.

---

## Contract Functions


### Core Functions
| Function             | Description                                                                                          | Parameters                     |
|----------------------|------------------------------------------------------------------------------------------------------|--------------------------------|
| `placeBid()`         | Submit a new bid (must be ≥5% higher than the current bid). Emits `NewBid` and possibly `AuctionExtended`. | Send ETH with the transaction |
| `concludeAuction()`  | Finalize the auction and distribute funds. Emits `AuctionConcluded`.                                 | Callable by the contract owner |
| `withdrawFull()`     | Withdraw full bid (non-winners only, after auction ends). Emits `FullWithdrawal`.                    | -                              |
| `withdrawPartial()`  | Withdraw excess funds during the auction. Emits `PartialWithdrawal`.                                 | `uint256 amount`              |


### View Functions
| Function             | Returns                  | Description                              |
|----------------------|--------------------------|------------------------------------------|
| `getWinnerInfo()`    | `(address, uint256)`     | Winner's address and bid amount          |
| `getBidHistory()`    | `Bid[]`                  | Complete history of all bids             |
| `getRemainingTime()` | `uint256`                | Time (in seconds) until auction ends     |

---

## Configuration

### Constants
```solidity
uint256 public constant MIN_BID_INCREASE_PERCENT = 5;    // 5% minimum increase
uint256 public constant COMMISSION_PERCENT = 2;          // 2% owner commission
uint256 public constant EXTENSION_DURATION = 10 minutes; // Auction extension window
```

## Events
All key actions in the auction lifecycle emit relevant events:

NewBid(address indexed bidder, uint256 amount, uint256 newEndTime)
Emitted when a new valid bid is placed. If the bid extends the auction, newEndTime reflects the new deadline.

AuctionExtended(uint256 newEndTime)
Emitted when a last-minute bid extends the auction duration by 10 minutes.

AuctionConcluded(address indexed winner, uint256 winningAmount)
Emitted when the auction ends. winningAmount reflects the final bid after the commission deduction.

FullWithdrawal(address indexed bidder, uint256 amount)
Emitted when a non-winner withdraws their full bid after the auction ends.

PartialWithdrawal(address indexed bidder, uint256 amount)
Emitted when a bidder withdraws excess funds during the auction.