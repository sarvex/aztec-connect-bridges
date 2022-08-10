// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "../../../aztec/libraries/AztecTypes.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IndexLeverageBridge} from "../../../bridges/indexcoop/IndexLeverageBridge.sol";
import {ErrorLib} from "../../../bridges/base/ErrorLib.sol";

import {IAaveLeverageModule} from "../../../interfaces/set/IAaveLeverageModule.sol";
import {IWETH} from "../../../interfaces/IWETH.sol";
import {IExchangeIssuanceLeveraged} from "../../../interfaces/set/IExchangeIssuanceLeveraged.sol";
import {ISetToken} from "../../../interfaces/set/ISetToken.sol";
import {AggregatorV3Interface} from "../../../interfaces/chainlink/AggregatorV3Interface.sol";
import {IQuoter} from "../../../interfaces/uniswapv3/IQuoter.sol";
import {TickMath} from "../../../libraries/uniswapv3/TickMath.sol";
import {FullMath} from "../../../libraries/uniswapv3/FullMath.sol";
import {IUniswapV3Factory} from "../../../interfaces/uniswapv3/IUniswapV3Factory.sol";
import {IUniswapV3PoolDerivedState} from "../../../interfaces/uniswapv3/pool/IUniswapV3PoolDerivedState.sol";
import {ICurvePool} from "../../../interfaces/curve/ICurvePool.sol";

contract IndexLeverageTest is BridgeTestBase {
    address public constant ETH2X = 0xAa6E8127831c9DE45ae56bB1b0d4D4Da6e5665BD;

    // The reference to the bridge
    IndexLeverageBridge internal bridge;

    // To store the id of the bridge after being added
    uint256 private id;

    AztecTypes.AztecAsset public eth2xAsset;
    AztecTypes.AztecAsset public ethAsset;
    AztecTypes.AztecAsset public empty;

    function setUp() public {
        bridge = new IndexLeverageBridge(address(ROLLUP_PROCESSOR));
        vm.deal(address(bridge), 0);

        vm.label(address(bridge), "IndexLeverageBridge");
        vm.label(ETH2X, "ETH2X");
        vm.label(address(bridge.cETH()), "cETH");
        vm.label(address(bridge.DEBT_ISSUANCE()), "DEBT_ISSUANCE");

        vm.startPrank(MULTI_SIG);

        ROLLUP_PROCESSOR.setSupportedBridge(address(bridge), 2000000);
        ROLLUP_PROCESSOR.setSupportedAsset(ETH2X, 100000);

        vm.stopPrank();

        id = ROLLUP_PROCESSOR.getSupportedBridgesLength();

        eth2xAsset = getRealAztecAsset(ETH2X);
        ethAsset = getRealAztecAsset(address(0));
    }

    // ===== Testing that buying/issuing and redeeming/selling returns the expected amount ======
    //    function testIssueSet(uint256 _depositAmount) public {
    function testIssueSetQ() public {
        //        uint256 depositAmount = bound(_depositAmount, 1e18, 500 ether);
        uint256 depositAmount = 1 ether;
        uint64 amountOutPrice = 61e8; // 100 ETH2x

        vm.deal(address(ROLLUP_PROCESSOR), depositAmount);

        vm.prank(address(ROLLUP_PROCESSOR));
        (uint256 outputValueA, uint256 outputValueB, ) = bridge.convert{value: depositAmount}(
            ethAsset,
            emptyAsset,
            eth2xAsset,
            ethAsset,
            depositAmount,
            0,
            amountOutPrice,
            address(0)
        );
    }
}
