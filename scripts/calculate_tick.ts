import { Decimal } from "decimal.js";

Decimal.set({ precision: 78 });

function getSqrtPriceRangeAroundParity(
  token0Decimals: number,
  token1Decimals: number,
  deltaPercent: number = 0.04
): { sqrtRatioLower: bigint; sqrtRatioUpper: bigint } {
  const decimalDiff = token1Decimals - token0Decimals;
  const parityPrice = new Decimal(10).pow(decimalDiff);
  const deltaMultiplier = new Decimal(deltaPercent).div(100);
  const priceLower = parityPrice.mul(new Decimal(1).minus(deltaMultiplier));
  const priceUpper = parityPrice.mul(new Decimal(1).plus(deltaMultiplier));
  const twoTo128 = new Decimal(2).pow(128);
  const sqrtRatioLower = priceLower.sqrt().mul(twoTo128).floor();
  const sqrtRatioUpper = priceUpper.sqrt().mul(twoTo128).floor();
  return {
    sqrtRatioLower: BigInt(sqrtRatioLower.toFixed(0)),
    sqrtRatioUpper: BigInt(sqrtRatioUpper.toFixed(0)),
  };
}

async function main() {
  const wbtcDecimals = 8;
  const solvDecimals = 18;
  const { sqrtRatioLower, sqrtRatioUpper } = getSqrtPriceRangeAroundParity(
    wbtcDecimals,
    solvDecimals
  );
  console.log(sqrtRatioLower, sqrtRatioUpper);
}

main();
