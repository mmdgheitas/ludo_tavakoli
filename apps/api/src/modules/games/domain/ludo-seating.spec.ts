import { Team } from '@prisma/client';
import { teamsForPlayerCount } from './game-state';

describe('teamsForPlayerCount', () => {
  it('seats two players on the diagonal like offline games', () => {
    expect(teamsForPlayerCount(2)).toEqual([Team.BLUE, Team.GREEN]);
  });

  it('seats four players on all corners', () => {
    expect(teamsForPlayerCount(4)).toEqual([Team.BLUE, Team.RED, Team.GREEN, Team.YELLOW]);
  });

  it('falls back to four corners for unknown counts', () => {
    expect(teamsForPlayerCount(3)).toEqual([Team.BLUE, Team.RED, Team.GREEN, Team.YELLOW]);
  });
});
