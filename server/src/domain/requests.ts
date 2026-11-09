/**
 * DIGITAL DELIVERY - Gerador e Dicionário de Requisições Pedagógicas
 * Ref: Seções 8 e 9 do GDD.md
 */

import {
  DifficultyTier,
  DeliveryRequest,
  FileDefinition
} from './types.js';
import { getFilesForDifficulty, SOFTWARE_STATIONS } from './extensions.js';

/**
 * Templates contextuais por categoria e nível de dificuldade
 */
const CONTEXTUAL_PROMPTS: Record<
  string,
  {
    tier1Templates: string[]; // Direto (menciona arquivo e/ou extensão claramente)
    tier2Templates: string[]; // Interpretativo (descreve a tarefa sem citar diretamente o software)
    tier3PlusTemplates: string[]; // Técnico / contextual avançado
  }
> = {
  DOCUMENT: {
    tier1Templates: [
      'O cliente precisa abrir o arquivo "{fileName}" no Editor de Texto para ler o contrato.',
      'Abra o arquivo "{fileName}" ({extension}) para revisar o relatório do projeto.',
      'Carregue o arquivo "{fileName}" no processador de texto com urgência.'
    ],
    tier2Templates: [
      'O departamento jurídico solicitou a revisão das cláusulas contratuais ({fileName}).',
      'O gerente precisa alterar a introdução e corrigir a gramática do memorando ({fileName}).',
      'Um usuário deseja redigir novos parágrafos para o documento ({fileName}).'
    ],
    tier3PlusTemplates: [
      'Identifique a extensão de texto aberto ou portátil em "{fileName}" e encaminhe ao destino correto.',
      'O cliente precisa visualizar a documentação técnica sem alterar o layout original ({fileName}).'
    ]
  },
  SPREADSHEET: {
    tier1Templates: [
      'Abra a planilha "{fileName}" ({extension}) no programa de planilhas para conferir o balanço.',
      'O cliente precisa editar os números no arquivo "{fileName}" usando a Planilha Eletrônica.',
      'Envie o arquivo de tabela "{fileName}" para o software de planilhas.'
    ],
    tier2Templates: [
      'Preciso recalcular as fórmulas financeiras e somar o faturamento mensal ({fileName}).',
      'O setor de compras precisa atualizar a lista de preços e gerar gráficos estatísticos ({fileName}).',
      'Um analista quer filtrar as linhas e colunas com os dados de vendas ({fileName}).'
    ],
    tier3PlusTemplates: [
      'O banco de dados gerou uma exportação com campos separados por vírgula ({fileName}). Qual software manipula esses dados?',
      'O cliente precisa analisar dados tabulares com extensão aberta ({fileName}).'
    ]
  },
  PRESENTATION: {
    tier1Templates: [
      'O palestrante precisa abrir os slides de "{fileName}" ({extension}) na Apresentação de Slides.',
      'Carregue a apresentação "{fileName}" no software de slides antes da conferência começar.',
      'Abra o arquivo de slides "{fileName}" no programa correspondente.'
    ],
    tier2Templates: [
      'A equipe precisa projetar os slides corporativos para a reunião de investidores ({fileName}).',
      'O professor quer adicionar animações e transições entre as páginas da aula ({fileName}).',
      'O diretor vai ministrar uma palestra e precisa exibir os tópicos na tela cheia ({fileName}).'
    ],
    tier3PlusTemplates: [
      'Encaminhe o arquivo de slides com extensão aberta ou corporativa ({fileName}) ao software de projeção.'
    ]
  },
  IMAGE: {
    tier1Templates: [
      'O cliente precisa retocar a imagem "{fileName}" ({extension}) no Editor de Imagens.',
      'Abra a foto "{fileName}" no programa de edição de fotos para ajustar as cores.',
      'Carregue o arquivo gráfico "{fileName}" no Editor de Imagens.'
    ],
    tier2Templates: [
      'O designer precisa cortar o fundo e ajustar o brilho desta fotografia ({fileName}).',
      'A equipe de marketing quer exportar o logotipo da empresa com fundo transparente ({fileName}).',
      'Precisamos redimensionar essa arte visual para uma publicação ({fileName}).'
    ],
    tier3PlusTemplates: [
      'O arquivo "{fileName}" possui formato com compressão sem perdas ou animação em quadros. Encaminhe ao software correto.',
      'O cliente precisa checar se a imagem vetorial ou rasterizada ({fileName}) é compatível com o editor.'
    ]
  },
  AUDIO: {
    tier1Templates: [
      'O ouvinte quer escutar a música "{fileName}" ({extension}) no Player de Áudio.',
      'Toque a gravação "{fileName}" no reprodutor de som do computador.',
      'Envie a faixa de áudio "{fileName}" para o reprodutor de mídia sonora.'
    ],
    tier2Templates: [
      'A rádio precisa reproduzir a vinheta gravada pelo locutor ({fileName}).',
      'O aluno quer ouvir a gravação da entrevista antes de escrever o trabalho ({fileName}).',
      'Precisamos executar a trilha sonora de fundo do evento ({fileName}).'
    ],
    tier3PlusTemplates: [
      'O arquivo "{fileName}" contém áudio de alta fidelidade sem perdas de estúdio. Envie para audição.',
      'Um arquivo de som comprimido com codec livre ({fileName}) aguarda reprodução.'
    ]
  },
  VIDEO: {
    tier1Templates: [
      'O cliente quer assistir ao filme "{fileName}" ({extension}) no Player de Vídeo.',
      'Abra a gravação "{fileName}" no reprodutor de vídeo do sistema.',
      'Carregue o vídeo da aula "{fileName}" no software de reprodução visual.'
    ],
    tier2Templates: [
      'O setor de RH precisa assistir ao vídeo institucional de integração dos novos funcionários ({fileName}).',
      'O estudante quer pausar e adiantar a videoaula sobre arquitetura de computadores ({fileName}).',
      'A diretoria quer avaliar o comercial de televisão gravado em alta definição ({fileName}).'
    ],
    tier3PlusTemplates: [
      'O arquivo multimídia contém faixas de legenda embutidas em container Matroska ({fileName}). Destine ao player.',
      'O clipe antigo gravado com formato legado ({fileName}) precisa ser executado.'
    ]
  },
  COMPRESSED: {
    tier1Templates: [
      'O cliente precisa extrair os arquivos do pacote "{fileName}" ({extension}) no Compactador.',
      'Descompacte o arquivo zipado "{fileName}" no software de compactação.',
      'Carregue o pacote compactado "{fileName}" no descompactador de arquivos.'
    ],
    tier2Templates: [
      'O usuário recebeu um lote com 50 arquivos reunidos em um único pacote menor ({fileName}) e precisa extraí-los.',
      'Para liberar espaço em disco, precisamos descompactar este arquivo de backup ({fileName}).',
      'O fornecedor enviou documentos empacotados com senha ({fileName}). Onde devemos abrir?'
    ],
    tier3PlusTemplates: [
      'O pacote compactado com algoritmo de alta taxa de compressão ({fileName}) precisa de extração.',
      'Um arquivo com múltiplos volumes compactados ({fileName}) aguarda o descompactador.'
    ]
  },
  WEB: {
    tier1Templates: [
      'Abra o código do site "{fileName}" ({extension}) no Navegador Web.',
      'O usuário quer navegar pela página "{fileName}" usando o Web Browser.',
      'Carregue a página de internet "{fileName}" no navegador.'
    ],
    tier2Templates: [
      'O cliente quer visualizar uma página da internet contendo textos formatados e hiperlinks ({fileName}).',
      'O desenvolvedor precisa testar a estilização e responsividade da página no navegador ({fileName}).',
      'O usuário clicou em um link e quer renderizar a interface de um site ({fileName}).'
    ],
    tier3PlusTemplates: [
      'Um arquivo contendo folhas de estilo ou lógica de scripts de internet ({fileName}) deve ser executado no navegador.'
    ]
  },
  EXECUTABLE: {
    tier1Templates: [
      'O administrador precisa executar o instalador "{fileName}" ({extension}) no Executor de Programas.',
      'Abra o arquivo executável "{fileName}" no inicializador de aplicativos.',
      'Carregue o instalador de software "{fileName}" para iniciar a aplicação.'
    ],
    tier2Templates: [
      'Um novo programa foi baixado e precisa ser instalado no sistema operacional ({fileName}).',
      'O usuário deseja inicializar uma ferramenta compilada em código de máquina ({fileName}).',
      'O técnico de suporte precisa rodar o assistente de configuração ({fileName}).'
    ],
    tier3PlusTemplates: [
      'O binário executável do sistema ({fileName}) aguarda despacho para inicialização de processo.'
    ]
  }
};

/**
 * Gera uma requisição contextual pedagógica baseada no nível da sala
 */
export function generateDeliveryRequest(
  difficultyTier: DifficultyTier,
  availablePool?: FileDefinition[]
): DeliveryRequest {
  const eligibleFiles = availablePool && availablePool.length > 0
    ? availablePool
    : getFilesForDifficulty(difficultyTier);

  // Seleciona um arquivo aleatório do pool disponível
  const targetFile = eligibleFiles[Math.floor(Math.random() * eligibleFiles.length)];
  const categoryKey = targetFile.category;
  const promptGroup = CONTEXTUAL_PROMPTS[categoryKey] || CONTEXTUAL_PROMPTS.DOCUMENT;

  let template = '';
  if (difficultyTier === DifficultyTier.TIER_1_IDENTIFICATION) {
    const list = promptGroup.tier1Templates;
    template = list[Math.floor(Math.random() * list.length)];
  } else if (difficultyTier === DifficultyTier.TIER_2_INTERPRETATION) {
    const list = promptGroup.tier2Templates;
    template = list[Math.floor(Math.random() * list.length)];
  } else {
    // Tiers 3, 4 e 5: mescla interpretativo com templates avançados
    const combined = [...promptGroup.tier2Templates, ...promptGroup.tier3PlusTemplates];
    template = combined[Math.floor(Math.random() * combined.length)];
  }

  // Preenche as variáveis do template
  const promptText = template
    .replace('{fileName}', targetFile.sampleFileName)
    .replace('{extension}', targetFile.extension);

  const correctSoftwareId = targetFile.recommendedSoftwareId;

  // Limite de tempo padrão: 45 segundos para bônus de velocidade
  const timeLimitMs = 45000;

  return {
    id: `req_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    promptText,
    targetFile,
    correctSoftwareId,
    difficultyTier,
    status: 'AVAILABLE',
    spawnTimeMs: Date.now(),
    timeLimitMs,
    basePoints: 100
  };
}
