// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";
import "prb-math/contracts/PRBMath.sol";

/// @custom:security-contact contact@dkdk.club
contract DonkeyDecay is ERC721, ERC721URIStorage, Ownable {
    using PRBMathSD59x18 for int256;
    using Counters for Counters.Counter;
    event UpdateTreasury(address indexed treasury);
    Counters.Counter private _tokenIdCounter;
    uint256 private _lastMintBlock;  // Default to 0
    string private _overrideBaseURI;
    address payable private _treasury;

    int256 public constant INITIAL_PRICE = 10**18; // in Wei
    int256 public constant FINAL_PRICE = 10**15; // in Wei
    int256 public constant AUCTION_DURATION_BLOCKS = (72 * 60 * 60 ) / 12 ; // Assume 12 seconds per block

    uint256 public constant MAX_SUPPLY = 10000;
    address public constant DESIGNATIED_INTIALIZER = 0xd240bc7905f8D32320937cd9aCC3e69084ec4658;
    string public constant DEFAULT_BASE_URI = "https://dkdk.club/metadata/";
    constructor() ERC721("Donkey Decay", "DKDK") {
        _transferOwnership(DESIGNATIED_INTIALIZER);
        _treasury = payable(DESIGNATIED_INTIALIZER);
        _lastMintBlock = block.number;
    }

    // --- READONLY FUNCTIONS --- //
    function getLastMintBlock() public view returns (uint256) {
        return _lastMintBlock;
    }

    function getElapsedPortion(uint256 blockNum) public view returns (int256) {
        int256 elapsedPortion;
        if (getElapsedTime(blockNum) > AUCTION_DURATION_BLOCKS) {
            elapsedPortion = 1e18;
        } else {
            elapsedPortion = getElapsedTime(blockNum).div(AUCTION_DURATION_BLOCKS);
        }
        return elapsedPortion;
    }

    function getElapsedTime(uint256 blockNum) public view returns (int256) {
        return int256(blockNum - _lastMintBlock);
    }

    function currentPrice() external view returns (int256) {
        return _getPriceAtBlock(block.number);
    }

    function getPriceAtBlock(uint256 blockNum) external view returns (int256) {
        return _getPriceAtBlock(blockNum);
    }

    function _getPriceAtBlock(uint256 blockNum) internal view returns (int256) {
        int256 base = FINAL_PRICE.div(INITIAL_PRICE);
        return INITIAL_PRICE.mul(base.pow(getElapsedPortion(blockNum)));
    }

    function _baseURI() internal view override returns (string memory) {
        return bytes(_overrideBaseURI).length > 0 ? _overrideBaseURI : DEFAULT_BASE_URI;
    }

    // --- WRAPPER OF WRITE FUNCTIONS  --- //
    fallback() external payable {
        _safeMint(msg.sender);
    }

    receive() external payable {
        _safeMint(msg.sender);
    }

    function safeMint(address to) public payable { 
        _safeMint(to);
    }
    
    // --- CORE WRITE FUNCTIONS  --- //

    function _safeMint(address to) internal {
        // assert the payment has enough value
        uint256 price = uint256(_getPriceAtBlock(block.number));
        require(msg.value >= price, "Not enough value sent");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        // refund the excess value sent
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        _lastMintBlock = block.number;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _overrideBaseURI = baseURI;
    }

    function setTreasury(address payable treasury) public onlyOwner {
        _treasury = treasury;
    }

    /// @dev Withdraws all proceeds to the treasury address
    function withdrawProceeds() public {
        require(_treasury != address(0), "Treasury not set");
        require(address(this).balance > 0, "No proceeds to withdraw");
        require(msg.sender == _treasury || msg.sender == owner(), "Not authorized");
        payable(_treasury).transfer(address(this).balance);
    }


    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
