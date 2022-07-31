// SPDX-License-Identifier: AGPL-3.0-only
// Proxy Redemption is a contract that redeems votes for treasury assets

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "../modules/VOTES.sol";
import "../modules/TRSRY.sol";
import "../Kernel.sol";

pragma solidity ^0.8.13;

contract Redemption is Policy {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    DefaultVotes public VOTES;
    DefaultTreasury public TRSRY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](1);
        
        dependencies[0] = toKeycode("VOTES");
        VOTES = DefaultVotes(getModuleAddress(toKeycode("VOTES")));

        dependencies[1] = toKeycode("TRSRY");
        TRSRY = DefaultTreasury(getModuleAddress(toKeycode("TRSRY")));
    }

    function requestPermissions() external view override onlyKernel returns (Permissions[] memory requests) {
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("VOTES"), VOTES.burnFrom.selector);
        requests[1] = Permissions(toKeycode("TRSRY"), TRSRY.withdraw.selector);

    }


    /////////////////////////////////////////////////////////////////////////////////
    //                                Policy Variables                             //
    /////////////////////////////////////////////////////////////////////////////////


    function redeem(uint256 amount_) external {
        ERC20[] memory reserveAssets = TRSRY.getReserveAssets();
        
        // return the pro-rata share of each reserve asset in the treasury
        for (uint i; i < reserveAssets.length;) {
            ERC20 asset = reserveAssets[i];

            uint256 totalVotes = VOTES.totalSupply();
            uint256 trsryAssetBalance = asset.balanceOf(address(TRSRY)); 
            VOTES.burnFrom(msg.sender, amount_);

            uint256 amtToRedeem = 95 * trsryAssetBalance * amount_ / (100 * totalVotes); // 95% of user's share of votes for a particular asset => i.e. 5% redemption fee.
            TRSRY.withdraw(asset, amtToRedeem);

            asset.transfer(msg.sender, amtToRedeem); 

            unchecked {++i;}
        }
    }
}