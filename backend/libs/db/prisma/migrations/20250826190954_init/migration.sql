-- CreateTable
CREATE TABLE "Report" (
    "id" TEXT NOT NULL,
    "blockNumber" INTEGER NOT NULL,
    "timestamp" INTEGER NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "newEpoch" BIGINT NOT NULL,
    "newHandledEpochLen" BIGINT NOT NULL,
    "totalSupply" BIGINT NOT NULL,
    "totalAssets" BIGINT NOT NULL,
    "managementFeeShares" BIGINT NOT NULL,
    "performanceFeeShares" BIGINT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Report_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RedeemRequested" (
    "id" TEXT NOT NULL,
    "blockNumber" INTEGER NOT NULL,
    "timestamp" INTEGER NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "receiver" TEXT NOT NULL,
    "shares" BIGINT NOT NULL,
    "assets" BIGINT NOT NULL,
    "redeemId" BIGINT NOT NULL,
    "epoch" BIGINT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RedeemRequested_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RedeemClaimed" (
    "id" TEXT NOT NULL,
    "blockNumber" INTEGER NOT NULL,
    "timestamp" INTEGER NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "receiver" TEXT NOT NULL,
    "redeemRequestNominal" BIGINT NOT NULL,
    "assets" BIGINT NOT NULL,
    "redeemId" BIGINT NOT NULL,
    "epoch" BIGINT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RedeemClaimed_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IndexerStatus" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "currentBlock" INTEGER NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "IndexerStatus_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Report_newEpoch_key" ON "Report"("newEpoch");

-- CreateIndex
CREATE UNIQUE INDEX "RedeemRequested_redeemId_key" ON "RedeemRequested"("redeemId");

-- CreateIndex
CREATE UNIQUE INDEX "RedeemClaimed_redeemId_key" ON "RedeemClaimed"("redeemId");
