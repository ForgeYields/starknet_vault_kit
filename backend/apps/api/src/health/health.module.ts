import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { HttpModule } from '@nestjs/axios';

@Module({
  providers: [],
  controllers: [HealthController],
  imports: [TerminusModule, HttpModule],
})
export class HealthModule {}
