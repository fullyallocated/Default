// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Kernel} from "./Kernel.sol";

contract KernelAccessControl {
    event PolicyRoleUpdated(address indexed policy_, uint8 indexed role, bool enabled);
    event UserRolesTransferred(address oldUser_, address newUser_);

    event RoleCapabilityUpdated(uint8 indexed role, address indexed module_, bytes4 indexed functionSig_, bool enabled);

    /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bytes32) public getPolicyRoles;

    mapping(bytes4 => bytes32) public getFuncSelectorId;// TODO instead make the selector into a role

    mapping(bytes5 => mapping(bytes4 => bytes32)) public getRolesWithCapability;
    // TODO need to invert this. make it so module upgrade is just a transfer of the bitmap to a new address in the mapping
    // TODO can prob be done by holding the funcSig access bitmap in the module
    //mapping(uint8 => )

    function doesRoleHaveCapability(
        uint8 policy_,
        bytes5 keycode_,
        bytes4 functionSig
    ) public view virtual returns (bool) {
        return (uint256(getRolesWithCapability[keycode_][functionSig]) >> policy_) & 1 != 0;
    }

    /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function canCall(
        address policy_,
        bytes5 module_,
        bytes4 functionSig_
    ) public view returns (bool) {
        return bytes32(0) != getPolicyRoles[policy_] & getRolesWithCapability[module_][functionSig_];
    }

    //function _setPolicyCapability(
    //    uint8 role,
    //    address module_,
    //    bytes4 functionSig_,
    //    bool enabled
    //) internal virtual {
    //    if (enabled) {
    //        getRolesWithCapability[module_][functionSig_] |= bytes32(1 << role);
    //    } else {
    //        getRolesWithCapability[module_][functionSig_] &= ~bytes32(1 << role);
    //    }

    //    emit RoleCapabilityUpdated(role, module_, functionSig_, enabled);
    //}

    function _setPolicyCapability(
        uint8 policy_,
        bytes5 keycode_,
        bytes4 functionSig_,
        bool enabled
    ) internal virtual {
        if (enabled) {
            getRolesWithCapability[keycode_][functionSig_] |= bytes32(1 << policy_);
        } else {
            getRolesWithCapability[keycode_][functionSig_] &= ~bytes32(1 << policy_);
        }

        emit RoleCapabilityUpdated(policy_, keycode_, functionSig_, enabled);
    }

    /*//////////////////////////////////////////////////////////////
                       USER ROLE ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _setUserRole(
        address policy_,
        uint8 role,
        bool enabled
    ) internal {
        if (enabled) {
            getPolicyRoles[policy_] |= bytes32(1 << role);
        } else {
            getPolicyRoles[policy_] &= ~bytes32(1 << role);
        }

        emit PolicyRoleUpdated(policy_, role, enabled);
    }
}