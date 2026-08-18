import { BadGatewayException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';

export interface VerificationResult {
  transactionId: string;
  productSku: string;
  raw: Record<string, string | number | boolean | null>;
}

@Injectable()
export class ProviderVerifierService {
  constructor(private readonly config: ConfigService) {}

  async verify(provider: PaymentProvider, purchaseToken: string, productSku: string): Promise<VerificationResult> {
    const prefix = provider === PaymentProvider.CAFE_BAZAAR ? 'BAZAAR' : 'MYKET';
    const url = this.config.get<string>(`${prefix}_VERIFY_URL`);
    const credential = this.config.get<string>(provider === PaymentProvider.CAFE_BAZAAR ? 'BAZAAR_CLIENT_SECRET' : 'MYKET_API_KEY');
    if (!url || !credential || !url.startsWith('https://')) {
      throw new ServiceUnavailableException(`${provider} receipt verification is not configured`);
    }
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${credential}` },
        body: JSON.stringify({ purchaseToken, productSku }),
        signal: controller.signal,
      });
      if (!response.ok) throw new BadGatewayException(`Provider verification failed with ${response.status}`);
      const data: unknown = await response.json();
      if (!this.isValidResponse(data) || data.productSku !== productSku || !data.valid) {
        throw new BadGatewayException('Provider rejected the purchase receipt');
      }
      return { transactionId: data.transactionId, productSku: data.productSku, raw: data };
    } finally {
      clearTimeout(timeout);
    }
  }

  private isValidResponse(value: unknown): value is Record<string, string | number | boolean | null> & { valid: boolean; productSku: string; transactionId: string } {
    if (typeof value !== 'object' || value == null) return false;
    const result = value as Record<string, unknown>;
    return typeof result.valid === 'boolean' && typeof result.productSku === 'string' && typeof result.transactionId === 'string';
  }
}
