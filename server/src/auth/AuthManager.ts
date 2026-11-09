/**
 * DIGITAL DELIVERY - Gerenciador de Autenticação e Contas de Usuário
 * Suporte a persistência em arquivo JSON para partidas em rede local
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export interface UserAccount {
  username: string;
  passwordHash: string;
  createdAt: number;
  lastLoginAt?: number;
}

export class AuthManager {
  private users: Map<string, UserAccount> = new Map();
  private filePath: string;

  constructor(customFilePath?: string) {
    const defaultDataDir = path.resolve(process.cwd(), 'data');
    if (!fs.existsSync(defaultDataDir)) {
      try {
        fs.mkdirSync(defaultDataDir, { recursive: true });
      } catch {
        // Ignora se não puder criar diretório
      }
    }

    this.filePath = customFilePath || path.resolve(defaultDataDir, 'users.json');
    this.loadUsers();
  }

  private hashPassword(password: string): string {
    return crypto.createHash('sha256').update(password).digest('hex');
  }

  private loadUsers(): void {
    if (fs.existsSync(this.filePath)) {
      try {
        const raw = fs.readFileSync(this.filePath, 'utf-8');
        const parsed: UserAccount[] = JSON.parse(raw);
        for (const u of parsed) {
          this.users.set(u.username.toLowerCase(), u);
        }
      } catch (err) {
        console.warn('[AUTH] Falha ao carregar banco de usuários existente:', err);
      }
    }
  }

  private saveUsers(): void {
    try {
      const list = Array.from(this.users.values());
      fs.writeFileSync(this.filePath, JSON.stringify(list, null, 2), 'utf-8');
    } catch (err) {
      console.warn('[AUTH] Falha ao salvar banco de usuários:', err);
    }
  }

  public register(username: string, password: string): { success: boolean; message: string } {
    const trimmedUser = username.trim();
    if (!trimmedUser || trimmedUser.length < 3) {
      return { success: false, message: 'Nome de usuário deve conter no mínimo 3 caracteres.' };
    }

    if (!/^[a-zA-Z0-9_-]+$/.test(trimmedUser)) {
      return { success: false, message: 'Nome de usuário só pode conter letras, números, hífen e sublinhado.' };
    }

    if (!password || password.length < 4) {
      return { success: false, message: 'A senha deve conter no mínimo 4 caracteres.' };
    }

    const key = trimmedUser.toLowerCase();
    if (this.users.has(key)) {
      return { success: false, message: `O operador '${trimmedUser}' já está cadastrado no sistema.` };
    }

    const newUser: UserAccount = {
      username: trimmedUser,
      passwordHash: this.hashPassword(password),
      createdAt: Date.now()
    };

    this.users.set(key, newUser);
    this.saveUsers();

    return {
      success: true,
      message: `Operador '${trimmedUser}' registrado com sucesso no banco do sistema.`
    };
  }

  public login(username: string, password: string): { success: boolean; message: string; username?: string } {
    const trimmedUser = username.trim();
    const key = trimmedUser.toLowerCase();

    const user = this.users.get(key);
    if (!user) {
      return { success: false, message: `Operador '${trimmedUser}' não encontrado. Use 'register <user> <pass>'.` };
    }

    const providedHash = this.hashPassword(password);
    if (user.passwordHash !== providedHash) {
      return { success: false, message: 'Senha incorreta para o operador especificado.' };
    }

    user.lastLoginAt = Date.now();
    this.saveUsers();

    return {
      success: true,
      message: `Acesso concedido. Bem-vindo, operador '${user.username}'.`,
      username: user.username
    };
  }

  public getUser(username: string): UserAccount | undefined {
    return this.users.get(username.toLowerCase());
  }

  public getAllUsersCount(): number {
    return this.users.size;
  }
}
