// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/NumTokenBrokerage.sol";

contract FakeOracle is IFunctionsConsumer {
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
    NumTokenBrokerage public psm;
    FakeOracle public oracle;
    NumToken counterpart;
    NumToken ntst;

    /**
     * @dev the price is expressed as the amount of NumTokens needed to buy 1 counterpart token
     *      thus, the price has the same amount of decimals as the Num Token - in our case, 18. 
     */
    function setPrice(uint256 price) public {
        oracle.setResponse(price);
    }

    function setUp() public {
        ntst = new NumToken(address(0));
        counterpart = new NumToken(address(0));
        oracle = new FakeOracle();

        ntst.initialize("nTST", "Num Test");
        counterpart.initialize("USDC", "USD Coin");

        counterpart.grantRole(counterpart.MINTER_BURNER_ROLE(), address(this));
        counterpart.mint(address(this), 1_000_000 * 10 ** 18);

        psm = new NumTokenBrokerage(ntst, IERC20(address(counterpart)), IFunctionsConsumer(oracle));
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

    function test_previewSellGem() public {
        oracle.setResponse(1 ether);
        assertEq(
            // NOTE: we sell 10 ether worth of gems here since
            //       the counterpart token has 18 decimals
            psm.previewSellGem(10 ether),
            10 ether
        );
    }

    function test_previewSellGem_asymmetric() public {
        // NOTE: if the price is 0.2, selling 1 USD stable nets 5 Num Stable
        oracle.setResponse(0.2 ether);
        assertEq(
            psm.previewSellGem(1 ether),
            5 ether
        );
    }

    function test_previewBuyGem_asymmetric() public {
        // NOTE: if the price is 0.2, selling 5 Num Stables nets 1 USD stable
        oracle.setResponse(0.2 ether);
        assertEq(
            psm.previewBuyGem(5 ether),
            1 ether
        );
    }

    function test_sellGem_asymmetric() public {
        oracle.setResponse(0.2 ether);
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
        oracle.setResponse(0.2 ether);
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
}
