# Uncork

Run Windows programs on your Mac by dropping them on a window.

Uncork is a small native macOS app on top of [Wine](https://www.winehq.org). It takes care of the parts that make Wine
hard to use on a Mac: installing it, keeping programs separate, and finding out what went wrong.

- **Drop and run.** Drop a `.exe` or `.msi` on the window or the Dock icon, or use *Open With → Uncork* in Finder.
- **No setup.** The first time you open a program, Uncork downloads a Wine runtime (about 185 MB), checks its SHA-256,
  and unpacks it. Nothing else to install.
- **One prefix per program.** Every program gets its own Wine prefix, so one program can't break another.
- **Logs one click away.** Wine's output for each program is saved, and *Show Log* opens it.

> Uncork isn't affiliated with the Wine project or CodeWeavers.

## Requirements

- macOS 14 or later
- On Apple Silicon: Rosetta 2. Uncork offers to install it, or run
  `softwareupdate --install-rosetta --agree-to-license`.

## How to install

### Homebrew

```sh
brew install 61uehigh/tap/uncork
```

Or add the tap once, then use the short name:

```sh
brew tap 61uehigh/tap
brew install uncork
```

Homebrew builds Uncork from source on your Mac, which takes a minute or two and needs Xcode's Command Line Tools
(`xcode-select --install`). Because it's built locally, Gatekeeper doesn't block it.

Then open the app:

```sh
open "$(brew --prefix)/opt/uncork/Uncork.app"
```

To find it in Launchpad and Spotlight, link it into Applications:

```sh
ln -sf "$(brew --prefix)/opt/uncork/Uncork.app" /Applications/Uncork.app
```

The formula also installs an `uncork` command that opens a program in the app:

```sh
uncork path/to/program.exe
```

Update with `brew upgrade uncork`.

### From source

See [Build from source](#build-from-source).

## Build from source

You only need Xcode's Command Line Tools; full Xcode isn't required.

```sh
./scripts/bundle.sh       # builds build/Uncork.app
open build/Uncork.app
```

Regenerate the app icon after editing `scripts/icon/AppIcon.swift`:

```sh
./scripts/make-icon.sh    # writes Resources/AppIcon.icns
```

Run the tests:

```sh
./scripts/test.sh
```

You can also open a program from the command line:

```sh
build/Uncork.app/Contents/MacOS/Uncork path/to/program.exe
```

## How it works

| Part | What it does |
|---|---|
| `WineReleaseCatalog` | Picks the newest `wine-stable` build from [Gcenx/macOS_Wine_builds](https://github.com/Gcenx/macOS_Wine_builds), falling back to `wine-devel`. These are the builds Homebrew's `wine-stable` cask used to install. |
| `RuntimeManager` | Downloads the build, checks it against the SHA-256 that GitHub publishes, and unpacks it to `~/Library/Application Support/Uncork/Runtime`. |
| `PrefixManager` | Creates one prefix per program path under `…/Uncork/Prefixes`. |
| `Launcher` | Runs `wine` with that program's `WINEPREFIX`, in the program's folder, and writes its output to `…/Uncork/Logs`. |
| `Rosetta` | Checks for Rosetta 2 and installs it. |

### About Gatekeeper

The Wine builds Uncork downloads aren't signed or notarized by Apple, and that's why Homebrew disabled its `wine-stable`
cask. Uncork downloads the build itself and checks its SHA-256 before using it, so you're trusting the Gcenx builds the
same way you would by installing them yourself.

## Uninstall

If you installed with Homebrew, run `brew uninstall uncork` and remove the `/Applications/Uncork.app` link if you made
one. If you built it yourself, delete `Uncork.app`.

Either way, delete `~/Library/Application Support/Uncork` to remove the Wine runtime, your programs' prefixes and logs.

## License

MIT. Wine is licensed under the LGPL. Uncork doesn't bundle Wine: it downloads Wine at first run and runs it as a
separate process.
