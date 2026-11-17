// Static guard for default.project.json, following Rojo 7.7.1's rules (resolution.rs):
// CFrame must be a 12-number array, Color3/Vector3 3-number arrays, Material an enum name.
// The fallback place builder accepts looser input, so this is what catches a Rojo build failure.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const project = JSON.parse(await fs.readFile(path.join(root, "default.project.json"), "utf8"));
const failures = [];
const enumNames = new Set(["Plastic", "SmoothPlastic", "Neon", "Slate", "Concrete", "Metal", "Wood", "Glass", "ForceField", "Grass", "Ice", "Brick", "Granite", "Marble", "Cobblestone", "Sand", "Fabric", "Foil", "Rock", "Pebble", "Basalt", "Asphalt", "Limestone", "Pavement", "Corroded", "CrackedLava", "DiamondPlate", "Glacier", "Mud", "Ground", "Salt", "WoodPlanks", "Rubber", "LeafyGrass", "Sandstone", "Snow", "Air"]);
const vectorKeys = { Size: 3, Color3: 3, Position: 3 };

async function walk(node, where) {
  if (Array.isArray(node) || node === null || typeof node !== "object") return;
  for (const [key, value] of Object.entries(node)) {
    const here = `${where}/${key}`;
    if (key === "CFrame") {
      if (!Array.isArray(value) || value.length !== 12 || value.some((n) => typeof n !== "number")) {
        failures.push(`${here}: CFrame must be 12 numbers (position + 3x3 matrix), got ${JSON.stringify(value)}`);
      }
    } else if (key in vectorKeys) {
      if (!Array.isArray(value) || value.length !== vectorKeys[key] || value.some((n) => typeof n !== "number")) {
        failures.push(`${here}: ${key} must be ${vectorKeys[key]} numbers`);
      }
    } else if (key === "Material" && !enumNames.has(value)) {
      failures.push(`${here}: unknown Material "${value}"`);
    } else if (key === "$path") {
      try {
        const stat = await fs.stat(path.join(root, value));
        if (!stat.isDirectory() && !stat.isFile()) throw new Error("not a file or folder");
      } catch {
        failures.push(`${here}: path "${value}" does not exist`);
      }
    }
    await walk(value, here);
  }
}

await walk(project.tree, "#/tree");
if (failures.length > 0) {
  console.error("Project check failed (Rojo would reject default.project.json):");
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log("PASS Rojo project: CFrame/vector shapes, enum names and $path folders valid");
