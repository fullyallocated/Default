// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "src/Kernel.sol";
import "./MockModule.sol";

contract MockPolicy is Policy {
    MockModule public MOCKY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](1);
        dependencies[0] = toKeycode("MOCKY");

        MOCKY = MockModule(getModuleAddress(dependencies[0]));
    }

    function requestPermissions() external view override returns (Permissions[] memory requests) {
        requests = new Permissions[](1);
        requests[0] = Permissions(toKeycode("MOCKY"), MOCKY.permissionedCall.selector);
    }

    function callPublicFunction() external {
        MOCKY.publicCall();
    }

    function callPermissionedFunction() external onlyRole("tester") {
        MOCKY.permissionedCall();
    }
}