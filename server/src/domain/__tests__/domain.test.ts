import { describe, it, expect } from 'vitest';
import {
  CATEGORY_VISUALS,
  SOFTWARE_STATIONS,
  FILE_CATALOG,
  getFilesForDifficulty,
  validateDeliveryTarget
} from '../extensions.js';
import { FileCategory, DifficultyTier } from '../types.js';
import { calculateDeliveryScore, SCORING_CONSTANTS } from '../scoring.js';
import { generateDeliveryRequest } from '../requests.js';

describe('Domain: Extensions & Visuals (GDD Seção 16 & 13)', () => {
  it('deve possuir as 9 cores exatas definidas no GDD', () => {
    expect(CATEGORY_VISUALS[FileCategory.DOCUMENT].hex).toBe('#3498DB');
    expect(CATEGORY_VISUALS[FileCategory.SPREADSHEET].hex).toBe('#2ECC71');
    expect(CATEGORY_VISUALS[FileCategory.PRESENTATION].hex).toBe('#F39C12');
    expect(CATEGORY_VISUALS[FileCategory.IMAGE].hex).toBe('#E84393');
    expect(CATEGORY_VISUALS[FileCategory.AUDIO].hex).toBe('#9B59B6');
    expect(CATEGORY_VISUALS[FileCategory.VIDEO].hex).toBe('#E74C3C');
    expect(CATEGORY_VISUALS[FileCategory.COMPRESSED].hex).toBe('#F1C40F');
    expect(CATEGORY_VISUALS[FileCategory.WEB].hex).toBe('#00B8D9');
    expect(CATEGORY_VISUALS[FileCategory.EXECUTABLE].hex).toBe('#34495E');
  });

  it('deve conter todas as estações de software e extensões do GDD', () => {
    expect(SOFTWARE_STATIONS['text_editor'].allowedExtensions).toContain('.docx');
    expect(SOFTWARE_STATIONS['calc_sheet'].allowedExtensions).toContain('.xlsx');
    expect(SOFTWARE_STATIONS['slide_presentation'].allowedExtensions).toContain('.pptx');
    expect(SOFTWARE_STATIONS['image_editor'].allowedExtensions).toContain('.jpg');
    expect(SOFTWARE_STATIONS['audio_player'].allowedExtensions).toContain('.mp3');
    expect(SOFTWARE_STATIONS['video_player'].allowedExtensions).toContain('.mp4');
    expect(SOFTWARE_STATIONS['archive_manager'].allowedExtensions).toContain('.zip');
  });

  it('deve filtrar arquivos por nível de dificuldade progressiva', () => {
    const tier1Files = getFilesForDifficulty(DifficultyTier.TIER_1_IDENTIFICATION);
    const tier1Extensions = tier1Files.map(f => f.extension);
    
    // Nível 1 do GDD (Seção 14): .docx, .xlsx, .pptx, .jpg, .mp3, .mp4
    expect(tier1Extensions).toContain('.docx');
    expect(tier1Extensions).toContain('.xlsx');
    expect(tier1Extensions).toContain('.pptx');
    expect(tier1Extensions).toContain('.jpg');
    expect(tier1Extensions).toContain('.mp3');
    expect(tier1Extensions).toContain('.mp4');
    expect(tier1Extensions).not.toContain('.csv'); // .csv é Tier 3

    const tier3Files = getFilesForDifficulty(DifficultyTier.TIER_3_EXTENSION);
    const tier3Extensions = tier3Files.map(f => f.extension);
    expect(tier3Extensions).toContain('.csv');
    expect(tier3Extensions).toContain('.gif');
    expect(tier3Extensions).toContain('.zip');
  });

  it('deve validar corretamente entregas certas e erradas', () => {
    // Entrega correta
    const validResult = validateDeliveryTarget('.docx', 'text_editor');
    expect(validResult.isValid).toBe(true);

    // Entrega incorreta: tentar abrir docx no reprodutor de vídeo
    const invalidResult = validateDeliveryTarget('.docx', 'video_player');
    expect(invalidResult.isValid).toBe(false);
    expect(invalidResult.reason).toContain('não pode ser aberta');
  });
});

describe('Domain: Scoring System (GDD Seção 10)', () => {
  it('deve calcular pontos de entrega correta com bônus de tempo e streak', () => {
    const result = calculateDeliveryScore({
      isCorrect: true,
      timeSpentMs: 15000,
      timeLimitMs: 45000,
      currentStreak: 2,
      difficultyTier: 1
    });

    expect(result.scoreDelta).toBeGreaterThan(SCORING_CONSTANTS.BASE_POINTS);
    expect(result.timeBonus).toBeGreaterThan(0);
    expect(result.streakBonus).toBeGreaterThan(0);
    expect(result.newStreak).toBe(3);
    expect(result.penalty).toBe(0);
  });

  it('deve aplicar penalidade e zerar streak em caso de entrega incorreta', () => {
    const result = calculateDeliveryScore({
      isCorrect: false,
      timeSpentMs: 10000,
      timeLimitMs: 45000,
      currentStreak: 4,
      difficultyTier: 1
    });

    expect(result.scoreDelta).toBeLessThan(0);
    expect(result.penalty).toBeGreaterThan(0);
    expect(result.newStreak).toBe(0);
  });
});

describe('Domain: Request Generator (GDD Seções 8 e 9)', () => {
  it('deve gerar requisição válida com prompt e arquivo', () => {
    const req = generateDeliveryRequest(DifficultyTier.TIER_1_IDENTIFICATION);

    expect(req.id).toBeDefined();
    expect(req.promptText.length).toBeGreaterThan(10);
    expect(req.targetFile).toBeDefined();
    expect(req.status).toBe('AVAILABLE');
    expect(req.correctSoftwareId).toBeDefined();
  });
});
