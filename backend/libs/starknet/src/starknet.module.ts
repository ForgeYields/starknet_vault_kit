import { Module } from "@nestjs/common";
import { StarknetService } from "./starknet.service";
import { ConfigModule } from "@forge/config";

@Module({
  imports: [ConfigModule],
  providers: [StarknetService],
  exports: [StarknetService],
})
export class StarknetModule {}