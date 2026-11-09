/**
 * DIGITAL DELIVERY - Entry Point do Servidor Backend
 * Servidor HTTP REST + WebSocket Server para multiplayer de 20 jogadores em rede local (LAN)
 */

import http from 'node:http';
import os from 'node:os';
import { WebSocketServer, WebSocket } from 'ws';
import { RoomManager } from './core/RoomManager.js';
import { AuthManager } from './auth/AuthManager.js';
import { ClientPacket } from './network/packets.js';
import { CATEGORY_VISUALS, SOFTWARE_STATIONS, FILE_CATALOG } from './domain/extensions.js';

const PORT = parseInt(process.env.PORT || '3001', 10);
const HOST = process.env.HOST || '0.0.0.0';

const roomManager = new RoomManager();
const authManager = new AuthManager();

// Mapeamento de conexões ativas: ws -> { roomId, playerId }
const clientSessions = new Map<WebSocket, { roomId: string; playerId: string }>();

// Criação do servidor HTTP para APIs auxiliares e painel do professor
const server = http.createServer((req, res) => {
  // CORS Headers para suportar chamadas de navegadores ou clientes externos
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url || '/', `http://${req.headers.host}`);

  // Health check
  if (req.method === 'GET' && url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      activeRooms: roomManager.getAllRooms().length,
      registeredUsers: authManager.getAllUsersCount()
    }));
    return;
  }

  // Autenticação: Cadastro de nova conta
  if (req.method === 'POST' && url.pathname === '/api/auth/register') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        const { username, password } = JSON.parse(body);
        const result = authManager.register(username, password);
        res.writeHead(result.success ? 201 : 400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: 'Payload JSON inválido.' }));
      }
    });
    return;
  }

  // Autenticação: Login de operador
  if (req.method === 'POST' && url.pathname === '/api/auth/login') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        const { username, password } = JSON.parse(body);
        const result = authManager.login(username, password);
        res.writeHead(result.success ? 200 : 401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: 'Payload JSON inválido.' }));
      }
    });
    return;
  }

  // Listagem pública de salas (usada pelo comando 'scan' do terminal)
  if (req.method === 'GET' && url.pathname === '/api/rooms') {
    const rooms = roomManager.getPublicRoomsSummary();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ rooms }));
    return;
  }

  // Base didática: estações de softwares
  if (req.method === 'GET' && url.pathname === '/api/stations') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(SOFTWARE_STATIONS));
    return;
  }

  // Base didática: cores e extensões
  if (req.method === 'GET' && url.pathname === '/api/catalog') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ visuals: CATEGORY_VISUALS, catalog: FILE_CATALOG }));
    return;
  }

  // Criação de sala via HTTP REST (para o professor / comando host)
  if (req.method === 'POST' && url.pathname === '/api/rooms') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const room = roomManager.createRoom(parsed);
        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ pin: room.pin, id: room.id, config: room.config }));
      } catch (err: any) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // Relatório pedagógico do professor
  if (req.method === 'GET' && url.pathname.startsWith('/api/rooms/') && url.pathname.endsWith('/summary')) {
    const parts = url.pathname.split('/');
    const pin = parts[3];
    const room = roomManager.getRoomByPin(pin);

    if (!room) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Sala não encontrada' }));
      return;
    }

    const summary = room.getTelemetry().generateDidacticSummary();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ pin, state: room.state, summary, logs: room.getTelemetry().getLogs() }));
    return;
  }

  // Rota não encontrada
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Endpoint não encontrado' }));
});

// Servidor WebSocket integrado
const wss = new WebSocketServer({ server });

wss.on('connection', (ws: WebSocket) => {
  ws.on('message', (message: string) => {
    try {
      const packet: ClientPacket = JSON.parse(message.toString());

      if (packet.type === 'C2S_JOIN_ROOM') {
        const room = roomManager.getRoomByPinOrName(packet.pin);
        if (!room) {
          ws.send(JSON.stringify({ type: 'S2C_ERROR', message: `Sala ou modalidade '${packet.pin}' não encontrada.` }));
          return;
        }

        const playerState = room.addPlayer(ws, packet.username, packet.teamId);
        if (playerState) {
          clientSessions.set(ws, { roomId: room.id, playerId: playerState.id });
        }
        return;
      }

      // Demais pacotes requerem sessão ativa na sala
      const session = clientSessions.get(ws);
      if (!session) {
        ws.send(JSON.stringify({ type: 'S2C_ERROR', message: 'Você precisa entrar em uma sala primeiro.' }));
        return;
      }

      const room = roomManager.getRoomById(session.roomId);
      if (room) {
        room.handlePacket(session.playerId, packet);
      }
    } catch {
      ws.send(JSON.stringify({ type: 'S2C_ERROR', message: 'Formato de pacote inválido.' }));
    }
  });

  ws.on('close', () => {
    const session = clientSessions.get(ws);
    if (session) {
      const room = roomManager.getRoomById(session.roomId);
      if (room) {
        room.removePlayer(session.playerId);
      }
      clientSessions.delete(ws);
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`[DIGITAL DELIVERY SERVER] Ativo em ${HOST}:${PORT}`);
  console.log(`[LOCAL ACCESS] http://localhost:${PORT}/health`);
  console.log(`[WEBSOCKET] ws://localhost:${PORT}`);

  // Exibe endereços IP na rede local (LAN) para conexões de outros computadores
  const nets = os.networkInterfaces();
  console.log('[LAN ACCESS] Conexão via rede local (outros computadores):');
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(`  -> IP: http://${net.address}:${PORT} (ws://${net.address}:${PORT})`);
      }
    }
  }
});
