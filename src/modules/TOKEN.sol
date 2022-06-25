// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Kernel, Module} from "src/Kernel.sol";

contract Token is Module, ERC20 {
    Kernel.Role public constant ISSUER = Kernel.Role.wrap("TOKEN_Issuer");

    uint256 public rewardRate;

    constructor(Kernel kernel_) Module(kernel_) ERC20("Token", "TOKEN", 18) {}

    function KEYCODE() public pure override returns (Kernel.Keycode) {
        return Kernel.Keycode.wrap("TOKEN");
    }

    function ROLES() public pure override returns (Kernel.Role[] memory roles) {
        roles = new Kernel.Role[](1);
        roles[0] = ISSUER;
    }

    // Policy Interface

    function mintTo(address wallet_, uint256 amount_)
        external
        onlyRole(ISSUER)
    {
        _mint(wallet_, amount_);
    }

    function burnFrom(address wallet_, uint256 amount_)
        external
        onlyRole(ISSUER)
    {
        _burn(wallet_, amount_);
    }
}
