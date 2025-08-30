//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IVeBLOCK {
	function totalSupply() external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
}
