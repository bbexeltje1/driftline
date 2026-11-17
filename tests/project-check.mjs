// Static guard for default.project.json against the Rojo 7.7.1 schema (src/project.rs):
//   - an Instance Description may contain only $-keys plus child instances;
//   - every instance property must live inside "$properties";
//   - property values follow Rojo's resolution rules (src/resolution.rs):
//     CFrame = 12 numbers, Size/Color/Position = 3 numbers, Material = enum name, etc.
// The fallback place builder accepts looser input, so it cannot prove compatibility.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const projectFile = process.argv[2] || path.join(root, "default.project.json");
const project = JSON.parse(await fs.readFile(projectFile, "utf8"));
const failures = [];

const knownDollarKeys = new Set(["$className", "$path", "$properties", "$attributes", "$ignoreUnknownInstances", "$id", "$schema"]);
const topLevelKeys = new Set(["$schema", "name", "tree", "emitLegacyScripts", "servePort", "servePlaceIds", "placeId", "gameId", "globIgnorePaths", "glob"]);
const knownMaterials = new Set(["Plastic", "SmoothPlastic", "Neon", "Slate", "Concrete", "Metal", "Wood", "WoodPlanks", "Glass", "ForceField", "Grass", "LeafyGrass", "Ice", "Brick", "Granite", "Marble", "Cobblestone", "Sand", "Sandstone", "Fabric", "Foil", "Rock", "Pebble", "Basalt", "Asphalt", "Limestone", "Pavement", "Corroded", "CrackedLava", "DiamondPlate", "Glacier", "Mud", "Ground", "Salt", "Rubber", "Snow", "Air"]);
const vectorProps = { Size: 3, Color: 3, Position: 3, Orientation: 3 };
const boolProps = new Set(["Anchored", "CanCollide", "CanQuery", "CanTouch", "Neutral", "Locked"]);
const numberProps = new Set(["Transparency", "Reflectance"]);

function isObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function checkProperties(where, props) {
  for (const [name, value] of Object.entries(props)) {
    const here = `${where}.$properties.${name}`;
    if (name === "Color3") {
      failures.push(`${here}: Roblox property is named "Color" (BasePart), not "Color3"`);
    } else if (name === "CFrame") {
      if (!Array.isArray(value) || value.length !== 12 || value.some((n) => typeof n !== "number")) {
        failures.push(`${here}: CFrame must be 12 numbers (position + 3x3 matrix)`);
      }
    } else if (name in vectorProps) {
      if (!Array.isArray(value) || value.length !== vectorProps[name] || value.some((n) => typeof n !== "number")) {
        failures.push(`${here}: ${name} must be ${vectorProps[name]} numbers`);
      }
    } else if (name === "Material") {
      if (!knownMaterials.has(value)) failures.push(`${here}: unknown Material "${value}"`);
    } else if (boolProps.has(name)) {
      if (typeof value !== "boolean") failures.push(`${here}: ${name} must be true or false`);
    } else if (numberProps.has(name)) {
      if (typeof value !== "number") failures.push(`${here}: ${name} must be a number`);
    }
  }
}

async function walk(node, where) {
  if (!isObject(node)) return;
  for (const key of Object.keys(node)) {
    if (key.startsWith("$") && !knownDollarKeys.has(key)) {
      failures.push(`${where}: unknown Rojo key "${key}"`);
    }
  }
  if ("$className" in node) {
    // Instance Description: every non-$ key is either a child instance (object) or a property.
    for (const [key, value] of Object.entries(node)) {
      if (key.startsWith("$") || isObject(value)) continue;
      failures.push(`${where}/${key}: property "${key}" sits outside "$properties". Rojo reads it as a child instance; move it into "$properties".`);
    }
    if (node.$properties !== undefined) {
      if (!isObject(node.$properties)) failures.push(`${where}.$properties must be an object`);
      else checkProperties(where, node.$properties);
    }
  }
  if (node.$path !== undefined) {
    try {
      await fs.stat(path.join(root, node.$path));
    } catch {
      failures.push(`${where}: $path "${node.$path}" does not exist`);
    }
  }
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("$")) continue;
    if (isObject(value)) await walk(value, `${where}/${key}`);
  }
}

// Luau paths: Rojo places a script's sibling folders beside it, so a server Script must reach
// "Modules" through script.Parent (the ServerScriptService folder). script.Modules is nil at runtime.
const luauRoot = path.join(root, "src");
async function listLuau(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const out = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await listLuau(full)));
    else if (entry.name.endsWith(".luau")) out.push(full);
  }
  return out;
}
for (const file of await listLuau(luauRoot)) {
  const lines = (await fs.readFile(file, "utf8")).split("\n");
  lines.forEach((line, index) => {
    if (/(^|[^.\w])script\.Modules\b/.test(line.replace(/--.*$/, ""))) {
      failures.push(`${path.relative(root, file)}:${index + 1}: "script.Modules" is nil here; use script.Parent.Modules`);
    }
  });
}

for (const key of Object.keys(project)) {
  if (!topLevelKeys.has(key)) failures.push(`top-level key "${key}" is not a Rojo project key`);
}
await walk(project.tree, "#tree");

if (failures.length > 0) {
  console.error(`Project check failed (Rojo 7.7.1 would reject ${path.relative(root, projectFile)}):`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
const count = JSON.stringify(project.tree).split('"$properties"').length - 1;
console.log(`PASS Rojo project schema: properties in $properties, Rojo value shapes, $path folders valid (${count} instances with $properties)`);
