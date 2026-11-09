/**
 * DIGITAL DELIVERY - Sistema de Gerenciamento do Pool de Requisições
 * Ref: Seções 5, 8, 9 e 15 do GDD.md
 */

import {
  DifficultyTier,
  DeliveryRequest,
  FileDefinition
} from '../domain/types.js';
import { generateDeliveryRequest } from '../domain/requests.js';
import { getFilesForDifficulty } from '../domain/extensions.js';

export class RequestSystem {
  private activeRequests: Map<string, DeliveryRequest> = new Map();
  private availableFilesPool: FileDefinition[] = [];
  private difficultyTier: DifficultyTier;
  private readonly TARGET_AVAILABLE_REQUESTS = 6;

  constructor(difficultyTier: DifficultyTier = DifficultyTier.TIER_1_IDENTIFICATION) {
    this.difficultyTier = difficultyTier;
    this.setDifficultyTier(difficultyTier);
  }

  public setDifficultyTier(tier: DifficultyTier) {
    this.difficultyTier = tier;
    this.availableFilesPool = getFilesForDifficulty(tier);
    this.replenishRequests();
  }

  public getDifficultyTier(): DifficultyTier {
    return this.difficultyTier;
  }

  /**
   * Mantém o pool de requisições sempre abastecido na Área de Requisições
   */
  public replenishRequests(): DeliveryRequest[] {
    const newlyGenerated: DeliveryRequest[] = [];
    const availableCount = Array.from(this.activeRequests.values()).filter(
      (r) => r.status === 'AVAILABLE'
    ).length;

    const deficit = this.TARGET_AVAILABLE_REQUESTS - availableCount;
    for (let i = 0; i < deficit; i++) {
      const newReq = generateDeliveryRequest(this.difficultyTier, this.availableFilesPool);
      this.activeRequests.set(newReq.id, newReq);
      newlyGenerated.push(newReq);
    }

    return newlyGenerated;
  }

  public getAvailableRequests(): DeliveryRequest[] {
    return Array.from(this.activeRequests.values()).filter((r) => r.status === 'AVAILABLE');
  }

  public getRequest(id: string): DeliveryRequest | undefined {
    return this.activeRequests.get(id);
  }

  /**
   * Jogador seleciona uma requisição no quadro da Área de Requisições
   */
  public claimRequest(requestId: string, playerId: string): DeliveryRequest | null {
    const req = this.activeRequests.get(requestId);
    if (!req || req.status !== 'AVAILABLE') {
      return null;
    }

    req.status = 'CLAIMED';
    req.claimedByPlayerId = playerId;
    return req;
  }

  /**
   * Finaliza uma requisição (entregue ou cancelada) e aciona reposição
   */
  public completeRequest(requestId: string, status: 'DELIVERED' | 'EXPIRED'): boolean {
    const req = this.activeRequests.get(requestId);
    if (!req) return false;

    req.status = status;
    this.activeRequests.delete(requestId);
    this.replenishRequests();
    return true;
  }

  /**
   * Libera uma requisição de volta ao pool se o jogador desistir ou desconectar
   */
  public releaseRequest(requestId: string): boolean {
    const req = this.activeRequests.get(requestId);
    if (!req) return false;

    req.status = 'AVAILABLE';
    req.claimedByPlayerId = undefined;
    return true;
  }
}
