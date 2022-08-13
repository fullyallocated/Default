// SPDX-License-Identifier: AGPL-3.0-only

// [VOTES] The Votes Module is the ERC20 token that represents voting power in the network.

pragma solidity ^0.8.15;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Kernel, Module, Keycode } from "src/Kernel.sol";

error VOTES_TransferDisabled();

contract DefaultVotes is Module, ERC20 {
    constructor(Kernel kernel_) Module(kernel_) ERC20("Voting Tokens", "VOTES", 3) {}

    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("VOTES");
    }

    // Policy Interface

    function mintTo(address wallet_, uint256 amount_) external permissioned {
        _mint(wallet_, amount_);
    }

    function burnFrom(address wallet_, uint256 amount_) external permissioned {
        _burn(wallet_, amount_);
    }

    function transfer(address, uint256) public override returns (bool) {
        revert VOTES_TransferDisabled();
        return true;
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 amount_
    ) public override permissioned returns (bool) {
        // skip the approve function because callers must be pre-approved via governance

        balanceOf[from_] -= amount_;
        unchecked {
            balanceOf[to_] += amount_;
        }

        emit Transfer(from_, to_, amount_);
        return true;
    }
}
