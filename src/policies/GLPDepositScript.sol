// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "src/Kernel.sol";

interface IGmxRewardRouter {
    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);
}

interface ITRSRY {
    function withdraw(ERC20 asset_, uint256 amount_) external;

    function depositFrom(
        address depositor_,
        ERC20 asset_,
        uint256 amount_
    ) external;
}

error TokenDoesNotMatchVault();

contract GLPDepositScript is Policy {
    event GLPDeposited(ERC20 depositToken_, uint256 amount_);

    ITRSRY public TRSRY;

    // arbitrum addresses
    address public constant DAI_ADDR = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant SGLP_ADDR = 0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE;
    IGmxRewardRouter public constant GMX_REWARD_ROUTER = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;

    // Execution vars
    // TODO needs to be adjusted to actual amount
    uint256 public constant depositAmount = 1000e18;

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
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("TRSRY"), TRSRY.withdraw.selector);
        requests[1] = Permissions(toKeycode("TRSRY"), TRSRY.depositFrom.selector);
    }

    // Deposits DAI into GLP then stakes into gauge, then sends sGLP back to treasury
    function run() external {
        TRSRY.withdraw(DAI_ADDR, depositAmount);

        // 1000_0000 * 98_00
        // 2% slippage
        uint256 minUsd = depositAmount * 98e16;
        uint256 minGlp = 0; // don't want to deal with glp pricing

        // USDG has same decimals as DAI, so can use same depositAmount value
        uint256 sGlpAmount = GMX_REWARD_ROUTER.mintAndStakeLp(
            DAI_ADDR,
            depositAmount,
            minUsd,
            minGlp
        );

        // Deposit sGLP into treasury
        TRSRY.depositFrom(address(this), SGLP_ADDR, sGlpAmount);

        emit GLPDeposited(depositToken_, amount_);
    }
}
