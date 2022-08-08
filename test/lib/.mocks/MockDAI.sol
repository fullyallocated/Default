import { ERC20 } from "solmate/tokens/ERC20.sol";

pragma solidity ^0.8.15;

contract MockDAI is ERC20("DAI", "DAI", 18) {
    
    function mint(address to_, uint256 amt_) public {
        _mint(to_, amt_);
    }
}
