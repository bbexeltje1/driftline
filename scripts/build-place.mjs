// Minimal Rojo-compatible place builder (fallback when the Rojo binary cannot
// be downloaded in this sandbox: release assets redirect to a host outside the
// allowlist, so `rojo build` is unavailable here). CI still verifies the real
// pinned Rojo 7.7.1 build; this builder emits the same tree + properties so
// `npm test` and `place-check` can run locally. Do not treat this as a
// replacement for Rojo in release verification.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const projectPath = path.join(root, "default.project.json");
const outPath = process.argv[2] || path.join(root, "build", "game.rbxlx");

let referent = 0;
function nextRef() {
  referent += 1;
  return `RBX${referent}`;
}
function esc(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
function num(n) {
  return String(Number(n.toFixed(6)));
}

// Rotation matrix for single-axis Euler (course parts use one axis only).
function eulerToMatrix(rx, ry, rz) {
  const cx = Math.cos(rx), sx = Math.sin(rx);
  const cy = Math.cos(ry), sy = Math.sin(ry);
  const cz = Math.cos(rz), sz = Math.sin(rz);
  // R = Ry * Rx * Rz (Roblox CFrame.Angles order); single-axis cases are exact.
  const r00 = cy * cz + sy * sx * sz;
  const r01 = -cy * sz + sy * sx * cz;
  const r02 = sy * cx;
  const r10 = cx * sz;
  const r11 = cx * cz;
  const r12 = -sx;
  const r20 = -sy * cz + cy * sx * sz;
  const r21 = sy * sz + cy * sx * cz;
  const r22 = cy * cx;
  return [r00, r01, r02, r10, r11, r12, r20, r21, r22];
}

const MATERIAL_IDS = { Plastic: 256, SmoothPlastic: 272, Neon: 288, Slate: 800 };

function propsXml(name, node, source) {
  const parts = [`<string name="Name">${esc(name)}</string>`];
  if (source !== undefined) {
    parts.push(`<ProtectedString name="Source">${esc(source)}</ProtectedString>`);
  }
  if (Array.isArray(node.Size)) {
    parts.push(`<Vector3 name="Size"><X>${num(node.Size[0])}</X><Y>${num(node.Size[1])}</Y><Z>${num(node.Size[2])}</Z></Vector3>`);
  }
  if (Array.isArray(node.CFrame)) {
    const [x, y, z, a, b, c] = node.CFrame;
    let m;
    if (node.CFrame.length === 6) m = eulerToMatrix(a || 0, b || 0, c || 0);
    else m = node.CFrame.slice(3, 12);
    parts.push(
      `<CoordinateFrame name="CFrame"><XS>${num(x)}</XS><YS>${num(y)}</YS><ZS>${num(z)}</ZS>` +
        `<XX>${num(m[0])}</XX><XY>${num(m[1])}</XY><XZ>${num(m[2])}</XZ>` +
        `<YX>${num(m[3])}</YX><YY>${num(m[4])}</YY><YZ>${num(m[5])}</YZ>` +
        `<ZX>${num(m[6])}</ZX><ZY>${num(m[7])}</ZY><ZZ>${num(m[8])}</ZZ></CoordinateFrame>`
    );
  }
  if (Array.isArray(node.Color)) {
    parts.push(`<Color3 name="Color"><R>${num(node.Color[0])}</R><G>${num(node.Color[1])}</G><B>${num(node.Color[2])}</B></Color3>`);
  }
  if (typeof node.Material === "string" && MATERIAL_IDS[node.Material] !== undefined) {
    parts.push(`<token name="Material">${MATERIAL_IDS[node.Material]}</token>`);
  }
  if (typeof node.Anchored === "boolean") parts.push(`<bool name="Anchored">${node.Anchored}</bool>`);
  if (typeof node.CanCollide === "boolean") parts.push(`<bool name="CanCollide">${node.CanCollide}</bool>`);
  if (typeof node.Transparency === "number") parts.push(`<float name="Transparency">${num(node.Transparency)}</float>`);
  if (typeof node.Neutral === "boolean") parts.push(`<bool name="Neutral">${node.Neutral}</bool>`);
  return `<Properties>${parts.join("")}</Properties>`;
}

async function scriptClassFor(fileName) {
  if (fileName.endsWith(".server.luau")) return "Script";
  if (fileName.endsWith(".client.luau")) return "LocalScript";
  return "ModuleScript";
}
function scriptNameFor(fileName) {
  return fileName.replace(/\.server\.luau$/, "").replace(/\.client\.luau$/, "").replace(/\.luau$/, "");
}

async function buildPathNode(dirAbs) {
  const entries = await fs.readdir(dirAbs, { withFileTypes: true });
  const items = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    if (entry.isDirectory()) {
      const children = await buildPathNode(path.join(dirAbs, entry.name));
      items.push(`<Item class="Folder" referent="${nextRef()}"><Properties><string name="Name">${esc(entry.name)}</string></Properties>${children.join("")}</Item>`);
    } else if (entry.isFile() && entry.name.endsWith(".luau")) {
      const source = await fs.readFile(path.join(dirAbs, entry.name), "utf8");
      const cls = await scriptClassFor(entry.name);
      const nm = scriptNameFor(entry.name);
      items.push(`<Item class="${cls}" referent="${nextRef()}">${propsXml(nm, {}, source)}</Item>`);
    }
  }
  return items;
}

async function buildNode(name, node) {
  if (node.$path) {
    const dirAbs = path.join(root, node.$path);
    const children = await buildPathNode(dirAbs);
    const cls = node.$className || "Folder";
    return `<Item class="${cls}" referent="${nextRef()}">${propsXml(name, node.$properties || {})}${children.join("")}</Item>`;
  }
  const cls = node.$className || "Folder";
  const children = [];
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("$")) continue;
    // Only plain objects are child instances; primitives/arrays are properties.
    if (typeof value !== "object" || value === null || Array.isArray(value)) continue;
    children.push(await buildNode(key, value));
  }
  return `<Item class="${cls}" referent="${nextRef()}">${propsXml(name, node.$properties || {})}${children.join("")}</Item>`;
}

const project = JSON.parse(await fs.readFile(projectPath, "utf8"));
const tree = project.tree;
const topItems = [];
for (const [key, value] of Object.entries(tree)) {
  if (key.startsWith("$")) continue;
  topItems.push(await buildNode(key, value));
}
const xml = `<?xml version="1.0" encoding="utf-8"?>\n<roblox version="4">\n${topItems.join("\n")}\n</roblox>\n`;
await fs.mkdir(path.dirname(outPath), { recursive: true });
await fs.writeFile(outPath, xml, "utf8");
console.log(`Built ${outPath} (${(xml.length / 1024).toFixed(1)} KiB, fallback builder)`);
