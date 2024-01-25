pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "src/NumToken.sol";
import "src/VendingMachine.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract VendingMachineTest is Test {
    MinimalForwarder forwarder;
    VendingMachine vendingMachine;

    ERC20 stableToken;
    NumToken etfToken;

    bytes32 alice_pk = keccak256("ALICE'S PRIVATE KEY");
    bytes32 bob_pk   = keccak256("BOB'S PRIVATE KEY");
    bytes32 carl_pk   = keccak256("CARL'S PRIVATE KEY");
    bytes32 dani_pk   = keccak256("DANI'S PRIVATE KEY");
    address alice    = vm.addr(uint256(alice_pk));
    address bob      = vm.addr(uint256(bob_pk));
    address carl     = vm.addr(uint256(carl_pk));
    address dani     = vm.addr(uint256(dani_pk));


    function setUp() public {

        forwarder = new MinimalForwarder();
        etfToken = new NumToken(address(forwarder));

        etfToken.initialize("nETF", "Num ETF Test");
        etfToken.grantRole(etfToken.MINTER_BURNER_ROLE(), alice);

        vm.prank(alice);
        etfToken.mint(alice, 1_000_000e18);

        stableToken = new ERC20PresetFixedSupply("USDC", "USD Coin", 1_000_000e18, alice);
        vendingMachine = new VendingMachine(address(forwarder));

        etfToken.grantRole(etfToken.MINTER_BURNER_ROLE(), address(vendingMachine));

        vendingMachine.initialize(
            IERC20Upgradeable(address(stableToken)),
            etfToken,
            payable(alice),
            payable(alice)
        );

        beforeEach();
    }

    function beforeEach() public {
        vendingMachine = new VendingMachine(address(forwarder));
        etfToken.grantRole(etfToken.MINTER_BURNER_ROLE(), address(vendingMachine));

        vendingMachine.initialize(
            IERC20Upgradeable(address(stableToken)),
            etfToken,
            payable(alice),
            payable(alice)
        );

        vm.prank(alice);
        vendingMachine.setMintingFee(0);
    }

    function test_requestMint_OK() public {
        vm.prank(alice);
        stableToken.transfer(bob, 1e18);

        vm.startPrank(bob);

        stableToken.approve(address(vendingMachine), 1e18);
        vendingMachine.requestMint(1e18);

        vm.stopPrank();
    }

    function test_requestMint_NoBalance() public {
        vm.startPrank(bob);

        stableToken.approve(address(vendingMachine), 1e18);
        vm.expectRevert();
        vendingMachine.requestMint(1e18);

        vm.stopPrank();
    }

    function test_requestRedeem_OK() public {
        vm.prank(alice);
        etfToken.transfer(carl, 3e18);

        vm.startPrank(carl);
        etfToken.approve(address(vendingMachine), 3e18);
        vendingMachine.requestRedeem(3e18);
        vm.stopPrank();
    }

    function test_requestRedeem_NoBalance() public {
        vm.startPrank(carl);
        etfToken.approve(address(vendingMachine), 3e18);
        vm.expectRevert();
        vendingMachine.requestRedeem(3e18);
        vm.stopPrank();
    }

    function test_FillBulkOrder(uint8 orderAmount) public {
        // NOTE: Request amount is bounded to ensure tests run fast.
        //       The contract actually has no logical limit on requests within bulk orders.
        vm.assume(orderAmount < 100);

        vm.startPrank(bob);
        etfToken.approve(address(vendingMachine), 1e18);
        stableToken.approve(address(vendingMachine), 1e18);
        vm.stopPrank();

        for (uint8 i = 0; i < orderAmount; i++) {
            vm.prank(alice);
            // randomly fill with buy/sell orders
            if (
                uint8(uint256(
                    keccak256(
                        abi.encodePacked(
                            i,
                            block.prevrandao
                        )
                    )
                )) & 0x1 > 0
            ) {
                stableToken.transfer(bob, 1);
                vm.prank(bob);
                vendingMachine.requestMint(1);
            } else {
                etfToken.transfer(bob, 1);
                vm.prank(bob);
                vendingMachine.requestRedeem(1);
            }
        }

        ( , , ,uint count, ,) = vendingMachine.bulkOrders(0);

        assertEq(count, orderAmount);
    }

    function test_closeBulkOrder_tooYoung() public {
        vm.prank(alice);
        vm.expectRevert();
        vendingMachine.closeBulkOrder(0);
    }

    function test_closeBulkOrder_mature() public {
        skip(1 days + 2 hours);

        vm.prank(alice);
        vendingMachine.closeBulkOrder(0);

        assertEq(vendingMachine.activeBulkOrder(), 1);
    }

    function test_closeBulkOrder_aliceReceivesTokens(uint256 tokenAmount, uint8 orderAmount) public {
        vm.assume(tokenAmount > orderAmount);
        vm.assume(tokenAmount < 100e18);
        vm.assume(orderAmount > 0);
        vm.assume(orderAmount < 100);

        uint256 requestAmount = tokenAmount / orderAmount;

        vm.prank(alice);
        stableToken.transfer(bob, tokenAmount);

        vm.startPrank(bob);
        stableToken.approve(address(vendingMachine), tokenAmount);
        for (uint i = 0; i < orderAmount; i++) {
            vendingMachine.requestMint(requestAmount);
        }
        vm.stopPrank();

        (uint256 stableTokenAmountCollected, , , , , ) = vendingMachine.bulkOrders(0);

        assertEq(stableToken.balanceOf(address(vendingMachine)), stableTokenAmountCollected);
        assertEq(stableToken.balanceOf(address(vendingMachine)), stableTokenAmountCollected);

        skip(1 days);
        uint256 aliceBalanceBefore = stableToken.balanceOf(alice);

        vm.prank(alice);
        vendingMachine.closeBulkOrder(0);

        uint256 aliceBalanceAfter = stableToken.balanceOf(alice);

        uint256 bobDust = stableToken.balanceOf(bob);

        assertEq(stableToken.balanceOf(address(vendingMachine)), 0);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, tokenAmount - bobDust);
    }

    function test_bulkOrder_happyPath(uint256 tokenAmount, uint8 orderAmount) public {
        vm.assume(tokenAmount > orderAmount);
        vm.assume(tokenAmount < 100e18);
        vm.assume(orderAmount > 0);
        vm.assume(orderAmount < 100);

        uint256 requestAmount = tokenAmount / orderAmount;

        vm.prank(alice);
        stableToken.transfer(bob, tokenAmount);

        vm.startPrank(bob);
        stableToken.approve(address(vendingMachine), tokenAmount);
        for (uint i = 0; i < orderAmount; i++) {
            vendingMachine.requestMint(requestAmount);
        }
        vm.stopPrank();

        (uint256 stableTokenAmountCollected, , , , VendingMachine.BulkOrderState stateBefore, ) = vendingMachine.bulkOrders(0);

        skip(1 days);

        // NOTE: Check bob can't close the bulk order himself.
        vm.expectRevert();
        vm.prank(bob);
        vendingMachine.closeBulkOrder(0);

        vm.startPrank(alice);
        vendingMachine.closeBulkOrder(0);
        // NOTE: This function call triggers offchain processes that actually acquire
        //       the underlying assets. The contract has no way of knowing this has effectively happened.
        //       Please refer to our internal operations manual.

        uint etfTokenBalanceBefore = etfToken.balanceOf(alice);


        vendingMachine.mintForBulkOrder(0, 1e18);

        uint etfTokenBalanceAfter = etfToken.balanceOf(alice);


        (, , , , VendingMachine.BulkOrderState stateAfter, ) = vendingMachine.bulkOrders(0);

        assertEq(uint8(stateAfter), uint8(VendingMachine.BulkOrderState.MINTED));

        assertEq(etfTokenBalanceAfter - etfTokenBalanceBefore, 1e18);

        // NOTE: Distribution is calculated offchain.
        //       This contract only helps in the collection of orders
        //       to buy/sell the underlying asset.

        // XXX: do some offchain magic here and decide on distribution

        // NOTE: The actual `etfToken` distribution is to be done via a Multicall
        //       or any similar token distribution method such as Disperse.app
        //       Distribution via this smart contract has been left out of scope.
        //       (mori, 2024-01-25)

        // XXX: actually distribute the tokens

        vendingMachine.markBulkOrderFulfilled(0);
        (, , , , VendingMachine.BulkOrderState stateFinal, ) = vendingMachine.bulkOrders(0);
        assertEq(uint8(stateFinal), uint8(VendingMachine.BulkOrderState.FULFILLED));

        assertEq(stableToken.balanceOf(address(vendingMachine)), 0);
        assertEq(etfToken.balanceOf(address(vendingMachine)), 0);

        // END OF USECASE
    }

    function test_bulkOrderInnerOrder() public {
        vm.prank(alice);
        stableToken.transfer(bob, 1e18);

        vm.startPrank(bob);
        stableToken.approve(address(vendingMachine), 1e18);
        vendingMachine.requestMint(1e18);
        vm.stopPrank();

        VendingMachine.Request memory order = vendingMachine.bulkOrderInnerOrder(0, 0);
        assertEq(order.stableTokenAmount, 1e18);
    }
}