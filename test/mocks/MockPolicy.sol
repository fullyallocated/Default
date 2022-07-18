// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {Kernel, Policy, Permissions} from "src/Kernel.sol";
import {MockModule} from "./MockModule.sol";

contract MockPolicy is Policy {

    MockModule public MOCKY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies()
        external
        override
        onlyKernel
        returns (Kernel.Keycode[] memory dependencies)
    {
        MOCKY = MockModule(getModuleAddress(_toKeycode("MOCKY")));

        dependencies = new Kernel.Keycode[](1);
        dependencies[0] = _toKeycode("MOCKY");
    }

    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](1);
        requests[0] = Permissions(_toKeycode("MOCKY"), MOCKY.permissionedCall.selector);
    }

    function callPublicFunction() external {
      MOCKY.publicCall();
    }

    // TODO Add identity
    function callPermissionedFunction() external {
      MOCKY.permissionedCall();
    }

}