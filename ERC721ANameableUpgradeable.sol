// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ERC721ANameableUpgradeable is Initializable {

    // VARIABLES //

    /// @notice Uint256 for bio change price in $PNUT
	uint256 public bioChangePrice;
	
    /// @notice Uint256 for name change price in $PNUT.
    uint256 public nameChangePrice;

    /// @notice Mapping for bio associated with a tokenId.
	mapping(uint256 => string) internal bio;

	/// @notice Mapping if certain name string has already been reserved
	mapping(string => bool) internal _nameReserved;

	/// @notice Mapping for name associated with a tokenId.
	mapping(uint256 => string) internal _tokenName;

    // INTERNAL FUNCTIONS //

    /// @notice Internal function called when smart contract is initialized.
    function __ERC721ANameable_init() internal onlyInitializing {}

    /// @notice Internal function called when smart contract is initialized.
    function __ERC721ANameable_init_unchained() internal onlyInitializing {}

	/// @notice Internal function called which reserves the name if isReserve is set to true, de-reserves if set to false.
	function toggleReserveName(string memory str, bool isReserve) internal {
		_nameReserved[toLower(str)] = isReserve;
	}

    // PUBLIC FUNCTIONS //

    /// @notice Function called when changing token name.
	function changeName(uint256 tokenId, string memory newName) public virtual {
		// If already named, dereserve old name
		if (bytes(_tokenName[tokenId]).length > 0) {
			toggleReserveName(_tokenName[tokenId], false);
		}
        toggleReserveName(newName, true);
		_tokenName[tokenId] = newName;
	}

    /// @notice Function called when changing token bio.
	function changeBio(uint256 _tokenId, string memory _bio) public virtual {
		bio[_tokenId] = _bio;
	}

    // GETTER FUNCTIONS, READ CONTRACT FUNCTIONS //

	/// @notice Function returns bio of the NFT tokenId.
	function tokenBio(uint256 tokenId) public view returns (string memory) {
		return bio[tokenId];
	}

	/// @notice Function returns name of the NFT tokenId.
	function tokenName(uint256 tokenId) public view returns (string memory) {
		return _tokenName[tokenId];
	}

	/// @notice Function returns true or false if a name has been reserved or not.
	function isNameReserved(string memory nameString) public view returns (bool) {
		return _nameReserved[toLower(nameString)];
	}

    /// @notice Function validates name and returns true or false.
	function validateName(string memory str) internal pure returns (bool) {
		bytes memory b = bytes(str);
		if (b.length < 1) {return false;}
		if (b.length > 25) {return false;} // Cannot be longer than 25 characters
		if (b[0] == 0x20) {return false;} // Leading space
		if (b[b.length - 1] == 0x20) {return false;} // Trailing space

		bytes1 lastChar = b[0];

		for (uint i; i < b.length; i++) {
			bytes1 char = b[i];

			if (char == 0x20 && lastChar == 0x20) {return false;} // Cannot contain continous spaces

			if (!(char >= 0x30 && char <= 0x39) && //9-0
				!(char >= 0x41 && char <= 0x5A) && //A-Z
				!(char >= 0x61 && char <= 0x7A) && //a-z
				!(char == 0x20) //space
			   ) {
			   return false;
            }

			lastChar = char;
		}

		return true;
	}

	 /// @notice Function converts the string to lowercase.
	function toLower(string memory str) internal pure returns (string memory){
		bytes memory bStr = bytes(str);
		bytes memory bLower = new bytes(bStr.length);
		for (uint i = 0; i < bStr.length; i++) {
			// Uppercase character
			if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
				bLower[i] = bytes1(uint8(bStr[i]) + 32);
			} else {
				bLower[i] = bStr[i];
			}
		}
		return string(bLower);
	}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}
