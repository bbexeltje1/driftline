import fs from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { LuauState } from "luau-web";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceRoot = path.join(root, "src");
const testRoot = path.join(root, "tests");
const read = (p) => fs.readFile(path.join(root, p), "utf8");

async function findLuau(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await findLuau(full)));
    else if (entry.isFile() && entry.name.endsWith(".luau")) files.push(full);
  }
  return files.sort();
}

const state = await LuauState.createAsync();
try {
  // 1. Every source file must also be valid Luau.
  const sources = await findLuau(sourceRoot);
  for (const file of sources) {
    const source = await fs.readFile(file, "utf8");
    state.loadstring(source, path.relative(root, file), true);
  }
  console.log(`PASS Luau syntax: ${sources.length} source files`);

  // 2. Shared config must be a plain table with the keys the docs promise.
  const config = await read("src/ReplicatedStorage/Shared/Config.luau");
  const configSpec = await read("tests/config.spec.luau");
  await state.loadstring(`local Config=(function()\n${config}\nend)()\n${configSpec}`, "config.spec.luau", true)();

  // 3. The client must boot against a strict stub: HUD built, build stamp shown, remotes found.
  const stub = await read("tests/client-stub.luau");
  const client = await read("src/StarterPlayer/StarterPlayerScripts/Main.client.luau");
  const hud = await read("src/ReplicatedStorage/Client/Hud.luau");
  const tag = await read("src/ReplicatedStorage/Shared/BuildTag.luau").catch(() => 'return { tag = "dev" }\n');
  const clientSpec = await read("tests/client.spec.luau");
  // Resolve modules by identity, exactly like Roblox: a queue would hand the wrong module
  // back depending on require order, and hide genuine wiring mistakes.
  const wiring = `Config=(function()\n${config}\nend)()
Tag=(function()\n${tag}\nend)()
local HudModule=(function()\n${hud}\nend)()
local __byModule={[configModule]=Config,[tagModule]=Tag,[hudModule]=HudModule}
require=function(module) local value=__byModule[module]; if value==nil then error("no module registered for "..tostring(module and module.Name)) end; return value end
`;
  await state.loadstring(`${stub}\n${wiring}\nlocal function bootClient()\n${client}\nend\nbootClient()\n${clientSpec}`, "client.spec.luau", true)();
  // Second variant: the server never published its remotes. The client must still draw its
  // interface and say so, instead of freezing on an endless wait.
  const missingSpec = await read("tests/client-missing-remotes.spec.luau");
  await state.loadstring(`${stub}\n${wiring}\nHARNESS_DROP_REMOTES()\nlocal function bootClient()\n${client}\nend\nbootClient()\n${missingSpec}`, "client-missing-remotes.spec.luau", true)();

  // 4. The built place must contain the right classes in the right places. Skip with a clear
  //    reason when nobody has built yet (a fresh copy has no build/ folder), and force argv[2]
  //    to a plain path: scripts invoked from tests otherwise receive the file URL, which
  //    arrives percent-encoded and breaks in any folder whose name contains a space.
  const placeFile = process.argv[2] || path.join(root, "build", "game.rbxlx");
  if (!existsSync(placeFile)) {
    console.log(`FAIL Place file: ${placeFile} is missing. Run .\\scripts\\play.ps1 (or rojo build) first.`);
    process.exitCode = 1;
  } else {
    execFileSync(process.execPath, [path.join(testRoot, "place-check.mjs"), placeFile], { stdio: "inherit" });
  }
} finally {
  state.destroy();
}
