# Liquidity Locker V2

Module for locking liquidity in CLMM (Concentrated Liquidity Market Maker) pools with a reward system.

## Running Tests

**IMPORTANT**: Tests require an increased gas limit for proper execution.

### Run all tests:
```bash
sui move test --gas-limit 2000000000
```

## Main Features

- Locking liquidity positions for specified periods
- Splitting and modifying locked positions
- Changing tick ranges of locked positions
- Claiming rewards from locked positions