// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC721AUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "./ERC721ANameableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IPNBB.sol";
import "./IPNUT.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract LuckyElephantClub is Initializable, ERC721AUpgradeable, OwnableUpgradeable, DefaultOperatorFiltererUpgradeable, ERC2981Upgradeable, ERC721ANameableUpgradeable, UUPSUpgradeable {

    using StringsUpgradeable for uint256;

    // VARIABLES //

    /// @notice Bytes32 for merkle root hash.
    bytes32 public merkleRoot;

    /// @notice PNBB erc20 token contract address.
    IPNBB public PNBB;

    /// @notice PNUT erc20 token contract address.
    IPNUT public PNUT;

    /// @notice Address of community wallet.
    address public communityWallet;

    /// @notice Boolean to reveal or unreveal.
    bool public revealed;

    /// @notice Uint256 for amalgamation price in $PNUT.
    uint256 public amalgamatePrice;

    /// @notice Uint256 for max supply of the entire collection.
    uint256 public maxSupply;

    /**
     * @notice Uint256 for sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    uint256 public saleMode;

    /// @notice String for base token URI prefix.
    string public baseTokenURIPrefix;

    /// @notice String for base token URI suffix.
    string public baseTokenURISuffix;

    /// @notice String for not revealed URI.
    string public notRevealedURI;

    /// @notice Struct for storing details of baby.
    struct Baby {
        uint256 parent1;
        uint256 parent2;
        string dna;
    }

    /// @notice Mapping for DNA.
	mapping(string => Baby) public DNA;

    /// @notice Mapping for balance of genesis associated with an address.
    mapping(address => uint256) public balanceGenesis;

    /**
     * @notice Mapping for whether minting is enabled for a sale mode,
     * true if enabled, false if disabled.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => bool) public _mintingEnabled;

    /**
     * @notice Mapping for max supply for a sale mode,
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => uint256) public _maxSupply;

    /**
     * @notice Mapping for max mint per address for a sale mode,
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => uint256) public _maxMintPerAddress;

    /**
     * @notice Mapping for total minted for a sale mode,
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => uint256) public _minted;

    /**
     * @notice Mapping for minting price for a sale mode,
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => uint256) public _price;

    /**
     * @notice Mapping for total number of NFTs minted by an address for a sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGS Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby
     */
    mapping(uint256 => mapping(address => uint256)) public addressMinted;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { 
        _disableInitializers();
    }

    // INITIALIZATION //

    /// @notice Function to initialize the smart contract. 
    function initialize() initializer public {
        __ERC721A_init("Lucky Elephant Club", "LEC");
        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ERC2981_init();
        __ERC721ANameable_init();
        __UUPSUpgradeable_init();

        saleMode = 1;
    }

    // MODIFIERS //

    /// @notice Modifier for mint compliances.
    modifier mintCompliance(address _to, uint256 _mintAmount) {
        require(_mintAmount + addressMinted[saleMode][_to] <= _maxMintPerAddress[saleMode], "You can't mint more for the saleMode");
        require(msg.value >= _mintAmount * _price[saleMode], "Insufficient Fund");
        require(_minted[saleMode] + _mintAmount <= _maxSupply[saleMode], "No more NFTs to mint for the saleMode");
        require(_mintingEnabled[saleMode] == true, "Minting not enabled");
        _;
    }

    /// @notice Modifier for amalgamation compliances.
    modifier amalgamateCompliance(uint256 _parent1, uint256 _parent2) {
        require(saleMode == 7, "Amalgamating not active");
        require(_minted[saleMode] + 1 <= _maxSupply[saleMode], "No more babies can be amalgamated");
        require(_mintingEnabled[saleMode] == true, "Minting not enabled");
        require(ownerOf(_parent1) == msg.sender, "You don't own this token");
        if (_parent2 < maxSupply + 1) {
            require(ownerOf(_parent2) == msg.sender, "You don't own this token");
        }
        _;
    }

    // PUBLIC FUNCTIONS, WRITE CONTRACT FUNCTIONS //

    /**
     * @notice Public function.
     * Function that allows the caller to amalgamate a NFT using $PNUT to create a new NFT.
     * Requires saleMode value to be 7.
     * Requires minting for saleMode 7 to be enabled.
     * _singleParent: tokenId of the single parent NFT.
     */
    function amalgamateWithERC20(uint256 _singleParent) public amalgamateCompliance(_singleParent, maxSupply + 1)  {
        string memory pair = getDNAFromPair(_singleParent, 0);
        require(!compareDNA(DNA[pair].dna, pair), "DNA exist, try other combination");
		require(PNUT.balanceOf(msg.sender) >= amalgamatePrice, "You don't have enough $PNUT");
        _safeMint(msg.sender, 1);
        addressMinted[saleMode][msg.sender]++;
        _minted[saleMode]++;
        DNA[pair] = Baby(_singleParent, maxSupply + 1, pair);
        PNUT.burn(msg.sender, amalgamatePrice);
    }

    /**
     * @notice Public function.
     * Function that allows a caller to amalgamate two NFTs to create a new NFT.
     * Requires saleMode value to be 7.
     * Requires minting for saleMode 7 to be enabled.
     * _parent1: tokenId of the first parent NFT.
     * _parent2: tokenId of the second parent NFT.
     */
    function amalgamateWithParents(uint256 _parent1, uint256 _parent2) public amalgamateCompliance(_parent1, _parent2) {
        string memory pair = getDNAFromPair(_parent1, _parent2);
        require(!compareDNA(DNA[pair].dna, pair), "DNA exist, try other combination");
        _safeMint(msg.sender, 1);
        addressMinted[saleMode][msg.sender]++;
        _minted[saleMode]++;
        DNA[pair] = Baby(_parent1, _parent2, pair);
    }

    /**
     * @notice Public function.
     * Function that allows the owner of an NFT to update the NFT's bio using $PNUT.
     * _tokenId: tokenId of the NFT to update.
     * _newBio: New bio string for the NFT.
     */
    function changeBio(uint256 _tokenId, string memory _newBio) public override {
		address owner = ownerOf(_tokenId);
		require(_msgSender() == owner, "ERC721: Caller are not the token owner");
		require(PNUT.balanceOf(msg.sender) >= bioChangePrice, "You don't have enough $PNUT");
        PNUT.burn(msg.sender, bioChangePrice);
		super.changeBio(_tokenId, _newBio);
    }

    /**
     * @notice Public function.
     * Function that allows the owner of an NFT to update the NFT's name using $PNUT.
     * _tokenId: tokenId of the NFT to update.
     * _newBio: New bio string for the NFT.
     */
    function changeName(uint256 _tokenId, string memory _newName) public override {
		address owner = ownerOf(_tokenId);
		require(_msgSender() == owner, "ERC721: Caller are not the token owner");
		require(PNUT.balanceOf(msg.sender) >= nameChangePrice, "You don't have enough $PNUT");
		require(validateName(_newName) == true, "New name is not valid");
		require(keccak256(bytes(_newName)) != keccak256(bytes(tokenName(_tokenId))), "New name is same as the current one");
		require(isNameReserved(_newName) == false, "New name is not available");
        PNUT.burn(msg.sender, nameChangePrice);
		super.changeName(_tokenId, _newName);
	}

    /**
     * @notice Public function.
     * Function mints a specified amount of Genesis tokens to a given address.
     * Requires saleMode value to be 4.
     * Requires minting for saleMode 4 to be enabled.
     * Requires sufficient ETH to execute.
     * _recipient: The address of the recipient.
     * _mintAmount: The amount of tokens to mint.
     */
    function publicMintGenesis(address _recipient, uint256 _mintAmount) public payable mintCompliance(_recipient, _mintAmount) {
        require(saleMode == 4, "Incorrect sale mode");
        _safeMint(_recipient, _mintAmount);
        addressMinted[saleMode][_recipient] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    /**
     * @notice Public function.
     * Function mints a specified amount of OGs tokens to a given address.
     * Requires saleMode value to be 5.
     * Requires minting for saleMode 5 to be enabled.
     * Requires sufficient ETH to execute.
     * _recipient: The address of the recipient.
     * _mintAmount: The amount of tokens to mint.
     */
    function publicMintOGs(address _recipient, uint256 _mintAmount) public payable mintCompliance(_recipient, _mintAmount) {
        require(saleMode == 5, "Incorrect sale mode");
        _safeMint(_recipient, _mintAmount);
        addressMinted[saleMode][_recipient] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    /**
     * @notice Public function.
     * Function mints a specified amount of LuckyList tokens to a given address.
     * Requires saleMode value to be 6.
     * Requires minting for saleMode 6 to be enabled.
     * Requires sufficient ETH to execute.
     * _recipient: The address of the recipient.
     * _mintAmount: The amount of tokens to mint.
     */
    function publicMintLuckyList(address _recipient, uint256 _mintAmount) public payable mintCompliance(_recipient, _mintAmount) {
        require(saleMode == 6, "Incorrect sale mode");
        _safeMint(_recipient, _mintAmount);
        addressMinted[saleMode][_recipient] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    /**
     * @notice Public function.
     * Function mints a specified amount of Genesis tokens to the caller using a whitelist.
     * Requires saleMode value to be 1.
     * Requires minting for saleMode 1 to be enabled.
     * Requires sufficient ETH to execute.
     * _mintAmount: The amount of tokens to mint.
     * _merkleProof: The merkle proof array of the caller being on the whitelist.
     */
    function whitelistMintGenesis(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(msg.sender, _mintAmount) {
        require(saleMode == 1, "Incorrect sale mode");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf), "You are not whitelisted");
        _safeMint(msg.sender, _mintAmount);
        addressMinted[saleMode][msg.sender] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    /**
     * @notice Public function.
     * Function mints a specified amount of OGs tokens to the caller using a whitelist.
     * Requires saleMode value to be 2.
     * Requires minting for saleMode 2 to be enabled.
     * Requires sufficient ETH to execute.
     * _mintAmount: The amount of tokens to mint.
     * _merkleProof: The merkle proof array of the caller being on the whitelist.
     */
    function whitelistMintOGs(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(msg.sender, _mintAmount) {
        require(saleMode == 2, "Incorrect sale mode");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf), "You are not whitelisted");
        _safeMint(msg.sender, _mintAmount);
        addressMinted[saleMode][msg.sender] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    /**
     * @notice Public function.
     * Function mints a specified amount of LuckyList tokens to the caller using a whitelist.
     * Requires saleMode value to be 3.
     * Requires minting for saleMode 3 to be enabled.
     * Requires sufficient ETH to execute.
     * _mintAmount: The amount of tokens to mint.
     * _merkleProof: The merkle proof array of the caller being on the whitelist.
     */
    function whitelistMintLuckyList(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(msg.sender, _mintAmount) {
        require(saleMode == 3, "Incorrect sale mode");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf), "You are not whitelisted");
        _safeMint(msg.sender, _mintAmount);
        addressMinted[saleMode][msg.sender] += _mintAmount;
        _minted[saleMode] += _mintAmount;
    }

    // SMART CONTRACT OWNER ONLY FUNCTIONS, WRITE CONTRACT FUNCTIONS //

    /**
     * @notice Smart contract owner only function.
     * Function airdrops a specified amount of tokens to an array of addresses for the current saleMode.
     * _recipients: The array of addresses to receive the airdrop.
     * _amount: The amount of tokens to airdrop to each address.
     */
    function airdrop(address[] calldata _recipients, uint256 _amount) public onlyOwner {
        require(_minted[saleMode] + _recipients.length * _amount <= _maxSupply[saleMode], "Exceeds sale mode max supply");
        for (uint256 i = 0; i < _recipients.length; i++) {
            _safeMint(_recipients[i], _amount);
            _minted[saleMode] += _amount;
        }
    }

    /**
     * @notice Smart contract owner only function.
     * Function changes the base token URI prefix.
     * newBaseTokenURI: The new base token URI prefix.
     */
    function changeBaseTokenURIPrefix(string memory newBaseTokenURIPrefix) public onlyOwner {
        baseTokenURIPrefix = newBaseTokenURIPrefix;
    }

    /**
     * @notice Smart contract owner only function.
     * Function changes the base token URI suffix.
     * newBaseTokenURISuffix: The new base token URI suffix.
     */
    function changeBaseTokenURISuffix(string memory newBaseTokenURISuffix) public onlyOwner {
        baseTokenURISuffix = newBaseTokenURISuffix;
    }

    /**
     * @notice Smart contract owner only function.
     * Function changes or increments the current sale mode safely to the next mode.
     * Use of this function is strongly recommended to change the sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGs Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    function changeSaleModeSafely() public onlyOwner {
        require(_maxSupply[saleMode] > 0, "Max supply of current sale mode must be greater than zero");
        require(_maxSupply[saleMode + 1] > 0, "Max supply of next sale mode must be greater than zero");
        if (_minted[saleMode] == _maxSupply[saleMode]) {
           saleMode++;
        }
    }

    /**
     * @notice Smart contract owner only function.
     * Function changes the sale mode.
     * Use of changeSaleModeSafely function is recommended rather than using this function.
     * _saleMode: The sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGs Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    function changeSaleMode(uint256 _saleMode) public onlyOwner {
        saleMode = _saleMode;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the amalgamation price required to execute the amalgamationWithERC20 function. 
     * newAmalgamatePrice: The new amalgamation price required to execute the amalgamationWithERC20 function.
     */  
    function setAmalgamatePrice(uint256 newAmalgamatePrice) public onlyOwner {
        amalgamatePrice = newAmalgamatePrice;
    }

    /** 
     * @notice Smart contract owner only function.
     * ERC2981 royalty standard implementation function.
     * It is upto the marketplace to honour this standard.
     * Function sets royalties for the entire collection for secondary sales.
     * Basis points limit is 10000, 500 basis points will mean 5% royalties on each sale.
     * To receive royalties to a payment splitter smart contract,
     * enter the payment splitter smart contract's contract address as the receiver.
     * receiver: The address of the royalty receiver.
     * basisPoints: The royalties in basis points.
     */
    function setCollectionRoyalties(address receiver, uint96 basisPoints) public onlyOwner {
        _setDefaultRoyalty(receiver, basisPoints);
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the community wallet address.
     * newAddress: The new community wallet address.
     */
    function setCommunityWallet(address newAddress) public onlyOwner {
        communityWallet = newAddress;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the price for changing a token's name and bio.
     * newNameChangePrice: The new price for changing a token's name.
     * newBioChangePrice: The new price for changing a token's bio.
     */
    function setNameAndBioChangePrice(uint256 newNameChangePrice, uint256 newBioChangePrice) public onlyOwner {
		nameChangePrice = newNameChangePrice;
		bioChangePrice = newBioChangePrice;
	}

    /**
     * @notice Smart contract owner only function.
     * Function sets the maximum allowed supply of tokens.
     * The new maximum supply must be greater than or equal to the current total supply.
     * newMaxSupply: The new maximum allowed supply of tokens.
     */
    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(newMaxSupply >= totalSupply(), "newMaxSupply must be greater than or equal to the totalSupply");
        maxSupply = newMaxSupply;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the merkle root for the whitelist.
     * merkleHash: The new merkle root hash.
     */
    function setMerkleRoot(bytes32 merkleHash) public onlyOwner {
        merkleRoot = merkleHash;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the URI for tokens when not revealed.
     * newNotRevealedURI: The new URI for tokens when not revealed.
     */
    function setNotRevealedURI(string memory newNotRevealedURI) public onlyOwner {
        notRevealedURI = newNotRevealedURI;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the addresses of the PNBB and PNUT ERC20 contracts.
     * addressPNBB: The address of the PNBB ERC20 contract.
     * addressPNUT: The address of the PNUT ERC20 contract.
     */
    function setPNBBAndPNUT(address addressPNBB, address addressPNUT) public onlyOwner {
        PNBB = IPNBB(addressPNBB);
        PNUT = IPNUT(addressPNUT);
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the revealed status.
     * status: true to set as revealed, false to set as not revealed.
     */
    function setRevealedStatus(bool status) public onlyOwner {
        revealed = status;
    }

    /**
     * @notice Smart contract owner only function.
     * Function set the max supply and max mint per address for a sale mode.
     * _saleMode: The sale mode.
     * __maxSupply: The max supply for the sale mode.
     * __maxMintPerAddress: The max mint per address for the sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGs Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    function setMaxMintAndSupply(uint256 _saleMode, uint256 __maxSupply, uint256 __maxMintPerAddress) public onlyOwner {
        require(__maxSupply >= _minted[_saleMode], "__maxSupply must be greater than or equal to current __minted for the saleMode");
        require(__maxMintPerAddress <= __maxSupply, "__maxMintPerAddress must be smaller than or equal to __maxSupply");
        _maxSupply[_saleMode] = __maxSupply;
        _maxMintPerAddress[_saleMode] = __maxMintPerAddress;
    }

    /**
     * @notice Smart contract owner only function.
     * Function enables or disables minting for a sale mode.
     * _saleMode: The sale mode.
     * __mintingEnabled: Set to true to enable minting for the sale mode and to false to disable minting for the sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGs Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    function setMintingEnabled(uint256 _saleMode, bool __mintingEnabled) public onlyOwner {
        _mintingEnabled[_saleMode] = __mintingEnabled;
    }

    /**
     * @notice Smart contract owner only function.
     * Function sets the price for minting a single NFT for a sale mode.
     * _saleMode: The sale mode.
     * __price: The price of a single NFT for the sale mode.
     * Sale modes:
     * 1 = Genesis Whitelist Mint,
     * 2 = OGs Whitelist Mint, 
     * 3 = LuckyList Whitelist Mint,
     * 4 = Genesis Public Mint,
     * 5 = OGS Public Mint,
     * 6 = LuckyList Public Mint,
     * 7 = Amalgamation / Baby .
     */
    function setPrice(uint256 _saleMode, uint256 __price) public onlyOwner {
        _price[_saleMode] = __price;
    }

    /**
     * @notice Smart contract owner only function.
     * Functions withdraws the ETH accumulated in the smart contract to the community wallet and the smart contract owner's wallet.
     * 80% of the mint price would be transferred to the community wallet.
     */
    function withdraw() public onlyOwner {
        payable(communityWallet).transfer(address(this).balance * 8 / 10);      
        payable(msg.sender).transfer(address(this).balance);
    }

    // OVERRIDDEN PUBLIC WRITE CONTRACT FUNCTIONS: OpenSea's Royalty Filterer Implementation //

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    // GETTER FUNCTIONS, READ CONTRACT FUNCTIONS //

    /**
     * @notice Function queries and returns true or false for whether a interface is supported or not.
     * interfaceId: The interface.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721AUpgradeable, ERC2981Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Function queries and returns the URI for a NFT tokenId.
     * tokenId: The tokenId of the NFT.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if (revealed == false) {
            return notRevealedURI;
        }
        return bytes(baseTokenURIPrefix).length > 0 ? string(abi.encodePacked(baseTokenURIPrefix, tokenId.toString(), baseTokenURISuffix)) : "";
    }

    // INTERNAL FUNCTIONS //


    /// @notice Internal function called when requiring authorization to upgrade to a new implementation.
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    /// @notice Internal function called for the calculation of rewards for the Genesis token holders.
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual override {
        if (startTokenId >= 1 && startTokenId <= _maxSupply[1]) {
            PNBB.updateReward(from, to);
            if (from != address(0)) {
                balanceGenesis[from] -= quantity;
            }
            if (to != address(0)) {
                balanceGenesis[to] += quantity;
            } 
        }
        if (startTokenId >= (_maxSupply[1] + _maxSupply[2] + _maxSupply[3] + 1) && startTokenId <= (_maxSupply[1] + _maxSupply[2] + _maxSupply[3] + _maxSupply[4])) {
            PNBB.updateReward(from, to);
            if (from != address(0)) {
                balanceGenesis[from] -= quantity;
            }
            if (to != address(0)) {
                balanceGenesis[to] += quantity;
            } 
        }
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    /// @notice Internal function called to compare dna.
    function compareDNA(string memory a, string memory b) pure internal returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    /// @notice Internal function called to get dna.
    function getDNAFromPair(uint256 parent1, uint256 parent2) pure internal returns (string memory) {
        require(parent1 != parent2, "Use different parents");
        uint256 lowest = parent1 < parent2 ? parent1 : parent2;
        uint256 highest = lowest == parent1 ? parent2 : parent1;
        return string(abi.encodePacked(StringsUpgradeable.toString(lowest), ":", StringsUpgradeable.toString(highest)));
    }

    /// @notice Internal function which ensures the first minted NFT has tokenId as 1.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
