#!/usr/bin/env node
// Comprueba que cada skill pasada como argumento exista en uno de los dos repositorios de
// los que se instalan: commentemeapp/adobe-commerce-skills (una carpeta por skill en skills/) o
// adobe/skills (cualquier SKILL.md cuyo frontmatter tenga ese name). Lo usa verificar.sh.
//
//   node scripts/skills-existen.mjs adobe-commerce-security commerce-app-eventing
//
// Código de salida: 0 si todas existen, 1 si alguna no existe, 2 si no se pudo consultar
// GitHub (sin red o con el límite de la API agotado): eso es "no verificado", nunca verde.
const skills = process.argv.slice(2);
const cabeceras = { Accept: "application/vnd.github+json", "User-Agent": "adobe-commerce-agents/verificar" };
if (process.env.GITHUB_TOKEN) cabeceras.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

const pedir = async (url, json = true) => {
	const r = await fetch(url, { headers: cabeceras, signal: AbortSignal.timeout(15_000) });
	if (!r.ok) throw new Error(`${url} respondió ${r.status}`);
	return json ? r.json() : r.text();
};

let propias;
let oficiales;
try {
	const contenido = await pedir("https://api.github.com/repos/commentemeapp/adobe-commerce-skills/contents/skills");
	propias = new Set(contenido.filter((x) => x.type === "dir").map((x) => x.name));
	const arbol = await pedir("https://api.github.com/repos/adobe/skills/git/trees/HEAD?recursive=1");
	oficiales = arbol.tree.filter((x) => x.type === "blob" && x.path.endsWith("/SKILL.md")).map((x) => x.path);
} catch (e) {
	console.log(`no se pudo consultar GitHub: ${e.message}`);
	process.exit(2);
}

const nombreDe = (texto) => texto.match(/^---\n[\s\S]*?^name:\s*["']?([^"'\n]+?)["']?\s*$/m)?.[1];
const faltan = [];
const origen = [];
try {
	for (const skill of skills) {
		if (propias.has(skill)) {
			origen.push(`${skill} (commentemeapp/adobe-commerce-skills)`);
			continue;
		}
		// En adobe/skills la carpeta suele llamarse como la skill; se confirma leyendo el name.
		let hallada = false;
		for (const ruta of oficiales.filter((p) => p.split("/").at(-2) === skill)) {
			const texto = await pedir(`https://raw.githubusercontent.com/adobe/skills/HEAD/${ruta}`, false);
			if (nombreDe(texto) === skill) {
				hallada = true;
				break;
			}
		}
		if (hallada) origen.push(`${skill} (adobe/skills)`);
		else faltan.push(skill);
	}
} catch (e) {
	console.log(`no se pudo consultar GitHub: ${e.message}`);
	process.exit(2);
}

if (faltan.length) {
	console.log(`no existen en commentemeapp/adobe-commerce-skills ni en adobe/skills: ${faltan.join(", ")}`);
	process.exit(1);
}
console.log(`las ${skills.length} skills precargadas existen: ${origen.join(", ")}`);
