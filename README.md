# Auctionator Smart Contract
![Solidity](https://img.shields.io/badge/Solidity-0.8.0-green)


## Contract Functions
### Core Functions
| Function | Description | Parameters |
|----------|-------------|------------|
| `placeBid()` | Submit new bid (must be ≥5% higher) | Send ETH with transaction |
| `concludeAuction()` | Finalize auction and distribute funds | Callable by owner |
| `withdrawFull()` | Withdraw full bid (non-winners only) | - |
| `withdrawPartial(amount)` | Withdraw excess funds during auction | `uint256 amount` |

### View Functions
| Function | Returns | Description |
|----------|---------|-------------|
| `getWinnerInfo()` | `(address, uint256)` | Winner address and bid amount |
| `getBidHistory()` | `Bid[]` | Complete bid history |
| `getRemainingTime()` | `uint256` | Seconds until auction ends |


## Configuration
### Constants
```solidity
uint256 public constant MIN_BID_INCREASE_PERCENT = 5; // 5% minimum increase
uint256 public constant COMMISSION_PERCENT = 2; // 2% owner commission
uint256 public constant EXTENSION_DURATION = 10 minutes;


## Events 
| Event Name               | Parameters                          | Description                                                                 |
|--------------------------|-------------------------------------|-----------------------------------------------------------------------------|
| `NewBid`                 | `address indexed bidder`            | Emitted when a new bid is placed                                            |
|                          | `uint256 amount`                    | Amount of the new bid (in wei)                                              |
|                          | `uint256 newEndTime`                | Updated auction end time (if extended)                                      |
| `AuctionExtended`        | `uint256 newEndTime`                | Emitted when auction time is extended (10 minute increments)               |
| `AuctionConcluded`       | `address indexed winner`            | Emitted when auction ends                                                  |
|                          | `uint256 winningAmount`             | Final winning bid amount (after commission deduction)                      |