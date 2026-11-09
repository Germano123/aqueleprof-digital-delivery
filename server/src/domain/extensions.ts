/**
 * DIGITAL DELIVERY - Base de Conhecimento de Arquivos, Extensões e Softwares
 * Ref: Seções 6, 7, 13, 14 e 16 do GDD.md
 */

import {
  FileCategory,
  CategoryVisualInfo,
  SoftwareStation,
  FileDefinition,
  DifficultyTier
} from './types.js';

/**
 * Cores estéticas oficiais do GDD (Seção 16)
 */
export const CATEGORY_VISUALS: Record<FileCategory, CategoryVisualInfo> = {
  [FileCategory.DOCUMENT]: {
    name: 'Documento',
    colorName: 'Azul',
    hex: '#3498DB',
    emoji: '📄'
  },
  [FileCategory.SPREADSHEET]: {
    name: 'Planilha',
    colorName: 'Verde',
    hex: '#2ECC71',
    emoji: '📊'
  },
  [FileCategory.PRESENTATION]: {
    name: 'Apresentação',
    colorName: 'Laranja',
    hex: '#F39C12',
    emoji: '📽️'
  },
  [FileCategory.IMAGE]: {
    name: 'Imagem',
    colorName: 'Rosa/Magenta',
    hex: '#E84393',
    emoji: '🖼️'
  },
  [FileCategory.AUDIO]: {
    name: 'Áudio',
    colorName: 'Roxo',
    hex: '#9B59B6',
    emoji: '🎵'
  },
  [FileCategory.VIDEO]: {
    name: 'Vídeo',
    colorName: 'Vermelho',
    hex: '#E74C3C',
    emoji: '🎬'
  },
  [FileCategory.COMPRESSED]: {
    name: 'Compactado',
    colorName: 'Amarelo',
    hex: '#F1C40F',
    emoji: '📦'
  },
  [FileCategory.WEB]: {
    name: 'Web',
    colorName: 'Ciano',
    hex: '#00B8D9',
    emoji: '🌐'
  },
  [FileCategory.EXECUTABLE]: {
    name: 'Executável',
    colorName: 'Cinza escuro',
    hex: '#34495E',
    emoji: '⚙️'
  }
};

/**
 * Estações de Software espalhadas pelo mapa do computador (Seção 6 e 13)
 */
export const SOFTWARE_STATIONS: Record<string, SoftwareStation> = {
  text_editor: {
    id: 'text_editor',
    name: 'Editor de Texto',
    description: 'Processa documentos de texto, artigos e relatórios editáveis.',
    handledCategories: [FileCategory.DOCUMENT],
    allowedExtensions: ['.doc', '.docx', '.txt', '.odt', '.pdf']
  },
  calc_sheet: {
    id: 'calc_sheet',
    name: 'Planilha Eletrônica',
    description: 'Calcula fórmulas, processa tabelas numéricas e listas financeiras.',
    handledCategories: [FileCategory.SPREADSHEET],
    allowedExtensions: ['.xls', '.xlsx', '.csv', '.ods']
  },
  slide_presentation: {
    id: 'slide_presentation',
    name: 'Apresentação de Slides',
    description: 'Exibe palestras, conferências e projetos em telas de slides.',
    handledCategories: [FileCategory.PRESENTATION],
    allowedExtensions: ['.ppt', '.pptx', '.odp']
  },
  image_editor: {
    id: 'image_editor',
    name: 'Editor de Imagens',
    description: 'Edita, retoca fotografias, artes visuais e ilustrações.',
    handledCategories: [FileCategory.IMAGE],
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.gif', '.bmp']
  },
  audio_player: {
    id: 'audio_player',
    name: 'Player de Áudio',
    description: 'Reproduz faixas sonoras, músicas e gravações de áudio.',
    handledCategories: [FileCategory.AUDIO],
    allowedExtensions: ['.mp3', '.wav', '.ogg']
  },
  video_player: {
    id: 'video_player',
    name: 'Player de Vídeo',
    description: 'Exibe filmes, animações e gravações visuais.',
    handledCategories: [FileCategory.VIDEO],
    allowedExtensions: ['.mp4', '.avi', '.mkv', '.rmvb']
  },
  archive_manager: {
    id: 'archive_manager',
    name: 'Compactador de Arquivos',
    description: 'Comprime e descompacta pacotes de arquivos com múltiplos dados.',
    handledCategories: [FileCategory.COMPRESSED],
    allowedExtensions: ['.zip', '.rar', '.7z']
  },
  web_browser: {
    id: 'web_browser',
    name: 'Navegador Web',
    description: 'Interpreta páginas HTML, estilizações CSS e scripts de Internet.',
    handledCategories: [FileCategory.WEB],
    allowedExtensions: ['.html', '.css', '.js']
  },
  pdf_viewer: {
    id: 'pdf_viewer',
    name: 'Visualizador de PDF',
    description: 'Exibe manuais e contratos formatados para leitura e impressão.',
    handledCategories: [FileCategory.DOCUMENT],
    allowedExtensions: ['.pdf']
  },
  system_runner: {
    id: 'system_runner',
    name: 'Executor de Aplicativos',
    description: 'Instala e executa programas compilados do sistema operacional.',
    handledCategories: [FileCategory.EXECUTABLE],
    allowedExtensions: ['.exe']
  }
};

/**
 * Catálogo Didático de Extensões (Seções 13 e 14 do GDD)
 */
export const FILE_CATALOG: FileDefinition[] = [
  // --- NÍVEL 1: Essenciais (Seção 14: .docx, .xlsx, .pptx, .jpg, .mp3, .mp4) ---
  {
    id: 'doc_docx',
    name: 'Documento Word',
    extension: '.docx',
    category: FileCategory.DOCUMENT,
    recommendedSoftwareId: 'text_editor',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'relatorio_trimestral.docx'
  },
  {
    id: 'sheet_xlsx',
    name: 'Planilha Excel',
    extension: '.xlsx',
    category: FileCategory.SPREADSHEET,
    recommendedSoftwareId: 'calc_sheet',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'tabela_vendas.xlsx'
  },
  {
    id: 'slide_pptx',
    name: 'Apresentação PowerPoint',
    extension: '.pptx',
    category: FileCategory.PRESENTATION,
    recommendedSoftwareId: 'slide_presentation',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'treinamento_equipe.pptx'
  },
  {
    id: 'img_jpg',
    name: 'Foto JPEG',
    extension: '.jpg',
    category: FileCategory.IMAGE,
    recommendedSoftwareId: 'image_editor',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'fotografia_perfil.jpg'
  },
  {
    id: 'audio_mp3',
    name: 'Música MP3',
    extension: '.mp3',
    category: FileCategory.AUDIO,
    recommendedSoftwareId: 'audio_player',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'podcast_episodio1.mp3'
  },
  {
    id: 'video_mp4',
    name: 'Vídeo MP4',
    extension: '.mp4',
    category: FileCategory.VIDEO,
    recommendedSoftwareId: 'video_player',
    difficultyTier: DifficultyTier.TIER_1_IDENTIFICATION,
    sampleFileName: 'videoaula_informatica.mp4'
  },

  // --- NÍVEL 2: Intermediários (Seção 14: .txt, .pdf, .png, .wav, .zip) ---
  {
    id: 'doc_txt',
    name: 'Texto Simples',
    extension: '.txt',
    category: FileCategory.DOCUMENT,
    recommendedSoftwareId: 'text_editor',
    difficultyTier: DifficultyTier.TIER_2_INTERPRETATION,
    sampleFileName: 'anotacoes_reuniao.txt'
  },
  {
    id: 'doc_pdf',
    name: 'Documento PDF',
    extension: '.pdf',
    category: FileCategory.DOCUMENT,
    recommendedSoftwareId: 'pdf_viewer', // Aceito tanto no pdf_viewer quanto text_editor
    difficultyTier: DifficultyTier.TIER_2_INTERPRETATION,
    sampleFileName: 'manual_instrucoes.pdf'
  },
  {
    id: 'img_png',
    name: 'Imagem PNG com Transparência',
    extension: '.png',
    category: FileCategory.IMAGE,
    recommendedSoftwareId: 'image_editor',
    difficultyTier: DifficultyTier.TIER_2_INTERPRETATION,
    sampleFileName: 'logotipo_empresa.png'
  },
  {
    id: 'audio_wav',
    name: 'Áudio Sem Compressão WAV',
    extension: '.wav',
    category: FileCategory.AUDIO,
    recommendedSoftwareId: 'audio_player',
    difficultyTier: DifficultyTier.TIER_2_INTERPRETATION,
    sampleFileName: 'entrevista_gravada.wav'
  },
  {
    id: 'archive_zip',
    name: 'Arquivo Compactado ZIP',
    extension: '.zip',
    category: FileCategory.COMPRESSED,
    recommendedSoftwareId: 'archive_manager',
    difficultyTier: DifficultyTier.TIER_2_INTERPRETATION,
    sampleFileName: 'backup_arquivos.zip'
  },

  // --- NÍVEL 3: Diversificação (Seção 14: .csv, .gif, .avi, .rar, .html) ---
  {
    id: 'sheet_csv',
    name: 'Dados Separados por Vírgula CSV',
    extension: '.csv',
    category: FileCategory.SPREADSHEET,
    recommendedSoftwareId: 'calc_sheet',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    sampleFileName: 'exportacao_banco.csv'
  },
  {
    id: 'img_gif',
    name: 'Imagem Animada GIF',
    extension: '.gif',
    category: FileCategory.IMAGE,
    recommendedSoftwareId: 'image_editor',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    sampleFileName: 'animacao_carregando.gif'
  },
  {
    id: 'video_avi',
    name: 'Vídeo AVI',
    extension: '.avi',
    category: FileCategory.VIDEO,
    recommendedSoftwareId: 'video_player',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    sampleFileName: 'gravacao_antiga.avi'
  },
  {
    id: 'archive_rar',
    name: 'Pacote WinRAR',
    extension: '.rar',
    category: FileCategory.COMPRESSED,
    recommendedSoftwareId: 'archive_manager',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    sampleFileName: 'projeto_instalacao.rar'
  },
  {
    id: 'web_html',
    name: 'Página Web HTML',
    extension: '.html',
    category: FileCategory.WEB,
    recommendedSoftwareId: 'web_browser',
    difficultyTier: DifficultyTier.TIER_3_EXTENSION,
    sampleFileName: 'portal_noticias.html'
  },

  // --- NÍVEL 4 e 5: Formatos Livres e Especializados (Seções 9 e 13) ---
  {
    id: 'doc_odt',
    name: 'Texto Aberto OpenDocument',
    extension: '.odt',
    category: FileCategory.DOCUMENT,
    recommendedSoftwareId: 'text_editor',
    difficultyTier: DifficultyTier.TIER_4_AMBIGUITY,
    sampleFileName: 'minuta_contrato.odt'
  },
  {
    id: 'sheet_ods',
    name: 'Planilha Aberta OpenDocument',
    extension: '.ods',
    category: FileCategory.SPREADSHEET,
    recommendedSoftwareId: 'calc_sheet',
    difficultyTier: DifficultyTier.TIER_4_AMBIGUITY,
    sampleFileName: 'orcamento_mensal.ods'
  },
  {
    id: 'slide_odp',
    name: 'Apresentação Aberta OpenDocument',
    extension: '.odp',
    category: FileCategory.PRESENTATION,
    recommendedSoftwareId: 'slide_presentation',
    difficultyTier: DifficultyTier.TIER_4_AMBIGUITY,
    sampleFileName: 'apresentacao_livre.odp'
  },
  {
    id: 'audio_ogg',
    name: 'Áudio OGG Vorbis',
    extension: '.ogg',
    category: FileCategory.AUDIO,
    recommendedSoftwareId: 'audio_player',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'trilha_sonora.ogg'
  },
  {
    id: 'video_mkv',
    name: 'Vídeo Matroska MKV',
    extension: '.mkv',
    category: FileCategory.VIDEO,
    recommendedSoftwareId: 'video_player',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'filme_documentario.mkv'
  },
  {
    id: 'archive_7z',
    name: 'Arquivo Compactado 7-Zip',
    extension: '.7z',
    category: FileCategory.COMPRESSED,
    recommendedSoftwareId: 'archive_manager',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'pacote_max_compressao.7z'
  },
  {
    id: 'web_css',
    name: 'Estilização Cascading Style Sheets',
    extension: '.css',
    category: FileCategory.WEB,
    recommendedSoftwareId: 'web_browser',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'estilos_site.css'
  },
  {
    id: 'web_js',
    name: 'Script JavaScript',
    extension: '.js',
    category: FileCategory.WEB,
    recommendedSoftwareId: 'web_browser',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'interatividade.js'
  },
  {
    id: 'exec_exe',
    name: 'Programa Executável',
    extension: '.exe',
    category: FileCategory.EXECUTABLE,
    recommendedSoftwareId: 'system_runner',
    difficultyTier: DifficultyTier.TIER_5_SPECIALIZATION,
    sampleFileName: 'instalador_app.exe'
  }
];

/**
 * Retorna os arquivos disponíveis para um determinado nível didático
 */
export function getFilesForDifficulty(maxTier: DifficultyTier): FileDefinition[] {
  return FILE_CATALOG.filter((f) => f.difficultyTier <= maxTier);
}

/**
 * Validação de entrega pedagógica: checa se o software de destino aceita a extensão
 */
export function validateDeliveryTarget(
  fileExtension: string,
  targetSoftwareId: string
): { isValid: boolean; reason?: string } {
  const station = SOFTWARE_STATIONS[targetSoftwareId];
  if (!station) {
    return { isValid: false, reason: `Software '${targetSoftwareId}' não existe no mapa do computador.` };
  }

  const normalizedExt = fileExtension.toLowerCase().startsWith('.')
    ? fileExtension.toLowerCase()
    : `.${fileExtension.toLowerCase()}`;

  const isAccepted = station.allowedExtensions.includes(normalizedExt);
  if (isAccepted) {
    return { isValid: true };
  }

  return {
    isValid: false,
    reason: `A extensão ${normalizedExt} não pode ser aberta em ${station.name}. O arquivo requer um software compatível!`
  };
}
