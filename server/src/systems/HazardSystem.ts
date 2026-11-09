/**
 * DIGITAL DELIVERY - Gerenciador de Caos & Obstáculos do Computador
 * Ref: Seção 11 do GDD.md
 */

import {
  Vector3,
  PlayerState,
  FileCubeEntity
} from '../domain/types.js';
import {
  HazardSnapshot,
  RamHazardSnapshot,
  VirusHazardSnapshot,
  FirewallHazardSnapshot,
  DefragHazardSnapshot
} from '../network/packets.js';

export interface BoundingBox {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
}

export class HazardSystem {
  // 1. Plataforma RAM
  private ramArea: BoundingBox = { minX: -15, maxX: 15, minZ: -5, maxZ: 5 };
  private ramPlayersCount = 0;
  private isRamOverloaded = false;

  // 2. Vírus (Esferas verdes vagando pelo mapa)
  private virusEntities: Array<{
    id: string;
    position: Vector3;
    targetPosition: Vector3;
    speed: number;
    targetPlayerId: string | null;
  }> = [
    {
      id: 'virus_1',
      position: { x: -20, y: 0, z: -20 },
      targetPosition: { x: 20, y: 0, z: -20 },
      speed: 4.0,
      targetPlayerId: null
    },
    {
      id: 'virus_2',
      position: { x: 20, y: 0, z: 20 },
      targetPosition: { x: -20, y: 0, z: 20 },
      speed: 4.5,
      targetPlayerId: null
    }
  ];

  // 3. Firewalls (Barreiras de chamas periódicas)
  private firewalls: Array<{
    id: string;
    position: Vector3;
    width: number;
    isActive: boolean;
    timerMs: number;
    activeDurationMs: number;
    inactiveDurationMs: number;
  }> = [
    {
      id: 'fw_central',
      position: { x: 0, y: 0, z: 0 },
      width: 10,
      isActive: false,
      timerMs: 0,
      activeDurationMs: 3000,
      inactiveDurationMs: 4000
    }
  ];

  // 6. USB Gate (Conector gigante que bloqueia passagem)
  private isUsbPlugged = false;
  private usbCycleTimerMs = 0;
  private readonly USB_INTERVAL_MS = 15000;

  // 7. Área de Manutenção (Área segura com imunidade)
  private maintenanceArea: BoundingBox = { minX: -8, maxX: 8, minZ: -30, maxZ: -20 };

  // 8. Desfragmentação de Disco (Chão que se reorganiza)
  private defragState: 'STABLE' | 'WARNING_BLINK' | 'DEFRAGMENTING' = 'STABLE';
  private defragTimerMs = 0;
  private fallenTiles: string[] = [];

  // Callbacks para eventos disparados aos jogadores
  public onVirusHitPlayer?: (playerId: string, qteSequence: string) => void;
  public onPlayerForceDropCube?: (playerId: string, knockback: Vector3) => void;

  constructor() {}

  public update(
    deltaMs: number,
    players: Map<string, PlayerState>,
    cubes: Map<string, FileCubeEntity>
  ) {
    this.updateMaintenanceImmunity(players);
    this.updateRamPlatform(players);
    this.updateFirewalls(deltaMs, players);
    this.updateUsbGate(deltaMs);
    this.updateViruses(deltaMs, players);
    this.updateDefrag(deltaMs);
  }

  /**
   * 7. Área de Manutenção: Jogadores dentro ganham imunidade
   */
  private updateMaintenanceImmunity(players: Map<string, PlayerState>) {
    for (const player of players.values()) {
      const inZone =
        player.position.x >= this.maintenanceArea.minX &&
        player.position.x <= this.maintenanceArea.maxX &&
        player.position.z >= this.maintenanceArea.minZ &&
        player.position.z <= this.maintenanceArea.maxZ;

      player.isImmune = inZone;
    }
  }

  /**
   * 1. Plataforma RAM:
   * Menos de 5 jogadores = aceleração (+40%).
   * 5 ou mais jogadores = sobrecarga e lentidão progressiva (-50%).
   */
  private updateRamPlatform(players: Map<string, PlayerState>) {
    let count = 0;
    const playersOnRam: PlayerState[] = [];

    for (const player of players.values()) {
      const onRam =
        player.position.x >= this.ramArea.minX &&
        player.position.x <= this.ramArea.maxX &&
        player.position.z >= this.ramArea.minZ &&
        player.position.z <= this.ramArea.maxZ;

      if (onRam) {
        count++;
        playersOnRam.push(player);
      } else {
        // Fora da RAM, restaura velocidade padrão (se não estiver com outro debuff)
        if (!player.isVirusStunned && !player.hasStuckPopups) {
          player.speedMultiplier = 1.0;
        }
      }
    }

    this.ramPlayersCount = count;
    this.isRamOverloaded = count >= 5;

    for (const p of playersOnRam) {
      if (this.isRamOverloaded) {
        // Sobrecarga de RAM: lentidão
        p.speedMultiplier = 0.5;
      } else {
        // Aceleração do barramento de alta velocidade
        p.speedMultiplier = 1.4;
      }
    }
  }

  /**
   * 3. Firewall:
   * Chamas ativas empurram o jogador e derrubam o arquivo que ele carrega.
   */
  private updateFirewalls(deltaMs: number, players: Map<string, PlayerState>) {
    for (const fw of this.firewalls) {
      fw.timerMs += deltaMs;
      const targetDuration = fw.isActive ? fw.activeDurationMs : fw.inactiveDurationMs;

      if (fw.timerMs >= targetDuration) {
        fw.timerMs = 0;
        fw.isActive = !fw.isActive;
      }

      // Se ativo, verifica colisão com jogadores
      if (fw.isActive) {
        for (const player of players.values()) {
          if (player.isImmune) continue;

          const distZ = Math.abs(player.position.z - fw.position.z);
          const distX = Math.abs(player.position.x - fw.position.x);

          if (distZ < 1.5 && distX < fw.width / 2) {
            // Knockback e derruba arquivo
            const knockbackZ = player.position.z >= fw.position.z ? 6 : -6;
            player.position.z += knockbackZ * (deltaMs / 1000);

            if (player.carriedCubeId && this.onPlayerForceDropCube) {
              this.onPlayerForceDropCube(player.id, { x: 0, y: 5, z: knockbackZ * 1.5 });
            }
          }
        }
      }
    }
  }

  /**
   * 2. Vírus:
   * Circula pelo mapa. Ao colidir com jogador não imune, trava movimentação e exige minigame.
   */
  private updateViruses(deltaMs: number, players: Map<string, PlayerState>) {
    const deltaSec = deltaMs / 1000;

    for (const virus of this.virusEntities) {
      // Movimentação simples em direção ao alvo
      const dx = virus.targetPosition.x - virus.position.x;
      const dz = virus.targetPosition.z - virus.position.z;
      const dist = Math.hypot(dx, dz);

      if (dist < 1.0) {
        // Chegou ao waypoint, inverte ou escolhe nova rota
        virus.targetPosition.x = (Math.random() - 0.5) * 60;
        virus.targetPosition.z = (Math.random() - 0.5) * 60;
      } else {
        virus.position.x += (dx / dist) * virus.speed * deltaSec;
        virus.position.z += (dz / dist) * virus.speed * deltaSec;
      }

      // Detecção de colisão com jogadores
      for (const player of players.values()) {
        if (player.isImmune || player.isVirusStunned) continue;

        const pDist = Math.hypot(
          player.position.x - virus.position.x,
          player.position.z - virus.position.z
        );

        if (pDist < 1.8) {
          // Infecção pelo vírus
          player.isVirusStunned = true;
          player.speedMultiplier = 0;

          // Se estiver carregando cubo, derruba
          if (player.carriedCubeId && this.onPlayerForceDropCube) {
            this.onPlayerForceDropCube(player.id, { x: (Math.random() - 0.5) * 4, y: 4, z: (Math.random() - 0.5) * 4 });
          }

          // Dispara minigame QTE com sequência de caracteres (ex: "CTRL+ALT+DEL" ou sequência de teclas)
          const qteSequence = this.generateVirusQte();
          if (this.onVirusHitPlayer) {
            this.onVirusHitPlayer(player.id, qteSequence);
          }
        }
      }
    }
  }

  /**
   * 6. USB Conectado: Bloqueio periódico de corredor
   */
  private updateUsbGate(deltaMs: number) {
    this.usbCycleTimerMs += deltaMs;
    if (this.usbCycleTimerMs >= this.USB_INTERVAL_MS) {
      this.usbCycleTimerMs = 0;
      this.isUsbPlugged = !this.isUsbPlugged;
    }
  }

  /**
   * 8. Desfragmentação de Disco: Reorganização dinâmica do piso
   */
  private updateDefrag(deltaMs: number) {
    this.defragTimerMs += deltaMs;

    // Ciclo: 12s estável -> 3s piscando/aviso -> 6s blocos caídos -> repete
    if (this.defragState === 'STABLE' && this.defragTimerMs >= 15000) {
      this.defragState = 'WARNING_BLINK';
      this.defragTimerMs = 0;
      this.fallenTiles = ['tile_sector_A', 'tile_sector_C'];
    } else if (this.defragState === 'WARNING_BLINK' && this.defragTimerMs >= 3000) {
      this.defragState = 'DEFRAGMENTING';
      this.defragTimerMs = 0;
    } else if (this.defragState === 'DEFRAGMENTING' && this.defragTimerMs >= 7000) {
      this.defragState = 'STABLE';
      this.defragTimerMs = 0;
      this.fallenTiles = [];
    }
  }

  private generateVirusQte(): string {
    const chars = 'QWERTYASDFGHZXCV';
    let seq = '';
    for (let i = 0; i < 4; i++) {
      seq += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return seq;
  }

  /**
   * Snapshot de estado serializado para enviar aos clientes via WebSocket
   */
  public getSnapshot(): HazardSnapshot {
    return {
      ram: {
        activePlayersCount: this.ramPlayersCount,
        isOverloaded: this.isRamOverloaded,
        speedMultiplier: this.isRamOverloaded ? 0.5 : 1.4
      },
      viruses: this.virusEntities.map((v) => ({
        id: v.id,
        position: { ...v.position },
        targetPlayerId: v.targetPlayerId
      })),
      firewalls: this.firewalls.map((f) => ({
        id: f.id,
        isActive: f.isActive,
        position: { ...f.position }
      })),
      isUsbBlocked: this.isUsbPlugged,
      defrag: {
        activeSectorIndex: 1,
        status: this.defragState,
        fallenTileIds: [...this.fallenTiles]
      }
    };
  }
}
