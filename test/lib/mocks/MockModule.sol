// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "src/Kernel.sol";

contract MockModule is Module {
    constructor(Kernel kernel_) Module(kernel_) {}

    uint256 public publicState;
    uint256 public permissionedState;

    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("MOCKY");
    }

    function publicCall() public {
        publicState++;
    }

    function permissionedCall() public permissioned {
        permissionedState++;
    }
}

contract UpgradedMockModule is Module {
    MockModule _oldModule;
    uint256 public publicState;
    uint256 public permissionedState;

    constructor(Kernel kernel_, MockModule oldModule_) Module(kernel_) {
        _oldModule = oldModule_;
    }

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("MOCKY");
    }

    function INIT() public override onlyKernel {
        permissionedState = _oldModule.permissionedState();
    }

    function publicCall() public {
        publicState++;
    }

    function permissionedCall() public permissioned {
        permissionedState++;
    }
}

contract InvalidMockModule is Module {
    constructor(Kernel kernel_) Module(kernel_) {}

    uint256 public publicState;
    uint256 public permissionedState;

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("badkc");
    }

    function INIT() public override onlyKernel {}

    function publicCall() public {
        publicState++;
    }

    function permissionedCall() public permissioned {
        permissionedState++;
    }
}
