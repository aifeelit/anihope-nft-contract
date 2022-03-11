// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Jebus is ERC721A, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public constant maxSupply = 6969;
    uint256 public constant maxPerMint = 20;
    uint256 public salePrice = 0.2 ether;
    uint256 public presaleMaxPerWallet = 2;

    address proxyRegistryAddress;

    bool public paused = false;
    bool public isRevealed = false;
    bool public publicSaleActive = false;
    bool public presaleActive = false;
    mapping(address => uint256) private _presaleMints;


    string public baseURI = "";
    string public notRevealedUri = "ipfs://QmYUuwLoiRb8woXwJCCsr1gvbr8E21KuxRtmVBmnH1tZz7/hidden.json";
    string public baseExtension = ".json";

    bytes32 public merkleRoot;

    constructor(address _proxyRegistryAddress) 
    ERC721A("Jebus", "JBS", 20) 
    {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function togglePause() public onlyOwner {
        paused = !paused;
    }

    function togglepresaleActive() external onlyOwner {
        presaleActive = !presaleActive;
    }

    function togglepublicSaleActive() external onlyOwner {
        publicSaleActive = !publicSaleActive;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setsalePrice(uint256 _newsalePrice) external onlyOwner {
        salePrice = _newsalePrice * (1 ether);
    }

    function toggleReveal() external onlyOwner {
        isRevealed = !isRevealed;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (isRevealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();

        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    /// Set number of maximum presale mints a wallet can have
    /// @param _newPresaleMaxPerWallet value to set
    function setPresaleMaxPerWallet(uint256 _newPresaleMaxPerWallet)
        external
        onlyOwner
    {
        presaleMaxPerWallet = _newPresaleMaxPerWallet;
    }

    /// Presale mint function
    /// @param tokens number of tokens to mint
    /// @param merkleProof Merkle Tree proof
    /// @dev reverts if any of the presale preconditions aren't satisfied
    function mintPresale(uint256 tokens, bytes32[] calldata merkleProof)
        external
        payable
    {
        require(presaleActive, "Presale has not started yet!");
        require(!paused, "Presale is Paused");
        require(
            MerkleProof.verify(
                merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "You are not on the whitelist."
        );
        require(
            _presaleMints[_msgSender()] + tokens <= presaleMaxPerWallet,
            "Address already claimed max tokens for Presale."
        );
        require(
            tokens <= maxPerMint,
            "Exceeded max per transaction."
        );
        require(
            totalSupply() + tokens <= maxSupply,
            "Minting would exceed max supply."
        );
        require(tokens > 0, "Mint can't be 0 tokens");
        require(
            salePrice * tokens == msg.value,
            "ETH amount is incorrect."
        );

        _safeMint(_msgSender(), tokens);
        _presaleMints[_msgSender()] += tokens;
    }

    function mint(uint256 tokens) external payable {
        require(publicSaleActive, "Public Sale not started yet!");
        require(!paused, "Public sale is paused");
        require(
            tokens <= maxPerMint,
            "Exceeded max per transaction."
        );
        require(
            totalSupply() + tokens <= maxSupply,
            "Minting would exceed max supply."
        );
        require(tokens > 0, "Mint can't be 0 tokens");
        require(
            salePrice * tokens == msg.value,
            "ETH amount is incorrect."
        );

        _safeMint(_msgSender(), tokens);
    }

    function ownerMint(address to, uint256 tokens) external onlyOwner {
        require(
            totalSupply() + tokens <= maxSupply,
            "Minting would exceed max supply."
        );
        require(tokens > 0, "Mint can't be 0 tokens.");

        _safeMint(to, tokens);
    }

    /// Withdraw Funds
    function withdraw() public onlyOwner nonReentrant {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        override(ERC721A)
        public
        view
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }
}

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

