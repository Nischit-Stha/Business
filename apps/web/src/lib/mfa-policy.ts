export type AssuranceLevel = string | null;

export function adminMfaDecision(input: { role: string; currentLevel: AssuranceLevel; nextLevel: AssuranceLevel; enforcement: string | undefined }) {
  if (input.role !== 'ADMIN') return 'allow' as const;
  if (input.currentLevel === 'aal2') return 'allow' as const;
  if (input.nextLevel === 'aal2') return 'challenge' as const;
  return input.enforcement === 'required' ? 'enroll' as const : 'allow-rollout' as const;
}
