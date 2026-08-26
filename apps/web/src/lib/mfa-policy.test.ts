import { describe, expect, it } from 'vitest';
import { adminMfaDecision } from './mfa-policy';

describe('administrator MFA policy', () => {
  it('does not alter staff/customer assurance behavior', () => expect(adminMfaDecision({role:'STAFF',currentLevel:'aal1',nextLevel:'aal2',enforcement:'required'})).toBe('allow'));
  it('requires an enrolled admin to challenge', () => expect(adminMfaDecision({role:'ADMIN',currentLevel:'aal1',nextLevel:'aal2',enforcement:'required'})).toBe('challenge'));
  it('avoids lockout during rollout but enforces enrollment when enabled', () => {
    expect(adminMfaDecision({role:'ADMIN',currentLevel:'aal1',nextLevel:'aal1',enforcement:'rollout'})).toBe('allow-rollout');
    expect(adminMfaDecision({role:'ADMIN',currentLevel:'aal1',nextLevel:'aal1',enforcement:'required'})).toBe('enroll');
  });
});
