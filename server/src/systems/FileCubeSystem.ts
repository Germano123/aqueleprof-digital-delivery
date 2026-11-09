/**
 * DIGITAL DELIVERY - Sistema de Cubos Físicos de Arquivos
 * Ref: Seção 7 e 11 do GDD.md
 */

import {
  Vector3,
  FileCubeEntity,
  FileDefinition,
  PlayerState
} from '../domain/types.js';
import { CATEGORY_VISUALS } from '../domain/extensions.js';
import { CubeSnapshot } from '../network/packets.js';

export class FileCubeSystem {
  private cubes: Map<string, FileCubeEntity> = new Map();
  private readonly GRAVITY = -18.0;
  private readonly FLOOR_Y = 0.0;
  private readonly BOUNCE_RESTITUTION = 0.55;
  private readonly FRICTION = 0.85;

  constructor() {}

  /**
   * Spawna um novo cubo de arquivo na área de requisições
   */
  public spawnCube(fileData: FileDefinition, spawnAreaCenter: Vector3 = { x: 0, y: 12.0, z: -4.5 }): FileCubeEntity {
    const id = `cube_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    // Dispersão na área de queda diretamente em frente ao jogador (Z entre -2.5 e -6.5)
    const offsetX = (Math.random() - 0.5) * 8;
    const offsetZ = (Math.random() - 0.5) * 4;

    const cube: FileCubeEntity = {
      id,
      fileData,
      position: {
        x: spawnAreaCenter.x + offsetX,
        y: 12.0, // Cai fisicamente do alto (Y = 12m)
        z: spawnAreaCenter.z + offsetZ
      },
      velocity: {
        x: (Math.random() - 0.5) * 1.0,
        y: -3.5, // Impulso de queda para quicar na placa-mãe
        z: (Math.random() - 0.5) * 1.0
      },
      carrierPlayerId: null,
      state: 'SPAWNED',
      createdAtMs: Date.now()
    };

    this.cubes.set(id, cube);
    return cube;
  }

  public getCube(id: string): FileCubeEntity | undefined {
    return this.cubes.get(id);
  }

  public getAllCubes(): Map<string, FileCubeEntity> {
    return this.cubes;
  }

  /**
   * Jogador tenta pegar o cubo no chão
   */
  public grabCube(playerId: string, cubeId: string, playerPos: Vector3): boolean {
    const cube = this.cubes.get(cubeId);
    if (!cube) return false;

    // Não pode pegar se já estiver com outro jogador
    if (cube.carrierPlayerId !== null && cube.carrierPlayerId !== playerId) {
      return false;
    }

    // Checagem de distância máxima para pegar (2.5 unidades)
    const dist = Math.hypot(cube.position.x - playerPos.x, cube.position.z - playerPos.z);
    if (dist > 3.0) {
      return false;
    }

    cube.carrierPlayerId = playerId;
    cube.state = 'CARRIED';
    cube.velocity = { x: 0, y: 0, z: 0 };
    return true;
  }

  /**
   * Jogador solta voluntariamente o cubo
   */
  public dropCube(playerId: string, impulse?: Vector3): FileCubeEntity | null {
    for (const cube of this.cubes.values()) {
      if (cube.carrierPlayerId === playerId) {
        cube.carrierPlayerId = null;
        cube.state = 'DROPPED_BOUNCING';
        cube.velocity = impulse ? { ...impulse } : { x: 0, y: 1.5, z: 0 };
        return cube;
      }
    }
    return null;
  }

  /**
   * Jogador sofre colisão forte / obstáculo e derruba o cubo com impulso
   */
  public forceDrop(playerId: string, knockbackImpulse: Vector3): FileCubeEntity | null {
    for (const cube of this.cubes.values()) {
      if (cube.carrierPlayerId === playerId) {
        cube.carrierPlayerId = null;
        cube.state = 'DROPPED_BOUNCING';
        cube.velocity = {
          x: knockbackImpulse.x,
          y: Math.max(knockbackImpulse.y, 3.5),
          z: knockbackImpulse.z
        };
        return cube;
      }
    }
    return null;
  }

  /**
   * Remove cubo do jogo (após entrega concluída no software)
   */
  public removeCube(cubeId: string): boolean {
    return this.cubes.delete(cubeId);
  }

  /**
   * Atualiza física dos cubos e posições dos cubos carregados
   */
  public update(deltaMs: number, players: Map<string, PlayerState>) {
    const deltaSec = deltaMs / 1000;

    for (const cube of this.cubes.values()) {
      if (cube.state === 'CARRIED' && cube.carrierPlayerId) {
        const carrier = players.get(cube.carrierPlayerId);
        if (carrier) {
          // Cubo segue as mãos do jogador (ligeiramente elevado e à frente)
          cube.position.x = carrier.position.x;
          cube.position.y = carrier.position.y + 1.2;
          cube.position.z = carrier.position.z + 0.8;
          cube.velocity = { x: 0, y: 0, z: 0 };
        } else {
          // Jogador desconectou
          cube.carrierPlayerId = null;
          cube.state = 'DROPPED_BOUNCING';
          cube.velocity.y = 1.0;
        }
      } else {
        // Física de quique no chão
        cube.velocity.y += this.GRAVITY * deltaSec;

        cube.position.x += cube.velocity.x * deltaSec;
        cube.position.y += cube.velocity.y * deltaSec;
        cube.position.z += cube.velocity.z * deltaSec;

        // Colisão com piso
        if (cube.position.y <= this.FLOOR_Y) {
          cube.position.y = this.FLOOR_Y;
          if (Math.abs(cube.velocity.y) > 0.8) {
            cube.velocity.y = -cube.velocity.y * this.BOUNCE_RESTITUTION;
          } else {
            cube.velocity.y = 0;
          }

          // Atrito no chão
          cube.velocity.x *= this.FRICTION;
          cube.velocity.z *= this.FRICTION;

          if (Math.abs(cube.velocity.x) < 0.05) cube.velocity.x = 0;
          if (Math.abs(cube.velocity.z) < 0.05) cube.velocity.z = 0;
        }
      }
    }
  }

  /**
   * Converte para snapshot serializado para os clientes via WebSocket
   * GDD Seção 7: Cubo é cinza no chão e ganha cor oficial da categoria somente em mãos!
   */
  public getSnapshots(): CubeSnapshot[] {
    const snapshots: CubeSnapshot[] = [];

    for (const cube of this.cubes.values()) {
      const categoryColor = CATEGORY_VISUALS[cube.fileData.category]?.hex || '#FFFFFF';
      // GDD: no chão fica cinza (#888888), em mãos brilha com a cor da categoria!
      const effectiveColorHex = cube.carrierPlayerId ? categoryColor : '#7F8C8D';

      snapshots.push({
        id: cube.id,
        fileName: cube.fileData.sampleFileName || cube.fileData.name,
        extension: cube.fileData.extension,
        category: cube.fileData.category,
        colorHex: effectiveColorHex,
        carrierPlayerId: cube.carrierPlayerId,
        position: { ...cube.position },
        state: cube.state
      });
    }

    return snapshots;
  }
}
