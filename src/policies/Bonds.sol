// SPDX-License-Identifier: AGPL-3.0-only
// Proxy Bonds are a modified gradual dutch auction mechanism for protocols to sell their native tokens.

import "../modules/VOTES.sol";
import "../Kernel.sol";

pragma solidity ^0.8.13;

error notEnoughInventory();
error executionPriceTooHigh();

contract Bonds is Policy {

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    DefaultVotes public VOTES;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](1);
        
        dependencies[0] = toKeycode("VOTES");
        VOTES = DefaultVotes(getModuleAddress(toKeycode("VOTES")));

        // dependencies[1] = toKeycode("TRSRY");
        // TRSRY = DefaultTreasury(getModuleAddress(toKeycode("TRSRY")));
    }

    function requestPermissions() external view override onlyKernel returns (Permissions[] memory requests) {
        requests = new Permissions[](1);
        requests[0] = Permissions(toKeycode("VOTES"), VOTES.mintTo.selector);
    }



    uint256 public constant EMISSION_RATE = 25000; // tokens added to inventory per day
    uint256 public constant BATCH_SIZE = 500; // number of tokens in each block
    uint256 public constant DECAY_RATE = 25; // the price decay (in cents) of the auction's base price each day
    uint256 public constant MAX_INVENTORY = 1000000; // maximum number of tokens available for purchase in the auction
    uint256 public constant RESERVE_PRICE = 100; // lowest possible price (in cents) for execution

    uint256 public basePrice = 100; // the base price of the auction after the last sale (initially $1.00)
    uint256 public prevSaleTimestamp; // the timestamp of the last purchase made at the bond
    uint256 public inventory = 400000; // the amount of tokens available for purchase in the auction (initially 300,000 PRXY)
    uint256 public tokenOffset; // the amount of tokens offset in an auction block due to previous sales


    // Utility Functions.


    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    // PRICE
    //
    // In proxy, tokens are sold in a batches of 500 tokens. Each batch of tokens sold in the auction
    // is $0.01 more expensive than the previous batch. The auction price decreases at a rate of $0.25 each
    // day, down to a $1.00 minimum reserve price. Batches can be partially bought, and the remaining tokens
    // may be purchased by a different buyer.


    // INVENTORY
    //    
    // The auction can hold up to a maximum of 1,000,000 tokens in the inventory at a given time. 
    // The inventory "refills" over time at a rate of 25,000 tokens per day.


    function purchase(uint256 amt_, uint256 maxPrice_) external returns (uint256 allInPrice) {

        // save the amount of seconds elapsed since the last sale
        uint256 timeElapsed = block.timestamp - prevSaleTimestamp;

        // calculate the total tokens available in the auction since based on available inventory and emissions
        uint256 newEmissions = timeElapsed * EMISSION_RATE / 1 days;

        // calculate the current inventory based on previous inventory and new emissions
        uint256 currentInventory = _min(inventory + newEmissions, MAX_INVENTORY);
        
        // revert the tx if there's not enough liquidity in the auction for the desired purchase amount
        if (amt_ > currentInventory) { revert notEnoughInventory(); }

        // price decay in cents, decays $ // maximum amount of liquidity that can be 0.25 per day ($0.01c every 3456 seconds, or ~57 minutes)
        uint256 priceDecay = timeElapsed * DECAY_RATE / 1 days;

        // starting price of current auction based on the final base price after last sale and time decay
        uint256 startingPrice = _max(basePrice - priceDecay, RESERVE_PRICE);
        
        // CALCULATE THE WHOLE BATCHES
        uint256 batchesPurchased = amt_ / BATCH_SIZE;
        uint256 finalPrice = (startingPrice + batchesPurchased - 1);
        uint256 totalCostForWholeBlocks = ((finalPrice + startingPrice) / 2) * batchesPurchased + BATCH_SIZE; 
        
        // CALCULATE THE RESIDUAL
        uint256 residual = amt_ % BATCH_SIZE;
        uint256 totalCostForResidual = (finalPrice + 1) * residual;

        // CALCULATE THE OFFSET PREMIUM
        uint256 offsetPremium = tokenOffset * batchesPurchased;
        allInPrice = totalCostForWholeBlocks + totalCostForResidual + offsetPremium;

        // revert if the execution price is worse than the minPrice_
        if (allInPrice > maxPrice_ * amt_) { revert executionPriceTooHigh(); }

        // calculate the new inventory remaining in the auctions after the sale is complete
        inventory = currentInventory - amt_;

        // reset the last purchase timestamp
        prevSaleTimestamp = block.timestamp;

        // adjust the base price
        basePrice = _min(basePrice - priceDecay + batchesPurchased, RESERVE_PRICE);

        // calculate & set the new residual for the next demand premium
        tokenOffset = (amt_ + tokenOffset) % BATCH_SIZE;

        // TRSRY.depositFunds(msg.sender, allInPrice,); // no TRSRY module yet
        // VOTES.mint(msg.sender, amt_);
    }
}