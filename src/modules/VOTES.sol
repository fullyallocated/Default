// SPDX-License-Identifier: AGPL-3.0-only

// [VOTES] The Votes Module is the ERC20 token that represents voting power in the network.

pragma solidity ^0.8.13;

import {Kernel, Module} from "../Kernel.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

error VOTES_TransferDisabled();

contract DefaultVotes is Module, ERC20 {

    constructor(Kernel kernel_)
        Module(kernel_)
        ERC20("Dummy Voting Tokens", "VOTES", 0)
    {}

    function KEYCODE() public pure override returns (Kernel.Keycode) {
        return Kernel.Keycode.wrap("VOTES");
    }

    // Policy Interface

    function mintTo(address wallet_, uint256 amount_)
        external
        permissioned
    {
        _mint(wallet_, amount_);
    }

    function burnFrom(address wallet_, uint256 amount_)
        external
        permissioned
    {
        _burn(wallet_, amount_);
    }

    function transfer(address, uint256) 
      public 
      override 
      returns (bool)
    {
      revert VOTES_TransferDisabled();
      return true;
    }

    function transferFrom(address from_, address to_, uint256 amount_) 
      public 
      override 
      permissioned
      returns (bool) 
    {
      // skip the approve function because callers must be pre-approved via governance

      balanceOf[from_] -= amount_;
      unchecked {
          balanceOf[to_] += amount_;
      }
      
      emit Transfer(from_, to_, amount_);     
      return true;
    }
}
