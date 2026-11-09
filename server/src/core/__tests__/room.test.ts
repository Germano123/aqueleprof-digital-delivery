import { describe, it, expect } from 'vitest';
import { Room } from '../Room.js';
import { RoomManager } from '../RoomManager.js';
import { DifficultyTier } from '../../domain/types.js';

// Mock simples de WebSocket para testes
class MockWebSocket {
  public readyState = 1; // WebSocket.OPEN
  public sentMessages: string[] = [];

  public send(msg: string) {
    this.sentMessages.push(msg);
  }
}

describe('Room & Multiplayer Lifecycle (GDD Seções 4, 5, 11 e 15)', () => {
  it('deve criar uma sala com PIN único e configurações padrão de até 20 jogadores', () => {
    const manager = new RoomManager();
    const room = manager.createRoom({ difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION });

    expect(room.pin).toBeDefined();
    expect(room.pin.length).toBe(6);
    expect(room.config.maxPlayers).toBe(20);
    expect(room.config.durationSeconds).toBe(480);
    expect(manager.getRoomByPin(room.pin)).toBe(room);
  });

  it('deve adicionar jogadores até o limite de 20 e atribuir Host ao primeiro', () => {
    const room = new Room('test_room', 'PIN123', { maxPlayers: 20 });
    const ws1 = new MockWebSocket() as any;
    const ws2 = new MockWebSocket() as any;

    const p1 = room.addPlayer(ws1, 'Aluno Alpha');
    const p2 = room.addPlayer(ws2, 'Aluno Beta');

    expect(p1?.isHost).toBe(true);
    expect(p2?.isHost).toBe(false);
    expect(room.getPlayerCount()).toBe(2);

    // Testar limite
    const smallRoom = new Room('small', 'PIN999', { maxPlayers: 2 });
    smallRoom.addPlayer(new MockWebSocket() as any, 'P1');
    smallRoom.addPlayer(new MockWebSocket() as any, 'P2');
    const rejected = smallRoom.addPlayer(new MockWebSocket() as any, 'P3');
    expect(rejected).toBeNull();
  });

  it('deve gerenciar pegada de cubo, entrega correta e pontuação', () => {
    const room = new Room('room_game', 'GAME01');
    const ws = new MockWebSocket() as any;
    const player = room.addPlayer(ws, 'Jogador Pro')!;

    // Inicia jogo
    room.state = 'IN_GAME';

    // Pega requisição disponível e spawna o cubo
    const req = room['requestSystem'].getAvailableRequests()[0];
    const cube = room['fileCubeSystem'].spawnCube(req.targetFile);

    // Posiciona jogador próximo ao cubo para pegar
    player.position = { ...cube.position };

    // Jogador pega o cubo
    room.handlePacket(player.id, {
      type: 'C2S_GRAB_CUBE',
      cubeId: cube.id
    });
    expect(player.carriedCubeId).toBe(cube.id);

    // Jogador entrega no software correto
    const correctSoftware = cube.fileData.recommendedSoftwareId;
    room.handlePacket(player.id, {
      type: 'C2S_SUBMIT_DELIVERY',
      softwareStationId: correctSoftware,
      cubeId: cube.id
    });

    // Score deve ter aumentado e streak incrementado
    expect(player.score).toBeGreaterThan(0);
    expect(player.correctDeliveries).toBe(1);
    expect(player.carriedCubeId).toBeNull();

    // Telemetria deve ter registrado o acerto
    const telemetry = room.getTelemetry().getLogs();
    expect(telemetry.length).toBe(1);
    expect(telemetry[0].isSuccess).toBe(true);
  });

  it('deve penalizar e resetar streak se entregar no software incorreto', () => {
    const room = new Room('room_err', 'ERR01');
    const ws = new MockWebSocket() as any;
    const player = room.addPlayer(ws, 'Aluno Desatento')!;
    player.score = 200;
    player.streak = 3;
    room.state = 'IN_GAME';

    const req = room['requestSystem'].getAvailableRequests()[0];
    const cube = room['fileCubeSystem'].spawnCube(req.targetFile);

    player.position = { ...cube.position };
    // Jogador pega o cubo
    room.handlePacket(player.id, { type: 'C2S_GRAB_CUBE', cubeId: cube.id });

    // Entrega em software propositalmente incorreto
    const wrongSoftware = cube.fileData.recommendedSoftwareId === 'video_player' ? 'text_editor' : 'video_player';
    room.handlePacket(player.id, {
      type: 'C2S_SUBMIT_DELIVERY',
      softwareStationId: wrongSoftware,
      cubeId: cube.id
    });

    expect(player.score).toBeLessThan(200);
    expect(player.streak).toBe(0);
    expect(player.failedDeliveries).toBe(1);
    expect(player.carriedCubeId).toBeNull(); // Cubo foi ejetado/derrubado
  });

  it('deve simular sobrecarga de RAM com 5 ou mais jogadores (GDD Seção 11)', () => {
    const room = new Room('ram_room', 'RAM123');
    room.state = 'IN_GAME';

    // Adiciona 5 jogadores na área de RAM (área entre x -15 e 15, z -5 e 5)
    const players = [];
    for (let i = 0; i < 5; i++) {
      const ws = new MockWebSocket() as any;
      const p = room.addPlayer(ws, `Player_${i}`)!;
      p.position = { x: 0, y: 0, z: 0 }; // Dentro da RAM
      players.push(p);
    }

    // Executa tick do jogo
    room['tick']();

    // Com 5 jogadores simultâneos na RAM: Sobrecarga e lentidão (0.5x)
    for (const p of players) {
      expect(p.speedMultiplier).toBe(0.5);
    }

    const hazardSnapshot = room['hazardSystem'].getSnapshot();
    expect(hazardSnapshot.ram.isOverloaded).toBe(true);
    expect(hazardSnapshot.ram.activePlayersCount).toBe(5);
  });

  it('deve inicializar 3 salas padrão (casual, border, challenge) e permitir busca por slug ou PIN', () => {
    const manager = new RoomManager();
    const rooms = manager.getPublicRoomsSummary();
    expect(rooms.length).toBe(3);
    const slugs = rooms.map(r => r.slug).sort();
    expect(slugs).toEqual(['border', 'casual', 'challenge']);

    const casualRoom = manager.getRoomByPinOrName('casual');
    expect(casualRoom).toBeDefined();
    expect(casualRoom?.name).toBe('casual');

    const borderRoom = manager.getRoomByPinOrName('BORDER');
    expect(borderRoom).toBeDefined();
    expect(borderRoom?.name).toBe('border');

    // Testar busca por PIN
    if (casualRoom) {
      expect(manager.getRoomByPinOrName(casualRoom.pin)).toBe(casualRoom);
    }
  });

  it('deve permitir apenas ao ADM (host) iniciar o túnel/jogo e rejeitar jogadores comuns', () => {
    const room = new Room('tunnel_room', 'TUN001', { name: 'casual' });
    const ws1 = new MockWebSocket() as any;
    const ws2 = new MockWebSocket() as any;

    const host = room.addPlayer(ws1, 'AdmHost')!;
    const guest = room.addPlayer(ws2, 'GuestPlayer')!;

    expect(host.isHost).toBe(true);
    expect(guest.isHost).toBe(false);
    expect(room.state).toBe('LOBBY');

    // Guest tenta iniciar o túnel
    room.handlePacket(guest.id, { type: 'C2S_START_TUNNEL' });
    expect(room.state).toBe('LOBBY');
    expect(ws2.sentMessages.some((m: string) => m.includes('Administrador (ADM)'))).toBe(true);

    // Host inicia o túnel
    room.handlePacket(host.id, { type: 'C2S_START_TUNNEL' });
    expect(room.state).toBe('IN_GAME');
  });

  it('deve repor a sala padrão quando a partida chegar em GAME_OVER', () => {
    const manager = new RoomManager();
    const originalCasual = manager.getRoomByPinOrName('casual')!;
    expect(originalCasual).toBeDefined();

    // Finaliza a sala original
    originalCasual.endGame('TIME_EXPIRED');
    expect(originalCasual.state).toBe('GAME_OVER');

    // As salas públicas ainda devem conter 3 salas ativas (com uma nova sala casual)
    const activeRooms = manager.getPublicRoomsSummary();
    expect(activeRooms.length).toBe(3);
    const newCasual = manager.getRoomByPinOrName('casual');
    expect(newCasual).toBeDefined();
    expect(newCasual?.id).not.toBe(originalCasual.id);
  });
});

