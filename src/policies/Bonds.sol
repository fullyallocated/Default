// // SPDX-License-Identifier: AGPL-3.0-only
// // Proxy Bonds are a modified gradual dutch auction mechanism for protocols to sell their native tokens.

// // TODO  
// // Review price calculations & purchase logic
// // Docs + Twitter thread

// pragma solidity ^0.8.13;

// error notEnoughLiquidity();
// error executionPriceTooHigh();

// contract DefaultBonds {

//   uint256 public constant EMISSION_RATE = 25000; // tokens added to liquidity per day
//   uint256 public constant GROWTH_FACTOR = 500; // number of tokens purchased to push the price up by 1
//   uint256 public constant DECAY_RATE = 25; // cents the base price falls by per day
//   uint256 public constant MAX_CAPACITY = 250000; // maximum amount of liquidity that can be 
//   uint256 public constant RESERVE_PRICE = 100; // lowest possible price for execution


//   uint256 public basePrice = 300; // the adjusted base price of the tokens for the last auction
//   uint256 public lastPurchaseTimestamp; // the timestamp of the last purchase made at the bond
//   uint256 public availableLiquidity = 100000; // the amount of tokens available to be sold (initially 100,000 PRXY)
//   uint256 public residualTokens; // the amount of tokens already accounted for from past auctions when calculating demand premium

//   function _min(uint256 a, uint256 b) internal pure returns (uint256) {
//     if (a < b) { return a; }
//     else { return b; }
//   }

//   function _max(uint256 a, uint256 b) internal pure returns (uint256) {
//     if (a > b) { return a; }
//     else { return b; }
//   }


//   function purchase(uint256 amt_, uint256 maxPrice_) external {

//     // get the amount of seconds since the last purchased block
//     uint256 timeElapsed = block.timestamp - lastPurchaseTimestamp;

//     // record the new liquidity minted to the auction since last sale
//     uint256 additionalLiquidity = timeElapsed * EMISSION_RATE / 1 days;
    
//     // revert the tx if there's not enough liquidity in the auction for the desired purchase amount
//     if (amt_ > _max(availableLiquidity + additionalLiquidity, MAX_CAPACITY)) { revert notEnoughLiquidity(); }

//     // demand premium in cents, grow $0.01 per 500 tokens purchased from the bond
//     uint256 demandPremium = (amt_ + residualTokens)/GROWTH_FACTOR;

//     // price decay in cents, decays $ // maximum amount of liquidity that can be 0.25 per day ($0.01c every 3456 seconds, or ~57 minutes)
//     uint256 priceDecay = timeElapsed * DECAY_RATE / 1 days;

//     // get the execution price. Not exactly precise but good enough
//     uint256 executionPrice = _min(basePrice - priceDecay + (demandPremium/2), RESERVE_PRICE);

//     // revert if the execution price is worse than the minPrice_
//     if (executionPrice > maxPrice_) { revert executionPriceTooHigh(); }

//     // calculate the new liquidity remaining in the auctions after the sale is complete
//     availableLiquidity = _max(availableLiquidity + additionalLiquidity, MAX_CAPACITY) - amt_; 

//     // reset the last purchase timestamp
//     lastPurchaseTimestamp = block.timestamp;

//     // adjust the base price
//     basePrice = _min(basePrice + demandPremium - priceDecay, RESERVE_PRICE);

//     // calculate & set the new residual for the next demand premium
//     residualTokens = (amt_ + residualTokens) % GROWTH_FACTOR;

//     // calculate the total price for  // maximum amount of liquidity that can be the size of the order and transfer it to the treasury.
//     // TRSRY.depositFrom(msg.sender, executionPrice * amt_); // no TRSRY module yet
//   }
// }