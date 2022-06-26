// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

import {Treasury} from "src/modules/TRSRY.sol";
import {Kernel, Policy} from "src/Kernel.sol";

error TokenDoesNotMatchVault();

contract TreasuryYieldManager is Policy, Auth {
    event AssetAllocated(ERC20 token_, ERC4626 vault_, uint256 amount_);
    event AssetDeallocated(ERC20 token_, ERC4626 vault_, uint256 amount_);

    Treasury public TRSRY;

    // Shares allocated to vault
    mapping(ERC20 => mapping(ERC4626 => uint256)) allocatedTo;

    constructor(Kernel kernel_)
        Policy(kernel_)
        Auth(address(kernel_), Authority(address(0)))
    {}

    function configureReads() external override {
        TRSRY = Treasury(getModuleAddress("TRSRY"));
    }

    function requestRoles()
        external
        view
        override
        onlyKernel
        returns (Kernel.Role[] memory roles)
    {
        roles = new Kernel.Role[](1);
        roles[0] = TRSRY.DEBTOR();
    }

    // Allocate assets to a specified vault
    function allocate(
        ERC20 token_,
        ERC4626 vault_,
        uint256 amount_
    ) external requiresAuth {
        if (token_ != vault_.asset()) revert TokenDoesNotMatchVault();

        TRSRY.getLoan(token_, amount_);
        uint256 shares = vault_.deposit(amount_, address(this));

        allocatedTo[token_][vault_] = shares;

        emit AssetAllocated(token_, vault_, amount_);
    }

    // Deallocate all allocated assets for vault
    function deallocate(ERC20 token_, ERC4626 vault_) external requiresAuth {
        uint256 shares = allocatedTo[token_][vault_];

        uint256 assets = vault_.redeem(shares, address(this), address(this));
        TRSRY.repayLoan(token_, assets);

        allocatedTo[token_][vault_] = 0;

        emit AssetDeallocated(token_, vault_, assets);
    }
}
