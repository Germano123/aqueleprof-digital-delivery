/**
 * DIGITAL DELIVERY - Gerenciador Central de Salas (RoomManager)
 * Ref: Salas permanentes 'casual', 'border', 'challenge' e rotação automática
 */

import { Room } from './Room.js';
import { DifficultyTier, RoomConfig } from '../domain/types.js';

export interface StandardRoomDef {
  name: string;
  slug: string;
  difficultyTier: DifficultyTier;
  durationSeconds: number;
  description: string;
}

export const STANDARD_ROOM_DEFS: StandardRoomDef[] = [
  {
    name: 'casual',
    slug: 'casual',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    durationSeconds: 480,
    description: 'Modo Iniciante / Casual (Tier 1 - Identificação Direta)'
  },
  {
    name: 'border',
    slug: 'border',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    durationSeconds: 480,
    description: 'Modo Intermediário / Border (Tier 3 - Análise de Extensões)'
  },
  {
    name: 'challenge',
    slug: 'challenge',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    durationSeconds: 480,
    description: 'Modo Avançado / Challenge (Tier 5 - Especialização & Frenesi)'
  }
];

export class RoomManager {
  private roomsByPin: Map<string, Room> = new Map();
  private roomsById: Map<string, Room> = new Map();

  constructor() {
    this.ensureStandardRooms();
  }

  /**
   * Garante que sempre haja 3 salas disponíveis prontas para conexão (casual, border, challenge)
   */
  public ensureStandardRooms(): void {
    for (const def of STANDARD_ROOM_DEFS) {
      const hasAvailableLobby = Array.from(this.roomsById.values()).some(
        (r) => r.name.toLowerCase() === def.slug.toLowerCase() && r.state === 'LOBBY'
      );

      if (!hasAvailableLobby) {
        this.createRoom({
          name: def.name,
          slug: def.slug,
          difficultyTier: def.difficultyTier,
          durationSeconds: def.durationSeconds
        });
      }
    }
  }

  /**
   * Gera um PIN curto de 6 caracteres alfanuméricos fácil para alunos digitarem
   */
  public generateUniquePin(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Sem O, 0, I, 1 para evitar confusão visual
    let pin = '';
    let attempts = 0;

    do {
      pin = '';
      for (let i = 0; i < 6; i++) {
        pin += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      attempts++;
    } while (this.roomsByPin.has(pin) && attempts < 100);

    return pin;
  }

  /**
   * Cria uma nova sala
   */
  public createRoom(initialConfig?: Partial<RoomConfig>): Room {
    const pin = this.generateUniquePin();
    const id = `room_${Date.now()}_${pin}`;

    const room = new Room(id, pin, initialConfig);

    // Quando uma partida terminar em GAME_OVER, recria automaticamente a sala padrão
    room.onGameOver = () => {
      this.ensureStandardRooms();
    };

    this.roomsByPin.set(pin, room);
    this.roomsById.set(id, room);

    return room;
  }

  /**
   * Busca sala por nome da modalidade ('casual', 'border', 'challenge') ou por PIN
   */
  public getRoomByPinOrName(query: string): Room | undefined {
    if (!query) return undefined;
    const clean = query.trim().toLowerCase();

    // 1. Busca por nome padrão ('casual', 'border', 'challenge')
    const matching = Array.from(this.roomsById.values()).filter(
      (r) => r.name.toLowerCase() === clean && r.state !== 'GAME_OVER'
    );

    if (matching.length > 0) {
      // Prioriza sala em LOBBY
      const lobby = matching.find((r) => r.state === 'LOBBY');
      return lobby || matching[0];
    }

    // 2. Busca por PIN exato
    return this.roomsByPin.get(query.toUpperCase().trim());
  }

  public getRoomByPin(pin: string): Room | undefined {
    return this.getRoomByPinOrName(pin);
  }

  public getRoomById(id: string): Room | undefined {
    return this.roomsById.get(id);
  }

  public deleteRoom(id: string): boolean {
    const room = this.roomsById.get(id);
    if (!room) return false;

    this.roomsByPin.delete(room.pin);
    this.roomsById.delete(id);
    return true;
  }

  public getAllRooms(): Room[] {
    return Array.from(this.roomsById.values());
  }

  /**
   * Lista apenas as salas que NÃO estão finalizadas com GAME_OVER
   */
  public getPublicRoomsSummary(): Array<{
    pin: string;
    id: string;
    name: string;
    state: string;
    playerCount: number;
    maxPlayers: number;
    difficultyTier: number;
    isTeamMode: boolean;
    durationSeconds: number;
  }> {
    const order = ['casual', 'border', 'challenge'];

    return Array.from(this.roomsById.values())
      .filter((r) => r.state !== 'GAME_OVER')
      .map((room) => ({
        pin: room.pin,
        id: room.id,
        name: room.name,
        slug: room.name,
        state: room.state,
        playerCount: room.getPlayerCount(),
        maxPlayers: room.config.maxPlayers,
        difficultyTier: room.config.difficultyTier,
        isTeamMode: room.config.isTeamMode,
        durationSeconds: room.config.durationSeconds
      }))
      .sort((a, b) => {
        const idxA = order.indexOf(a.name.toLowerCase());
        const idxB = order.indexOf(b.name.toLowerCase());
        return (idxA !== -1 ? idxA : 99) - (idxB !== -1 ? idxB : 99);
      });
  }
}
