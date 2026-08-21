import { validate } from 'class-validator';
import { RegisterDto, ResetPasswordDto } from './auth.dto';

describe('credential DTO validation', () => {
  it('accepts a strong registration payload', async () => {
    const dto = Object.assign(new RegisterDto(), {
      username: 'player_one',
      email: 'player@example.com',
      password: 'StrongPass123',
    });
    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects a weak registration password', async () => {
    const dto = Object.assign(new RegisterDto(), {
      username: 'player_one',
      email: 'player@example.com',
      password: 'alllowercase',
    });
    expect(await validate(dto)).not.toHaveLength(0);
  });

  it('requires a six digit recovery code', async () => {
    const dto = Object.assign(new ResetPasswordDto(), {
      identifier: 'player_one',
      code: 'abc',
      newPassword: 'StrongPass123',
    });
    expect(await validate(dto)).not.toHaveLength(0);
  });
});
