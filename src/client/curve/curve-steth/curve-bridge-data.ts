import {
  UnderlyingAsset,
  AuxDataConfig,
  AztecAsset,
  SolidityType,
  AztecAssetType,
  BridgeDataFieldGetters,
} from "../../bridge-data.js";

import {
  IWstETH,
  ILidoOracle,
  ICurvePool,
  IWstETH__factory,
  ILidoOracle__factory,
  ICurvePool__factory,
  IChainlinkOracle__factory,
  IChainlinkOracle,
} from "../../../../typechain-types/index.js";
import { EthereumProvider } from "@aztec/barretenberg/blockchain";
import { createWeb3Provider } from "../../aztec/provider/web3_provider.js";
import { EthAddress } from "@aztec/barretenberg/address";
import { AssetValue } from "@aztec/barretenberg/asset";

export class CurveStethBridgeData implements BridgeDataFieldGetters {
  public readonly scalingFactor: bigint = 1n * 10n ** 18n;
  public readonly wstEthAddress: EthAddress = EthAddress.fromString("0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0");

  private constructor(
    private bridgeAddressId: number,
    private wstETHContract: IWstETH,
    private lidoOracleContract: ILidoOracle,
    private curvePoolContract: ICurvePool,
    private chainlinkOracleContract: IChainlinkOracle,
  ) {}

  static create(
    bridgeAddressId: number,
    provider: EthereumProvider,
    wstEthAddress: EthAddress,
    lidoOracleAddress: EthAddress,
    curvePoolAddress: EthAddress,
    chainlinkOracleAddress: EthAddress,
  ) {
    const ethersProvider = createWeb3Provider(provider);
    const wstEthContract = IWstETH__factory.connect(wstEthAddress.toString(), ethersProvider);
    const lidoContract = ILidoOracle__factory.connect(lidoOracleAddress.toString(), ethersProvider);
    const curvePoolContract = ICurvePool__factory.connect(curvePoolAddress.toString(), ethersProvider);
    const chainlinkOracleContract = IChainlinkOracle__factory.connect(chainlinkOracleAddress.toString(), ethersProvider);
    return new CurveStethBridgeData(bridgeAddressId, wstEthContract, lidoContract, curvePoolContract, chainlinkOracleContract);
  }

  // Unused
  public auxDataConfig: AuxDataConfig[] = [
    {
      start: 0,
      length: 64,
      solidityType: SolidityType.uint64,
      description: "Not Used",
    },
  ];

  // Lido bridge contract is stateless
  async getInteractionPresentValue(interactionNonce: number): Promise<AssetValue[]> {
    return [];
  }

  async getAuxData(
    inputAssetA: AztecAsset,
    inputAssetB: AztecAsset,
    outputAssetA: AztecAsset,
    outputAssetB: AztecAsset,
  ): Promise<bigint[]> {
    if (inputAssetA.assetType === AztecAssetType.ETH && inputAssetB.assetType === AztecAssetType.NOT_USED && outputAssetA.erc20Address.equals(this.wstEthAddress) && outputAssetB.assetType === AztecAssetType.NOT_USED) {
      // Buying wstETH
      return [0n];
    } if (inputAssetA.erc20Address.equals(this.wstEthAddress) && inputAssetB.assetType === AztecAssetType.NOT_USED && outputAssetA.assetType === AztecAssetType.ETH && outputAssetB.assetType === AztecAssetType.NOT_USED) {
     // Selling wstETH
     return [0n]
    } else {
      throw "Incorrect combination of input/output assets.";
    }
  }

  async getExpectedOutput(
    inputAssetA: AztecAsset,
    inputAssetB: AztecAsset,
    outputAssetA: AztecAsset,
    outputAssetB: AztecAsset,
    auxData: bigint,
    inputValue: bigint,
  ): Promise<bigint[]> {
    // ETH -> wstETH
    if (inputAssetA.assetType == AztecAssetType.ETH) {
      const stEthBalance = await this.curvePoolContract.get_dy(0, 1, inputValue);
      const wstETHBalance = await this.wstETHContract.getWstETHByStETH(stEthBalance);
      return [wstETHBalance.toBigInt()];
    }

    // wstETH -> ETH
    if (inputAssetA.assetType == AztecAssetType.ERC20) {
      const stETHBalance = await this.wstETHContract.getStETHByWstETH(inputValue);
      const ETHBalance = await this.curvePoolContract.get_dy(1, 0, stETHBalance);
      return [ETHBalance.toBigInt()];
    }
    return [0n];
  }
  async getAPR(yieldAsset: AztecAsset): Promise<number> {
    const YEAR = 60n * 60n * 24n * 365n;
    const { postTotalPooledEther, preTotalPooledEther, timeElapsed } =
      await this.lidoOracleContract.getLastCompletedReportDelta();

    const scaledAPR =
      ((postTotalPooledEther.toBigInt() - preTotalPooledEther.toBigInt()) * YEAR * this.scalingFactor) /
      (preTotalPooledEther.toBigInt() * timeElapsed.toBigInt());

    return Number(scaledAPR / (this.scalingFactor / 10000n)) / 100;
  }

  async getMarketSize(
    inputAssetA: AztecAsset,
    inputAssetB: AztecAsset,
    outputAssetA: AztecAsset,
    outputAssetB: AztecAsset,
    auxData: bigint,
  ): Promise<AssetValue[]> {
    const { postTotalPooledEther } = await this.lidoOracleContract.getLastCompletedReportDelta();
    return [
      {
        assetId: inputAssetA.id,
        value: postTotalPooledEther.toBigInt(),
      },
    ];
  }

  async getUnderlyingAmount(asset: AztecAsset, amount: bigint): Promise<UnderlyingAsset> {
    if (!asset.erc20Address.equals(EthAddress.fromString("0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"))) {
      throw new Error("Eth have no underlying");
    }
    const stETHBalance = await this.wstETHContract.getStETHByWstETH(amount);
    return {
      address: EthAddress.fromString("0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"),
      name: "Liquid staked Ether 2.0 ",
      symbol: "stETH",
      decimals: 18,
      amount: stETHBalance.toBigInt(),
    };
  }
}
