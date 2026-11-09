/**
 * DIGITAL DELIVERY - Gerenciador de Sala e Loop de Jogo Multiplayer
 * Ref: Seções 4, 5, 10, 11 e 15 do GDD.md
 */

import { WebSocket } from 'ws';
import {
  DifficultyTier,
  PlayerState,
  RoomConfig,
  RoomState,
  TeamId,
  Vector3
} from '../domain/types.js';
import { validateDeliveryTarget } from '../domain/extensions.js';
import { calculateDeliveryScore } from '../domain/scoring.js';
import { RequestSystem } from '../systems/RequestSystem.js';
import { FileCubeSystem } from '../systems/FileCubeSystem.js';
import { HazardSystem } from '../systems/HazardSystem.js';
import { TelemetryTracker } from '../telemetry/TelemetryTracker.js';
import {
  ClientPacket,
  ServerPacket,
  PlayerSnapshot,
  PlayerRanking
} from '../network/packets.js';

interface ConnectedPlayer {
  state: PlayerState;
  ws: WebSocket;
}

export class Room {
  public readonly id: string;
  public readonly pin: string;
  public readonly name: string;
  public config: RoomConfig;
  public state: RoomState = 'LOBBY';
  public onGameOver?: (room: Room) => void;

  private players: Map<string, ConnectedPlayer> = new Map();
  private requestSystem: RequestSystem;
  private fileCubeSystem: FileCubeSystem;
  private hazardSystem: HazardSystem;
  private telemetryTracker: TelemetryTracker;

  private tickInterval: NodeJS.Timeout | null = null;
  private matchTimeRemainingMs: number = 480_000; // 8 minutos (GDD Seção 5 e 15)
  private readonly TICK_RATE_HZ = 20; // 20 atualizações por segundo (50ms)
  private readonly TICK_DELTA_MS = 1000 / 20;

  constructor(id: string, pin: string, initialConfig?: Partial<RoomConfig>) {
    this.id = id;
    this.pin = pin;
    this.name = initialConfig?.name || initialConfig?.slug || 'casual';

    this.config = {
      id,
      pin,
      name: this.name,
      slug: this.name,
      maxPlayers: initialConfig?.maxPlayers ?? 20, // GDD Seção 4: Até 20 jogadores
      isTeamMode: initialConfig?.isTeamMode ?? false,
      difficultyTier: initialConfig?.difficultyTier ?? DifficultyTier.TIER_1_IDENTIFICATION,
      durationSeconds: initialConfig?.durationSeconds ?? 480, // 8 minutos
      hazardsEnabled: initialConfig?.hazardsEnabled ?? true
    };

    this.requestSystem = new RequestSystem(this.config.difficultyTier);
    this.fileCubeSystem = new FileCubeSystem();
    this.hazardSystem = new HazardSystem();
    this.telemetryTracker = new TelemetryTracker();

    this.setupHazardCallbacks();
  }

  private setupHazardCallbacks() {
    // Vírus atinge jogador: dispara sequência QTE
    this.hazardSystem.onVirusHitPlayer = (playerId, qteSequence) => {
      this.sendToPlayer(playerId, {
        type: 'S2C_VIRUS_TRIGGERED',
        playerId,
        sequenceToType: qteSequence
      });
    };

    // Obstáculo ou colisão derruba o arquivo carregado
    this.hazardSystem.onPlayerForceDropCube = (playerId, knockback) => {
      const droppedCube = this.fileCubeSystem.forceDrop(playerId, knockback);
      const player = this.players.get(playerId);
      if (player && droppedCube) {
        player.state.carriedCubeId = null;
      }
    };
  }

  /**
   * Adiciona novo jogador à sala
   */
  public addPlayer(ws: WebSocket, username: string, teamId?: TeamId): PlayerState | null {
    if (this.players.size >= this.config.maxPlayers) {
      this.sendPacket(ws, { type: 'S2C_ERROR', message: 'A sala atingiu o limite de 20 jogadores.' });
      return null;
    }

    if (this.state === 'GAME_OVER') {
      this.sendPacket(ws, { type: 'S2C_ERROR', message: 'Esta partida já foi finalizada.' });
      return null;
    }

    const playerId = `p_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const isFirstPlayer = this.players.size === 0;

    // Cores de jogadores para modo individual
    const playerColors = ['#E74C3C', '#3498DB', '#2ECC71', '#F1C40F', '#9B59B6', '#E67E22', '#1ABC9C'];
    const assignedColor = playerColors[this.players.size % playerColors.length];

    const playerState: PlayerState = {
      id: playerId,
      username: username || `Aluno_${this.players.size + 1}`,
      teamId: this.config.isTeamMode ? teamId || 'RED' : undefined,
      color: assignedColor,
      isHost: isFirstPlayer,
      score: 0,
      correctDeliveries: 0,
      failedDeliveries: 0,
      streak: 0,
      carriedCubeId: null,
      position: { x: (Math.random() - 0.5) * 10, y: 0, z: -15 },
      isImmune: false,
      isVirusStunned: false,
      hasStuckPopups: false,
      speedMultiplier: 1.0,
      connected: true
    };

    this.players.set(playerId, { state: playerState, ws });

    // Notifica o jogador que entrou com o estado completo da sala
    this.sendPacket(ws, {
      type: 'S2C_ROOM_JOINED',
      player: playerState,
      config: this.config,
      roomName: this.name,
      players: Array.from(this.players.values()).map((p) => p.state)
    });

    // Transmite para todos os outros jogadores que alguém entrou
    this.broadcast(
      { type: 'S2C_PLAYER_JOINED', player: playerState },
      playerId // exclui o próprio
    );

    return playerState;
  }

  /**
   * Remove jogador da sala
   */
  public removePlayer(playerId: string) {
    const player = this.players.get(playerId);
    if (!player) return;

    // Solta cubo se estava carregando
    if (player.state.carriedCubeId) {
      this.fileCubeSystem.dropCube(playerId);
    }

    // Libera requisição ativa de volta ao pool
    if (player.state.activeRequestId) {
      this.requestSystem.releaseRequest(player.state.activeRequestId);
    }

    const wasHost = player.state.isHost;
    this.players.delete(playerId);
    this.broadcast({ type: 'S2C_PLAYER_LEFT', playerId });

    // Se o ADM saiu e ainda há jogadores na sala, transfere a administração para o próximo
    if (wasHost && this.players.size > 0) {
      const nextPlayer = this.players.values().next().value;
      if (nextPlayer) {
        nextPlayer.state.isHost = true;
        this.sendPacket(nextPlayer.ws, {
          type: 'S2C_ROOM_JOINED',
          player: nextPlayer.state,
          config: this.config,
          roomName: this.name,
          players: Array.from(this.players.values()).map((p) => p.state)
        });
      }
    }

    // Se a sala esvaziar, encerra o loop e finaliza partida se estava em andamento
    if (this.players.size === 0) {
      this.stopLoop();
      if (this.state === 'IN_GAME') {
        this.endGame('TIME_EXPIRED');
      }
    }
  }

  /**
   * Host atualiza parâmetros da sala
   */
  public updateConfig(hostPlayerId: string, newConfig: Partial<RoomConfig>) {
    const host = this.players.get(hostPlayerId);
    if (!host || !host.state.isHost) return;

    if (newConfig.difficultyTier) {
      this.config.difficultyTier = newConfig.difficultyTier;
      this.requestSystem.setDifficultyTier(newConfig.difficultyTier);
    }
    if (newConfig.isTeamMode !== undefined) this.config.isTeamMode = newConfig.isTeamMode;
    if (newConfig.durationSeconds !== undefined) {
      this.config.durationSeconds = newConfig.durationSeconds;
      this.matchTimeRemainingMs = newConfig.durationSeconds * 1000;
    }
    if (newConfig.hazardsEnabled !== undefined) this.config.hazardsEnabled = newConfig.hazardsEnabled;
  }

  /**
   * Inicia a partida (autoritativo)
   */
  public startGame(hostPlayerId?: string): boolean {
    if (hostPlayerId) {
      const host = this.players.get(hostPlayerId);
      if (!host || !host.state.isHost) return false;
    }
    if (this.state !== 'LOBBY') return false;

    this.state = 'IN_GAME';
    this.matchTimeRemainingMs = this.config.durationSeconds * 1000;

    // Popula requisições iniciais e spawna cubos correspondentes
    this.requestSystem.replenishRequests();
    for (const req of this.requestSystem.getAvailableRequests()) {
      this.fileCubeSystem.spawnCube(req.targetFile);
    }

    this.broadcast({
      type: 'S2C_ROOM_STATE_CHANGE',
      state: 'IN_GAME',
      matchTimeRemainingMs: this.matchTimeRemainingMs
    });
    this.broadcast({
      type: 'S2C_REQUEST_POOL_UPDATE',
      requests: this.requestSystem.getAvailableRequests()
    });

    this.startLoop();
    return true;
  }

  /**
   * Processamento de pacotes do cliente
   */
  public handlePacket(playerId: string, packet: ClientPacket) {
    const player = this.players.get(playerId);
    if (!player) return;

    switch (packet.type) {
      case 'C2S_UPDATE_CONFIG':
        this.updateConfig(playerId, packet.config);
        break;

      case 'C2S_START_GAME':
      case 'C2S_START_TUNNEL':
        if (!player.state.isHost) {
          this.sendPacket(player.ws, {
            type: 'S2C_ERROR',
            message: 'Apenas o Administrador (ADM) da sala pode iniciar o túnel com "start tunnel".'
          });
          return;
        }
        this.startGame(playerId);
        break;

      case 'C2S_PLAYER_INPUT':
        // Atualiza posição do jogador
        if (!player.state.isVirusStunned) {
          player.state.position = packet.position;
        }
        break;

      case 'C2S_CLAIM_REQUEST': {
        const req = this.requestSystem.claimRequest(packet.requestId, playerId);
        if (req) {
          player.state.activeRequestId = req.id;
          this.broadcast({
            type: 'S2C_REQUEST_POOL_UPDATE',
            requests: this.requestSystem.getAvailableRequests()
          });
        }
        break;
      }

      case 'C2S_GRAB_CUBE': {
        const success = this.fileCubeSystem.grabCube(playerId, packet.cubeId, player.state.position);
        if (success) {
          player.state.carriedCubeId = packet.cubeId;
        }
        break;
      }

      case 'C2S_DROP_CUBE': {
        const dropped = this.fileCubeSystem.dropCube(playerId, packet.impulse);
        if (dropped) {
          player.state.carriedCubeId = null;
        }
        break;
      }

      case 'C2S_SUBMIT_DELIVERY': {
        this.processDelivery(playerId, packet.softwareStationId, packet.cubeId);
        break;
      }

      case 'C2S_RESOLVE_VIRUS_QTE': {
        if (packet.success) {
          player.state.isVirusStunned = false;
          player.state.speedMultiplier = 1.0;
        }
        break;
      }

      case 'C2S_RESOLVE_POPUP': {
        player.state.hasStuckPopups = false;
        break;
      }
    }
  }

  /**
   * Processamento e avaliação didática de entrega de arquivo
   */
  private processDelivery(playerId: string, softwareStationId: string, cubeId: string) {
    const player = this.players.get(playerId);
    if (!player) return;

    const cube = this.fileCubeSystem.getCube(cubeId);
    if (!cube) return;

    // Validação didática
    const validation = validateDeliveryTarget(cube.fileData.extension, softwareStationId);
    const activeReq = player.state.activeRequestId
      ? this.requestSystem.getRequest(player.state.activeRequestId)
      : undefined;

    const timeSpentMs = activeReq ? Date.now() - activeReq.spawnTimeMs : 10000;
    const timeLimitMs = activeReq?.timeLimitMs || 45000;

    const scoreResult = calculateDeliveryScore({
      isCorrect: validation.isValid,
      timeSpentMs,
      timeLimitMs,
      currentStreak: player.state.streak,
      difficultyTier: this.config.difficultyTier
    });

    // Atualiza pontuação e streak do jogador
    player.state.score = Math.max(0, player.state.score + scoreResult.scoreDelta);
    player.state.streak = scoreResult.newStreak;

    if (validation.isValid) {
      player.state.correctDeliveries++;
    } else {
      player.state.failedDeliveries++;
    }

    // Registra telemetria pedagógica
    const telemetryLog = {
      timestamp: Date.now(),
      playerId,
      playerName: player.state.username,
      requestId: activeReq?.id || 'none',
      requestedExtension: cube.fileData.extension,
      fileCategory: cube.fileData.category,
      deliveredToSoftwareId: softwareStationId,
      correctSoftwareId: cube.fileData.recommendedSoftwareId,
      isSuccess: validation.isValid,
      pointsEarned: scoreResult.scoreDelta,
      timeSpentMs,
      errorMessage: validation.reason
    };
    this.telemetryTracker.recordDelivery(telemetryLog);

    // Resolução do cubo e da requisição
    if (validation.isValid) {
      // Sucesso: remove o cubo entregue e completa requisição
      this.fileCubeSystem.removeCube(cubeId);
      player.state.carriedCubeId = null;

      if (activeReq) {
        this.requestSystem.completeRequest(activeReq.id, 'DELIVERED');
        player.state.activeRequestId = undefined;
      }

      // Spawna um novo cubo para o pool recarregado
      const available = this.requestSystem.getAvailableRequests();
      if (available.length > 0) {
        const nextReq = available[available.length - 1];
        this.fileCubeSystem.spawnCube(nextReq.targetFile);
      }
    } else {
      // Erro: Ejeta o cubo do software para longe com repulsão
      this.fileCubeSystem.forceDrop(playerId, {
        x: (Math.random() - 0.5) * 8,
        y: 6.0,
        z: (Math.random() - 0.5) * 8
      });
      player.state.carriedCubeId = null;
    }

    // Notifica todos da avaliação de entrega
    this.broadcast({
      type: 'S2C_DELIVERY_EVALUATED',
      playerId,
      requestId: activeReq?.id || '',
      result: scoreResult,
      telemetry: telemetryLog
    });

    this.broadcast({
      type: 'S2C_REQUEST_POOL_UPDATE',
      requests: this.requestSystem.getAvailableRequests()
    });
  }

  private processSpawnCooldownMs: number = 0;

  public getTargetActiveProcesses(): number {
    const playerCount = Math.max(1, this.players.size);
    return Math.max(3, Math.ceil(playerCount * 2));
  }

  public getMaxProcessesCapacity(): number {
    const target = this.getTargetActiveProcesses();
    return Math.max(12, target * 3);
  }

  /**
   * Inicia o loop autoritativo de 20 Hz (50ms)
   */
  private startLoop() {
    this.stopLoop();
    this.processSpawnCooldownMs = 3000;

    this.tickInterval = setInterval(() => {
      this.tick();
    }, this.TICK_DELTA_MS);
    if (this.tickInterval && typeof (this.tickInterval as any).unref === 'function') {
      (this.tickInterval as any).unref();
    }
  }

  private stopLoop() {
    if (this.tickInterval) {
      clearInterval(this.tickInterval);
      this.tickInterval = null;
    }
  }

  /**
   * Tick de jogo autoritativo
   */
  private tick() {
    if (this.state !== 'IN_GAME') return;

    this.matchTimeRemainingMs -= this.TICK_DELTA_MS;

    // Condição de fim de partida (8 minutos de acordo com GDD Seção 5 e 15)
    if (this.matchTimeRemainingMs <= 0) {
      this.matchTimeRemainingMs = 0;
      this.endGame('TIME_EXPIRED');
      return;
    }

    const activeCubes = this.fileCubeSystem.getAllCubes().size;
    const maxCapacity = this.getMaxProcessesCapacity();
    const targetProcesses = this.getTargetActiveProcesses();

    // Condição de Crash do Sistema: sobrecarga de processos atingida
    if (activeCubes >= maxCapacity) {
      this.endGame('SYSTEM_CRASH');
      return;
    }

    // Modo Frenesi: novos processos caem continuamente do alto
    this.processSpawnCooldownMs -= this.TICK_DELTA_MS;
    if (activeCubes < targetProcesses || this.processSpawnCooldownMs <= 0) {
      this.processSpawnCooldownMs = 4500;
      const available = this.requestSystem.getAvailableRequests();
      if (available.length > 0) {
        const nextReq = available[Math.floor(Math.random() * available.length)];
        this.fileCubeSystem.spawnCube(nextReq.targetFile);
      }
    }

    const playersMap = new Map(
      Array.from(this.players.entries()).map(([id, p]) => [id, p.state])
    );

    // Atualiza obstáculos caóticos (RAM, vírus, defrag, firewalls)
    if (this.config.hazardsEnabled) {
      this.hazardSystem.update(
        this.TICK_DELTA_MS,
        playersMap,
        this.fileCubeSystem.getAllCubes()
      );
    }

    // Atualiza física e posições dos cubos
    this.fileCubeSystem.update(this.TICK_DELTA_MS, playersMap);

    // Gera snapshots e transmite aos clientes conectados
    this.broadcastSnapshot();
  }

  private broadcastSnapshot() {
    const playerSnapshots: PlayerSnapshot[] = Array.from(this.players.values()).map(
      (p) => ({
        id: p.state.id,
        username: p.state.username,
        teamId: p.state.teamId,
        color: p.state.color,
        score: p.state.score,
        streak: p.state.streak,
        carriedCubeId: p.state.carriedCubeId,
        position: { ...p.state.position },
        velocity: { x: 0, y: 0, z: 0 },
        yaw: 0,
        isImmune: p.state.isImmune,
        isVirusStunned: p.state.isVirusStunned,
        hasStuckPopups: p.state.hasStuckPopups,
        speedMultiplier: p.state.speedMultiplier
      })
    );

    const cubeSnapshots = this.fileCubeSystem.getSnapshots();
    const hazardSnapshot = this.hazardSystem.getSnapshot();
    const activeCubes = this.fileCubeSystem.getAllCubes().size;
    const maxCapacity = this.getMaxProcessesCapacity();

    this.broadcast({
      type: 'S2C_TICK_SNAPSHOT',
      serverTime: Date.now(),
      timeRemainingMs: this.matchTimeRemainingMs,
      players: playerSnapshots,
      cubes: cubeSnapshots,
      hazards: hazardSnapshot,
      processCount: activeCubes,
      maxProcesses: maxCapacity
    });
  }

  /**
   * Finaliza partida e computa ranking e relatório didático
   */
  public endGame(reason: 'TIME_EXPIRED' | 'SYSTEM_CRASH' = 'TIME_EXPIRED') {
    this.state = 'GAME_OVER';
    this.stopLoop();

    // Ordenação do ranking individual
    const sortedPlayers = Array.from(this.players.values())
      .map((p) => p.state)
      .sort((a, b) => b.score - a.score);

    const rankings: PlayerRanking[] = sortedPlayers.map((p, idx) => ({
      rank: idx + 1,
      playerId: p.id,
      username: p.username,
      teamId: p.teamId,
      score: p.score,
      correctDeliveries: p.correctDeliveries,
      failedDeliveries: p.failedDeliveries
    }));

    // Ranking por equipe (se aplicável)
    const teamRankings: Record<TeamId, number> = {
      RED: 0,
      BLUE: 0,
      YELLOW: 0,
      GREEN: 0
    };

    if (this.config.isTeamMode) {
      for (const p of sortedPlayers) {
        if (p.teamId) {
          teamRankings[p.teamId] += p.score;
        }
      }
    }

    const didacticSummary = this.telemetryTracker.generateDidacticSummary();

    this.broadcast({
      type: 'S2C_GAME_OVER',
      rankings,
      teamRankings: this.config.isTeamMode ? teamRankings : undefined,
      didacticSummary,
      reason
    });

    if (this.onGameOver) {
      this.onGameOver(this);
    }
  }

  public broadcast(packet: ServerPacket, excludePlayerId?: string) {
    const raw = JSON.stringify(packet);
    for (const [id, p] of this.players.entries()) {
      if (id !== excludePlayerId && p.ws.readyState === WebSocket.OPEN) {
        p.ws.send(raw);
      }
    }
  }

  public sendToPlayer(playerId: string, packet: ServerPacket) {
    const p = this.players.get(playerId);
    if (p && p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(JSON.stringify(packet));
    }
  }

  private sendPacket(ws: WebSocket, packet: ServerPacket) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(packet));
    }
  }

  public getPlayerCount(): number {
    return this.players.size;
  }

  public getTelemetry(): TelemetryTracker {
    return this.telemetryTracker;
  }
}
