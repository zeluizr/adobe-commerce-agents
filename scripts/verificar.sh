#!/usr/bin/env bash
# Gate del repositorio. Es el mismo comando en la máquina y en el CI: si algo falla,
# sale con código distinto de cero y nada se promueve de rama.
#
#   ./scripts/verificar.sh
#
# "No verificado" se informa como aviso, nunca como verde. En el CI (CI=true) la
# falta de una herramienta obligatoria es un error.
set -uo pipefail
# Las búsquedas con tildes necesitan UTF-8: en el locale C, [ãõç] atrapa cualquier letra acentuada.
export LC_ALL=C.UTF-8
cd "$(dirname "$0")/.." || exit 1

FALLO=0
paso() { printf '\n\033[1m── %s ──\033[0m\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
mal() {
	printf '  \033[31m✗\033[0m %s\n' "$1"
	FALLO=1
}
aviso() { printf '  \033[33m⚠\033[0m %s\n' "$1"; }

PLUGIN_NOMBRE="adobe-commerce-agents"
MARKETPLACE=".claude-plugin/marketplace.json"
PLUGIN_DIR="plugins/$PLUGIN_NOMBRE"
PLUGIN="$PLUGIN_DIR/.claude-plugin/plugin.json"
MCP="$PLUGIN_DIR/.mcp.json"
AGENTES_DIR="$PLUGIN_DIR/agents"
SERVIDOR="adobe-commerce"
PREFIJO="mcp__plugin_${PLUGIN_NOMBRE}_${SERVIDOR}__"
MAX_SKILLS=4

# ─────────────────────────────── JSON ───────────────────────────────
paso "JSON válido"
JSON_ROTOS=0
while IFS= read -r -d '' f; do
	if ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$f" 2>/dev/null; then
		mal "JSON inválido: $f"
		JSON_ROTOS=1
	fi
done < <(find . -name '*.json' -not -path './node_modules/*' -not -path './.git/*' -print0)
[ "$JSON_ROTOS" -eq 0 ] && ok "todos los .json se leen"

# ─────────────────────────────── manifiestos ───────────────────────────────
paso "Versión igual en los tres manifiestos"
if [ -f "$MARKETPLACE" ] && [ -f "$PLUGIN" ]; then
	VERSIONES=$(node -e '
		const fs = require("fs");
		const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
		const p = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
		const entrada = (m.plugins || []).find((x) => x.name === process.argv[3]) || {};
		console.log([m.version, entrada.version, p.version].join(" "));
	' "$MARKETPLACE" "$PLUGIN" "$PLUGIN_NOMBRE")
	read -r V1 V2 V3 <<<"$VERSIONES"
	if [ -n "$V1" ] && [ "$V1" = "$V2" ] && [ "$V2" = "$V3" ]; then
		ok "versión $V1 en marketplace, entrada del plugin y plugin.json"
	else
		mal "versiones distintas: marketplace=$V1 entrada=$V2 plugin.json=$V3"
	fi
else
	aviso "todavía no existen los manifiestos (no verificado)"
fi

# ─────────────────────────────── servidor MCP ───────────────────────────────
paso "Servidor MCP $SERVIDOR"
if [ -f "$MCP" ] && [ -f "$PLUGIN" ]; then
	node -e '
		const fs = require("fs");
		const p = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
		const mcp = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
		const servidor = process.argv[3];
		const errores = [];
		if (p.mcpServers !== "./.mcp.json") errores.push("plugin.json no apunta mcpServers a ./.mcp.json");
		const s = (mcp.mcpServers || {})[servidor];
		if (!s) errores.push(`.mcp.json no declara el servidor ${servidor}`);
		else {
			if (s.command !== "npx") errores.push("el comando del servidor no es npx");
			const args = s.args || [];
			if (!args.includes("-y")) errores.push("falta -y en los args de npx");
			if (!args.some((a) => /^@commenteme\/adobe-commerce-mcp(@.+)?$/.test(a))) errores.push("los args no ejecutan el paquete @commenteme/adobe-commerce-mcp");
		}
		if (errores.length) { console.error(errores.join("\n")); process.exit(1); }
	' "$PLUGIN" "$MCP" "$SERVIDOR" 2>/tmp/mcp-errores.txt && ok "plugin.json y .mcp.json ejecutan npx -y @commenteme/adobe-commerce-mcp" || {
		sed 's/^/    /' /tmp/mcp-errores.txt
		mal "configuración del servidor MCP"
	}
else
	aviso "todavía no existe $MCP (no verificado)"
fi

# ─────────────────────────────── agentes ───────────────────────────────
paso "Agentes: frontmatter, skills precargadas y herramientas MCP"
if [ -d "$AGENTES_DIR" ] && ls "$AGENTES_DIR"/*.md >/dev/null 2>&1; then
	AGENTES_MAL=0
	for f in "$AGENTES_DIR"/*.md; do
		ERR=$(node -e '
			const fs = require("fs");
			const path = require("path");
			const [archivo, prefijo, maxSkills] = process.argv.slice(1);
			const s = fs.readFileSync(archivo, "utf8");
			const fm = s.match(/^---\n([\s\S]*?)\n---/);
			const errores = [];
			if (!fm) { console.log("sin frontmatter"); process.exit(0); }
			const lineas = fm[1].split("\n");
			const campo = (k) => { const l = lineas.find((x) => x.startsWith(k + ":")); return l ? l.slice(k.length + 1).trim() : null; };
			const nombre = campo("name");
			if (nombre !== path.basename(archivo, ".md")) errores.push(`name "${nombre}" distinto del archivo`);
			const desc = campo("description");
			if (!desc) errores.push("sin description");
			else if ([...desc].length > 1024) errores.push("description de más de 1024 caracteres");
			const tools = (campo("tools") || "").split(",").map((t) => t.trim()).filter(Boolean);
			if (!tools.includes("Skill")) errores.push("no tiene el tool Skill");
			for (const t of ["Write", "Edit", "NotebookEdit"]) if (tools.includes(t)) errores.push(`tiene ${t}: los agentes son read-only`);
			for (const t of tools) {
				if (t.startsWith("mcp__") && !t.startsWith(prefijo)) errores.push(`tool MCP con prefijo ajeno: ${t}`);
			}
			const i = lineas.findIndex((l) => l.startsWith("skills:"));
			let skills = [];
			if (i >= 0) for (let j = i + 1; j < lineas.length && /^\s+- /.test(lineas[j]); j++) skills.push(lineas[j].replace(/^\s+- /, "").trim());
			if (skills.length > Number(maxSkills)) errores.push(`${skills.length} skills precargadas (máximo ${maxSkills})`);
			console.log(errores.join("; "));
		' "$f" "$PREFIJO" "$MAX_SKILLS")
		if [ -n "$ERR" ]; then
			mal "$(basename "$f"): $ERR"
			AGENTES_MAL=1
		fi
	done
	[ "$AGENTES_MAL" -eq 0 ] && ok "$(ls "$AGENTES_DIR"/*.md | wc -l | tr -d ' ') agentes con frontmatter correcto"

	# Las skills precargadas tienen que existir en commentemeapp/adobe-commerce-skills (carpeta skills/) o
	# en adobe/skills (cualquier SKILL.md con ese name). Necesita red: sin ella, aviso.
	SKILLS=$(grep -hE '^[[:space:]]+- [a-z0-9-]+$' "$AGENTES_DIR"/*.md | sed -E 's/^[[:space:]]+- //' | sort -u)
	if [ -z "$SKILLS" ]; then
		ok "ningún agente precarga skills"
	else
		RESULTADO=$(node scripts/skills-existen.mjs $SKILLS 2>&1)
		CODIGO=$?
		case "$CODIGO" in
		0) ok "$RESULTADO" ;;
		2) aviso "$RESULTADO (no verificado)" ;;
		*)
			printf '%s\n' "$RESULTADO" | sed 's/^/    /'
			mal "hay skills precargadas que no existen"
			;;
		esac
	fi
else
	aviso "todavía no hay agentes (no verificado)"
fi

# ─────────────────────────────── claude plugin validate ───────────────────────────────
paso "claude plugin validate --strict"
if command -v claude >/dev/null 2>&1; then
	for par in ".:$MARKETPLACE" "$PLUGIN_DIR:$PLUGIN" "$AGENTES_DIR:$AGENTES_DIR"; do
		objetivo="${par%%:*}"
		requisito="${par#*:}"
		if [ ! -e "$requisito" ]; then
			aviso "todavía no existe $requisito (no verificado)"
			continue
		fi
		if SALIDA=$(claude plugin validate --strict "$objetivo" 2>&1); then
			ok "válido: $objetivo"
		else
			printf '%s\n' "$SALIDA" | sed 's/^/    /'
			mal "claude plugin validate falló en $objetivo"
		fi
	done
elif [ "${CI:-}" = "true" ]; then
	mal "falta el CLI de Claude Code en el CI"
else
	aviso "no está instalado el CLI de Claude Code (no verificado)"
fi

# ─────────────────────────────── formato ───────────────────────────────
paso "Formato (Prettier)"
if npx --no-install prettier --check . >/dev/null 2>&1; then
	ok "todo formateado"
else
	npx --no-install prettier --list-different . 2>/dev/null | sed 's/^/    /'
	mal "hay archivos sin formatear: corre 'npm run format'"
fi

paso "Sintaxis de Bash"
SH_ROTOS=0
while IFS= read -r -d '' f; do
	if ! bash -n "$f" 2>/dev/null; then
		mal "error de sintaxis: $f"
		SH_ROTOS=1
	fi
done < <(find . -name '*.sh' -type f -not -path './node_modules/*' -not -path './.git/*' -print0)
[ "$SH_ROTOS" -eq 0 ] && ok "todos los scripts de shell pasan bash -n"

# ─────────────────────────────── filtraciones ───────────────────────────────
# El repositorio es público: nada de la máquina de quien lo escribe, nada de clientes,
# nada del idioma de los proyectos de origen. Este archivo queda fuera de la búsqueda
# porque contiene los propios patrones.
paso "Rastros de los proyectos de origen"
EXCLUIR=(--exclude-dir=node_modules --exclude-dir=.git --exclude=package-lock.json --exclude=verificar.sh)

buscar() {
	local descripcion="$1" patron="$2"
	shift 2
	local hallado
	hallado=$(grep -rniIE "${EXCLUIR[@]}" "$patron" "$@" 2>/dev/null || true)
	if [ -n "$hallado" ]; then
		printf '%s\n' "$hallado" | head -20 | sed 's/^/    /'
		mal "$descripcion"
	else
		ok "sin $descripcion"
	fi
}

buscar "rutas de una máquina" '/Users/|/Volumes/|/home/[a-z]|\.dante/' .
buscar "correos personales" '[a-z0-9._%+-]+@(gmail|me|icloud|hotmail|outlook|yahoo)\.com' .
buscar "enlaces de referidos en el plugin" 'referral' "$PLUGIN_DIR"
buscar "nombres de clientes" 'construplaza|drsimi|rutpay|casaideas|magriffe|manchile' .
buscar "rastros de otras plataformas" 'vtex|shopify' .
buscar "travesones" '—' .
buscar "portugués" '[ãõç]|\bnao\b|\bnão\b|producao|produção|esteira|armazenamento|você|\btambém\b|\bentão\b' .

# ─────────────────────────────── resultado ───────────────────────────────
echo
if [ "$FALLO" -eq 0 ]; then
	printf '\033[32m✓ gate en verde\033[0m\n'
else
	printf '\033[31m✗ gate en rojo\033[0m\n'
fi
exit "$FALLO"
