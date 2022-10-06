// SPDX-License-Identifier: AGPL-3.0-only
// Proxy Redemption is a contract that redeems votes for treasury assets

pragma solidity ^0.8.15;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { DefaultVotes } from "../modules/VOTES.sol";
import { DefaultTreasury } from "../modules/TRSRY.sol";
import { Kernel, Policy, Permissions, Keycode } from "../Kernel.sol";
import { toKeycode } from "../utils/KernelUtils.sol";



interface IRedemption {

    // redeeming
    event TokensRedeemed(address redeemer, uint256 amt);
}


contract Redemption is Policy, IRedemption {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    DefaultVotes public VOTES;
    DefaultTreasury public TRSRY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        
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

    /// @param amount_ the amount of VOTES to redeem for TRSRY assets
    function redeem(uint256 amount_) external {
        ERC20[] memory reserveAssets = TRSRY.getReserveAssets();
        
        // burn the votes that are being redeemed
        uint256 totalVotes = VOTES.totalSupply();
        VOTES.burnFrom(msg.sender, amount_);

        // return the pro-rata share of each reserve asset in the treasury
        uint256 numReserveAssets = reserveAssets.length;
        for (uint i; i < numReserveAssets;) {
            ERC20 asset = reserveAssets[i];

            uint256 trsryAssetBalance = asset.balanceOf(address(TRSRY));

            // 95% of user's share of votes for a particular asset => i.e. 5% redemption fee.
            uint256 amtToRedeem = (trsryAssetBalance * amount_ * 95) / (totalVotes * 100);

            TRSRY.withdraw(asset, amtToRedeem);

            asset.transfer(msg.sender, amtToRedeem); 

            unchecked {++i;}
        }

        emit TokensRedeemed(msg.sender, amount_);
    }
}
