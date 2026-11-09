extends Node

## DIGITAL DELIVERY - Base de Conhecimento Pedagógica (Godot 4 Autoload)
## Ref: Seções 6, 7, 13, 14 e 16 do GDD.md

# Cores oficiais do GDD (Seção 16)
const CATEGORY_COLORS = {
	"DOCUMENT": Color("#3498DB"),     # Azul
	"SPREADSHEET": Color("#2ECC71"),  # Verde
	"PRESENTATION": Color("#F39C12"), # Laranja
	"IMAGE": Color("#E84393"),        # Rosa/Magenta
	"AUDIO": Color("#9B59B6"),        # Roxo
	"VIDEO": Color("#E74C3C"),        # Vermelho
	"COMPRESSED": Color("#F1C40F"),   # Amarelo
	"WEB": Color("#00B8D9"),          # Ciano
	"EXECUTABLE": Color("#34495E")    # Cinza escuro
}

const CATEGORY_NAMES = {
	"DOCUMENT": "Documento",
	"SPREADSHEET": "Planilha",
	"PRESENTATION": "Apresentação",
	"IMAGE": "Imagem",
	"AUDIO": "Áudio",
	"VIDEO": "Vídeo",
	"COMPRESSED": "Compactado",
	"WEB": "Web",
	"EXECUTABLE": "Executável"
}

const CATEGORY_ICONS = {
	"DOCUMENT": "📄",
	"SPREADSHEET": "📊",
	"PRESENTATION": "📽️",
	"IMAGE": "🖼️",
	"AUDIO": "🎵",
	"VIDEO": "🎬",
	"COMPRESSED": "📦",
	"WEB": "🌐",
	"EXECUTABLE": "⚙️"
}

# Estações de software no computador (Seção 6 e 13)
const SOFTWARE_STATIONS = {
	"text_editor": {
		"id": "text_editor",
		"name": "Editor de Texto",
		"icon": "📄",
		"allowed_extensions": [".doc", ".docx", ".txt", ".odt", ".pdf"],
		"color": Color("#3498DB")
	},
	"calc_sheet": {
		"id": "calc_sheet",
		"name": "Planilha Eletrônica",
		"icon": "📊",
		"allowed_extensions": [".xls", ".xlsx", ".csv", ".ods"],
		"color": Color("#2ECC71")
	},
	"slide_presentation": {
		"id": "slide_presentation",
		"name": "Apresentação de Slides",
		"icon": "📽️",
		"allowed_extensions": [".ppt", ".pptx", ".odp"],
		"color": Color("#F39C12")
	},
	"image_editor": {
		"id": "image_editor",
		"name": "Editor de Imagens",
		"icon": "🖼️",
		"allowed_extensions": [".jpg", ".jpeg", ".png", ".gif", ".bmp"],
		"color": Color("#E84393")
	},
	"audio_player": {
		"id": "audio_player",
		"name": "Player de Áudio",
		"icon": "🎵",
		"allowed_extensions": [".mp3", ".wav", ".ogg"],
		"color": Color("#9B59B6")
	},
	"video_player": {
		"id": "video_player",
		"name": "Player de Vídeo",
		"icon": "🎬",
		"allowed_extensions": [".mp4", ".avi", ".mkv", ".rmvb"],
		"color": Color("#E74C3C")
	},
	"archive_manager": {
		"id": "archive_manager",
		"name": "Compactador de Arquivos",
		"icon": "📦",
		"allowed_extensions": [".zip", ".rar", ".7z"],
		"color": Color("#F1C40F")
	},
	"web_browser": {
		"id": "web_browser",
		"name": "Navegador Web",
		"icon": "🌐",
		"allowed_extensions": [".html", ".css", ".js"],
		"color": Color("#00B8D9")
	},
	"pdf_viewer": {
		"id": "pdf_viewer",
		"name": "Visualizador de PDF",
		"icon": "📑",
		"allowed_extensions": [".pdf"],
		"color": Color("#3498DB")
	},
	"system_runner": {
		"id": "system_runner",
		"name": "Executor de Programas",
		"icon": "⚙️",
		"allowed_extensions": [".exe"],
		"color": Color("#34495E")
	}
}

# Amostras de arquivos para teste local/offline
const SAMPLE_FILES = [
	{ "name": "relatorio.docx", "ext": ".docx", "category": "DOCUMENT", "software": "text_editor", "tier": 1 },
	{ "name": "vendas.xlsx", "ext": ".xlsx", "category": "SPREADSHEET", "software": "calc_sheet", "tier": 1 },
	{ "name": "treinamento.pptx", "ext": ".pptx", "category": "PRESENTATION", "software": "slide_presentation", "tier": 1 },
	{ "name": "foto.jpg", "ext": ".jpg", "category": "IMAGE", "software": "image_editor", "tier": 1 },
	{ "name": "musica.mp3", "ext": ".mp3", "category": "AUDIO", "software": "audio_player", "tier": 1 },
	{ "name": "videoaula.mp4", "ext": ".mp4", "category": "VIDEO", "software": "video_player", "tier": 1 },
	{ "name": "backup.zip", "ext": ".zip", "category": "COMPRESSED", "software": "archive_manager", "tier": 2 },
	{ "name": "manual.pdf", "ext": ".pdf", "category": "DOCUMENT", "software": "pdf_viewer", "tier": 2 },
	{ "name": "installer.exe", "ext": ".exe", "category": "EXECUTABLE", "software": "system_runner", "tier": 2 },
	{ "name": "planilha.csv", "ext": ".csv", "category": "SPREADSHEET", "software": "calc_sheet", "tier": 3 },
	{ "name": "pagina.html", "ext": ".html", "category": "WEB", "software": "web_browser", "tier": 3 }
]

static func get_category_color(category: String) -> Color:
	if CATEGORY_COLORS.has(category):
		return CATEGORY_COLORS[category]
	return Color("#7F8C8D") # Cinza neutro

static func get_category_emoji(category: String) -> String:
	if CATEGORY_ICONS.has(category):
		return CATEGORY_ICONS[category]
	return "📦"

static func validate_delivery(extension: String, software_id: String) -> Dictionary:
	if not SOFTWARE_STATIONS.has(software_id):
		return { "is_valid": false, "reason": "Software não reconhecido." }
	
	var station = SOFTWARE_STATIONS[software_id]
	var norm_ext = extension.to_lower()
	if not norm_ext.begins_with("."):
		norm_ext = "." + norm_ext
		
	if station["allowed_extensions"].has(norm_ext):
		return { "is_valid": true, "station_name": station["name"] }
	
	return {
		"is_valid": false,
		"station_name": station["name"],
		"reason": "A extensão %s não é manipulada por %s!" % [norm_ext, station["name"]]
	}
