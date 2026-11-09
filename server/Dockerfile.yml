# ==========================================
# DIGITAL DELIVERY - Backend Server Dockerfile
# Multi-stage build otimizado para Node.js + TypeScript
# ==========================================

# Estágio 1: Builder
FROM node:22-alpine AS builder

WORKDIR /app

# Copia manifests de pacotes e tsconfig
COPY package*.json tsconfig.json ./

# Instala todas as dependências necessárias para a compilação
RUN npm install

# Copia o código-fonte
COPY src/ ./src/

# Compila o TypeScript para JavaScript (gera ./dist)
RUN npm run build

# Estágio 2: Runner de Produção
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3001
ENV HOST=0.0.0.0

# Copia manifests e instala apenas dependências de produção
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copia os arquivos compilados do estágio de build
COPY --from=builder /app/dist ./dist

# Garante a pasta de dados persistentes para o banco de usuários (data/users.json)
RUN mkdir -p /app/data && chown -R node:node /app

USER node

EXPOSE 3001

# Inicializa o servidor backend
CMD ["node", "dist/index.js"]
