/*
  Warnings:

  - You are about to drop the column `currentBlock` on the `IndexerStatus` table. All the data in the column will be lost.
  - Added the required column `lastBlock` to the `IndexerStatus` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "public"."IndexerStatus" DROP COLUMN "currentBlock",
ADD COLUMN     "lastBlock" INTEGER NOT NULL;
