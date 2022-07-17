// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Vm} from "forge-std/Vm.sol";

//common utilities for forge tests
contract UserFactory {
    address internal constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    bytes32 internal nextUser = keccak256(abi.encodePacked("users"));

    function next() public returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    //create users with 100 ether balance
    function create(uint256 userNum) public returns (address[] memory) {
        address[] memory usrs = new address[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address user = next();
            vm.deal(user, 100 ether);
            usrs[i] = user;
        }
        return usrs;
    }
}
