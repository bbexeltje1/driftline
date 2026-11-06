# Roblox game template (Rojo + PowerShell)

A minimal, self-checking Roblox project. Clone it, run one command, and you are playing.

## Start a new project

Copy `new-game.ps1` into a folder of your own — **not** `C:\Users` itself, which Windows
protects — for example `C:\Users\exelt\projects`. Then:

```powershell
.\new-game.ps1 -Name my-game -DisplayName "My Game"
```

Run it from **anywhere** and it does the whole job:

1. checks `git`, `node`, `npm`, `rojo` and `gh` are installed,
2. downloads this template from GitHub (no clone of this repository needed),
3. creates `my-game` **beside** `new-game.ps1`,
4. renames the Rojo project and the in-game title, and verifies the JSON has no BOM,
5. installs test dependencies, builds `build\game.rbxlx`,
6. makes the first commit on `main`, creates the GitHub repository and pushes,
7. opens the place in Roblox Studio.

| Flag | Effect |
| --- | --- |
| `-Name <name>` | required; folder and repository name |
| `-DisplayName <text>` | in-game title (defaults to the name) |
| `-Path <dir>` | where to create it (defaults to a sibling folder) |
| `-NoRepo` | skip git and GitHub entirely |
| `-Public` | create a public repository instead of private |
| `-NoPush` | make the commit but do not push |
| `-NoPlay` | build but do not open Studio |
| `-SkipInstall` | skip `npm` install |
| `-Fresh` | replace the target folder if it already exists |
| `-TemplatePath <dir>` | copy from a template folder on disk instead of downloading |

Requires the template repository to be readable from that machine: it is private, so a
machine that has never signed in to GitHub will be refused. If that happens, sign in with
`gh auth login` (or `git config --global credential.helper manager`), or point at a local
copy with `-TemplatePath`.

If a GitHub repository with that name already exists, it is reused rather than recreated.

> Never paste a command containing `<...>` into PowerShell: `<` is a reserved operator and it
> aborts the whole paste.

### If Rojo says "Failed to parse JSONC"

`default.project.json` has a **byte-order mark**. Windows PowerShell 5.1's
`Set-Content -Encoding utf8` writes one, and Rojo's parser rejects it. The launcher writes
UTF-8 without a BOM and verifies it, and `play.ps1` names this cause when a build fails. To
repair an existing file, re-save it as "UTF-8 without BOM" in your editor.

## Put it in a GitHub repository you already made

Make the repository on GitHub (empty, no README), then:

```powershell
.\copy-template.ps1 game-2 -Remote bbexeltje1/game2
```

That creates the folder, fills it, commits, connects the remote and pushes. If the
repository already has commits, it stops and tells you to add `-Replace`, which rebuilds the
commit on an empty root (so the old history is gone) and pushes it as the only commit.

`copy-template.ps1` flags:

| Flag | Effect |
| --- | --- |
| `game-1` (a name) | create that folder beside the script and fill it |
| no name | fill the folder you are standing in |
| `-Path <dir>` | fill an exact folder, creating it if needed |
| `-Remote <owner/repo>` | connect that GitHub repository, commit and push |
| `-Replace` | required when that repository already has commits |
| `-Install` | run `npm ci` so the tests work |
| `-Commit`, `-Push` | commit and push to an existing `origin` |
| `-Force` | overwrite template files already in the folder |
| `-TemplatePath <dir>` | copy from a local template folder instead of downloading |

## Fill a repository you already made

If you would rather create the repository yourself first (on GitHub, or with `git init`),
copy `fill-repository.ps1` beside it and run it from inside that folder:

```powershell
cd C:\Users\exelt\my-game
.\fill-repository.ps1
```

It uses the folder name as the project name, or the repository name when an `origin`
remote exists. It copies the template in, renames it, installs, builds, and opens Studio.
Your existing `.git` is kept, and the first commit can be made for you:

```powershell
.\fill-repository.ps1 -Commit -Push
```

| Flag | Effect |
| --- | --- |
| `-RepositoryPath <dir>` | fill a folder other than the current one |
| `-DisplayName <text>` | in-game title (defaults to the repository name) |
| `-Commit` | make the first commit |
| `-Push` | also push to `origin` |
| `-Force` | overwrite template files that are already there |
| `-NoBuild`, `-NoPlay`, `-SkipInstall` | skip those steps |
| `-TemplatePath <dir>` | copy from a template folder on disk instead of downloading |

Without `-Force` it refuses to touch a repository that already contains template files.

## Commands

| Command | What it does |
| --- | --- |
| `.\scripts\play.ps1` | pull → build → open Roblox Studio |
| `.\scripts\play.ps1 -SkipPull` | build the current commit → open Studio |
| `.\scripts\play.ps1 -NoOpen` | pull → build, do not launch Studio |
| `.\scripts\build.ps1` | build only (`build/game.rbxlx`) |
| `.\scripts\test.ps1` | `npm ci` then `npm test` (never blocks playing) |

Studio runs use temporary progress on purpose: **nothing has to be published and no API
setting has to be enabled** before you press Play.

## Layout

```
src/ReplicatedStorage/Shared/     rules and config, read by both sides
src/ReplicatedStorage/Client/     client-only modules (Hud, effects, ...)
src/ServerScriptService/          server entry point + Modules
src/StarterPlayer/StarterPlayerScripts/   the LocalScript entry point
tests/                            Luau checks against a strict Roblox stub
```

## The four rules this template enforces

1. **Client modules live in `ReplicatedStorage`, never beside the LocalScript.** Rojo does not
   copy a folder of ModuleScripts into `PlayerScripts`; `script.Parent` is the PlayerScripts
   container at runtime, so requiring from there fails with *Infinite yield possible*.
2. **Never touch DataStore at module load.** In an unpublished place it throws
   *You must publish this place to the web*, which kills the whole server script.
3. **Build the interface before awaiting the server**, and give every `WaitForChild` a
   timeout, so a missing remote is reported instead of freezing the screen.
4. **Instances cannot hold functions as fields** (`model:Wander()` fails). Put behaviour in a
   plain table and attach it with `rawset`, or use a ModuleScript.

`npm test` checks all four, including a place-layout check that fails if a `Modules` folder
appears beside the LocalScript. Keep it that way and the failures above cannot come back.
