// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "src/Kernel.sol";

interface ITRSRY {
    function withdraw(ERC20 asset_, uint256 amount_) external;
}

contract DumbassRescueScript is Policy {
    ITRSRY public TRSRY;

    // arbitrum addresses
    address public constant FULLY_ADDR = 0x88532f5e88F6A1ccd9E64681aCc63416594000f4;
    address public constant DAI_ADDR = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies()
        external
        override
        onlyKernel
        returns (Keycode[] memory dependencies)
    {
        Keycode TRSRY_KEYCODE = toKeycode("TRSRY");

        dependencies = new Keycode[](1);

        dependencies[0] = TRSRY_KEYCODE;
        TRSRY = ITRSRY(getModuleAddress(TRSRY_KEYCODE));
    }

    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](1);
        requests[0] = Permissions(toKeycode("TRSRY"), TRSRY.withdraw.selector);
    }

    // Deposits DAI into GLP then stakes into gauge, then sends sGLP back to treasury
    function run() external {
        ERC20 dai = ERC20(DAI_ADDR);
        uint256 daiBalance = dai.balanceOf(address(TRSRY));

        TRSRY.withdraw(ERC20(DAI_ADDR), daiBalance);
        dai.transfer(FULLY_ADDR, daiBalance);
    }
}
