import { Module } from "@nestjs/common";
import { ConfigModule } from "@forge/config";
import { PrismaModule } from "@forge/db";
import { StarknetModule } from "@forge/starknet";
import { RelayerAutomaticRedeemService } from "./relayerAutomaticRedeem.service";

@Module({
  imports: [ConfigModule, PrismaModule, StarknetModule],
  providers: [RelayerAutomaticRedeemService],
  exports: [RelayerAutomaticRedeemService],
})
export class RelayerAutomaticRedeemModule {}