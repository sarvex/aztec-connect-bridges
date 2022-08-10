// SPDX-License-Identifier: GPL-2.0-only
pragma solidity >=0.8.4;

import "./ISetToken.sol";

interface IDebtIssuanceModule {
    /**
     * Deposits components to the SetToken, replicates any external module component positions and mints
     * the SetToken. If the token has a debt position all collateral will be transferred in first then debt
     * will be returned to the minting address. If specified, a fee will be charged on issuance.
     *
     * @param _setToken         Instance of the SetToken to issue
     * @param _quantity         Quantity of SetToken to issue
     * @param _to               Address to mint SetToken to
     */
    function issue(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    ) external;

    /**
     * Returns components from the SetToken, unwinds any external module component positions and burns
     * the SetToken. If the token has a debt position all debt will be paid down first then equity positions
     * will be returned to the minting address. If specified, a fee will be charged on redeem.
     *
     * @param _setToken         Instance of the SetToken to redeem
     * @param _quantity         Quantity of SetToken to redeem
     * @param _to               Address to send collateral to
     */
    function redeem(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    ) external;
}
