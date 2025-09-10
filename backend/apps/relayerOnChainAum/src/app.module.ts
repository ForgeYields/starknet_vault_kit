import { Module } from '@nestjs/common';
import { ConfigModule as NestConfigModule } from '@nestjs/config';
import { ConfigModule } from '@forge/config';
import { StarknetModule } from '@forge/starknet';
import { RelayerService } from './relayer.service';

@Module({
  imports: [
    NestConfigModule.forRoot({
      isGlobal: true,
    }),
    ConfigModule,
    StarknetModule,
  ],
  providers: [RelayerService],
})
export class AppModule {}