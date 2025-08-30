//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "./LibStructBlockz.sol";
interface IBlockzNFTCollection {
    function getBlockz(uint256 tokenId) external view returns (LibStructBlockz.Blockz memory);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 tokenId) external;
}