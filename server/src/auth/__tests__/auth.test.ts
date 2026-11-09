import { describe, it, expect, beforeEach } from 'vitest';
import { AuthManager } from '../AuthManager.js';
import fs from 'node:fs';
import path from 'node:path';

describe('AuthManager: Registro e Autenticação de Operadores', () => {
  const testDbPath = path.resolve(process.cwd(), 'data', 'test_users.json');

  beforeEach(() => {
    if (fs.existsSync(testDbPath)) {
      try {
        fs.unlinkSync(testDbPath);
      } catch {}
    }
  });

  it('deve registrar um novo operador com sucesso', () => {
    const auth = new AuthManager(testDbPath);
    const res = auth.register('aluno_hack', 'senha1234');

    expect(res.success).toBe(true);
    expect(res.message).toContain('registrado com sucesso');
    expect(auth.getUser('aluno_hack')).toBeDefined();
  });

  it('deve rejeitar operador com menos de 3 caracteres ou caracteres inválidos', () => {
    const auth = new AuthManager(testDbPath);
    const short = auth.register('al', 'senha1234');
    expect(short.success).toBe(false);

    const invalidChars = auth.register('aluno@hack!', 'senha1234');
    expect(invalidChars.success).toBe(false);
  });

  it('deve rejeitar senha com menos de 4 caracteres', () => {
    const auth = new AuthManager(testDbPath);
    const res = auth.register('operador', '123');
    expect(res.success).toBe(false);
    expect(res.message).toContain('no mínimo 4 caracteres');
  });

  it('deve impedir nomes de operadores duplicados (case insensitive)', () => {
    const auth = new AuthManager(testDbPath);
    auth.register('Cypher', 'senha1234');
    const dup = auth.register('cypher', 'outrasenha');

    expect(dup.success).toBe(false);
    expect(dup.message).toContain('já está cadastrado');
  });

  it('deve autenticar corretamente com senha válida e rejeitar senha incorreta', () => {
    const auth = new AuthManager(testDbPath);
    auth.register('Neo', 'matrix123');

    const ok = auth.login('Neo', 'matrix123');
    expect(ok.success).toBe(true);
    expect(ok.username).toBe('Neo');

    const fail = auth.login('Neo', 'errada');
    expect(fail.success).toBe(false);
    expect(fail.message).toContain('Senha incorreta');

    const notFound = auth.login('Morpheus', '123456');
    expect(notFound.success).toBe(false);
    expect(notFound.message).toContain('não encontrado');
  });
});
