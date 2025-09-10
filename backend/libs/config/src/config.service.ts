import { Injectable } from "@nestjs/common";
import { ConfigService as NestConfigService } from "@nestjs/config";

@Injectable()
export class ConfigService {
  constructor(private readonly configService: NestConfigService) {}

  public get(key: string): string | number | undefined {
    return this.configService.get(key, { infer: true });
  }
}
