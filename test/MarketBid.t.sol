pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "src/ERC20Token.sol";
import 'src/NFT2.sol';
import 'src/Market.sol';
import 'src/MarketFactory.sol';

contract MarketAskTest is Test {
    NFT2 nft;
    Market market;
    MarketFactory factory;
    ERC20Token erc20;

    uint256 tokenId = 1;

    address internal alice;
    address internal bob;
    address internal charlie;

    function setUp() public {
        nft = new NFT2("a", "b");
        factory = new MarketFactory();
        market = Market(factory.createMarket(address(nft)));
        erc20 = new ERC20Token("a", "b");

        alice = address(1); //always the owner
        bob = address(2); //
        charlie = address(3);

        vm.prank(alice);
        nft.mintTo(alice);
    }
    // alice is owner/seller/acceptor, bob is buyer/bidder

    /** 
     * ------------- TEST BUYER BID -------------
    */
    function testBobBidSuccess() public {
        uint64 bidPrice = 1000;
        buyerApproveERC20(bob, address(market), bidPrice);
        buyerBid(bob, bidPrice);
        (, ,uint64 price , , , ) = market.bidList(tokenId, bob); 
        assertEq(price, bidPrice);
    }

    function testBobBidTwice() public {
        address[] memory bidders = market.getBidders(tokenId);
        assertEq(getBidderFromArray(bob, bidders), false);
        // bid first time 
        uint64 bidPrice = 1000;
        buyerApproveERC20(bob, address(market), bidPrice);
        buyerBid(bob, bidPrice);
        (, ,uint64 price , , , ) = market.bidList(tokenId, bob); 
        assertEq(price, bidPrice);
        bidders = market.getBidders(tokenId);
        assertEq(getBidderFromArray(bob, bidders), true);
        // bid second time
        bidPrice = 10000;
        buyerApproveERC20(bob, address(market), bidPrice);
        buyerBid(bob, bidPrice);
        (, , price , , , ) = market.bidList(tokenId, bob); 
        assertEq(price, bidPrice);
        bidders = market.getBidders(tokenId);
        assertEq(bidders.length, 1);
        assertEq(getBidderFromArray(bob, bidders), true);
    }

    function testBidderRescindBid() public { // bidder can Rescind bid
        testBobBidSuccess();
        vm.startPrank(bob);
        (,address buyer , , , , ) = market.bidList(tokenId, bob); 
        assertEq(buyer, bob);
        address[] memory bidders = market.getBidders(tokenId);
        assertEq(getBidderFromArray(bob, bidders), true);
        // Rescind bid
        market.buyerRescindBid(tokenId);
        (, buyer , , , , ) = market.bidList(tokenId, bob); 
        assertEq(buyer, address(0));
        bidders = market.getBidders(tokenId);
        assertEq(bidders.length, 0);
        assertEq(getBidderFromArray(bob, bidders), false);
        vm.stopPrank();
    }

    function testNotBidderRescindBid() public { // not bidder cannot Rescind bid
        testBobBidSuccess();
        (,address buyer , , , , ) = market.bidList(tokenId, bob); 
        assertEq(buyer, bob);
        address[] memory bidders = market.getBidders(tokenId);
        assertEq(getBidderFromArray(bob, bidders), true);
        // charlie tries to Rescind bid
        vm.prank(charlie);
        vm.expectRevert(bytes("no bid"));
        market.buyerRescindBid(tokenId);
    } 

    function getBidderFromArray(address bidder, address[] memory bidders) private pure returns (bool) {
        for (uint i = 0; i < bidders.length; i++) {
            if (bidders[i] == bidder) {
                return true;
            }
        }
        return false;
    }

    function buyerApproveERC20(address owner, address spender, uint256 amount) public {
        vm.prank(owner);
        require(erc20.approve(spender, amount));
    }

    function buyerBid(address buyer, uint64 price) public {
        vm.prank(buyer);
        market.buyerBid(tokenId, price, address(erc20), uint32(1000));
    }

    /** 
     * ------------- TEST SELEER ACCEPT -------------
    */
    function testAliceAcceptBidSuccess() public {
        testBobBidSuccess();
        // alice needs to first setApproval for its nft
        vm.startPrank(alice);
        nft.setApprovalForAll(address(market), true);
        erc20.mint(bob, uint256(1000));
        market.sellerAcceptBid(tokenId, bob);
    }

    // function 

}