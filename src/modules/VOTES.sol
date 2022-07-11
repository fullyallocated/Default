// // SPDX-License-Identifier: AGPL-3.0-only

// // [VOTES] The Votes Module is the ERC20 token that represents voting power in the network.

// pragma solidity ^0.8.13;

// import {Kernel, Module} from "../Kernel.sol";
// import {ERC20} from "solmate/tokens/ERC20.sol";

// error VOTES_TransferDisabled();

// contract DefaultVotes is Module, ERC20 {
//     Kernel.Role public constant ISSUER = Kernel.Role.wrap("VOTES_Issuer");
//     Kernel.Role public constant GOVERNOR = Kernel.Role.wrap("VOTES_Governor");

//     constructor(Kernel kernel_)
//         Module(kernel_)
//         ERC20("Dummy Voting Tokens", "VOTES", 0)
//     {}

//     function KEYCODE() public pure override returns (Kernel.Keycode) {
//         return Kernel.Keycode.wrap("VOTES");
//     }

//     function ROLES() public pure override returns (Kernel.Role[] memory roles) {
//         roles = new Kernel.Role[](2);
//         roles[0] = ISSUER;
//         roles[1] = GOVERNOR;
//     }

//     // Policy Interface

//     function mintTo(address wallet_, uint256 amount_)
//         external
//         permissioned(mintTo.selector)
//     {
//         _mint(wallet_, amount_);
//     }

//     function burnFrom(address wallet_, uint256 amount_)
//         external
//         permissioned(burnFrom.selector)
//     {
//         _burn(wallet_, amount_);
//     }

//     function transfer(address, uint256) 
//       public 
//       override 
//       returns (bool)
//     {
//       revert VOTES_TransferDisabled();
//       return true;
//     }

//     function transferFrom(address from_, address to_, uint256 amount_) 
//       public 
//       override 
//       permissioned(transferFrom.selector)
//       returns (bool) 
//     {
//       // skip the approve function because callers must be pre-approved via governance

//       balanceOf[from_] -= amount_;
//       unchecked {
//           balanceOf[to_] += amount_;
//       }
      
//       emit Transfer(from_, to_, amount_);     
//       return true;
//     }
// }
