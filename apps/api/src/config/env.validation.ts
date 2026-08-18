type Environment = Record<string, string | undefined>;

export function validateEnvironment(env: Environment): Environment {
  const production = env.NODE_ENV === 'production';
  const required = ['DATABASE_URL', 'REDIS_URL', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
  const missing = required.filter((key) => !env[key]);
  if (production && missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET']) {
    const value = env[key];
    if (production && value && value.length < 32) {
      throw new Error(`${key} must contain at least 32 characters`);
    }
  }
  return env;
}
