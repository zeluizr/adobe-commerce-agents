# Changelog

Todos los cambios de adobe-commerce-agents. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y las versiones siguen [SemVer](https://semver.org/lang/es/).

## [Sin publicar]

## [0.1.0] - 2026-10-25

### Agregado

- Cinco subagentes para el desarrollo PHP de Adobe Commerce (Magento Open Source) y Adobe Commerce en la nube o en
  servidor propio: `adobe-commerce-explorer` (haiku), `adobe-commerce-reviewer` (`inherit`, con memoria de proyecto),
  `adobe-commerce-qa` (sonnet), `adobe-commerce-integration-architect` (opus) y `adobe-commerce-docs-researcher`
  (haiku). Ninguno tiene `Write`, `Edit` ni `NotebookEdit`.
- Skills precargadas de [adobe-commerce-skills](https://github.com/zeluizr/adobe-commerce-skills), como máximo cuatro
  por agente. Las oficiales de App Builder de `adobe/skills` quedan disponibles bajo demanda, sin precargar.
- El servidor MCP `adobe-commerce` ([adobe-commerce-mcp](https://github.com/zeluizr/adobe-commerce-mcp)), ejecutado con
  `npx -y adobe-commerce-mcp`. Los agentes declaran las cinco herramientas de consulta que usan; las de scaffolding
  quedan en la conversación principal.
- `adobe-commerce-qa` corre solo comandos documentados por Adobe Commerce: `composer validate`, el Magento Coding
  Standard, PHPStan, los tests unitarios del módulo, `setup:di:compile`, la regeneración del whitelist del esquema y
  `setup:db:status`. Las páginas están en `docs/agentes.md`.
- Gate del repositorio (`scripts/verificar.sh`): JSON válido, misma versión en los tres manifiestos, configuración del
  servidor MCP, frontmatter de los agentes, skills precargadas que existen en `zeluizr/adobe-commerce-skills` o en
  `adobe/skills` (`scripts/skills-existen.mjs`), `claude plugin validate --strict`, Prettier, `bash -n` y búsqueda de
  rastros.
- `scripts/probar-mcp.mjs`: arranca el servidor MCP por stdio y comprueba que cada herramienta que usa un agente exista
  y que ninguno declare una de scaffolding. Con `ADOBE_COMMERCE_MCP` arranca un build local.
- CI en GitHub Actions con el gate, la prueba del servidor MCP, gitleaks y el control del flujo `dev → qa → main`.

### Pendiente

- `adobe-commerce-mcp` todavía no está publicado en npm: hasta entonces el servidor no arranca con el plugin, los
  agentes siguen sin él y el job `mcp` del CI falla.
