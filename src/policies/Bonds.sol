// SPDX-License-Identifier: AGPL-3.0-only
// Proxy Bonds are a modified gradual dutch auction mechanism for protocols to sell their native tokens.

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "../modules/VOTES.sol";
import "../modules/TRSRY.sol";
import "../Kernel.sol";

pragma solidity ^0.8.13;

error NotEnoughInventory();
error ExecutionPriceTooHigh();

contract Bonds is Policy {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    DefaultVotes public VOTES;
    DefaultTreasury public TRSRY;

    constructor(Kernel kernel_, ERC20 DAI_) Policy(kernel_) {
        DAI = DAI_; // set the address of payment currency
    }

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](1);
        
        dependencies[0] = toKeycode("VOTES");
        VOTES = DefaultVotes(getModuleAddress(toKeycode("VOTES")));

        dependencies[1] = toKeycode("TRSRY");
        TRSRY = DefaultTreasury(getModuleAddress(toKeycode("TRSRY")));
    }

    function requestPermissions() external view override onlyKernel returns (Permissions[] memory requests) {
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("VOTES"), VOTES.mintTo.selector);
        requests[1] = Permissions(toKeycode("TRSRY"), TRSRY.depositFrom.selector);

    }


    /////////////////////////////////////////////////////////////////////////////////
    //                                Policy Variables                             //
    /////////////////////////////////////////////////////////////////////////////////


    ERC20 public DAI; // DAI contract addr

    uint256 public constant EMISSION_RATE = 25000; // tokens added to inventory per day
    uint256 public constant BATCH_SIZE = 500; // number of tokens in each batch
    uint256 public constant PRICE_DECAY_RATE = 25; // the price decay (in cents) of the auction's base price each day
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


    // INVENTORY

    // The auction can hold up to a maximum of 1,000,000 tokens in the inventory at a given time. 
    // The inventory "refills" over time at a rate of 25,000 tokens per day.

    function getCurrentInventory() public view returns (uint256 currentInventory) {
        // calculate the total tokens available in the auction since based on available inventory and emissions
        uint256 newEmissions = (block.timestamp - prevSaleTimestamp) * EMISSION_RATE / 1 days;

        // calculate the current inventory based on previous inventory and new emissions
        currentInventory = _min(inventory + newEmissions, MAX_INVENTORY);
    }


    // PRICE

    // The auction price is a factor of two variables: slippage and price decay. 
    
    // In Default Bonds, tokens are auctioned in 'batches' of 500 tokens. Each batch of tokens is 
    // priced $0.01 more expensive than its previous batch. As more tokens are purchased, the price
    // of the auction rises. Like in traditional markets, larger orders of tokens impact the auction
    // price faster and have worse overall price execution (slippage) than smaller orders.

    // The price of the tokens in the bond decrease linearly over time. Every 24 hours, the price decreases by .25c.
    // The more time passes between sales, the cheaper the price becomes, down to a lower limit of $1. 

    function getTotalCost(uint256 tokensPurchased_) public view returns (uint256 totalCost, uint256 newBasePrice) {
        // price decay in cents, decays $ // maximum amount of liquidity that can be 0.25 per day ($0.01c every 3456 seconds, or ~57 minutes)
        uint256 priceDecay = (block.timestamp - prevSaleTimestamp) * PRICE_DECAY_RATE / 1 days;

        // starting price of current auction based on the final base price after last sale and time decay
        uint256 startingPrice = _max(basePrice - priceDecay, RESERVE_PRICE);
        
        // CALCULATE THE WHOLE BATCHES
        uint256 batchesPurchased = tokensPurchased_ / BATCH_SIZE;
        uint256 finalPrice = (startingPrice + batchesPurchased - 1);
        uint256 totalCostForWholeBatches = (finalPrice + startingPrice) * batchesPurchased * BATCH_SIZE / 2; 
        
        // CALCULATE THE RESIDUAL
        uint256 residual = tokensPurchased_ % BATCH_SIZE;
        uint256 totalCostForResidual = (finalPrice + 1) * residual;

        // CALCULATE THE OFFSET PREMIUM
        uint256 offsetPremium = (tokenOffset * batchesPurchased);
        uint256 residualOffsetPremium = (residual + tokenOffset) > BATCH_SIZE ? (residual + tokenOffset) % BATCH_SIZE : 0; 
        
        totalCost = totalCostForWholeBatches + totalCostForResidual + offsetPremium + residualOffsetPremium;
        newBasePrice = _max(basePrice - priceDecay + batchesPurchased, RESERVE_PRICE);
    }


    function purchase(uint256 tokensPurchased_, uint256 maxPrice_) external returns (uint256) {

        uint256 currentInventory = getCurrentInventory();
        (uint256 totalCost, uint256 newBasePrice) = getTotalCost(tokensPurchased_);

        // revert the tx if there's not enough liquidity in the auction for the desired purchase amount
        if (tokensPurchased_ > currentInventory) { revert NotEnoughInventory(); }

        // revert if the execution price is worse than the minPrice_
        if (totalCost > maxPrice_ * tokensPurchased_) { revert ExecutionPriceTooHigh(); }

        // save the new inventory after purchase
        inventory = currentInventory - tokensPurchased_;

        // reset the purchase timestamp
        prevSaleTimestamp = block.timestamp;

        // set the new base price after purchase
        basePrice = newBasePrice;

        // calculate & set the new token offest
        tokenOffset = (tokensPurchased_ + tokenOffset) % BATCH_SIZE;

        // return totalCost;  <=  currently used for testing, but should change tests now 

        TRSRY.depositFrom(msg.sender, DAI, totalCost); // <== TEST THIS, untested
        VOTES.mintTo(msg.sender, tokensPurchased_); // <= TEST THIS, untested
    }
}