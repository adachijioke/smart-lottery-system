# Clarity Lottery Smart Contract

## Overview

This smart contract implements a flexible lottery system on the Stacks blockchain using the Clarity programming language. The contract supports two types of lotteries:

1. Time-based: The lottery ends after a specified number of blocks.
2. Participant-based: The lottery ends when a specified number of participants have joined.

## Features

- Two lottery types: time-based and participant-based
- Configurable ticket price
- Random winner selection using block information
- Owner-only functions for starting lotteries and withdrawing funds
- Public functions for buying tickets and drawing winners
- Read-only functions for retrieving lottery information

## Contract Structure

### Constants

- `contract-owner`: The principal who deployed the contract
- Error codes for various failure conditions

### Data Variables

- `ticket-price`: The cost of a lottery ticket in microSTX
- `lottery-end-condition`: Stores either the end block height or participant limit
- `lottery-end-block`: The block height at which a time-based lottery ends
- `participants`: A list of principals who have bought tickets
- `lottery-type`: The current type of lottery ("time-based", "participant-based", or "none")

### Public Functions

1. `start-lottery`: Starts a time-based lottery
2. `start-participant-lottery`: Starts a participant-based lottery
3. `buy-ticket`: Allows users to purchase a lottery ticket
4. `draw-winner`: Selects and pays the winner when the lottery ends
5. `withdraw-funds`: Allows the contract owner to withdraw funds

### Read-Only Functions

- `get-ticket-price`: Returns the current ticket price
- `get-lottery-type`: Returns the current lottery type
- `get-lottery-end-condition`: Returns the end condition (block height or participant limit)
- `get-lottery-end-block`: Returns the end block for time-based lotteries
- `get-participants`: Returns the list of current participants
- `get-balance`: Returns the contract's current balance

## Usage

### Starting a Lottery

The contract owner can start either a time-based or participant-based lottery:

```clarity
;; Start a time-based lottery lasting 1000 blocks
(contract-call? .lottery start-lottery u1000)

;; Start a participant-based lottery with a limit of 50 participants
(contract-call? .lottery start-participant-lottery u50)
```

### Buying a Ticket

Any user can buy a ticket while the lottery is active:

```clarity
(contract-call? .lottery buy-ticket)
```

### Drawing a Winner

Once the lottery end condition is met, anyone can call the `draw-winner` function:

```clarity
(contract-call? .lottery draw-winner)
```

### Retrieving Lottery Information

Use the read-only functions to get information about the current lottery:

```clarity
(contract-call? .lottery get-lottery-type)
(contract-call? .lottery get-participants)
```

## Security Considerations

- The contract uses `tx-sender` for authentication, ensuring only the contract owner can perform certain actions.
- The winner selection process uses block information as a source of randomness
- There's a maximum limit of 100 participants per lottery to prevent excessive gas costs.


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request..
