import 'reflect-metadata';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { INTERNAL_COMMAND_ERROR, describeGameCommandError } from './games.gateway';

/**
 * Real-time errors go straight into a player's snackbar, and the mobile client
 * only translates the codes below. Anything it cannot translate is shown raw, so
 * internal failures must never leave the server log.
 */
describe('describeGameCommandError', () => {
  const internal = `${INTERNAL_COMMAND_ERROR}: Command failed; please retry`;

  it('keeps the rule codes the client translates', () => {
    expect(
      describeGameCommandError(
        new BadRequestException({ code: 'FATTAH_ALREADY_USED', message: 'Fattah is limited to once per game' }),
      ),
    ).toBe('FATTAH_ALREADY_USED: Fattah is limited to once per game');
    expect(describeGameCommandError(new BadRequestException({ code: 'INVALID_TARGET' }))).toBe(
      'INVALID_TARGET: Command rejected',
    );
    expect(describeGameCommandError(new BadRequestException('Roll the dice before moving'))).toBe(
      'Roll the dice before moving',
    );
    expect(describeGameCommandError(new BadRequestException({ message: 'Room is full' }))).toBe('Room is full');
    // Non-string shapes must not be stringified into `[object Object]`.
    expect(describeGameCommandError(new BadRequestException({ code: 42, message: { nested: true } }))).not.toContain(
      '[object Object]',
    );
  });

  it('passes player-facing HTTP messages through', () => {
    expect(describeGameCommandError(new ConflictException('Fattah inventory is empty'))).toBe(
      'Fattah inventory is empty',
    );
    expect(describeGameCommandError(new ConflictException('Game state changed; synchronize and retry'))).toBe(
      'Game state changed; synchronize and retry',
    );
    expect(describeGameCommandError(new ForbiddenException('You are not a participant in this game'))).toBe(
      'You are not a participant in this game',
    );
    expect(describeGameCommandError(new NotFoundException('Game not found'))).toBe('Game not found');
  });

  it('never echoes a database or driver error to a player', () => {
    // Verbatim failure produced by a too-long FattahUsage.targetTokenId.
    const overflow = new Prisma.PrismaClientKnownRequestError(
      "The provided value for the column is too long for the column's type. Column: (not available)",
      { code: 'P2000', clientVersion: 'test' },
    );

    expect(describeGameCommandError(overflow)).toBe(internal);
    expect(describeGameCommandError(overflow)).not.toContain('column');
    expect(describeGameCommandError(overflow)).not.toContain('P2000');
    expect(describeGameCommandError(new Error('connect ECONNREFUSED 127.0.0.1:5432'))).toBe(internal);
    expect(describeGameCommandError('boom')).toBe(internal);
    expect(describeGameCommandError(undefined)).toBe(internal);
  });

  it('labels the failing command when the caller supplies context', () => {
    expect(describeGameCommandError(new Error('redis timeout'), 'Could not subscribe to the game')).toBe(
      `${INTERNAL_COMMAND_ERROR}: Could not subscribe to the game`,
    );
  });
});
