import { BigNumberish, CallData, uint256 } from "starknet";
import { CalldataResult } from "../types";

export class CalldataBuilder {
  /**
   * Build calldata for ERC20 approve operation
   */
  static buildApproveCalldata(
    tokenAddress: string,
    spender: string,
    amount: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      spender: spender,
      amount: uint256.bnToUint256(amount.toString()),
    });

    return {
      contractAddress: tokenAddress,
      entrypoint: "approve",
      calldata,
    };
  }

  /**
   * Build calldata for deposit operation
   */
  static buildDepositCalldata(
    vaultAddress: string,
    assets: BigNumberish,
    receiver: string
  ): CalldataResult {
    const calldata = CallData.compile({
      assets: uint256.bnToUint256(assets.toString()),
      receiver: receiver,
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "deposit",
      calldata,
    };
  }

  /**
   * Build calldata for mint operation
   */
  static buildMintCalldata(
    vaultAddress: string,
    shares: BigNumberish,
    receiver: string
  ): CalldataResult {
    const calldata = CallData.compile({
      shares: uint256.bnToUint256(shares.toString()),
      receiver: receiver,
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "mint",
      calldata,
    };
  }

  /**
   * Build calldata for request_redeem operation
   */
  static buildRequestRedeemCalldata(
    vaultAddress: string,
    shares: BigNumberish,
    receiver: string,
    owner: string
  ): CalldataResult {
    const calldata = CallData.compile({
      shares: uint256.bnToUint256(shares.toString()),
      receiver: receiver,
      owner: owner,
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "request_redeem",
      calldata,
    };
  }

  /**
   * Build calldata for claim_redeem operation
   */
  static buildClaimRedeemCalldata(
    vaultAddress: string,
    id: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      id: uint256.bnToUint256(id.toString()),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "claim_redeem",
      calldata,
    };
  }

  /**
   * Build calldata for report operation (curator only)
   */
  static buildReportCalldata(
    vaultAddress: string,
    newAum: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      new_aum: uint256.bnToUint256(newAum.toString()),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "report",
      calldata,
    };
  }

  /**
   * Build calldata for bring_liquidity operation (curator only)
   */
  static buildBringLiquidityCalldata(
    vaultAddress: string,
    amount: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      amount: uint256.bnToUint256(amount.toString()),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "bring_liquidity",
      calldata,
    };
  }

  /**
   * Build calldata for pause operation (curator only)
   */
  static buildPauseCalldata(vaultAddress: string): CalldataResult {
    const calldata = CallData.compile({});

    return {
      contractAddress: vaultAddress,
      entrypoint: "pause",
      calldata,
    };
  }

  /**
   * Build calldata for unpause operation (curator only)
   */
  static buildUnpauseCalldata(vaultAddress: string): CalldataResult {
    const calldata = CallData.compile({});

    return {
      contractAddress: vaultAddress,
      entrypoint: "unpause",
      calldata,
    };
  }

  /**
   * Build calldata for set_fees_config operation (curator only)
   */
  static buildSetFeesConfigCalldata(
    vaultAddress: string,
    feesRecipient: string,
    redeemFees: BigNumberish,
    managementFees: BigNumberish,
    performanceFees: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      fees_recipient: feesRecipient,
      redeem_fees: uint256.bnToUint256(redeemFees.toString()),
      management_fees: uint256.bnToUint256(managementFees.toString()),
      performance_fees: uint256.bnToUint256(performanceFees.toString()),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "set_fees_config",
      calldata,
    };
  }

  /**
   * Build calldata for set_report_delay operation (curator only)
   */
  static buildSetReportDelayCalldata(
    vaultAddress: string,
    reportDelay: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      report_delay: reportDelay.toString(),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "set_report_delay",
      calldata,
    };
  }

  /**
   * Build calldata for set_max_delta operation (curator only)
   */
  static buildSetMaxDeltaCalldata(
    vaultAddress: string,
    maxDelta: BigNumberish
  ): CalldataResult {
    const calldata = CallData.compile({
      max_delta: uint256.bnToUint256(maxDelta.toString()),
    });

    return {
      contractAddress: vaultAddress,
      entrypoint: "set_max_delta",
      calldata,
    };
  }
}