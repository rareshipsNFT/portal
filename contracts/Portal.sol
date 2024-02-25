//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// Portal is a contract that allows depositing and withdrawing of NFTs
// It acts as a starting point for the game
// Additionally it allows equipping the NFTs into each other
contract Portal {
    
    // admins is a list of addresses that are allowed to perform admin actions
    address[] public admins;

    modifier onlyAdmin() {
        bool isAdmin = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == msg.sender) {
                isAdmin = true;
                break;
            }
        }
        require(isAdmin, "only admins can perform this action");
        _;
    }

    // NFT struct represents a non-fungible token
    struct NFT {
        uint256 id;
        address contract_;
        uint256 tokenId;
        address owner;
    }

    // nftsByOwner is a mapping of owner address to their NFTs
    mapping(address => NFT[]) public nftsByOwner;

    // nftsById is a mapping of NFT id to the NFT
    mapping(uint256 => NFT) public nftsById;

    // equippedNFTs is a mapping of NFT id to the NFTs that are equipped into it
    mapping(uint256 => uint256[]) public equippedNFTs;
    
    // isEquipped is a mapping of NFT id to a boolean that represents if the NFT is equipped
    mapping(uint256 => bool) public isEquipped;

    // authorizations is a mapping of address to a mapping of address to a boolean
    // that represents if the first address is authorized by the second address
    mapping(address => mapping(address => bool)) public authorizations;

    // constructor adds the sender to the list of admins
    constructor() {
        admins.push(msg.sender);
    }

    // addAdmin allows adding an address to the list of admins
    function addAdmin(address admin) public onlyAdmin {
        admins.push(admin);
    }

    // removeAdmin allows removing an address from the list of admins
    function removeAdmin(address admin) public onlyAdmin {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
    }

    // authorize allows authorizing an address by another address
    function authorize(address to) public {
        authorizations[msg.sender][to] = true;
    }

    // unauthorize allows unauthorizing an address by another address
    function unauthorize(address to) public {
        authorizations[msg.sender][to] = false;
    }

    // isAuthorized returns true either if the sender is the first address or if the first address authorized the second address
    function isAuthorized(address from, address to) public view returns (bool) {
        return msg.sender == from || authorizations[from][to] ;
    }

    // depositNFT allows depositing an NFT into the portal
    function depositNFT(address contract_, uint256 tokenId) public {
        // compute id for the NFT
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender, contract_, tokenId)));
        NFT memory nft = NFT(id, contract_, tokenId, msg.sender);
        
        // Add the NFT to the owner's list of NFTs
        nftsByOwner[msg.sender].push(nft);
        
        // Add the NFT to the list of NFTs
        nftsById[id] = nft;
        
        // Transfer the NFT from the sender to the contract_
        IERC721(contract_).transferFrom(msg.sender, address(this), tokenId);
    }

    // withdrawNFT allows withdrawing an NFT from the portal
    function withdrawNFT(uint256 id) public {
        // Find the NFT by id
        NFT memory nft;
        for (uint256 i = 0; i < nftsByOwner[msg.sender].length; i++) {
            if (nftsByOwner[msg.sender][i].id == id) {
                nft = nftsByOwner[msg.sender][i];
                
                // check if the sender is the owner of the NFT
                require(isAuthorized(nft.owner, msg.sender), "only the owner or an authorized address can withdraw the NFT");
                
                // remove the NFT from the owner's list of NFTs
                nftsByOwner[msg.sender][i] = nftsByOwner[msg.sender][nftsByOwner[msg.sender].length - 1];
                nftsByOwner[msg.sender].pop();
                
                // remove the NFT from the list of NFTs
                delete nftsById[id];
                break;
            }
        }

        // Transfer the NFT from the contract_ to the sender
        IERC721(nft.contract_).transferFrom(address(this), msg.sender, nft.tokenId);
    }

    // equipNFT allows equipping an NFT into another NFT
    function equipNFT(uint256 id, uint256 intoId) public {
        // Find the NFT by id
        NFT memory nft = nftsById[id];
        
        // check if the sender is the owner of the NFT
        require(isAuthorized(nft.owner, msg.sender), "only the owner or an authorized address can equip the NFT");

        // check if the NFT is not equipped
        require(!isEquipped[id], "the NFT is already equipped");

        // Find the NFT by intoId
        NFT memory intoNft = nftsById[intoId];
        
        // check if the sender is the owner of the NFT
        require(isAuthorized(intoNft.owner, msg.sender), "only the owner or an authorized address can equip something into the NFT");

        // Add the NFT to the list of equipped NFTs
        equippedNFTs[intoId].push(id);

        // Mark the NFT as equipped
        isEquipped[id] = true;
    }

    // unequipNFT allows unequipping an NFT from another NFT
    function unequipNFT(uint256 id, uint256 fromId) public {
        // Find the NFT by id
        NFT memory nft = nftsById[id];
        
        // check if the sender is the owner of the NFT
        require(isAuthorized(nft.owner, msg.sender), "only the owner or an authorized address can unequip the NFT");

        // check if the NFT is equipped
        require(isEquipped[id], "the NFT is not equipped");

        // Find the NFT by fromId
        NFT memory fromNft = nftsById[fromId];
        
        // @dev No check if isAuthorized on the fromNFT because a authorized person for the first NFT should always be able to unequip

        // Remove the NFT from the list of equipped NFTs
        bool found = false;
        for (uint256 i = 0; i < equippedNFTs[fromId].length; i++) {
            if (equippedNFTs[fromId][i] == id) {
                equippedNFTs[fromId][i] = equippedNFTs[fromId][equippedNFTs[fromId].length - 1];
                equippedNFTs[fromId].pop();
                found = true;
                break;
            }
        }

        // check if the NFT is equipped into the other NFT
        require(found, "the NFT is not equipped into the other NFT");

        // Mark the NFT as unequipped
        isEquipped[id] = false;
    }

    // getNFTsByOwner returns the NFTs of an owner
    function getNFTsByOwner(address owner) public view returns (NFT[] memory) {
        return nftsByOwner[owner];
    }

    // getEquippedNFTs returns the equipped NFTs of an NFT
    function getEquippedNFTs(uint256 id) public view returns (NFT[] memory) {
        uint256[] memory equippedNFTIds = equippedNFTs[id];
        NFT[] memory equippedNFTs_ = new NFT[](equippedNFTIds.length);
        for (uint256 i = 0; i < equippedNFTIds.length; i++) {
            equippedNFTs_[i] = nftsById[equippedNFTIds[i]];
        }
        return equippedNFTs_;
    }

}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}