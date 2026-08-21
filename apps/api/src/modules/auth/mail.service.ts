import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter?: Transporter;

  constructor(private readonly config: ConfigService) {
    const host = config.get<string>('SMTP_HOST');
    const user = config.get<string>('SMTP_USER');
    const pass = config.get<string>('SMTP_PASSWORD');
    const port = Number(config.get<string>('SMTP_PORT') ?? 587);
    if (host && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
        disableFileAccess: true,
        disableUrlAccess: true,
      });
    }
  }

  async sendPasswordReset(email: string, code: string): Promise<void> {
    if (!this.transporter) {
      if (this.config.get<string>('NODE_ENV') !== 'production') {
        this.logger.warn(`Development password reset code for ${email}: ${code}`);
      } else {
        this.logger.error('SMTP is not configured; password reset email was not sent');
      }
      return;
    }
    await this.transporter.sendMail({
      from: this.config.get<string>('SMTP_FROM') ?? 'Manche Irani <no-reply@example.invalid>',
      to: email,
      subject: 'کد بازیابی رمز عبور منچ ایرانی',
      text: `کد بازیابی شما: ${code}\nاین کد تا ۱۵ دقیقه معتبر است.`,
      html: `<div dir="rtl" style="font-family:Tahoma,sans-serif"><h2>منچ ایرانی</h2><p>کد بازیابی رمز عبور:</p><p style="font-size:30px;font-weight:bold;letter-spacing:6px">${code}</p><p>این کد تا ۱۵ دقیقه معتبر است.</p></div>`,
    });
  }
}
