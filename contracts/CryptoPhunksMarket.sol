// SPDX-License-Identifier: MIT License
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";  //resolves issue #7
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



contract CryptoPhunksMarket is ReentrancyGuard, Pausable {

    IERC721 phunksContract;     // instance of the CryptoPhunks contract
    address contractOwner;      // owner can change phunksContract

    struct Offer {
        bool isForSale;
        uint phunkIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint phunkIndex;
        address bidder;
        uint value;
    }

    // A record of phunks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Offer) public phunksOfferedForSale;

    // A record of the highest phunk bid
    mapping (uint => Bid) public phunkBids;

    // A record of pending ETH withdrawls by address
    mapping (address => uint) public pendingWithdrawals;

    event PhunkOffered(uint indexed phunkIndex, uint minValue, address indexed toAddress);
    event PhunkBidEntered(uint indexed phunkIndex, uint value, address indexed fromAddress);
    event PhunkBidWithdrawn(uint indexed phunkIndex, uint value, address indexed fromAddress);
    event PhunkBought(uint indexed phunkIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event PhunkNoLongerForSale(uint indexed phunkIndex);

    /* Initializes contract with an instance of CryptoPhunks contract, and sets deployer as owner */
    constructor(address initialPhunksAddress) {
        //if (initialPhunksAddress == address(0x0)) revert();  //per audit Issue #1
        IERC721(initialPhunksAddress).balanceOf(address(this)); //per audit Issue #1
        phunksContract = IERC721(initialPhunksAddress);
        contractOwner = msg.sender;
    }

    /* Returns the CryptoPhunks contract address currently being used */
    function phunksAddress() public view returns (address) {
      return address(phunksContract);
    }

    /* Allows the owner of the contract to set a new CryptoPhunks contract address */
    function setPhunksContract(address newPhunksAddress) public {
      if (msg.sender != contractOwner) revert();
      phunksContract = IERC721(newPhunksAddress);
    }

    /* Allows the owner of a CryptoPhunks to stop offering it for sale */
    function phunkNoLongerForSale(uint phunkIndex) public nonReentrant() {
        if (phunkIndex >= 10000) revert();
        if (phunksContract.ownerOf(phunkIndex) != msg.sender) revert();
        phunksOfferedForSale[phunkIndex] = Offer(false, phunkIndex, msg.sender, 0, address(0x0));
        emit PhunkNoLongerForSale(phunkIndex);
    }

    /* Allows a CryptoPhunk owner to offer it for sale */
    function offerPhunkForSale(uint phunkIndex, uint minSalePriceInWei) public whenNotPaused nonReentrant()  {
        if (phunkIndex >= 10000) revert();
        if (phunksContract.ownerOf(phunkIndex) != msg.sender) revert();
        phunksOfferedForSale[phunkIndex] = Offer(true, phunkIndex, msg.sender, minSalePriceInWei, address(0x0));
        emit PhunkOffered(phunkIndex, minSalePriceInWei, address(0x0));
    }

    //to resolve Issue #5 this function was removed
    /* Allows a CryptoPhunk owner to offer it for sale to a specific address */
    /*
    function offerPhunkForSaleToAddress(uint phunkIndex, uint minSalePriceInWei, address toAddress) public whenNotPaused nonReentrant() {
        if (phunkIndex >= 10000) revert();
        if (phunksContract.ownerOf(phunkIndex) != msg.sender) revert();
        if (phunksContract.getApproved(phunkIndex) != address(this)) revert();
        phunksOfferedForSale[phunkIndex] = Offer(true, phunkIndex, msg.sender, minSalePriceInWei, toAddress);
        emit PhunkOffered(phunkIndex, minSalePriceInWei, toAddress);
    }
    */

    /* Allows users to buy a CryptoPhunk offered for sale */
    function buyPhunk(uint phunkIndex) payable public whenNotPaused nonReentrant() {
        if (seller != msg.sender) revert(); //added to address Issue #6
        if (phunkIndex >= 10000) revert();
        Offer memory offer = phunksOfferedForSale[phunkIndex];
        if (!offer.isForSale) revert();                // phunk not actually for sale
        if (offer.onlySellTo != address(0x0) && offer.onlySellTo != msg.sender) revert();  // phunk not supposed to be sold to this user
        if (msg.value != offer.minValue) revert();  //Issue #8    // Didn't send enough ETH
        address seller = offer.seller;
        if (seller != phunksContract.ownerOf(phunkIndex)) revert(); // Seller no longer owner of phunk

        //phunksContract.safeTransferFrom(seller, msg.sender, phunkIndex); //issue #12
        //phunkNoLongerForSale(phunkIndex);
        phunksOfferedForSale[phunkIndex] = Offer(false, phunkIndex, msg.sender, 0, address(0x0)); //issue #11
        phunksContract.safeTransferFrom(seller, msg.sender, phunkIndex); //issue #12
        pendingWithdrawals[seller] += msg.value;
        emit PhunkBought(phunkIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = phunkBids[phunkIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            phunkBids[phunkIndex] = Bid(false, phunkIndex, address(0x0), 0);
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
    function enterBidForPhunk(uint phunkIndex) payable public whenNotPaused nonReentrant() {
        if (phunkIndex >= 10000) revert();
        //if (phunksContract.ownerOf(phunkIndex) == address(0x0)) revert(); //Issue #9
        if (phunksContract.ownerOf(phunkIndex) == msg.sender) revert();
        if (msg.value == 0) revert();
        Bid memory existing = phunkBids[phunkIndex];
        if (msg.value <= existing.value) revert();
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        phunkBids[phunkIndex] = Bid(true, phunkIndex, msg.sender, msg.value);
        emit PhunkBidEntered(phunkIndex, msg.value, msg.sender);
    }

    /* Allows CryptoPhunk owners to accept bids for their Phunks */
    function acceptBidForPhunk(uint phunkIndex, uint minPrice) public whenNotPaused nonReentrant() {
        if (seller == bidder) revert(); //Issue #14
        if (phunkIndex >= 10000) revert();
        if (phunksContract.ownerOf(phunkIndex) != msg.sender) revert();
        address seller = msg.sender;
        Bid memory bid = phunkBids[phunkIndex];
        if (bid.value == 0) revert();
        if (bid.value < minPrice) revert();

        address bidder = bid.bidder;
        //phunksContract.safeTransferFrom(msg.sender, bidder, phunkIndex);
        //phunksOfferedForSale[phunkIndex] = Offer(false, phunkIndex, bidder, 0, address(0x0));
        //uint amount = bid.value;
        //phunkBids[phunkIndex] = Bid(false, phunkIndex, address(0x0), 0);
        phunksOfferedForSale[phunkIndex] = Offer(false, phunkIndex, bidder, 0, address(0x0)); //issue #13
        uint amount = bid.value;//issue #13
        phunkBids[phunkIndex] = Bid(false, phunkIndex, address(0x0), 0);//issue #13
        phunksContract.safeTransferFrom(msg.sender, bidder, phunkIndex);//issue #13
        pendingWithdrawals[seller] += amount;
        emit PhunkBought(phunkIndex, bid.value, seller, bidder);
    }

    /* Allows bidders to withdraw their bids */
    function withdrawBidForPhunk(uint phunkIndex) public nonReentrant() {
        if (phunkIndex >= 10000) revert();
        //if (phunksContract.ownerOf(phunkIndex) == address(0x0)) revert(); //Issue #9
        //if (phunksContract.ownerOf(phunkIndex) == msg.sender) revert(); per audit Issue#3
        Bid memory bid = phunkBids[phunkIndex];
        if (bid.bidder != msg.sender) revert();
        emit PhunkBidWithdrawn(phunkIndex, bid.value, msg.sender);
        uint amount = bid.value;
        phunkBids[phunkIndex] = Bid(false, phunkIndex, address(0x0), 0);
        // Refund the bid money
        payable(msg.sender).transfer(amount);
    }

}
