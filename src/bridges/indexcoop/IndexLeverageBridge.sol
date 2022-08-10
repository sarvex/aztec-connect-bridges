// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeBase} from "../base/BridgeBase.sol";
import {ErrorLib} from "../base/ErrorLib.sol";
import {AztecTypes} from "../../aztec/libraries/AztecTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRollupProcessor} from "../../aztec/interfaces/IRollupProcessor.sol";
import {ISetToken} from "../../interfaces/set/ISetToken.sol";
import {ICETH} from "../../interfaces/compound/ICETH.sol";
import {IExchangeIssuanceLeveraged} from "../../interfaces/set/IExchangeIssuanceLeveraged.sol";
import {IDebtIssuanceModule} from "../../interfaces/set/IDebtIssuanceModule.sol";

/**
 * @title IndexCoop Leveraged Tokens Bridge
 * @notice A smart contract responsible for buying and selling icETH with ETH either through selling/buying from
 * a DEX or by issuing/redeeming icEth set tokens.
 */
contract IndexLeverageBridge is BridgeBase {
    IDebtIssuanceModule public constant DEBT_ISSUANCE = IDebtIssuanceModule(0x39F024d621367C044BacE2bf0Fb15Fb3612eCB92);
    // solhint-disable-next-line
    ICETH public constant cETH = ICETH(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    ISetToken public constant ETH2X = ISetToken(0xAa6E8127831c9DE45ae56bB1b0d4D4Da6e5665BD);

    uint256 public constant PRECISION = 1e8;
    uint256 public constant DUST = 1;

    constructor(address _rollupProcessor) BridgeBase(_rollupProcessor) {
        // Tokens can be pre approved since the bridge is stateless
        cETH.approve(address(DEBT_ISSUANCE), type(uint256).max);
        ETH2X.approve(address(ROLLUP_PROCESSOR), type(uint256).max);
    }

    receive() external payable {}

    /**
     * @notice Function that swaps between icETH and ETH.
     * @dev The flow of this functions is based on the type of input and output assets.
     *
     * @param _inputAssetA - ETH to buy/issue icETH, icETH to sell/redeem icETH.
     * @param _outputAssetA - icETH to buy/issue icETH, ETH to sell/redeem icETH.
     * @param _outputAssetB - ETH to buy/issue icETH, empty to sell/redeem icETH.
     * @param _totalInputValue - Total amount of ETH/icETH to be swapped for icETH/ETH
     * @param _interactionNonce - Globally unique identifier for this bridge call
     * @param _auxData - Encodes flowSelector and maxSlip. See notes on the decodeAuxData
     * function for encoding details.
     * @return outputValueA - Amount of icETH received when buying/issuing, Amount of ETH
     * received when selling/redeeming.
     * @return outputValueB - Amount of ETH returned when issuing icETH. A portion of ETH
     * is always returned when issuing icETH since the issuing function in ExchangeIssuance
     * requires an exact output amount rather than input.
     */
    function convert(
        AztecTypes.AztecAsset calldata _inputAssetA,
        AztecTypes.AztecAsset calldata,
        AztecTypes.AztecAsset calldata _outputAssetA,
        AztecTypes.AztecAsset calldata _outputAssetB,
        uint256 _totalInputValue,
        uint256 _interactionNonce,
        uint64 _auxData,
        address
    )
        external
        payable
        override(BridgeBase)
        onlyRollup
        returns (
            uint256 outputValueA,
            uint256 outputValueB,
            bool
        )
    {
        uint256 amountOut = (_totalInputValue * _auxData) / PRECISION;

        if (
            _inputAssetA.assetType == AztecTypes.AztecAssetType.ETH &&
            _outputAssetA.erc20Address == address(ETH2X) &&
            _outputAssetB.assetType == AztecTypes.AztecAssetType.ETH
        ) {
            cETH.mint{value: _totalInputValue}();
            DEBT_ISSUANCE.issue(ETH2X, amountOut, address(this));

            // Unwrap the remaining cETH in order to return ETH
            cETH.redeem(cETH.balanceOf(address(this)) - DUST);

            outputValueA = ISetToken(ETH2X).balanceOf(address(this)) - DUST;
            outputValueB = address(this).balance;

            if (outputValueB > 0) {
                IRollupProcessor(ROLLUP_PROCESSOR).receiveEthFromBridge{value: outputValueB}(_interactionNonce);
            }
        } else if (
            _inputAssetA.erc20Address == address(ETH2X) &&
            _outputAssetA.assetType == AztecTypes.AztecAssetType.ETH &&
            _outputAssetB.assetType == AztecTypes.AztecAssetType.NOT_USED
        ) {
            // Redeem ETH2X for cETH
            DEBT_ISSUANCE.redeem(ETH2X, _totalInputValue, address(this));

            // Unwrap cETH balance in order to return ETH
            cETH.redeem(cETH.balanceOf(address(this)) - DUST);

            outputValueA = address(this).balance;
            IRollupProcessor(ROLLUP_PROCESSOR).receiveEthFromBridge{value: outputValueA}(_interactionNonce);
        } else {
            revert ErrorLib.InvalidInput();
        }
    }
}
