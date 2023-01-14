// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IPNUT {
    
    function balanceOf(address account) external view returns(uint256);

    function burn(address account, uint256 amount) external;
}