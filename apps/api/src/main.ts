import { ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './redis/redis-io.adapter';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { cors: false });
  const config = app.get(ConfigService);
  app.use(helmet());
  const socketAdapter = new RedisIoAdapter(app, config);
  await socketAdapter.connectToRedis();
  app.useWebSocketAdapter(socketAdapter);
  app.enableShutdownHooks();
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });
  app.setGlobalPrefix('api');
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: { enableImplicitConversion: false },
  }));
  const origins = (config.get<string>('CORS_ORIGINS') ?? 'http://localhost:3000')
    .split(',').map((origin) => origin.trim());
  // app.enableCors({ origin: origins, credentials: true, methods: ['GET', 'POST', 'PATCH', 'DELETE'] });

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Manche Irani API')
    .setDescription('Authoritative multiplayer, economy and administration API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swaggerConfig), {
    swaggerOptions: { persistAuthorization: true },
  });

  const port = config.get<number>('PORT') ?? 3001;
  await app.listen(port, '0.0.0.0');
}

void bootstrap();
