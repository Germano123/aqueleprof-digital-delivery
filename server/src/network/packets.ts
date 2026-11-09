/**
 * DIGITAL DELIVERY - Protocolo de Pacotes de Rede (Client <-> Server)
 * Baseado no GDD.md para comunicação em tempo real via WebSockets
 */

import {
  DifficultyTier,
  FileCategory,
  RoomState,
  TeamId,
  Vector3,
  DeliveryRequest,
  FileCubeEntity,
  PlayerState,
  RoomConfig,
  TelemetryDeliveryLog
} from '../domain/types.js';
import { ScoreResult } from '../domain/scoring.js';

// --- Pacotes de Cliente -> Servidor (C2S) ---

export type ClientPacket =
  | { type: 'C2S_JOIN_ROOM'; pin: string; username: string; teamId?: TeamId }
  | { type: 'C2S_UPDATE_CONFIG'; config: Partial<RoomConfig> }
  | { type: 'C2S_START_GAME' }
  | { type: 'C2S_START_TUNNEL' }
  | { type: 'C2S_PLAYER_INPUT'; position: Vector3; velocity: Vector3; yaw: number }
  | { type: 'C2S_CLAIM_REQUEST'; requestId: string }
  | { type: 'C2S_GRAB_CUBE'; cubeId: string }
  | { type: 'C2S_DROP_CUBE'; cubeId: string; impulse?: Vector3 }
  | { type: 'C2S_SUBMIT_DELIVERY'; softwareStationId: string; cubeId: string }
  | { type: 'C2S_RESOLVE_VIRUS_QTE'; success: boolean }
  | { type: 'C2S_RESOLVE_POPUP'; popupId: string };

// --- Snapshots e Estados Compactados ---

export interface PlayerSnapshot {
  id: string;
  username: string;
  teamId?: TeamId;
  color: string;
  score: number;
  streak: number;
  carriedCubeId: string | null;
  position: Vector3;
  velocity: Vector3;
  yaw: number;
  isImmune: boolean;
  isVirusStunned: boolean;
  hasStuckPopups: boolean;
  speedMultiplier: number;
}

export interface CubeSnapshot {
  id: string;
  fileName?: string;
  extension: string;
  category: FileCategory;
  colorHex: string;
  carrierPlayerId: string | null;
  position: Vector3;
  state: 'SPAWNED' | 'CARRIED' | 'DROPPED_BOUNCING';
}

export interface RamHazardSnapshot {
  activePlayersCount: number;
  isOverloaded: boolean; // >= 5 jogadores
  speedMultiplier: number;
}

export interface VirusHazardSnapshot {
  id: string;
  position: Vector3;
  targetPlayerId: string | null;
}

export interface FirewallHazardSnapshot {
  id: string;
  isActive: boolean;
  position: Vector3;
}

export interface DefragHazardSnapshot {
  activeSectorIndex: number;
  status: 'STABLE' | 'WARNING_BLINK' | 'DEFRAGMENTING';
  fallenTileIds: string[];
}

export interface HazardSnapshot {
  ram: RamHazardSnapshot;
  viruses: VirusHazardSnapshot[];
  firewalls: FirewallHazardSnapshot[];
  isUsbBlocked: boolean;
  defrag: DefragHazardSnapshot;
}

export interface PlayerRanking {
  rank: number;
  playerId: string;
  username: string;
  teamId?: TeamId;
  score: number;
  correctDeliveries: number;
  failedDeliveries: number;
}

export interface ClassDidacticSummary {
  totalDeliveries: number;
  accuracyPercentage: number;
  mostConfusedExtensions: Array<{ extension: string; errorsCount: number; commonMistake: string }>;
  bestCategory: string;
  needsReviewCategory: string;
}

// --- Pacotes de Servidor -> Cliente (S2C) ---

export type ServerPacket =
  | { type: 'S2C_ROOM_JOINED'; player: PlayerState; config: RoomConfig; players: PlayerState[]; roomName?: string }
  | { type: 'S2C_PLAYER_JOINED'; player: PlayerState }
  | { type: 'S2C_PLAYER_LEFT'; playerId: string }
  | { type: 'S2C_ROOM_STATE_CHANGE'; state: RoomState; countdownSeconds?: number; matchTimeRemainingMs?: number }
  | { type: 'S2C_REQUEST_POOL_UPDATE'; requests: DeliveryRequest[] }
  | {
      type: 'S2C_TICK_SNAPSHOT';
      serverTime: number;
      timeRemainingMs: number;
      players: PlayerSnapshot[];
      cubes: CubeSnapshot[];
      hazards: HazardSnapshot;
      processCount?: number;
      maxProcesses?: number;
    }
  | {
      type: 'S2C_DELIVERY_EVALUATED';
      playerId: string;
      requestId: string;
      result: ScoreResult;
      telemetry: TelemetryDeliveryLog;
    }
  | { type: 'S2C_VIRUS_TRIGGERED'; playerId: string; sequenceToType: string }
  | { type: 'S2C_POPUP_TRIGGERED'; playerId: string; popupId: string; popupCount: number }
  | {
      type: 'S2C_GAME_OVER';
      rankings: PlayerRanking[];
      teamRankings?: Record<TeamId, number>;
      didacticSummary: ClassDidacticSummary;
      reason?: 'TIME_EXPIRED' | 'SYSTEM_CRASH';
    }
  | { type: 'S2C_ERROR'; message: string };
