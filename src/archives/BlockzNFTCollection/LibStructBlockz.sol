//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library LibStructBlockz {
	struct Blockz {
		uint8 strength;
		uint8 agility;
		uint8 vitality;
		uint8 intelligence;
		uint8 fertility;
		uint256 level;
		uint16 rebirths;
		uint64 birthTime;
	}
}
