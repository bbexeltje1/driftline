// Verifies the Rojo-built place actually contains the scripts the game needs.
// A built place can look fine and still ship with the HUD script downgraded to a
// server Script (or missing entirely), which shows up in Studio as "no interface".
import fs from "node:fs/promises";

const file = process.argv[2];
if (!file) {
  // No build to inspect: self-check against the committed fixtures so the layout rules are
  // exercised by `npm test` too, not only in CI against a real Rojo build.
  const { execFileSync } = await import("node:child_process");
  const self = new URL(import.meta.url).pathname;
  let failed = false;
  try {
    execFileSync(process.execPath, [self, "tests/fixtures/place-good.rbxlx"], { stdio: "inherit" });
  } catch {
    failed = true;
  }
  let rejected = false;
  try {
    execFileSync(process.execPath, [self, "tests/fixtures/place-modules-in-scriptspath.rbxlx"], { stdio: "pipe" });
  } catch {
    rejected = true;
  }
  if (!rejected) {
    console.error("Place check failed: the bad-layout fixture was accepted, so the layout rules do not bite.");
    failed = true;
  }
  process.exit(failed ? 1 : 0);
}

const xml = await fs.readFile(file, "utf8");

// Minimal rbxlx reader: enough to recover Item class/name/paths, not a full XML parser.
function readTree(source) {
  const token = /<Item class="([^"]+)"[^>]*?(\/?)>|<\/Item>|<Properties>([\s\S]*?)<\/Properties>/g;
  const root = { className: "DataModel", name: "DataModel", children: [] };
  const stack = [root];
  let match;
  while ((match = token.exec(source))) {
    if (match[1]) {
      const node = { className: match[1], name: "", children: [] };
      stack[stack.length - 1].children.push(node);
      if (match[2] !== "/") stack.push(node); // self-closing items have no children
    } else if (match[0] === "</Item>") {
      if (stack.length > 1) stack.pop();
    } else if (match[3]) {
      const node = stack[stack.length - 1];
      const name = /<string name="Name">([^<]*)<\/string>/.exec(match[3]);
      if (name) node.name = name[1];
    }
  }
  return root;
}

const tree = readTree(xml);
const failures = [];

function child(node, name) {
  return node.children.find((entry) => entry.name === name);
}
function walk(node, trail) {
  for (const entry of node.children) {
    const path = `${trail}/${entry.name}(${entry.className})`;
    if (entry.name === "MassMonsterRemotes") continue;
    walk(entry, path);
  }
  return trail;
}

function expect(trail, name, className) {
  let node = tree;
  const steps = trail.split("/").filter(Boolean);
  for (const step of steps) {
    node = child(node, step);
    if (!node) {
      failures.push(`missing ${trail}/${name}: no ${step} service`);
      return;
    }
  }
  const found = child(node, name);
  if (!found) {
    failures.push(`missing ${trail}/${name} in the built place`);
    return;
  }
  if (found.className !== className) {
    failures.push(`${trail}/${name} is a ${found.className}, expected ${className}`);
  }
}

expect("StarterPlayer/StarterPlayerScripts", "Main", "LocalScript");
expect("ServerScriptService", "Main", "Script");
expect("ReplicatedStorage/Shared", "Config", "ModuleScript");
expect("ReplicatedStorage/ClientModules", "Hud", "ModuleScript");

const scripts = tree.children
  .find((entry) => entry.name === "StarterPlayer")
  ?.children.find((entry) => entry.name === "StarterPlayerScripts");
if (scripts) {
  const locals = scripts.children.filter((entry) => entry.className === "LocalScript");
  if (locals.length === 0) failures.push("StarterPlayerScripts contains no LocalScript, so no client code runs");
  if (child(scripts, "Modules")) {
    failures.push("StarterPlayerScripts still contains a Modules folder; client modules belong in ReplicatedStorage.ClientModules");
  }
}

if (failures.length > 0) {
  console.error("Place check failed:");
  for (const failure of failures) console.error(`  - ${failure}`);
  console.error("Client tree:");
  const scripts2 = tree.children.find((entry) => entry.name === "StarterPlayer");
  console.error(JSON.stringify(scripts2?.children ?? [], (key, value) => (key === "children" ? value : value), 1).slice(0, 2000));
  process.exit(1);
}

const clientTree = scripts.children.map((entry) => `${entry.name}:${entry.className}`).join(", ");
console.log(`PASS Place file: client scripts present (${clientTree})`);
