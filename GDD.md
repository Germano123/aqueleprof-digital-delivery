# DIGITAL DELIVERY
## Game Design Document

## 1. Conceito

Digital Delivery é um jogo multiplayer competitivo de corrida e entrega de arquivos ambientado dentro de um computador gigante.

Até 20 jogadores participam simultaneamente de uma partida. Cada jogador controla um personagem responsável por atender requisições de clientes.

O jogador poderá coletar uma requisição na área de requisições, identificar o tipo de tarefa, verificar sua extensão, localizar o aplicativo do arquivo correspondente e transportar o arquivo até o software adequado.

A partida combina:

- Corrida
- Física caótica
- Obstáculos
- Colisões entre jogadores
- Competição
- Identificação de arquivos
- Extensões de arquivos
- Categorias de software
- Organização digital

A referência de ritmo e interação é semelhante a jogos de party royale, como Fall Guys, porém com uma finalidade educacional.

---

# 2. Objetivo Educacional

O jogo deve ensinar o jogador a relacionar:

REQUISIÇÃO
↓
TIPO DE ARQUIVO
↓
EXTENSÃO
↓
CATEGORIA
↓
SOFTWARE ADEQUADO

Exemplo:

"Preciso editar um documento de texto."

→ Arquivo: relatório.docx
→ Extensão: .docx
→ Categoria: Documento
→ Software: Editor de Texto

O objetivo não é apenas memorizar extensões, mas compreender sua relação com os tipos de arquivos e os softwares utilizados para manipulá-los.

---

# 3. Público

- Alunos do curso de Operador de Computador
- Iniciantes em informática
- Jovens e adultos
- Até 20 jogadores por partida

---

# 4. Estrutura da Partida

## Jogadores

Máximo: 20 jogadores.

Possibilidade de:

- 20 jogadores individuais
- até 4 equipes
  de 5 jogadores

O modo principal será individual.

---

# 5. Loop Principal

Cada partida terá um tempo de até 8 minutos e segue o fluxo:

1. Receber requisições constantes na área de requisições.
2. Interpretar o que o cliente deseja.
3. Identificar o arquivo necessário.
4. Verificar sua extensão.
5. Identificar o software correto.
6. Localizar o software no mapa.
7. Pegar o arquivo.
8. Transportar o arquivo.
9. Enfrentar obstáculos e outros jogadores.
10. Entregar o arquivo.
11. Receber pontuação.
12. Nova requisição.

---

# 6. Ambiente

O mapa representa o interior de um computador.

 Os softwares aparecem como grandes estruturas quadradas espalhadas pelo cenário.

Exemplos:

- Editor de Texto
- Planilha
- Apresentação
- Navegador
- Editor de Imagens
- Player de Áudio
- Player de Vídeo
- Compactador/descompactador
- Visualizador de PDF

Cada software possui uma área visual própria.

---

# 7. Arquivos

Os arquivos aparecem fisicamente no mundo como objetos carregáveis. Um modelo 3D de um cubo em 45 graus apenas com suas arestas aparentes e um centro simulando o dado. Cada tipo de arquivo gera uma coloração diferente que o jogador só vê quando carrega o cubo em mãos, ao largar o arquivo fica cinza novamente.

Exemplos:

Documento:
- contrato.pdf
- relatório.docx
- mensagem.txt

Planilha:
- vendas.xlsx
- estoque.xlsx

Apresentação:
- treinamento.pptx

Imagem:
- fotografia.jpg
- logotipo.png

Áudio:
- musica.mp3
- entrevista.wav

Vídeo:
- aula.mp4

Documento portátil:
- manual.pdf

Compactado:
- projeto.zip

---

# 8. Requisições

A requisição deve apresentar uma situação contextualizada.

Exemplo:

> "O cliente precisa alterar o relatório de vendas."

Arquivo:
`vendas.xlsx`

Destino:
Planilha

---

Outro exemplo:

> "O cliente precisa visualizar o manual do equipamento."

Arquivo:
`manual.pdf`

Destino:
Visualizador de PDF

---

Outro:

> "O cliente precisa editar uma fotografia."

Arquivo:
`foto.jpg`

Destino:
Editor de Imagens

---

# 9. Níveis de Dificuldade

## Nível 1 — Identificação

A requisição informa claramente o arquivo.

Exemplo:

"Abra o arquivo relatório.docx em um editor de texto."

O jogador precisa apenas relacionar:

.docx → Documento → Editor de Texto

---

## Nível 2 — Interpretação

A requisição descreve a tarefa sem indicar diretamente o software.

Exemplo:

"Preciso alterar os valores da tabela de vendas."

Arquivo:
`vendas.xlsx`

O jogador precisa identificar:

.xlsx → Planilha

---

## Nível 3 — Extensão

O jogador precisa analisar o arquivo.

Exemplo:

`imagem_final.png`

Pergunta:

"Qual tipo de arquivo você está carregando?"

Resposta:

Imagem.

---

## Nível 4 — Ambiguidade

Arquivos diferentes podem possuir finalidades semelhantes.

Exemplo:

`foto.jpg`
`logo.png`

O jogador precisa reconhecer que ambos pertencem à categoria de imagens.

---

## Nível 5 — Especialização

Introdução de extensões menos comuns.

Exemplos:

- .csv
- .gif
- .wav
- .zip
- .rar
- .html

---

# 10. Sistema de Pontuação

A pontuação considera:

- Entrega correta
- Tempo de entrega
- Extensão identificada corretamente
- Software correto
- Sequência de entregas corretas

Erros podem causar:

- Perda de pontos
- Perda de tempo
- Arquivo devolvido
- Necessidade de buscar novamente

---

# 11. Caos Multiplayer

O mapa deve possuir elementos que provoquem interação entre jogadores e, ao mesmo tempo, representem de forma lúdica conceitos relacionados ao funcionamento e à utilização de computadores.

Mecânica do jogo	Representação no computador	Efeito no jogo
Plataformas RAM	Barramento de ida e volta representando o acesso rápido da memória RAM às informações	Jogadores recebem aceleração sobre a plataforma. Com 5 ou mais jogadores simultaneamente, ocorre uma sobrecarga de RAM e a plataforma fica progressivamente mais lenta
Vírus	Uma bola verde que circula pelo mapa	Ao atingir um jogador, ele perde o controle temporariamente e precisa executar um minigame de sequência de caracteres e interação com o mouse para remover o vírus e colocá-lo em quarentena
Firewall	Pilar de chamas representando uma barreira de segurança	O jogador que tenta atravessar é empurrado para trás e pode derrubar o arquivo que está carregando
Fila de processos	Região onde vários arquivos circulam rapidamente, representando processos aguardando processamento	Os arquivos em circulação podem atingir os jogadores e fazer com que derrubem o arquivo carregado
Janela travada	Pop-ups que aparecem sobre a tela do jogador	O jogador precisa fechar várias janelas. Se demorar, novos pop-ups aparecem, até o limite de 8 segundos ou até que todas sejam fechadas
USB conectado	Um enorme conector USB bloqueando uma passagem	A região fica bloqueada e os jogadores precisam procurar outra rota
Manutenção	Área representando uma região do sistema em manutenção	Jogadores recebem proteção temporária contra lentidão, fila de processos, vírus e outros problemas
Desfragmentação de disco	Região onde o chão desaparece enquanto o espaço é reorganizado	O piso desaparece de maneira progressiva e depois é reconstruído em uma nova configuração, obrigando os jogadores a encontrar uma nova rota. A destruição do chão é uma alegoria visual para a reorganização dos dados no armazenamento

Jogadores podem esbarrar uns nos outros enquanto carregam arquivos.

Quando um jogador sofre uma colisão suficientemente forte, pode derrubar o arquivo.

O arquivo deve quicar levemente e ser lançado para longe utilizando a física de movimento, permitindo que outro jogador possa eventualmente pegá-lo.

---

# 12. Regra Fundamental

O jogador não deve vencer simplesmente por correr mais rápido.

A velocidade ajuda, mas o conhecimento determina a rota correta.

Um jogador pode:

- chegar rapidamente ao arquivo errado;
- carregar o arquivo correto para o software errado;
- escolher uma rota mais longa para evitar outros jogadores;
- identificar corretamente a extensão e ganhar vantagem.

Assim, conhecimento e habilidade física coexistem.

---

# 13. Categorias de Arquivos

Categoria inicial:

### Documentos
- .doc
- .docx
- .txt
- .odt
- .pdf

### Planilhas
- .xls
- .xlsx
- .csv
- .ods

### Apresentações
- .ppt
- .pptx
- .odp

### Imagens
- .jpg
- .jpeg
- .png
- .gif
- .bmp

### Áudio
- .mp3
- .wav
- .ogg

### Vídeo
- .mp4
- .avi
- .mkv
- .rmvb

### Compactados
- .zip
- .rar
- .7z

### Web
- .html
- .css
- .js

### Executáveis
- .exe

---

# 14. Progressão Didática

A quantidade de extensões aumenta de acordo com o nível selecionada no início da sala da partida.

### Nível 1
.docx
.xlsx
.pptx
.jpg
.mp3
.mp4

### Nível 2
.txt
.pdf
.png
.wav
.zip

### Nível 3
.csv
.gif
.avi
.rar
.html

### Nível 4

Combinação de múltiplas categorias e requisições simultâneas.

---

# 15. Condição de Vitória

A partida possui duração máxima de 8 minutos.

Durante toda a partida, novas requisições continuam aparecendo na área de requisições, representando tarefas sendo constantemente adicionadas ao sistema.

Os jogadores escolhem as requisições disponíveis e precisam executar corretamente cada tarefa.

Uma execução correta gera pontuação para o jogador ou equipe.

Não existe eliminação permanente durante a partida.

Um jogador que perder um arquivo, sofrer um obstáculo ou errar uma entrega pode retornar à atividade e continuar realizando requisições.

Erros podem resultar em:

Perda de pontos;
Perda de tempo;
Arquivo devolvido;
Necessidade de buscar novamente o arquivo;
Necessidade de retornar à área de requisições.

Ao final dos 8 minutos, o jogador ou equipe com a maior pontuação é declarado vencedor.

A pontuação deve recompensar principalmente a execução correta das tarefas, permitindo que conhecimento e habilidade influenciem diretamente o resultado da partida.

# 16. Definições estéticas

## Cores das requisições

| Categoria        | Cor          | Hex       |
| ---------------- | ------------ | --------- |
| 📄 Documento     | Azul         | `#3498DB` |
| 📊 Planilha      | Verde        | `#2ECC71` |
| 📽️ Apresentação | Laranja      | `#F39C12` |
| 🖼️ Imagem       | Rosa/Magenta | `#E84393` |
| 🎵 Áudio         | Roxo         | `#9B59B6` |
| 🎬 Vídeo         | Vermelho     | `#E74C3C` |
| 📦 Compactado    | Amarelo      | `#F1C40F` |
| 🌐 Web           | Ciano        | `#00B8D9` |
| ⚙️ Executável    | Cinza escuro | `#34495E` |


