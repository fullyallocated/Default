// SPDX-License-Identifier: AGPL-3.0-only

// Proxy Bonds are a modified gradual dutch auction mechanism for protocols to sell their native tokens.

contract DefaultBonds {

  uint256 public basePrice; // the adjusted base price of the tokens for the last auction
  uint256 public lastPurchaseTimestamp; // the timestamp of the last purchase made at the bond
  uint256 public availableLiquidity; // the amount of tokens available to be sold
  uint256 public residualTokens; // the amount of tokens already accounted for in the demand premium

  function _min(uint256 a, uint256 b) internal returns (uint256) {
    if (a < b) { return a; }
    else { return b; }
  }

  function purchase(uint256 amt_, uint256 maxPrice_) external {

    // get the amount of seconds since the last purchased block
    uint256 timeElapsed = block.timestamp - lastPurchaseTimestamp;

    // record the new liquidity minted to the auction since last sale
    uint256 additionalLiquidity = timeElapsed * 25000 / 86400;
    
    // revert the tx if there's not enough liquidity in the auction for the desired purchase amount
    if (amt_ > availableLiquidity + additionalLiquidity) { revert notEnoughLiquidity(); }

    // demand premium in cents, grow $0.01 per 500 tokens purchased from the bond
    uint256 demandPremium = (amt_ + residualTokens)/500;

    // price decay in cents, decays $0.01 per 3456 sec (~ 1 hr.)
    uint256 priceDecay = timeElapsed / 3456; 

    // get the execution price
    uint256 executionPrice = basePrice - priceDecay + (demandPremium/2);

    // revert if the execution price is worse than the minPrice_
    if (executionPrice > maxPrice_) { revert priceTooHigh(); }

    // calculate the new liquidity remaining in the auctions after the sale is complete
    totalLiquidityAvailable = totalLiquidityAvailable + newLiquidity - amt_; 

    // reset the last purchase timestamp
    lastPurchaseTimestamp = block.timestamp;

    // adjust the base price
    basePrice = basePrice + demandPremium - priceDecay;

    // calculate & set the new residual for the next demand premium
    residualTokens = (amt_ + residualTokens) % 500; 

    // calculate the total price for the size of the order and transfer it to the treasury.
    TRSRY.depositFrom(msg.sender, executionPrice * amt_);
  }
}