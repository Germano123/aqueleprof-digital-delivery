/**
 * DIGITAL DELIVERY - Módulo de Telemetria e Relatório Pedagógico para o Professor
 * Ref: Seções 2, 3 e 15 do GDD.md
 */

import {
  TelemetryDeliveryLog,
  FileCategory
} from '../domain/types.js';
import {
  ClassDidacticSummary,
  PlayerRanking
} from '../network/packets.js';

export class TelemetryTracker {
  private logs: TelemetryDeliveryLog[] = [];

  constructor() {}

  public recordDelivery(log: TelemetryDeliveryLog) {
    this.logs.push(log);
  }

  public getLogs(): TelemetryDeliveryLog[] {
    return this.logs;
  }

  /**
   * Gera relatório pedagógico consolidado da partida
   */
  public generateDidacticSummary(): ClassDidacticSummary {
    const totalDeliveries = this.logs.length;
    if (totalDeliveries === 0) {
      return {
        totalDeliveries: 0,
        accuracyPercentage: 100,
        mostConfusedExtensions: [],
        bestCategory: 'N/A',
        needsReviewCategory: 'N/A'
      };
    }

    const successes = this.logs.filter((l) => l.isSuccess).length;
    const accuracyPercentage = Math.round((successes / totalDeliveries) * 100);

    // Mapeamento de erros por extensão
    const errorMap: Map<string, { errorsCount: number; destinationAttempts: Map<string, number> }> = new Map();
    const categoryStats: Map<FileCategory, { total: number; success: number }> = new Map();

    for (const log of this.logs) {
      // Estatísticas de categorias
      const catStat = categoryStats.get(log.fileCategory) || { total: 0, success: 0 };
      catStat.total++;
      if (log.isSuccess) catStat.success++;
      categoryStats.set(log.fileCategory, catStat);

      // Se errou, analisa a extensão e o software de tentativa
      if (!log.isSuccess) {
        const extEntry = errorMap.get(log.requestedExtension) || {
          errorsCount: 0,
          destinationAttempts: new Map()
        };
        extEntry.errorsCount++;
        const currentCount = extEntry.destinationAttempts.get(log.deliveredToSoftwareId) || 0;
        extEntry.destinationAttempts.set(log.deliveredToSoftwareId, currentCount + 1);
        errorMap.set(log.requestedExtension, extEntry);
      }
    }

    // Top extensões que geraram mais confusão
    const mostConfusedExtensions = Array.from(errorMap.entries())
      .sort((a, b) => b[1].errorsCount - a[1].errorsCount)
      .slice(0, 3)
      .map(([ext, data]) => {
        // Encontra o software mais tentado erroneamente
        let topMistake = 'Software incorreto';
        let maxMistakeCount = 0;
        for (const [soft, cnt] of data.destinationAttempts.entries()) {
          if (cnt > maxMistakeCount) {
            maxMistakeCount = cnt;
            topMistake = soft;
          }
        }

        return {
          extension: ext,
          errorsCount: data.errorsCount,
          commonMistake: `Tentaram abrir em '${topMistake}'`
        };
      });

    // Categoria de maior e menor aproveitamento
    let bestCategory = 'Geral';
    let highestRatio = -1;
    let worstCategory = 'Geral';
    let lowestRatio = 2;

    for (const [cat, stat] of categoryStats.entries()) {
      const ratio = stat.success / stat.total;
      if (ratio > highestRatio) {
        highestRatio = ratio;
        bestCategory = cat;
      }
      if (ratio < lowestRatio) {
        lowestRatio = ratio;
        worstCategory = cat;
      }
    }

    return {
      totalDeliveries,
      accuracyPercentage,
      mostConfusedExtensions,
      bestCategory,
      needsReviewCategory: worstCategory
    };
  }
}
