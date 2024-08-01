# STX Lottery Smart Contract

## Overview

The STX Lottery is a decentralized lottery system built on the Stacks blockchain. It allows users to participate in a fair and transparent lottery using STX tokens. The lottery runs in cycles, with each cycle concluding when 100 tickets have been sold.

## Features

- Buy lottery tickets using STX tokens
- Automatic draw when the ticket threshold is reached
- Fair winner selection using blockchain-based randomness
- Claim rewards for winning tickets
- Cycle progression for continuous lottery operation

## Contract Details

- **Ticket Price**: 10 STX per ticket
- **Tickets per Draw**: 100
- **Minimum Participation**: 1 ticket (10 STX)
- **Maximum Participation**: No limit (up to 100 tickets per cycle)

## Smart Contract Functions

### Public Functions

1. `buy-tickets(number-of-tickets: uint)`
   - Purchase lottery tickets for the current cycle
   - Returns: (ok true) on success, (err u100) if insufficient funds, (err u101) if cycle is full

2. `perform-draw()`
   - Initiates the winner selection process (owner-only function)
   - Returns: (ok principal) with the winner's address on success, or an error code

3. `claim-reward()`
   - Allows the winner to claim their prize
   - Returns: (ok true) on successful claim, or an error code

### Read-Only Functions

1. `get-cycle-progress()`
   - Returns the current cycle's progress as a percentage (0-100)

2. `get-participant-tickets(participant: principal)`
   - Returns the number of tickets owned by a participant in the current cycle

## Error Codes

- `ERR_UNAUTHORIZED (u101000)`: Unauthorized action
- `ERR_CYCLE_INCOMPLETE (u101001)`: Lottery cycle is not complete
- `ERR_NOT_WINNER (u101002)`: Caller is not the winner
- `ERR_DRAW_ALREADY_DONE (u101003)`: Draw has already been performed for this cycle

## How to Participate

1. Ensure you have sufficient STX tokens in your wallet.
2. Call the `buy-tickets` function with the number of tickets you want to purchase.
3. Wait for the cycle to complete (100 tickets sold).
4. The contract owner will initiate the draw.
5. If you're the winner, call the `claim-reward` function to receive your prize.

## Development and Testing

This contract is developed using Clarity, the smart contract language for the Stacks blockchain. To set up your development environment:

1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Clone this repository
3. Run `clarinet console` to interact with the contract
4. Use `clarinet test` to run the test suite

## Security Considerations

- The contract uses blockchain-based randomness for winner selection, which is influenced by block data.
- There's no time limit for claiming rewards, so winners should claim their prizes promptly.
- The contract owner has the responsibility to initiate the draw, which introduces a centralization point.


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
