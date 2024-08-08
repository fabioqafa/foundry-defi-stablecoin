# Decentralized Stablecoin Smart Contract using Foundry

## Smart Contracts in this project are deployed and tested in Anvil

## Follows the CDP model of MakerDAO

1. Relative Stability: Anchored or Pegged -> $1.00
   1. Chainlink Price feed.
   2. Set a function to exchange ETH & BTC -> $$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint stablecoin with enough collateral (coded)
3. Collateral: Exogenous (Crypto):
   1. wETH
   2. wBTC

Tested using Mock, Unit and Fuzz testing