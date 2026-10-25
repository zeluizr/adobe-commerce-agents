# Los cinco agentes y el servidor MCP, y por qué son así

Este documento explica las decisiones de diseño detrás de cada agente del paquete. No es documentación de uso, para eso está el [README](../README.md). Es el razonamiento: por qué cada agente corre en el modelo que corre, por qué carga esas skills y no otras, de dónde salen los comandos que corre el QA, y por qué todos son read-only.

El paquete cubre el desarrollo PHP de Adobe Commerce (Magento Open Source) y de Adobe Commerce en la nube (PaaS) o en servidor propio: módulos, `di.xml`, plugins y observers, layout, `db_schema.xml`, `webapi.xml`, cache, cron y colas, deploy y modos.

## Los principios que aplican a los cinco

Antes de entrar agente por agente, seis decisiones que atraviesan todo el paquete.

### Un subagente vale por lo que no devuelve

Un subagente corre en su propia ventana de contexto y devuelve a la conversación principal solo su respuesta final. Todo lo que leyó, todo lo que grepeó, toda la salida de los comandos que ejecutó se queda en su contexto y se descarta.

Esa es la única razón por la que un subagente vale su costo. Si una tarea no genera ruido intermedio, delegarla es más caro que hacerla en la conversación principal, porque pagas el arranque en frío de un agente que no sabe nada de lo que ya conversaron. Los cinco agentes de este paquete existen porque su trabajo produce mucho material intermedio que nadie necesita volver a leer: decenas de `di.xml` y `events.xml` repartidos por áreas, diffs completos, reportes de PHP_CodeSniffer, la salida de la compilación de DI, páginas de documentación.

Por eso cada uno tiene una regla explícita de formato de salida, y por eso `adobe-commerce-qa` es el caso más extremo del paquete: corre comandos que escupen cientos de líneas y devuelve una sola cuando todo pasa.

### Máximo cuatro skills precargadas

El campo `skills` del frontmatter inyecta el contenido completo de cada skill en el contexto del subagente al arrancar, no solo su descripción. Precargar diez skills significa que el agente empieza a trabajar con la ventana ya cargada de conocimiento que quizá no aplique al caso.

El límite de cuatro es arbitrario en el número pero no en la intención: precargas lo que el agente va a necesitar casi siempre, y dejas el resto para que lo pida si lo necesita. Los cinco agentes tienen el tool `Skill` habilitado, así que las once skills de [adobe-commerce-skills](https://github.com/zeluizr/adobe-commerce-skills) y las oficiales de App Builder siguen disponibles bajo demanda.

La consecuencia práctica es que la elección de las skills precargadas es una apuesta sobre el caso típico de cada agente, no sobre su caso máximo. El gate comprueba en GitHub que cada skill precargada exista en `zeluizr/adobe-commerce-skills` o en `adobe/skills`; sin red, lo deja como aviso.

### Las skills oficiales de App Builder: disponibles, ninguna precargada

Las skills oficiales de Adobe Commerce en [adobe/skills](https://github.com/adobe/skills) (Apache-2.0) son todas de App Builder: `commerce-app-init`, `commerce-app-eventing`, `commerce-app-webhooks`, `commerce-app-business-config`, `commerce-app-admin-ui`, `commerce-app-api-mesh`, `commerce-app-storage`, `commerce-app-migrate` y `commerce-app-review`. Ninguna cubre el código PHP de un módulo, que es el alcance de este paquete; eso lo cubren las nuestras.

El candidato natural para precargar una era `adobe-commerce-integration-architect`, porque los eventos de Adobe I/O Events y los webhooks de Adobe Commerce son una forma real de integrar. Se decidió no hacerlo, por tres razones:

- **Son procedimientos de escritura, no conocimiento de diseño.** `commerce-app-eventing` y `commerce-app-webhooks` empiezan por exigir una app ya inicializada con `commerce-app-init`, piden Node 22 y el CLI `aio`, y siguen con pasos que escriben `app.commerce.config.ts` y suscriben servicios en la Developer Console. Precargadas en un agente sin `Write` ni `Bash`, son instrucciones que el agente no puede ni debe seguir, ocupando contexto en cada invocación.
- **Sesgarían la recomendación.** El arquitecto tiene que comparar la integración dentro del proceso (Web API, observers, colas, cron) con la de fuera del proceso (App Builder). Arrancar con dos skills de App Builder y ninguna de colas dejaría la balanza inclinada antes de mirar el caso.
- **No todos los proyectos tienen App Builder.** Muchas instalaciones en servidor propio no lo usan. Precargar algo que en la mitad de los proyectos no aplica es justo lo que el límite de cuatro quiere evitar.

Lo que sí hace el arquitecto es nombrarlas en su prompt: cuando el diseño sale del proceso, pide `commerce-app-eventing`, `commerce-app-webhooks` o `commerce-app-api-mesh` con el tool `Skill` para entender el modelo de configuración de cada pieza, y deja los pasos de instalación a quien implemente. Para la documentación de App Builder, que el servidor MCP no trae, tiene `WebFetch` contra developer.adobe.com.

### Read-only por defecto

Ninguno de los cinco tiene `Write`, `Edit` ni `NotebookEdit`. Dos de ellos tienen `Bash`, y sus instrucciones acotan explícitamente para qué.

No es paranoia, es división del trabajo. Un agente que puede escribir se convierte en un desarrollador paralelo que no ve la conversación completa, y sus cambios llegan a la conversación principal como un hecho consumado que hay que revisar. Un agente que solo lee devuelve información, y la decisión de qué hacer con esa información se queda donde está el contexto acumulado.

En Adobe Commerce hay una razón más: `bin/magento` está a un comando de cambiar la base de datos, el modo de la aplicación o los módulos habilitados. `setup:upgrade`, `deploy:mode:set` y `module:enable` no se deshacen con un `git checkout`. Los dos agentes con `Bash` tienen escrito en su prompt qué pueden correr, y ninguno lee `app/etc/env.php`, que guarda las credenciales del ambiente.

### El servidor MCP es fuente, no cerebro

El plugin trae el servidor MCP `adobe-commerce`, que es [adobe-commerce-mcp](https://github.com/zeluizr/adobe-commerce-mcp) ejecutado con `npx -y adobe-commerce-mcp`. Viaja con su conocimiento dentro del paquete: la documentación de cuatro repositorios de AdobeDocs (`commerce-php`, `commerce-frontend-core`, `commerce-webapi` y `commerce-operations.en`), la referencia de `bin/magento`, el esquema OpenAPI de REST y la referencia de GraphQL. No abre conexiones ni pide credenciales.

Expone diez herramientas. Cinco son de consulta (`search-docs`, `read-doc`, `explain-config-file`, `lookup-cli-command`, `lookup-webapi`) y cinco de scaffolding (`scaffold-module`, `add-plugin`, `add-observer`, `add-controller`, `add-db-schema`). La regla fue la misma que para las skills: cada agente recibe solo las de consulta que su caso típico necesita, y ninguno recibe las de scaffolding. Esas devuelven archivos para escribir, y escribir es trabajo de la conversación principal. Un agente read-only con herramientas de scaffolding sería una contradicción, y `scripts/probar-mcp.mjs` falla si alguien se la da a uno.

Las herramientas MCP de un plugin llevan el prefijo `mcp__plugin_adobe-commerce-agents_adobe-commerce__`, y así aparecen en el campo `tools` de cada agente. Ese campo es una lista cerrada: lo que no está ahí, el agente no lo ve. Por eso cada agente declara nombre por nombre las herramientas que usa, y por eso el gate arranca el servidor de verdad y comprueba que cada nombre exista. Si `adobe-commerce-mcp` renombra una herramienta, falla el CI de este repositorio antes de fallar en la sesión de alguien.

Todos los agentes que usan el servidor tienen la misma instrucción de degradación: si las herramientas no aparecen en la sesión, siguen con lo que tienen y lo dicen en una línea. El servidor mejora la respuesta; su ausencia no la impide. Eso importa desde el primer día: en la versión 0.1.0 el paquete todavía no está en npm, y el servidor no arranca hasta que se publique.

No existe un servidor MCP oficial para el desarrollo PHP de Adobe Commerce. El oficial, `@adobe-commerce/commerce-extensibility-tools`, es de App Builder; el README cuenta lo que pide.

### La description es el router, no la documentación

Claude decide a qué agente delegar leyendo el campo `description` de cada uno. No lee el cuerpo del archivo hasta que ya decidió delegar.

Por eso las cinco descripciones dicen cuándo delegar, no qué hace el agente por dentro. Tres de ellas incluyen una instrucción de proactividad explícita, porque la diferencia entre un agente que se usa y uno que no se usa suele ser esa frase.

## `adobe-commerce-explorer`

**Qué problema resuelve.** Nadie debería tocar un módulo de Adobe Commerce sin saber después de qué módulos carga, qué plugins y preferences declara, en qué áreas, a qué eventos reacciona y qué expone por la Web API. Averiguarlo a mano son veinte llamadas de Glob, Grep y Read que llenan la conversación de árboles de `app/code` y fragmentos de XML.

**Por qué haiku.** Es el agente más barato del paquete y el que más se invoca. Su trabajo es de reconocimiento de patrones sobre archivos con formato conocido, no de razonamiento. `etc/module.xml` declara el `sequence`, `etc/di.xml` declara plugins, `etc/webapi.xml` declara rutas: identificar eso no necesita un modelo caro.

**Por qué esas dos skills.** `adobe-commerce-module-contract` le da el vocabulario del esqueleto de un módulo: `registration.php`, `module.xml`, `sequence`, `composer.json` y la diferencia entre `etc/` y `etc/<area>/`. `adobe-commerce-di-and-plugins` le da el modelo mental de lo que más se repite en el mapa de cualquier proyecto real: quién intercepta qué, con qué tipo de plugin y en qué área. Las demás (layout, Web API, esquema) las pide cuando el proyecto las trae.

**Por qué read-only estricto.** Es un cartógrafo. Devuelve un mapa, no un plan de obra.

**Qué recibe del servidor MCP.** `explain-config-file` y `lookup-webapi`, nada más. La primera para nombrar con precisión un archivo de configuración poco común y su área; la segunda para saber si una ruta o un tipo del proyecto extiende una operación nativa. El prompt le prohíbe usarlas para explorar la documentación, que es trabajo del investigador.

**Qué devuelve.** Un resumen estructurado de unas cuarenta líneas: qué hay, dónde está qué, intercepciones, contratos expuestos y puntos de atención. Nunca contenido de archivos.

## `adobe-commerce-reviewer`

**Qué problema resuelve.** El momento más caro para descubrir un problema es después del deploy: un `anonymous` en `webapi.xml` ya expuso datos, un `cacheable="false"` en `default.xml` ya dejó sin cache todo el storefront. Este agente mete una revisión entre escribir el código y desplegarlo.

**Por qué `inherit`.** Es el único agente del paquete que hereda el modelo de la conversación principal. Revisar código es la tarea donde la calidad del modelo se nota más directamente en la calidad del resultado, y es donde el usuario ya expresó su preferencia al elegir con qué modelo trabajar.

**Por qué esas cuatro skills.** Son los cuatro ejes donde un error de un módulo cuesta caro en producción. `adobe-commerce-security` cubre ACL del Admin, CSRF, escape, mass assignment, secretos y SSRF. `adobe-commerce-webapi` cubre la otra mitad de la superficie de seguridad: qué `resource` tiene cada ruta y quién llega a ella. `adobe-commerce-di-and-plugins` cubre lo que la guía de code review de Adobe Commerce pide revisar a mano: plugins `around` evitables, plugins que devuelven el tipo equivocado, `ObjectManager` directo. `adobe-commerce-performance-and-cache` cubre la cache de página completa, que se rompe con una línea.

Estas cuatro llenan el cupo. Es el agente con más contexto precargado, y se justifica porque la revisión es la tarea donde el conocimiento previo evita más falsos negativos. Los ejes de su prompt siguen la lista de la [guía de code review](https://experienceleague.adobe.com/en/docs/commerce-operations/implementation-playbook/best-practices/development/code-review): consultas en loops, `cacheable="false"`, plugins `around`, SQL crudo, datos de clientes en loops.

**Por qué tiene `Bash`.** Porque la primera instrucción del agente es correr `git diff`. El `Bash` está acotado por instrucción a inspección: git, ls, lectura de fragmentos. Nada de `bin/magento`, nada de Composer.

**Qué recibe del servidor MCP.** Las cinco herramientas de consulta, con una instrucción precisa: verificar antes de reportar, nunca revisar en su lugar. `lookup-cli-command` está porque un diff que toca un script de deploy puede llamar a un comando o una opción que no existe.

**Por qué `memory: project`.** Es el agente que más se beneficia de recordar: convenciones del equipo, falsos positivos ya discutidos, decisiones aceptadas. Nunca guarda credenciales, nombres de clientes ni datos de tiendas.

**Qué devuelve.** Tres niveles fijos: Crítico (bloquea el deploy), Aviso (corregir antes del release), Sugerencia. Un nivel vacío aparece igual, con la palabra Ninguno.

## `adobe-commerce-qa`

**Qué problema resuelve.** Correr el coding standard, los tests y la compilación de DI genera cientos de líneas de salida de las que importan cinco.

**Por qué sonnet.** Haiku se queda corto para distinguir el error real del ruido que lo rodea en una compilación de DI o en un reporte de PHP_CodeSniffer; opus sería desperdicio, porque una vez identificado el error hay que reportarlo, no razonar sobre él.

**Por qué esas dos skills.** `adobe-commerce-module-contract` porque la verificación no termina en los comandos: hay que mirar si la versión del `composer.json` acompaña el tipo de cambio, si sobra un `setup_version` y si los tres archivos del esqueleto dan el mismo nombre. `adobe-commerce-deploy-and-modes` porque el QA corre `bin/magento` y tiene que saber qué hace cada comando, qué cambia el modo y qué toca la base, para no correr lo que no debe.

**Los comandos que corre, y de dónde salen.** Solo los que la documentación de Adobe Commerce trae. Si la documentación no trae un comando, no entra.

| Comando                                                                             | Para qué                                                         | Fuente                                                                                                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `composer validate`                                                                 | Valida el `composer.json` del módulo                             | [Code review best practices, Automation](https://experienceleague.adobe.com/en/docs/commerce-operations/implementation-playbook/best-practices/development/code-review)                                                                                                                                          |
| `vendor/bin/phpcs --standard=Magento2 <ruta>`                                       | El Magento Coding Standard                                       | [Coding standards](https://developer.adobe.com/commerce/php/coding-standards/)                                                                                                                                                                                                                                   |
| `vendor/bin/phpstan analyze <ruta>`                                                 | Análisis estático, si el proyecto tiene PHPStan                  | [Code review best practices, Automation](https://experienceleague.adobe.com/en/docs/commerce-operations/implementation-playbook/best-practices/development/code-review)                                                                                                                                          |
| `vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist <ruta>/Test/Unit`            | Los tests unitarios del módulo                                   | [Unit tests, Command line](https://developer.adobe.com/commerce/testing/guide/unit/command-line/)                                                                                                                                                                                                                |
| `bin/magento deploy:mode:show`                                                      | Saber el modo antes de compilar                                  | [Set the mode](https://experienceleague.adobe.com/en/docs/commerce-operations/configuration-guide/cli/set-mode)                                                                                                                                                                                                  |
| `bin/magento setup:di:compile`                                                      | La compilación de DI: plugins, factories, proxies, interceptores | [Code compiler](https://experienceleague.adobe.com/en/docs/commerce-operations/configuration-guide/cli/code-compiler) y [Code review best practices, Automation](https://experienceleague.adobe.com/en/docs/commerce-operations/implementation-playbook/best-practices/development/code-review)                  |
| `bin/magento setup:db-declaration:generate-whitelist --module-name=<Vendor_Module>` | Que `db_schema_whitelist.json` no cambie al regenerarlo          | [Code review best practices, Automation](https://experienceleague.adobe.com/en/docs/commerce-operations/implementation-playbook/best-practices/development/code-review) y [Declarative schema, migration](https://developer.adobe.com/commerce/php/development/components/declarative-schema/migration-scripts/) |
| `bin/magento setup:db:status`                                                       | Si el código pide `setup:upgrade`, por el código de salida       | [Check the database status](https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/tutorials/database-status)                                                                                                                                                                         |

De las siete páginas citadas, seis vienen dentro del servidor MCP. La de los tests unitarios es del repositorio `AdobeDocs/commerce-testing` (Apache-2.0), que el servidor no incluye. Qué directorios regenera `setup:di:compile` lo dice [Directory and cache clearing](https://developer.adobe.com/commerce/php/development/components/clear-directories/), y por eso el QA lo avisa en su reporte.

**Lo que quedó fuera, a propósito.** La guía de code review compila con una secuencia completa que deshabilita y rehabilita todos los módulos, borra `generated/`, `var/` y `pub/static/` y pasa la aplicación a production y de vuelta a developer. El QA corre solo `setup:di:compile` de esa secuencia: el resto cambia el estado de la instalación. `bin/magento setup:upgrade --dry-run=1` está documentado y no cambia la base, pero es el mismo comando que sin la bandera la cambia, y la página no dice qué más toca en disco; queda fuera. `bin/magento dev:tests:run` está documentado, pero corre las suites de todo el código base y no las del módulo. Los tests de integración y los funcionales necesitan una base y una instancia configuradas aparte, y tampoco entran.

`setup:db-declaration:generate-whitelist` es el único comando que escribe en el repositorio. La guía dice correrlo y comprobar que el archivo no cambió; el QA lo corre solo si el whitelist estaba limpio antes, y si lo cambió, lo reporta como falla y lo devuelve a su estado con `git restore`, porque el cambio lo hizo él.

**Por qué no tiene herramientas MCP.** Su trabajo es correr comandos y filtrar salida; consultar documentación durante una verificación es exactamente el ruido que existe para evitar.

**Qué devuelve.** Si todo pasa, una línea. Si algo falla, solo las fallas, con archivo, línea, el mensaje recortado (en PHP_CodeSniffer, el nombre del sniff) y las líneas de stack del proyecto, descartando `vendor/` y `generated/`.

## `adobe-commerce-integration-architect`

**Qué problema resuelve.** Es el único agente del paquete que emite juicio. Los otros cuatro reportan hechos; este propone una arquitectura y se hace responsable de sus trade offs.

**Por qué opus.** Porque diseñar una integración de catálogo, stock o pedidos con un ERP es la tarea del paquete donde equivocarse cuesta más y donde el error tarda más en aparecer. Una sincronización mal diseñada no falla el primer día; falla el día que el consumidor de la cola se detiene y nadie lo nota.

**Por qué esas cuatro skills.** `adobe-commerce-webapi` cubre cómo entra el sistema externo: rutas, contratos de servicio, tokens y recursos de ACL. `adobe-commerce-cron-and-queues` cubre el procesamiento fuera del request, que es donde termina viviendo cualquier integración seria. `adobe-commerce-events-and-observers` cubre cómo se reacciona a lo que pasa en la tienda, y deja claro dónde empiezan los eventos de App Builder. `adobe-commerce-security` cubre lo que toda integración trae consigo: credenciales del sistema externo, webhooks entrantes y llamadas salientes.

Las skills oficiales de App Builder quedaron fuera de la precarga por las razones de arriba, y el agente sabe pedirlas.

**Qué recibe del servidor MCP.** `lookup-webapi`, `search-docs`, `read-doc` y `explain-config-file`. La instrucción es consultar el servidor antes de WebFetch, y usar WebFetch para App Builder y para el sistema externo, nunca contra una instalación.

**Por qué `memory: project`.** Las decisiones arquitectónicas se toman una vez y se viven durante años.

**Las dos reglas innegociables.** Nunca proponer una integración sin estrategia de reintento y sin estrategia de reconciliación, y siempre explicitar los trade offs: consistencia contra latencia, push contra pull, idempotencia, acoplamiento, volumen y seguridad. Y una tercera propia de esta plataforma: la elección entre integrar dentro del proceso o con App Builder se expone como una opción con su costo, nunca se da por hecha.

**Qué devuelve.** Contexto entendido, opciones consideradas (mínimo dos), recomendación, puntos de falla, reintento y reconciliación, y qué queda abierto.

## `adobe-commerce-docs-researcher`

**Qué problema resuelve.** Buscar en la documentación consume mucho contexto para devolver poca información. La de Adobe Commerce está repartida entre developer.adobe.com y Experience League, en cuatro repositorios distintos.

**Por qué haiku.** Su trabajo es buscar y citar, no razonar.

**Por qué no precarga ninguna skill.** Un agente de investigación que arranca con skills en contexto arranca con una hipótesis sobre dónde está la respuesta, y esa hipótesis sesga la búsqueda. Sigue teniendo el tool `Skill` para cuando la pregunta lo pida.

**El orden de búsqueda.** Primero el servidor MCP, con las cinco herramientas de consulta. Segundo, clones locales de los repositorios de AdobeDocs, si están en la sesión. Tercero, la documentación del propio proyecto. Y solo después, `WebFetch` contra developer.adobe.com, Experience League y AdobeDocs en GitHub, que es también donde va directo para App Builder.

**Por qué `memory: user`.** El mapa de la documentación no cambia de un proyecto a otro.

**La regla de cita.** Toda afirmación va con su fuente: la herramienta y la URL de la página cuando viene del servidor MCP, ruta y línea cuando viene de un archivo, URL completa cuando viene de la web. Lo que aporte de su propio conocimiento va marcado como no verificado en la documentación.

## Por qué no hay más agentes

La pregunta que decide si vale la pena un agente nuevo es siempre la misma: ¿esta tarea genera ruido intermedio que la conversación principal no necesita ver?

Si la respuesta es no, el agente sale más caro que el trabajo. Por eso no hay un agente "Developer" que escriba módulos: escribir código es la tarea que más se beneficia del contexto acumulado, y para eso la conversación principal tiene las herramientas de scaffolding del servidor MCP.

Y por eso tampoco un agente es siempre la respuesta correcta. Si lo que necesitas es una restricción sobre un directorio concreto, una regla en `.claude/rules/` con `paths:` acotado es más barata y más precisa. Si lo que necesitas es que el equipo comparta convenciones, eso va en `CLAUDE.md`.

Los agentes son para el trabajo ruidoso, acotado y repetitivo. Cinco alcanzan.
