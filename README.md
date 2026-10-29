<p align="center">
  <img src="assets/banner.png" width="100%" alt="adobe-commerce-agents · Cinco subagentes y el servidor MCP para desarrollar módulos de Adobe Commerce en PHP">
</p>

# adobe-commerce-agents

**Cinco subagentes de Claude Code y el servidor MCP para desarrollar módulos de Adobe Commerce en PHP.**

![version](https://img.shields.io/github/package-json/v/commentemeapp/adobe-commerce-agents/main?filename=plugins%2Fadobe-commerce-agents%2F.claude-plugin%2Fplugin.json&label=version&labelColor=005278&color=FFBD38)
![license](https://img.shields.io/github/license/commentemeapp/adobe-commerce-agents?labelColor=005278&color=FFBD38)

## Instalación

```bash
/plugin marketplace add commentemeapp/adobe-commerce-agents
/plugin install adobe-commerce-agents@adobe-commerce-agents
```

Reinicia Claude Code o corre `/reload-plugins`. Los agentes aparecen en el typeahead de `@` como `adobe-commerce-agents:adobe-commerce-reviewer`, y el servidor MCP como `adobe-commerce`. Si ya tenías el servidor agregado con `claude mcp add adobe-commerce`, quítalo con `claude mcp remove adobe-commerce` para no tenerlo dos veces.

## Uso rápido

Por mención:

```
@adobe-commerce-agents:adobe-commerce-reviewer revisa lo que acabo de cambiar en app/code/Acme/Erp
```

Por lenguaje natural, sin nombrarlos:

```
antes de abrir el pull request, corre el coding standard y la compilación de DI y revisa el diff
```

Por sesión completa:

```bash
claude --agent adobe-commerce-agents:adobe-commerce-integration-architect
```

El servidor MCP también responde directo en la conversación: "Crea el módulo `Acme_Reviews` que dependa de `Magento_Catalog`", "agrega un plugin after a `Magento\Catalog\Model\Product::getName`", "que opciones tiene `bin/magento setup:static-content:deploy`?".

## Que incluye

Para Adobe Commerce (Magento Open Source) en la nube (PaaS) o en servidor propio: módulos, `di.xml`, plugins y observers, layout, `db_schema.xml`, `webapi.xml`, cache, cron y colas, deploy y modos.

| Agente                                 | Que hace                                                                                                    | Skills que precarga                                                                                                         | Herramientas del servidor MCP                                                           | Modelo    |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------- |
| `adobe-commerce-explorer`              | Mapea módulos y temas: `sequence`, plugins, preferences, observers, rutas de la Web API, tablas. Read-only. | `adobe-commerce-module-contract`, `adobe-commerce-di-and-plugins`                                                           | `explain-config-file`, `lookup-webapi`                                                  | haiku     |
| `adobe-commerce-reviewer`              | Revisa el diff antes del deploy: seguridad, ACL de la Web API, plugins, cache, contrato del módulo.         | `adobe-commerce-security`, `adobe-commerce-webapi`, `adobe-commerce-di-and-plugins`, `adobe-commerce-performance-and-cache` | `search-docs`, `read-doc`, `explain-config-file`, `lookup-webapi`, `lookup-cli-command` | `inherit` |
| `adobe-commerce-qa`                    | Corre el coding standard, PHPStan, los tests unitarios y la compilación de DI, y devuelve solo las fallas.  | `adobe-commerce-module-contract`, `adobe-commerce-deploy-and-modes`                                                         | ninguna, a propósito                                                                    | sonnet    |
| `adobe-commerce-integration-architect` | Diseña y audita integraciones con ERP, OMS y marketplaces, en PHP o con App Builder, con los trade offs.    | `adobe-commerce-webapi`, `adobe-commerce-cron-and-queues`, `adobe-commerce-events-and-observers`, `adobe-commerce-security` | `lookup-webapi`, `search-docs`, `read-doc`, `explain-config-file`                       | opus      |
| `adobe-commerce-docs-researcher`       | Busca en la documentación de Adobe Commerce y cita siempre la fuente.                                       | ninguna, a propósito                                                                                                        | `search-docs`, `read-doc`, `explain-config-file`, `lookup-cli-command`, `lookup-webapi` | haiku     |

El servidor MCP es [adobe-commerce-mcp](https://github.com/commentemeapp/adobe-commerce-mcp), ejecutado con `npx -y @commenteme/adobe-commerce-mcp`. Trae la documentación de cuatro repositorios oficiales de AdobeDocs, los comandos de `bin/magento`, el esquema OpenAPI de REST y la referencia de GraphQL; no abre conexiones ni pide credenciales. Además de lo que usan los agentes, deja en la conversación principal las herramientas de scaffolding (`scaffold-module`, `add-plugin`, `add-observer`, `add-controller`, `add-db-schema`), que devuelven los archivos para que la conversación los escriba. Las herramientas y los resources están en el [README de adobe-commerce-mcp](https://github.com/commentemeapp/adobe-commerce-mcp#herramientas).

Ningún agente precarga mas de cuatro skills ni tiene `Write`, `Edit` o `NotebookEdit`. Las skills salen de [adobe-commerce-skills](https://github.com/commentemeapp/adobe-commerce-skills). Código abierto y sin costo.

## Documentación

### Requisitos

- Claude Code con soporte de plugins.
- Node `>= 18`, para que `npx` ejecute el servidor MCP.
- Las skills de [adobe-commerce-skills](https://github.com/commentemeapp/adobe-commerce-skills), con `npx skills add commentemeapp/adobe-commerce-skills`. Sin ellas los agentes funcionan degradados: Claude Code omite las skills que no encuentra y conserva el flujo de cada agente, pero sin el conocimiento de la plataforma que hace precisas sus respuestas.
- Opcional: las skills oficiales de App Builder, con `npx skills add adobe/skills`. Ningún agente las precarga; el arquitecto las pide cuando la integración sale del proceso.
- Para `adobe-commerce-qa`: PHP y las dependencias de Composer instaladas en el proyecto (`vendor/bin/phpcs` con el Magento Coding Standard, `vendor/bin/phpunit` y, si lo ocupas, `vendor/bin/phpstan`). La compilación de DI y los controles de la base necesitan además una instalación lista para `bin/magento`.

### Como funciona

1. **La `description`** de cada agente es lo que Claude lee para decidir a quién delegar. Están escritas para que la delegación ocurra sola: "úsalo proactivamente antes de cualquier cambio estructural", "úsalo antes del deploy o del pull request".
2. **Las skills precargadas** entran completas al contexto del agente al arrancar. Las demás siguen disponibles bajo demanda con el tool `Skill`, incluidas las oficiales de App Builder si están instaladas.
3. **El servidor MCP** arranca con el plugin. Cada agente declara nombre por nombre las herramientas que usa, con el prefijo `mcp__plugin_adobe-commerce-agents_adobe-commerce__`; si el servidor no está en la sesión, el agente sigue con lo que tiene y lo dice.

El razonamiento detrás de cada decisión está en [docs/agentes.md](docs/agentes.md).

### App Builder

Este plugin y su servidor cubren el desarrollo en PHP. Si desarrollas con App Builder (eventos, webhooks, API Mesh, Admin UI SDK), el servidor oficial es [`@adobe-commerce/commerce-extensibility-tools`](https://www.npmjs.com/package/@adobe-commerce/commerce-extensibility-tools). Pide iniciar sesión en Adobe IMS (`aio auth login`), incluso para buscar documentación; su licencia es propietaria (EULA), y una de sus herramientas envía el historial de la conversación a Adobe. Las skills oficiales de App Builder (`npx skills add adobe/skills`) conviven con este plugin.

### Clones locales de la documentación

`adobe-commerce-docs-researcher` busca primero en el servidor MCP y después en clones locales de la documentación, si los encuentra. Para dárselos:

```bash
git clone --depth 1 https://github.com/AdobeDocs/commerce-php.git ~/adobedocs/commerce-php
git clone --depth 1 https://github.com/AdobeDocs/commerce-operations.en.git ~/adobedocs/commerce-operations.en
claude --add-dir ~/adobedocs
```

### Actualizar y desinstalar

| Acción      | Comando                                                         |
| ----------- | --------------------------------------------------------------- |
| Actualizar  | `/plugin marketplace update adobe-commerce-agents`              |
| Desinstalar | `/plugin uninstall adobe-commerce-agents@adobe-commerce-agents` |

### Estructura

```
.claude-plugin/marketplace.json       catálogo del marketplace de Claude Code
plugins/adobe-commerce-agents/
	.claude-plugin/plugin.json          manifiesto del plugin; mcpServers apunta a .mcp.json
	.mcp.json                           el servidor MCP adobe-commerce: npx -y @commenteme/adobe-commerce-mcp
	agents/                             los cinco agentes, uno por archivo
docs/agentes.md                       por que cada agente es como es
scripts/verificar.sh                  gate de este repositorio
scripts/skills-existen.mjs            comprueba en GitHub que existan las skills precargadas
scripts/probar-mcp.mjs                arranca el servidor MCP y comprueba las herramientas que usan los agentes
assets/                               banner del README, social preview y avatar
```

### Desarrollo

Este repositorio pide Node `>= 20` ([package.json](package.json)); el `>= 18` de arriba es para ejecutar el servidor MCP. Los cinco agentes viven en [plugins/adobe-commerce-agents/agents/](plugins/adobe-commerce-agents/agents/) y su conexión MCP en [.mcp.json](plugins/adobe-commerce-agents/.mcp.json).

```bash
git clone https://github.com/commentemeapp/adobe-commerce-agents.git
cd adobe-commerce-agents
npm ci
./scripts/verificar.sh
node scripts/probar-mcp.mjs
```

`scripts/verificar.sh` es el gate, el mismo que corre el CI: JSON válido, la misma versión en los tres manifiestos, la configuración del servidor MCP, el frontmatter de cada agente (nombre igual al archivo, `description`, tool `Skill` presente, sin `Write`, `Edit` ni `NotebookEdit`, máximo cuatro skills precargadas, prefijo MCP propio), que cada skill precargada exista en `commentemeapp/adobe-commerce-skills` o en `adobe/skills`, `claude plugin validate --strict`, Prettier, `bash -n` y una búsqueda de rastros que no deben llegar a un repositorio público. Sin red, la comprobación de las skills queda como aviso, nunca en verde.

`scripts/probar-mcp.mjs` arranca el servidor por stdio y falla si una herramienta que un agente declara no existe, o si un agente declara una de scaffolding. Para probar contra un build local del servidor:

```bash
ADOBE_COMMERCE_MCP=/ruta/a/adobe-commerce-mcp/build/index.js node scripts/probar-mcp.mjs
```

El CI suma la búsqueda de secretos con gitleaks y el control del flujo de ramas, y prueba el servidor con `npx`.

Para probar el plugin sin publicarlo:

```bash
claude --plugin-dir ./plugins/adobe-commerce-agents
```

La versión vive en tres lugares: arriba en `.claude-plugin/marketplace.json`, en la entrada del plugin del mismo archivo y en `plugins/adobe-commerce-agents/.claude-plugin/plugin.json`. Súbela en los tres a la vez: sin eso, Claude Code no entrega el cambio a quien ya tiene el plugin. Los cambios de cada versión están en [CHANGELOG.md](CHANGELOG.md).

## Contribuir · Licencia

Abre un PR contra `dev` con Conventional Commits; la promoción a `qa` y `main` es merge de la rama entera. Un agente nuevo tiene que pasar la pregunta de [docs/agentes.md](docs/agentes.md#por-qué-no-hay-más-agentes): genera ruido intermedio que la conversación principal no necesita ver? Si no, no hace falta.

[MIT](LICENSE).

---

Hecho por [commente.me](https://commente.me) · hola@commente.me
