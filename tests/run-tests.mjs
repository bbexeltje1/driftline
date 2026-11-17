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

  // 2b. Pure M1 rules: physics, landing, tricks, run rules, profile, contracts.
  // Loaded with fake script/require so script.Parent.X resolves by identity.
  const sharedOrder = [
    ["Config", "src/ReplicatedStorage/Shared/Config.luau"],
    ["TrickCatalog", "src/ReplicatedStorage/Shared/TrickCatalog.luau"],
    ["BoardCatalog", "src/ReplicatedStorage/Shared/BoardCatalog.luau"],
    ["Landing", "src/ReplicatedStorage/Shared/Landing.luau"],
    ["Physics", "src/ReplicatedStorage/Shared/Physics.luau"],
    ["RideDynamics", "src/ReplicatedStorage/Shared/RideDynamics.luau"],
    ["RunRules", "src/ReplicatedStorage/Shared/RunRules.luau"],
    ["TrickScorer", "src/ReplicatedStorage/Shared/TrickScorer.luau"],
    ["NetworkContracts", "src/ReplicatedStorage/Shared/NetworkContracts.luau"],
    ["Profile", "src/ReplicatedStorage/Shared/Profile.luau"],
  ];
  let pureChunk = "local __byToken = {}\nlocal __tokens = {}\n";
  for (const [name] of sharedOrder) {
    pureChunk += `__tokens.${name} = { Name = "${name}" }\n`;
  }
  pureChunk += "local __sharedParent = {}\n";
  for (const [name] of sharedOrder) {
    pureChunk += `__sharedParent.${name} = __tokens.${name}\n`;
  }
  pureChunk += "script = { Parent = __sharedParent }\nrequire = function(m) local v = __byToken[m]; if v == nil then error(\"no module registered for \"..tostring(m and m.Name)) end; return v end\n";
  for (const [name, file] of sharedOrder) {
    const source = await read(file);
    pureChunk += `local ${name} = (function()\n${source}\nend)()\n__byToken[__tokens.${name}] = ${name}\n`;
  }
  for (const spec of ["physics.spec.luau", "ride.spec.luau", "landing.spec.luau", "trick.spec.luau", "runrules.spec.luau", "profile.spec.luau", "contracts.spec.luau"]) {
    pureChunk += await read(`tests/${spec}`);
    pureChunk += "\n";
  }
  await state.loadstring(pureChunk, "pure-rules.spec.luau", true)();

  // 3. The client must boot against a strict stub: HUD built, build stamp shown, remotes found.
  const stub = await read("tests/client-stub.luau");
  const client = await read("src/StarterPlayer/StarterPlayerScripts/Main.client.luau");
  const tag = await read("src/ReplicatedStorage/Shared/BuildTag.luau").catch(() => 'return { tag = "dev" }\n');
  const clientSpec = await read("tests/client.spec.luau");
  const moduleFiles = {
    Config: "src/ReplicatedStorage/Shared/Config.luau",
    Tag: "src/ReplicatedStorage/Shared/BuildTag.luau",
    Physics: "src/ReplicatedStorage/Shared/Physics.luau",
    RideDynamics: "src/ReplicatedStorage/Shared/RideDynamics.luau",
    Landing: "src/ReplicatedStorage/Shared/Landing.luau",
    TrickCatalog: "src/ReplicatedStorage/Shared/TrickCatalog.luau",
    TrickScorer: "src/ReplicatedStorage/Shared/TrickScorer.luau",
    BoardCatalog: "src/ReplicatedStorage/Shared/BoardCatalog.luau",
    RunRules: "src/ReplicatedStorage/Shared/RunRules.luau",
    NetworkContracts: "src/ReplicatedStorage/Shared/NetworkContracts.luau",
    Profile: "src/ReplicatedStorage/Shared/Profile.luau",
    Hud: "src/ReplicatedStorage/Client/Hud.luau",
    HudPresenter: "src/ReplicatedStorage/Client/HudPresenter.luau",
    InputMapper: "src/ReplicatedStorage/Client/InputMapper.luau",
    BoardController: "src/ReplicatedStorage/Client/BoardController.luau",
    AnimationController: "src/ReplicatedStorage/Client/AnimationController.luau",
    CameraController: "src/ReplicatedStorage/Client/CameraController.luau",
  };
  const moduleSources = {};
  for (const [name, file] of Object.entries(moduleFiles)) {
    moduleSources[name] = name === "Tag" ? tag : await read(file);
  }
  const stubInstance = {
    Config: "configModule",
    Tag: "tagModule",
    Physics: "physicsModule",
    RideDynamics: "rideDynamicsModule",
    Landing: "landingModule",
    TrickCatalog: "trickCatalogModule",
    TrickScorer: "trickScorerModule",
    BoardCatalog: "boardCatalogModule",
    RunRules: "runRulesModule",
    NetworkContracts: "networkContractsModule",
    Profile: "profileModule",
    Hud: "hudModule",
    HudPresenter: "hudPresenterModule",
    InputMapper: "inputMapperModule",
    BoardController: "boardControllerModule",
    AnimationController: "animationControllerModule",
    CameraController: "cameraControllerModule",
  };
  // Resolve modules by identity, exactly like Roblox: a queue would hand the wrong module
  // back depending on require order, and hide genuine wiring mistakes.
  let wiring = "local __byModule = {}\n";
  wiring += "local __originalScript = script\n";
  wiring += "local __sharedScript = { Parent = Shared }\n";
  wiring += "local __clientScript = { Parent = ClientModules }\n";
  wiring += "require = function(module) local value = __byModule[module]; if value == nil then error(\"no module registered for \"..tostring(module and module.Name)) end; return value end\n";
  const sharedNames = ["Config", "TrickCatalog", "BoardCatalog", "Landing", "Physics", "RideDynamics", "RunRules", "TrickScorer", "NetworkContracts", "Profile"];
  const clientNames = ["Hud", "HudPresenter", "InputMapper", "BoardController", "AnimationController", "CameraController"];
  wiring += "script = __sharedScript\n";
  wiring += `local Tag = (function()\n${moduleSources.Tag}\nend)()\n__byModule[tagModule] = Tag\n`;
  for (const name of sharedNames) {
    wiring += `local ${name} = (function()\n${moduleSources[name]}\nend)()\n__byModule[${stubInstance[name]}] = ${name}\n`;
  }
  wiring += "script = __clientScript\n";
  for (const name of clientNames) {
    wiring += `local ${name} = (function()\n${moduleSources[name]}\nend)()\n__byModule[${stubInstance[name]}] = ${name}\n`;
  }
  wiring += "script = __originalScript\n";
  await state.loadstring(`${stub}\n${wiring}\nlocal function bootClient()\n${client}\nend\nbootClient()\n${clientSpec}`, "client.spec.luau", true)();
  // Second variant: the server never published its remotes. The client must still draw its
  // interface and say so, instead of freezing on an endless wait.
  const missingSpec = await read("tests/client-missing-remotes.spec.luau");
  await state.loadstring(`${stub}\n${wiring}\nHARNESS_DROP_REMOTES()\nlocal function bootClient()\n${client}\nend\nbootClient()\n${missingSpec}`, "client-missing-remotes.spec.luau", true)();

  // 4. The built place must contain the right classes in the right places. Skip with a clear
  //    reason when nobody has built yet (a fresh copy has no build/ folder), and force argv[2]
  //    to a plain path: scripts invoked from tests otherwise receive the file URL, which
  //    arrives percent-encoded and breaks in any folder whose name contains a space.
  // Rojo-rule guard on default.project.json runs on every test pass, build or not.
  execFileSync(process.execPath, [path.join(testRoot, "project-check.mjs")], { stdio: "inherit" });
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
