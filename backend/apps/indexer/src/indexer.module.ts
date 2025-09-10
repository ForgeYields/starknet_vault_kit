import { Module } from '@nestjs/common';
import { ConfigModule } from '@forge/config';
import { PrismaModule } from '@forge/db';
import { IndexerService } from './indexer.service';

@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [IndexerService],
  exports: [IndexerService],
})
export class IndexerModule {}
