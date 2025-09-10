import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiTags, ApiResponse, ApiParam, ApiQuery } from '@nestjs/swagger';
import { AppService, PendingRedeem, StrategyAnalytics, RedeemRequiredAssets } from './app.service';

@ApiTags('api')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @ApiResponse({ status: 200, description: 'API information and available endpoints' })
  getApiInfo() {
    return this.appService.getApiInfo();
  }

  @Get('pending-redeems/:address')
  @ApiParam({ name: 'address', description: 'User address' })
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Number of pending redeems to return',
    type: Number,
  })
  @ApiQuery({
    name: 'offset',
    required: false,
    description: 'Number of pending redeems to skip',
    type: Number,
  })
  @ApiResponse({ status: 200, description: 'Pending redeems for the address' })
  async getPendingRedeems(
    @Param('address') address: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string
  ): Promise<PendingRedeem[]> {
    const limitNumber = limit ? parseInt(limit, 10) : undefined;
    const offsetNumber = offset ? parseInt(offset, 10) : undefined;
    return this.appService.getPendingRedeems(address, limitNumber, offsetNumber);
  }

  @Get('reports/last')
  @ApiResponse({ status: 200, description: 'Latest report from database' })
  async getLastReport() {
    return this.appService.getLastReport();
  }

  @Get('redeems/:id')
  @ApiParam({ name: 'id', description: 'Redeem ID' })
  @ApiResponse({ status: 200, description: 'Redeem details by ID' })
  async getRedeemById(@Param('id') id: string) {
    return this.appService.getRedeemById(id);
  }

  @Get('strategy-analytics')
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Number of reports to return',
    type: Number,
  })
  @ApiQuery({
    name: 'offset',
    required: false,
    description: 'Number of reports to skip',
    type: Number,
  })
  @ApiResponse({ status: 200, description: 'Strategy analytics data' })
  async getStrategyAnalytics(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string
  ): Promise<StrategyAnalytics[]> {
    const limitNumber = limit ? parseInt(limit, 10) : 10;
    const offsetNumber = offset ? parseInt(offset, 10) : undefined;
    return this.appService.getStrategyAnalytics(limitNumber, offsetNumber);
  }

  @Get('redeem-required-assets')
  @ApiResponse({ status: 200, description: 'Redeem required assets for each epoch' })
  async getRedeemRequiredAssets(): Promise<RedeemRequiredAssets[]> {
    return this.appService.getRedeemRequiredAssets();
  }

  @Get('indexer-status')
  @ApiResponse({ status: 200, description: 'Current indexer status including last indexed block' })
  async getIndexerStatus() {
    return this.appService.getIndexerStatus();
  }
}
