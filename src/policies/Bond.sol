// SPDX-License-Identifier: AGPL-3.0-only
// Proxy Bonds are a modified gradual dutch auction mechanism for protocols to sell their native tokens.

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { DefaultVotes } from "../modules/VOTES.sol";
import { DefaultTreasury } from "../modules/TRSRY.sol";
import { Kernel, Policy, Permissions, Keycode } from "../Kernel.sol";
import { toKeycode } from "../utils/KernelUtils.sol";

pragma solidity ^0.8.15;


interface IBond {
    
    // purchasing
    event TokensPurchased(address buyer, uint256 tokens, uint256 totalCost);
    error NotEnoughInventory();
    error ExecutionPriceTooHigh();
}


contract Bond is Policy, IBond {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    DefaultVotes public VOTES;
    DefaultTreasury public TRSRY;

    constructor(Kernel kernel_, ERC20 DAI_) Policy(kernel_) {
        DAI = DAI_; // set the address of payment currency
    }

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        
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

    uint256 public constant EMISSION_RATE = 25000; // tokens added to auction inventory per day
    uint256 public constant SLIPPAGE_RATE = 15; // price increase per token, denominated in 1/10,000th's of a cent (+ 15c / 10,000 tokens)
    uint256 public constant PRICE_DECAY_RATE = 187_500; // the rate that token prices decay each day, denominated in 1/10,000th's of a cent (~.19c / day)
    uint256 public constant MAX_INVENTORY = 1_000_000; // maximum number of tokens available for purchase in the auction
    uint256 public constant RESERVE_PRICE = 1_000_000; // lowest possible price for tokens to be sold in auction

    uint256 public basePrice = 1_000_000; // the base price of the auction after the last sale, priced in 1/10,000th's of a cent (starts at $1.00)
    uint256 public prevSaleTimestamp = block.timestamp; // the timestamp of the last purchase made at the bond
    
    uint256 internal prevInventory = 400_000; // the amount of tokens available for purchase in the auction (initially 400,000 PROX)


    /////////////////////////////////////////////////////////////////////////////////
    //                              View Functions                                 //
    /////////////////////////////////////////////////////////////////////////////////


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
        currentInventory = _min(prevInventory + newEmissions, MAX_INVENTORY);
    }


    // PRICE

    // The auction price is a factor of two variables how many tokens are purchased and 
    // time elapsed since the previous sale. Each token purchased increases the price of
    // each subsequent token, and the price goes down linearly over time.

    /// @param tokensPurchased_ The integer amount of tokens to purchase
    /// @return totalCost the total cost in dollars. $1 = 1e6.
    /// @return newBasePrice the new base price in dollars. $1 = 1e6.
    function getTotalCost(uint256 tokensPurchased_) public view returns (uint256 totalCost, uint256 newBasePrice) {
        // price decay in cents, decays $ // maximum amount of liquidity that can be 0.25 per day ($0.01c every 3456 seconds, or ~57 minutes)
        uint256 priceDecay = (block.timestamp - prevSaleTimestamp) * PRICE_DECAY_RATE / 1 days;

        // calculate starting price of current sale based on the last recorded base price and timestamp from the previous sale
        uint256 startingPrice = basePrice > priceDecay ? _max(basePrice - priceDecay, RESERVE_PRICE) : RESERVE_PRICE;

        // final price of current sale including slippage from on tokens purchased
        uint256 finalPrice = startingPrice + (SLIPPAGE_RATE * tokensPurchased_);

        // get the average execution price
        totalCost = tokensPurchased_ * ((startingPrice + finalPrice) / 2);
        newBasePrice = finalPrice;
    }

    /// @param tokensPurchased_ the integer amount of tokens to purchase
    /// @param maxPrice_ the price in dollars. $1 = 1e6
    function purchase(uint256 tokensPurchased_, uint256 maxPrice_) external {

        uint256 currentInventory = getCurrentInventory();
        (uint256 totalCost, uint256 newBasePrice) = getTotalCost(tokensPurchased_);

        // revert the tx if there's not enough liquidity in the auction for the desired purchase amount
        if (tokensPurchased_ > currentInventory) { revert NotEnoughInventory(); }

        // revert if the execution price is worse than the minPrice_
        if (totalCost > maxPrice_ * tokensPurchased_) { revert ExecutionPriceTooHigh(); }

        // save the new inventory after purchase
        prevInventory = currentInventory - tokensPurchased_;

        // reset the purchase timestamp
        prevSaleTimestamp = block.timestamp;

        // set the new base price after purchase
        basePrice = newBasePrice;

        // transfer dai from and mint VOTES to buyer
        TRSRY.depositFrom(msg.sender, DAI, totalCost * 1e12); // total DAI = totalCost * 1e18 (decimals) / 1e6 (10,000th's of a cent), in dollars
        VOTES.mintTo(msg.sender, tokensPurchased_ * 1e3);

        emit TokensPurchased(msg.sender, tokensPurchased_, totalCost);
    }
}
