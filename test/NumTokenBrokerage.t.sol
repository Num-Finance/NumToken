// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/NumTokenBrokerage.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/pricing/interfaces/IPriceProvider.sol";

contract FakePriceProvider is IPriceProvider {
    uint256 response;

    constructor() {
        response = 0;
    }

    function getPrice() public view returns (uint256) {
        return response;
    }

    function setResponse(uint256 newResponse) public {
        response = newResponse;
    }
}

contract FakeOracle {
    bytes public s_lastResponse;

    constructor() {
        s_lastResponse = bytes(abi.encodePacked(uint256(0)));
    }

    function setResponse(uint256 response) public {
        s_lastResponse = bytes(abi.encodePacked(response));
    }
}

contract NumTokenBrokerageTest is Test {
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carl = address(0x3);

    NumTokenBrokerage public psm;
    NumToken counterpart;
    NumToken ntst;
    FakePriceProvider provider;

    /**
     * @dev the price is expressed as the amount of NumTokens needed to buy 1 counterpart token
     *      thus, the price has the same amount of decimals as the Num Token - in our case, 18. 
     */
    function setPrice(uint256 price) public {
        provider.setResponse(price);
    }

    function setUp() public {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(carl, "carl");

        ntst = new NumToken(address(0));
        vm.label(address(ntst), "nTST");

        counterpart = new NumToken(address(0));
        vm.label(address(counterpart), "counterpart");

        provider = new FakePriceProvider();
        vm.label(address(provider), "price provider");

        ntst.initialize("nTST", "Num Test");
        counterpart.initialize("USDC", "USD Coin");

        counterpart.grantRole(counterpart.MINTER_BURNER_ROLE(), address(this));
        counterpart.mint(address(this), 1_000_000 * 10 ** 18);

        psm = new NumTokenBrokerage(ntst, IERC20Metadata(address(counterpart)), provider);
        vm.label(address(psm), "num token brokerage");
        psm.grantRole(psm.DEFAULT_ADMIN_ROLE(), carl);
        psm.grantRole(psm.BROKERAGE_ADMIN_ROLE(), alice);
        ntst.grantRole(ntst.MINTER_BURNER_ROLE(), address(psm));
    }

    function test_setTin() public {
        vm.prank(alice);
            psm.file("tin", 0);
    }

    function testFail_setTin_notAuthorized() public {
        vm.prank(bob);
            psm.file("tin", 0);
    }

    function testFail_setTin_BadData() public {
        vm.prank(alice);
            psm.file("tin", type(uint256).max);
    }

    function test_setTout() public {
        vm.prank(alice);
            psm.file("tout", 0);
    }

    function testFail_setTout_notAuthorized() public {
        vm.prank(bob);
            psm.file("tout", 0);
    }

    function testFail_setTout_BadData() public {
        vm.prank(alice);
            psm.file("tout", type(uint256).max);
    }

    function test_setLine() public {
        vm.prank(alice);
            psm.file("line", 0);
    }

    function testFail_setLine_notAuthorized() public {
        vm.prank(bob);
            psm.file("line", 0);
    }

    function test_setStop() public {
        vm.prank(alice);
            psm.file("stop", 1);
    }

    function testFail_setStop_notAuthorized() public {
        vm.prank(bob);
            psm.file("stop", 1);
    }

    function testFail_setInvalidFile() public {
        vm.prank(alice);
            psm.file("invalid_key", 1 ether);
    }

    function test_previewSellGem() public {
        setPrice(1 ether);
        assertEq(
            // NOTE: we sell 10 ether worth of gems here since
            //       the counterpart token has 18 decimals
            psm.previewSellGem(10 ether),
            10 ether
        );
    }

    function test_previewSellGem_asymmetric() public {
        // NOTE: if the price is 0.2, selling 1 USD stable nets 5 Num Stable
        setPrice(0.2 ether);
        assertEq(
            psm.previewSellGem(1 ether),
            5 ether
        );
    }

    function test_previewBuyGem_asymmetric() public {
        // NOTE: if the price is 0.2, selling 5 Num Stables nets 1 USD stable
        setPrice(0.2 ether);
        assertEq(
            psm.previewBuyGem(5 ether),
            1 ether
        );
    }

    function test_sellGem_asymmetric() public {
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);

        uint256 balanceBefore = ntst.balanceOf(address(this));

        // NOTE: price = 0.2 buy with 10, get 50 (1/0.2 = 5)
        counterpart.approve(address(psm), 10 ether);
        psm.sellGem(address(this), 10 ether);

        uint256 balanceAfter = ntst.balanceOf(address(this));

        assertEq(
            balanceAfter - balanceBefore,
            50 ether
        );
    }

    function test_buyGem_asymmetric() public {
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);

        // NOTE: fund the contract
        counterpart.approve(address(psm), 100 ether);
        psm.sellGem(address(this), 100 ether);

        // NOTE: test case starts here
        uint256 balanceBefore = counterpart.balanceOf(address(this));

        // NOTE price = 0.2, sell 10 get 2
        ntst.approve(address(psm), 10 ether);
        psm.buyGem(address(this), 10 ether);

        uint256 balanceAfter = counterpart.balanceOf(address(this));

        assertEq(
            balanceAfter - balanceBefore,
            2 ether
        );
    }

    function testBuyGem_asymmetric_tout() public {
        //revert("todo!");
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);
        // NOTE: 1% tout
        psm.file("tout", 0.01 ether);

        // NOTE: fund the contract
        counterpart.approve(address(psm), 100 ether);
        psm.sellGem(address(this), 100 ether);
        
        uint256 balanceBefore = counterpart.balanceOf(address(this));
        
        // NOTE price = 0.2, sell 10 get 2
        ntst.approve(address(psm), 10 ether);
        psm.buyGem(address(this), 10 ether);

        uint256 balanceAfter = counterpart.balanceOf(address(this));

        assertEq(
            balanceAfter - balanceBefore,
            1.98 ether
        );
    }

    function testSellGem_asymmetric_tin() public {
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);
        psm.file("tin", 0.01 ether);

        uint256 balanceBefore = ntst.balanceOf(address(this));

        // NOTE: price = 0.2 buy with 10, get 50 (1/0.2 = 5)
        counterpart.approve(address(psm), 10 ether);
        psm.sellGem(address(this), 10 ether);

        uint256 balanceAfter = ntst.balanceOf(address(this));

        assertEq(
            balanceAfter - balanceBefore,
            49.5 ether
        );
    }

    function skip_testPreviewBuyGem_smallAmount(uint256 amount) public {
        vm.assume(amount > 0.0001 ether);
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);

        uint256 previewZeroTin = psm.previewBuyGem(amount);

        psm.file("tin", 0.01 ether);
        skip(1);

        uint256 previewNonZeroTin = psm.previewBuyGem(amount);

        assertGt(
            previewZeroTin,
            previewNonZeroTin
        );
    }

    function skip_testPreviewSellGem_smallAmount(uint256 amount) public {
        vm.assume(amount > 0.0001 ether);
        setPrice(0.2 ether);
        psm.file("line", type(uint256).max);

        uint256 previewZeroTout = psm.previewSellGem(amount);

        psm.file("tout", 0.01 ether);
        skip(1);

        uint256 previewNonZeroTout = psm.previewSellGem(amount);

        assertGt(
            previewZeroTout,
            previewNonZeroTout
        );
    }

    function test_timelock_lock() public {
        // NOTE: Wed Aug 21 18:46:35 -03 2024
        vm.warp(1724276786);

        // NOTE: set timelock to test whether the timelock applies to the timelock itself
        psm.file("lock", 5 minutes);
        uint256 lockBefore = psm.timelock();
        assertEq(lockBefore, 5 minutes);
        skip(5 minutes);

        // NOTE: after setting the timelock here, we have to wait for the older timelock to apply
        psm.file("lock", 10 minutes);
        assertEq(psm.timelock(), lockBefore);
        skip(2 minutes);
        assertEq(psm.timelock(), lockBefore);
        skip(3 minutes);
        assertEq(psm.timelock(), 10 minutes);
    }

    function test_timelock_tin_tout() public {
        psm.file("lock", 5 minutes);
        // NOTE: wait for lock to apply
        skip(5 minutes);

        uint256 tin = psm.tin();
        uint256 tout = psm.tout();

        psm.file("tin", 0.1 ether);
        psm.file("tout", 0.1 ether);

        assertEq(psm.tin(), tin);
        assertEq(psm.tout(), tout);

        skip(5 minutes);

        assertEq(psm.tin(), 0.1 ether);
        assertEq(psm.tout(), 0.1 ether);
    }

    event FileChangeStaged(bytes32 indexed what, uint256 value);
    event FileChanged(bytes32 indexed what, uint256 value);

    function test_file_timelock_emitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit FileChangeStaged("tin", 0.1 ether);
        psm.file("tin", 0.1 ether);

        vm.expectEmit(true, true, false, false);
        emit FileChangeStaged("tout", 0.1 ether);
        psm.file("tout", 0.1 ether);

        vm.expectEmit(true, true, false, false);
        emit FileChangeStaged("lock", 5 minutes);
        psm.file("lock", 5 minutes);
    }

    function test_file_timelock_update_emitsEvent() public {
        psm.file("lock", 5 minutes);
        skip(5 minutes);

        vm.expectEmit(true, true, false, false);
        emit FileChanged("lock", 5 minutes);
        psm.file("tin", 0.1 ether);

        skip(5 minutes);

        vm.expectEmit(true, true, false, false);
        emit FileChanged("tin", 0.1 ether);
        psm.file("tout", 0.1 ether);

        skip(5 minutes);

        vm.expectEmit(true, true, false, false);
        emit FileChanged("tout", 0.1 ether);
        psm.file("tout", 0.1 ether);
    }

    function test_take() public {
        psm.take(address(this), 0);
    }

    function testFail_take_unauthorized() public {
        vm.prank(bob);
        psm.take(address(this), 0);
    }

    function test_give() public {
        counterpart.mint(bob, 1 ether);

        vm.startPrank(bob);
            counterpart.approve(address(psm), 1 ether);
            psm.give(1 ether);
        vm.stopPrank();
    }

    function testFail_give_noBalance() public {
        vm.startPrank(bob);
            counterpart.approve(address(psm), 1 ether);
            psm.give(1 ether);
        vm.stopPrank();
    }

    function test_rely() public {
        vm.prank(carl);
            psm.rely(bob);
    }

    function testFail_rely_unauthorized() public {
        vm.prank(alice);
            psm.rely(bob);
    }

    function test_deny() public {
        vm.prank(carl);
            psm.deny(bob);
    }

    function testFail_deny_unauthorized() public {
        vm.prank(alice);
            psm.deny(bob);
    }
}
