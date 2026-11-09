/**
 * DIGITAL DELIVERY - Sistema de Pontuação e Fórmulas Pedagógicas
 * Ref: Seção 10 do GDD.md
 */

export interface ScoreCalculationParams {
  isCorrect: boolean;
  timeSpentMs: number;
  timeLimitMs: number;
  currentStreak: number;
  difficultyTier: number;
}

export interface ScoreResult {
  scoreDelta: number;
  basePoints: number;
  timeBonus: number;
  streakBonus: number;
  penalty: number;
  newStreak: number;
  summaryMessage: string;
}

export const SCORING_CONSTANTS = {
  BASE_POINTS: 100,
  MAX_TIME_BONUS: 50,
  STREAK_BONUS_STEP: 15,
  MAX_STREAK_MULTIPLIER: 4,
  WRONG_SOFTWARE_PENALTY: 40,
  WRONG_REQUEST_PENALTY: 20
};

/**
 * Calcula os pontos ganhos ou perdidos em uma tentativa de entrega
 */
export function calculateDeliveryScore(params: ScoreCalculationParams): ScoreResult {
  const { isCorrect, timeSpentMs, timeLimitMs, currentStreak, difficultyTier } = params;

  if (!isCorrect) {
    const penalty = SCORING_CONSTANTS.WRONG_SOFTWARE_PENALTY + (difficultyTier * 5);
    return {
      scoreDelta: -penalty,
      basePoints: 0,
      timeBonus: 0,
      streakBonus: 0,
      penalty,
      newStreak: 0, // Reset de streak em caso de falha
      summaryMessage: `Entrega incorreta! Penalidade de -${penalty} pontos e sequência zerada.`
    };
  }

  // Entrega correta
  const tierMultiplier = 1 + (difficultyTier - 1) * 0.15; // Níveis mais altos dão mais pontos
  const basePoints = Math.round(SCORING_CONSTANTS.BASE_POINTS * tierMultiplier);

  // Bônus de tempo: quanto mais rápido entregar em relação ao limite
  let timeBonus = 0;
  if (timeSpentMs < timeLimitMs) {
    const remainingRatio = Math.max(0, (timeLimitMs - timeSpentMs) / timeLimitMs);
    timeBonus = Math.round(SCORING_CONSTANTS.MAX_TIME_BONUS * remainingRatio);
  }

  // Bônus de Streak (sequência de acertos seguidos)
  const effectiveStreak = Math.min(currentStreak, SCORING_CONSTANTS.MAX_STREAK_MULTIPLIER);
  const streakBonus = effectiveStreak * SCORING_CONSTANTS.STREAK_BONUS_STEP;

  const totalEarned = basePoints + timeBonus + streakBonus;
  const newStreak = currentStreak + 1;

  let summaryMessage = `Entrega perfeita! +${totalEarned} pts (Base: ${basePoints}`;
  if (timeBonus > 0) summaryMessage += `, Tempo: +${timeBonus}`;
  if (streakBonus > 0) summaryMessage += `, Streak x${newStreak}: +${streakBonus}`;
  summaryMessage += `)`;

  return {
    scoreDelta: totalEarned,
    basePoints,
    timeBonus,
    streakBonus,
    penalty: 0,
    newStreak,
    summaryMessage
  };
}
