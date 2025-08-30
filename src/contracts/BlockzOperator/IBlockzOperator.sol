//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IBlockzOperator {
    struct Blockz {
        uint32 level;
        uint32 rarityScore;
    }
    function callbackRandomWord(uint256 _requestId, uint256[] calldata _randomWords) external;
    function getBlockzPower(uint256 _tokenId) external view returns (uint256);
    function getBlockzAttribute(uint256 _tokenId) external view returns (Blockz memory);
}