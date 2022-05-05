// SPDX-License-Identifier: MIT License
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @dev Contract module which provides access control
 *
 * the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * mapped to 
 * `onlyOwner`
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }
    

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}



contract MetaPunksMarket is ReentrancyGuard, Pausable, Ownable {

    IERC721 MetaPunksContract;     // instance of the CryptoPhunks contract

    struct Offer {
        bool isForSale;
        uint MetaPunkIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;
    }

    struct Bid {
        bool hasBid;
        uint MetaPunkIndex;
        address bidder;
        uint value;
    }

    // A record of phunks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Offer) public metapunksOfferedForSale;

    // A record of the highest phunk bid
    mapping (uint => Bid) public metapunkBids;

    // A record of pending ETH withdrawls by address
    mapping (address => uint) public pendingWithdrawals;

    event MetaPunkOffered(uint indexed metapunkIndex, uint minValue, address indexed toAddress);
    event MetaPunkBidEntered(uint indexed metapunkIndex, uint value, address indexed fromAddress);
    event MetaPunkBidWithdrawn(uint indexed metapunkIndex, uint value, address indexed fromAddress);
    event MetaPunkBought(uint indexed metapunkIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event MetaPunkNoLongerForSale(uint indexed metapunkIndex);

    /* Initializes contract with an instance of CryptoPhunks contract, and sets deployer as owner */
    constructor(address initialMetaPunksAddress) {
        IERC721(initialMetaPunksAddress).balanceOf(address(this));
        metapunksContract = IERC721(initialMetaPunksAddress);
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    /* Returns the CryptoPhunks contract address currently being used */
    function metapunkAddress() public view returns (address) {
      return address(metapunksContract);
    }

    /* Allows the owner of the contract to set a new CryptoPhunks contract address */
    function setMetaPunksContract(address newMetaPunksAddress) public onlyOwner {
      metapunksContract = IERC721(newMetaPunksAddress);
    }

    /* Allows the owner of a CryptoPhunks to stop offering it for sale */
    function metapunkNoLongerForSale(uint metapunkIndex) public nonReentrant() {
        if (metapunkIndex >= 10000) revert('token index not valid');
        if (metapunksContract.ownerOf(metapunkIndex) != msg.sender) revert('you are not the owner of this token');
        metapunksOfferedForSale[metapunkIndex] = Offer(false, metapunkIndex, msg.sender, 0, address(0x0));
        emit MetaPunkNoLongerForSale(metapunkIndex);
    }

    /* Allows a CryptoPhunk owner to offer it for sale */
    function offerMetaPunkForSale(uint metapunkIndex, uint minSalePriceInWei) public whenNotPaused nonReentrant()  {
        if (metapunkIndex >= 10000) revert('token index not valid');
        if (metapunksContract.ownerOf(metapunkIndex) != msg.sender) revert('you are not the owner of this token');
        metapunksOfferedForSale[metapunkIndex] = Offer(true, metapunkIndex, msg.sender, minSalePriceInWei, address(0x0));
        emit MetaPunkOffered(metapunkIndex, minSalePriceInWei, address(0x0));
    }

    /* Allows a CryptoPhunk owner to offer it for sale to a specific address */
    function offerMetaPunkForSaleToAddress(uint metapunkIndex, uint minSalePriceInWei, address toAddress) public whenNotPaused nonReentrant() {
        if (metapunkIndex >= 10000) revert();
        if (metapunksContract.ownerOf(metapunkIndex) != msg.sender) revert('you are not the owner of this token');
        metapunksOfferedForSale[metapunkIndex] = Offer(true, metapunkIndex, msg.sender, minSalePriceInWei, toAddress);
        emit MetaPunkOffered(metapunkIndex, minSalePriceInWei, toAddress);
    }

    /* Allows users to buy a CryptoPhunk offered for sale */
    function buyMetaPunk(uint metapunkIndex) payable public whenNotPaused nonReentrant() {
        if (metapunkIndex >= 10000) revert('token index not valid');
        Offer memory offer = metapunksOfferedForSale[metapunkIndex];
        if (!offer.isForSale) revert('metapunk is not for sale'); // phunk not actually for sale
        if (offer.onlySellTo != address(0x0) && offer.onlySellTo != msg.sender) revert();
        if (msg.value != offer.minValue) revert('not enough ether'); // Didn't send enough ETH
        address seller = offer.seller;
        if (seller == msg.sender) revert('seller == msg.sender');
        if (seller != metapunksContract.ownerOf(metapunkIndex)) revert('seller no longer owner of metapunk'); // Seller no longer owner of phunk


        metapunksOfferedForSale[metapunkIndex] = Offer(false, metapunkIndex, msg.sender, 0, address(0x0));
        metapunksContract.safeTransferFrom(seller, msg.sender, metapunkIndex);
        pendingWithdrawals[seller] += msg.value;
        emit MetaPunkBought(metapunkIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = metapunkBids[metapunkIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            metapunkBids[metapunkIndex] = Bid(false, metapunkIndex, address(0x0), 0);
        }
    }



    /* Allows users to retrieve ETH from sales */
    function withdraw() public nonReentrant() {
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /* Allows users to enter bids for any CryptoPhunk */
    function enterBidForMetaPunk(uint metapunkIndex) payable public whenNotPaused nonReentrant() {
        if (metapunkIndex >= 10000) revert('token index not valid');
        if (metapunksContract.ownerOf(metapunkIndex) == msg.sender) revert('you already own this metapunk');
        if (msg.value == 0) revert('cannot enter bid of zero');
        Bid memory existing = metapunkBids[metapunkIndex];
        if (msg.value <= existing.value) revert('your bid is too low');
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        metapunkBids[metapunkIndex] = Bid(true, metapunkIndex, msg.sender, msg.value);
        emit MetaPunkBidEntered(metapunkIndex, msg.value, msg.sender);
    }

    /* Allows CryptoPhunk owners to accept bids for their Phunks */
    function acceptBidForMetaPunk(uint metapunkIndex, uint minPrice) public whenNotPaused nonReentrant() {
        if (metapunkIndex >= 10000) revert('token index not valid');
        if (metapunksContract.ownerOf(metapunkIndex) != msg.sender) revert('you do not own this token');
        address seller = msg.sender;
        Bid memory bid = metapunkBids[metapunkIndex];
        if (bid.value == 0) revert('cannot enter bid of zero');
        if (bid.value < minPrice) revert('your bid is too low');

        address bidder = bid.bidder;
        if (seller == bidder) revert('you already own this token');
        metapunksOfferedForSale[metapunkIndex] = Offer(false, metapunkIndex, bidder, 0, address(0x0));
        uint amount = bid.value;
        metapunkBids[metapunkIndex] = Bid(false, metapunkIndex, address(0x0), 0);
        metapunksContract.safeTransferFrom(msg.sender, bidder, metapunkIndex);
        pendingWithdrawals[seller] += amount;
        emit MetaPunkBought(metapunkIndex, bid.value, seller, bidder);
    }

    /* Allows bidders to withdraw their bids */
    function withdrawBidForMetaPunk(uint metapunkIndex) public nonReentrant() {
        if (metapunkIndex >= 10000) revert('token index not valid');
        Bid memory bid = metapunkBids[metapunkIndex];
        if (bid.bidder != msg.sender) revert('the bidder is not message sender');
        emit MetaPunkBidWithdrawn(metapunkIndex, bid.value, msg.sender);
        uint amount = bid.value;
        metapunkBids[metapunkIndex] = Bid(false, metapunkIndex, address(0x0), 0);
        // Refund the bid money
        payable(msg.sender).transfer(amount);
    }

}