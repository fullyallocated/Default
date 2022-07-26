// SPDX-License-Identifier: AGPL-3.0-only

// [TOKEN] The Token Module is the ERC20 token that represents in the protocol

pragma solidity ^0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "src/Kernel.sol";


contract DefaultToken is Module, ERC20 {
    constructor(Kernel kernel_) Module(kernel_) ERC20("Default Token", "TOKEN", 3) {}

    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("TOKEN");
    }

    // Policy Interface

    function mint(address wallet_, uint256 amount_) external permissioned {
        _mint(wallet_, amount_);
    }

    function burn(address wallet_, uint256 amount_) external permissioned {
        _burn(wallet_, amount_);
    }
}
