import { Module } from '@nestjs/common';
import { ConfigModule } from '@forge/config';
import { PrismaModule } from '@forge/db';
import { StarknetModule } from '@forge/starknet';
import { HealthModule } from './health';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    StarknetModule,
    HealthModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}