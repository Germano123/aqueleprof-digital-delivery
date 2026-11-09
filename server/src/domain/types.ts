/**
 * DIGITAL DELIVERY - Domain Types & Data Contracts
 * Baseado nas especificações do Game Design Document (GDD.md)
 */

export type Vector3 = {
  x: number;
  y: number;
  z: number;
};

export enum FileCategory {
  DOCUMENT = 'DOCUMENT',
  SPREADSHEET = 'SPREADSHEET',
  PRESENTATION = 'PRESENTATION',
  IMAGE = 'IMAGE',
  AUDIO = 'AUDIO',
  VIDEO = 'VIDEO',
  COMPRESSED = 'COMPRESSED',
  WEB = 'WEB',
  EXECUTABLE = 'EXECUTABLE'
}

export interface CategoryVisualInfo {
  name: string;
  colorName: string;
  hex: string;
  emoji: string;
}

export enum DifficultyTier {
  TIER_1_IDENTIFICATION = 1,  // Requisição informa diretamente o arquivo e extensão
  TIER_2_INTERPRETATION = 2,  // Descreve a tarefa sem indicar diretamente o software
  TIER_3_EXTENSION = 3,       // Análise de extensão e categoria
  TIER_4_AMBIGUITY = 4,       // Arquivos com finalidades semelhantes e múltiplas requisições
  TIER_5_SPECIALIZATION = 5   // Extensões menos comuns (.csv, .gif, .wav, .rar, .7z, etc.)
}

export interface SoftwareStation {
  id: string;
  name: string;
  description: string;
  handledCategories: FileCategory[];
  allowedExtensions: string[];
  stationPosition?: Vector3;
}

export interface FileDefinition {
  id: string;
  name: string;
  extension: string;
  category: FileCategory;
  recommendedSoftwareId: string;
  difficultyTier: DifficultyTier;
  sampleFileName: string;
}

export type RequestStatus = 'AVAILABLE' | 'CLAIMED' | 'DELIVERED' | 'EXPIRED';

export interface DeliveryRequest {
  id: string;
  promptText: string;
  targetFile: FileDefinition;
  correctSoftwareId: string;
  difficultyTier: DifficultyTier;
  status: RequestStatus;
  claimedByPlayerId?: string;
  spawnTimeMs: number;
  timeLimitMs: number;
  basePoints: number;
}

export type CubeState = 'SPAWNED' | 'CARRIED' | 'DROPPED_BOUNCING';

export interface FileCubeEntity {
  id: string;
  fileData: FileDefinition;
  position: Vector3;
  velocity: Vector3;
  carrierPlayerId: string | null;
  state: CubeState;
  createdAtMs: number;
}

export type RoomState = 'LOBBY' | 'STARTING' | 'IN_GAME' | 'GAME_OVER';

export type TeamId = 'RED' | 'BLUE' | 'YELLOW' | 'GREEN';

export interface PlayerState {
  id: string;
  username: string;
  teamId?: TeamId;
  color: string;
  isHost: boolean;
  score: number;
  correctDeliveries: number;
  failedDeliveries: number;
  streak: number;
  activeRequestId?: string;
  carriedCubeId: string | null;
  position: Vector3;
  isImmune: boolean;           // Área de Manutenção
  isVirusStunned: boolean;     // Atingido pelo Vírus
  hasStuckPopups: boolean;     // Janela Travada
  speedMultiplier: number;
  connected: boolean;
}

export interface RoomConfig {
  id: string;
  pin: string;
  name?: string;
  slug?: string;
  maxPlayers: number;
  isTeamMode: boolean;
  difficultyTier: DifficultyTier;
  durationSeconds: number;     // GDD define até 8 minutos (480s)
  hazardsEnabled: boolean;
}

export interface TelemetryDeliveryLog {
  timestamp: number;
  playerId: string;
  playerName: string;
  requestId: string;
  requestedExtension: string;
  fileCategory: FileCategory;
  deliveredToSoftwareId: string;
  correctSoftwareId: string;
  isSuccess: boolean;
  pointsEarned: number;
  timeSpentMs: number;
  errorMessage?: string;
}
