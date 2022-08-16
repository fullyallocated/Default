// SPDX-License-Identifier: AGPL-3.0-only

// [VOTES] The Votes Module is the ERC20 token that represents voting power in the network.

pragma solidity ^0.8.15;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Kernel, Module, Keycode } from "src/Kernel.sol";

error IsAlreadyReserveAsset();
error NotReserveAsset();

contract DefaultTreasury is Module {

    constructor(Kernel kernel_, ERC20[] memory initialAssets_) Module(kernel_) {
        uint256 length = initialAssets_.length;
        for (uint256 i; i < length;) {
            ERC20 asset = initialAssets_[i];
            isReserveAsset[asset] = true;
            reserveAssets.push(asset);
            unchecked {
                ++i;
            }
        }   
    }

    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("TRSRY");
    }

    // VARIABLES

    mapping(ERC20 => bool) public isReserveAsset;
    ERC20[] public reserveAssets;

    // Policy Interface

    function getReserveAssets() public view returns (ERC20[] memory reserveAssets_) {
        reserveAssets_ = reserveAssets;
    }

    // whitelisting: add and remove reserve assets (if the treasury supports these currencies)

    function addReserveAsset(ERC20 asset_) public permissioned {
        if (isReserveAsset[asset_]) {revert IsAlreadyReserveAsset();}
        isReserveAsset[asset_] = true;
        reserveAssets.push(asset_);
    }

    function removeReserveAsset(ERC20 asset_) public permissioned {
        if (!isReserveAsset[asset_]) {revert NotReserveAsset();}       
        isReserveAsset[asset_] = false;
        
        uint numAssets = reserveAssets.length;
        for (uint i; i < numAssets;) {
            if (reserveAssets[i] == asset_) {
                reserveAssets[i] = reserveAssets[numAssets - 1];
                reserveAssets.pop();
                break;
            }
            unchecked {++i;}
        }
    }

    // more convenient than "transferFrom", since users only have to approve the Treasury
    // and any policy can make approved transfers on the Treasury's behalf.
    // beware of approving malicious policies that can rug the user.

    function depositFrom(address depositor_, ERC20 asset_, uint256 amount_) external permissioned {
        if (!isReserveAsset[asset_]) {revert NotReserveAsset();}
        asset_.transferFrom(depositor_, address(this), amount_);
    }

    // must withdraw assets to approved policies, where withdrawn assets are handled in their internal logic.
    // no direct withdraws to arbitrary addresses allowed.
    function withdraw(ERC20 asset_, uint256 amount_) external permissioned {
        if (!isReserveAsset[asset_]) {revert NotReserveAsset();}
        asset_.transfer(msg.sender, amount_);
    }
}
