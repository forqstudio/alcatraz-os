# NixOS distribution conventions check

**Session ID:** ses_30a79d5b9ffe2Fx69hWeyz4Or2
**Created:** 3/16/2026, 8:22:16 AM
**Updated:** 3/16/2026, 8:34:31 AM

---

## User

Does this codebase follow NixOS conventions for distribution ?

---

## Assistant (Plan · claude-opus-4-6 · 108.9s)

_Thinking:_

Let me explore the codebase structure to answer this question.

**Tool: task**

**Input:**
```json
{
  "description": "Explore NixOS conventions",
  "prompt": "Explore this codebase and determine if it follows NixOS distribution conventions. Look for:\n1. Top-level structure (flake.nix, default.nix, shell.nix, etc.)\n2. Module structure under modules/ or nixos/\n3. Package definitions in pkgs/\n4. Overlay usage\n5. NixOS module options/config patterns\n6. Use of lib, pkgs, config attributes\n7. Any deviation from standard NixOS conventions\n\nReturn a concise summary of what NixOS conventions are followed, what's missing or non-standard, and the overall directory structure.",
  "subagent_type": "explore"
}
```

**Output:**
```
task_id: ses_30a79b79fffeaxtnsR0yHj9nS3 (for resuming to continue this task if needed)

<task_result>
I now have a complete picture of the codebase. Here is the summary.

---

## NixOS Convention Analysis: alcatraz-os

### Overall Directory Structure

```
alcatraz-os/                          # Git repository root
  .gitignore
  README.md
  iso-build-session.md                # OpenCode AI session log (non-standard)
  nixos.wsl                           # Binary build artifact (gitignored)
  result/                             # Nix build symlink (gitignored)
  src/                                # <-- All Nix source lives here
    flake.nix
    flake.lock
    docs/
      tools.md
    hosts/
      alcatraz/                       # Bare-metal host
        configuration.nix
        hardware-configuration.nix
      alcatraz-iso/                   # Installer ISO host
        configuration.nix
      alcatraz-wsl/                   # WSL2 host
        configuration.nix
    modules/
      base.nix                        # Shared: users, networking, nix settings
      desktop.nix                     # Graphical: X11, XFCE, PipeWire, CUPS
      wsl.nix                         # WSL2 integration via nixos-wsl
    home/
      home-common.nix                 # Shared home-manager base
      home-dev.nix                    # dev user packages
      home-al.nix                     # al user packages
```

---

### Conventions FOLLOWED

1. **Flake-based project structure.** The project uses `flake.nix` + `flake.lock` as its entry point, which is the modern standard for NixOS configurations. Inputs are properly pinned via the lock file.

2. **Input follows convention.** All third-party inputs (`home-manager`, `nixos-wsl`) have their `nixpkgs` input set to `follows = "nixpkgs"`, avoiding duplicate nixpkgs evaluations. This is a widely recommended best practice.

3. **`nixosConfigurations` output attribute.** Each machine (`alcatraz`, `alcatraz-iso`, `alcatraz-wsl`) is a named entry under `nixosConfigurations`, built via `nixpkgs.lib.nixosSystem { ... }`. This is the standard flake convention and supports `sudo nixos-rebuild switch --flake .#<hostname>`.

4. **`packages` output attribute.** Buildable artifacts (ISO image, WSL tarball) are properly exposed under `packages.x86_64-linux`, following the flake schema.

5. **hosts/ directory pattern.** Per-host directories under `hosts/<hostname>/` each containing a `configuration.nix` is a widely adopted community convention. Host configs contain only machine-specific settings (hostname, locale, timezone, bootloader, hardware).

6. **modules/ directory for shared configuration.** Reusable NixOS configuration modules live under `modules/` and are split by concern (`base.nix`, `desktop.nix`, `wsl.nix`). This separation-of-concerns pattern is standard.

7. **hardware-configuration.nix.** The bare-metal host includes a `nixos-generate-config`-produced `hardware-configuration.nix`, which is the standard NixOS approach for hardware detection. It correctly uses `modulesPath`, `lib.mkDefault`, and `config` references.

8. **Home Manager as a NixOS module.** Home Manager is integrated via `home-manager.nixosModules.home-manager` with `useGlobalPkgs = true` and `useUserPackages = true`, which is the recommended NixOS-module integration style (as opposed to standalone home-manager).

9. **home/ directory for user configs.** Per-user home-manager files live under `home/` with a common base (`home-common.nix`) imported by each user file. This is a standard pattern.

10. **Standard module function signatures.** All modules use the idiomatic `{ config, pkgs, ... }:` function signature. The `hardware-configuration.nix` correctly receives `{ config, lib, pkgs, modulesPath, ... }:`.

11. **`specialArgs` for passing flake inputs.** Extra inputs (`inputs`, `nixos-wsl`, `self`) are passed to modules via `specialArgs`, which is the standard mechanism for making flake inputs available inside NixOS modules.

12. **`stateVersion` is set.** Both `system.stateVersion` (in `base.nix`) and `home.stateVersion` (in `home-common.nix`) are properly set to `"25.11"`.

13. **ISO build using upstream nixpkgs modules.** The ISO configuration correctly imports `${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix` and `channel.nix`, and exposes the image via `config.system.build.isoImage`. This is the canonical approach.

14. **`.gitignore` follows Nix conventions.** Build outputs (`result`, `result-*`), direnv artifacts (`.direnv`), and generated binaries (`nixos.wsl`, `*.iso`) are all properly ignored.

15. **Inline documentation.** Every module and host file has header comments explaining its purpose and referencing community conventions. This is good practice though not a strict convention.

---

### Conventions NOT FOLLOWED or MISSING

1. **`flake.nix` is not at the repository root.** The flake lives at `src/flake.nix` rather than at the top-level. This is a notable deviation. The standard convention places `flake.nix` at the repository root. This means all `nix` commands must use `./src#` rather than `.#` (e.g., `nix build ./src#iso` instead of `nix build .#iso`). While this works, it is non-standard and may confuse users accustomed to the typical layout.

2. **No `default.nix` or `shell.nix`.** These files are absent entirely. While `default.nix` is a pre-flake convention (and is optional in a flake-only project), many flake projects still provide a `default.nix` (via `flake-compat`) for backward compatibility with users who have not enabled flakes. Similarly, `shell.nix` (or the flake equivalent `devShells` output) is absent, meaning there is no development shell for contributors.

3. **No `pkgs/` directory.** There are no custom package definitions. The project relies entirely on packages from nixpkgs. This is not necessarily wrong for a system configuration flake, but it means there are no custom derivations, and the `alcatraz-install` script is defined inline in the ISO host configuration rather than as a standalone package.

4. **No overlays.** There are zero overlay definitions or usages anywhere in the codebase. Again, not strictly required for a system config flake, but overlays are a common NixOS pattern for customizing or extending nixpkgs.

5. **No custom NixOS module options.** None of the modules under `modules/` define `options` using `mkOption` or `mkEnableOption`. They are purely configuration-setting modules (i.e., they only set `config` values). In a more mature NixOS distribution, modules typically expose declarative options (e.g., `alcatraz.desktop.enable = true;`) that other modules or host configs can toggle. The current approach of using `imports` to compose functionality works but is less flexible.

6. **No `devShells` output.** The flake does not expose a development shell (`devShells.${system}.default`), which is a common convention for projects that want to provide a reproducible development environment for contributors.

7. **No `checks` output.** There are no `checks` defined in the flake, meaning `nix flake check` does nothing beyond basic schema validation. Many NixOS flakes define checks to verify that configurations build successfully.

8. **No `nixosModules` output.** The flake does not export its modules (base, desktop, wsl) as reusable `nixosModules` for consumption by other flakes. This is a convention for libraries/distributions intended to be composable.

9. **No `lib` output or custom library functions.** There is no `lib` output and no shared utility functions. The use of `lib` is limited to the auto-generated `hardware-configuration.nix` (via `lib.mkDefault`).

10. **Hardcoded single architecture.** The `system` variable is hardcoded to `"x86_64-linux"` in the `let` block. The common convention for multi-arch support is to use `nixpkgs.lib.genAttrs` or `flake-utils.lib.eachDefaultSystem`, though for a personal NixOS config targeting specific hardware, single-arch is acceptable.

11. **`system.stateVersion` in a shared module.** The `system.stateVersion` is set in `modules/base.nix` (shared across all hosts) rather than per-host. The NixOS documentation recommends setting it per-host because it should reflect when each machine was initially installed and should never change. Setting it in a shared module means all hosts share the same state version, which could cause issues if hosts were installed at different times.

12. **Locale/timezone duplication.** The `time.timeZone` and `i18n.extraLocaleSettings` blocks are duplicated verbatim across `hosts/alcatraz/configuration.nix` and `hosts/alcatraz-wsl/configuration.nix`. These could be extracted into the shared `base.nix` module or a separate `locale.nix` module.

13. **No `formatter` output.** The flake does not define a `formatter` (e.g., `formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;`), which is a convention for enabling `nix fmt` on the repository.

14. **No CI/CD.** There are no GitHub Actions workflows, no `.github/` directory, no Hydra job definitions, and no automated testing or release pipelines.

---

### Summary Assessment

The project follows the **core NixOS flake conventions** well: flake inputs/outputs, `nixosConfigurations`, per-host directories, shared modules, Home Manager integration, and hardware-configuration separation are all done correctly. The code is clean, well-commented, and idiomatic Nix.

The main deviations are:
- **Structural:** `flake.nix` lives under `src/` instead of the repo root (non-standard).
- **Missing advanced patterns:** No custom NixOS options (`mkOption`/`mkEnableOption`), no overlays, no `pkgs/` directory, no exported `nixosModules`, no `devShells`, no `checks`, no `formatter`.
- **Minor issues:** Shared `stateVersion`, duplicated locale settings, hardcoded single architecture.

Overall, this is a **straightforward, early-stage NixOS system configuration flake** that follows the essential conventions correctly. The missing items (overlays, custom options, exported modules, CI, etc.) are features that would be expected in a more mature NixOS distribution project but are not necessary for a personal/small-team system configuration.
</task_result>
```

---

## Assistant (Plan · claude-opus-4-6 · 11.9s)

## NixOS Convention Analysis

**Short answer:** The codebase follows the core NixOS flake conventions correctly, but has some gaps expected in a more mature distribution.

### What's done well
- Flake-based with proper `nixosConfigurations`, pinned inputs, and `follows` for nixpkgs
- Standard `hosts/<name>/configuration.nix` layout with shared `modules/`
- Home Manager integrated as a NixOS module with `useGlobalPkgs`/`useUserPackages`
- Proper `hardware-configuration.nix`, `stateVersion`, `specialArgs`, and ISO build using upstream nixpkgs modules
- Clean `.gitignore` for Nix build outputs

### Notable deviations

1. **`flake.nix` is under `src/` instead of the repo root** — non-standard, forces `nix build ./src#...` instead of `.#...`
2. **No custom NixOS module options** — modules only set config values, never define `options` with `mkOption`/`mkEnableOption`
3. **No `devShells`, `checks`, or `formatter` outputs** — missing standard flake schema entries
4. **No overlays, `pkgs/`, or exported `nixosModules`** — fine for a personal config, but expected for a "distribution"
5. **`system.stateVersion` in shared module** — should be per-host per NixOS docs
6. **Hardcoded `x86_64-linux`** — no multi-arch support
7. **Duplicated locale/timezone settings** across hosts instead of factoring into `base.nix`
8. **No CI/CD or automated checks**

### Verdict

This is a well-structured **personal NixOS system configuration flake**, not a distribution in the NixOS sense. To be considered a proper distribution, it would need exported `nixosModules`, custom options (`mkOption`), overlays, a `pkgs/` directory for custom packages, and the flake at the repo root.

---

## User

How can we make this a a proper distribution instead of a personal NixOs configuration ?

---

## Assistant (Plan · claude-opus-4-6 · 6.5s)

_Thinking:_

The user wants a plan to transform this personal NixOS configuration into a proper NixOS distribution. Let me think about what that entails and ask some clarifying questions before proposing a detailed plan.

Let me first understand the current state better by looking at key files.

Let me review the current structure in more detail to craft a concrete plan.

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/flake.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/flake.nix</path>
<type>file</type>
<content>1: {
2:   description = "Alcatraz OS - NixOS configurations for bare-metal and WSL2";
3: 
4:   # Community convention: pin all third-party inputs to follow the same
5:   # nixpkgs to avoid multiple evaluations and ensure consistency.
6:   inputs = {
7:     nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
8: 
9:     home-manager.url = "github:nix-community/home-manager";
10:     home-manager.inputs.nixpkgs.follows = "nixpkgs";
11: 
12:     nixos-wsl.url = "github:nix-community/NixOS-WSL";
13:     nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
14:   };
15: 
16:   outputs = { self, nixpkgs, home-manager, nixos-wsl, ... }@inputs:
17:   let
18:     system = "x86_64-linux";
19: 
20:     # Shared Home Manager configuration used by both hosts.
21:     # Community convention: define home-manager as a NixOS module so that
22:     # user environments are managed declaratively alongside the system.
23:     homeManagerModule = {
24:       home-manager.useGlobalPkgs = true;
25:       home-manager.useUserPackages = true;
26:       home-manager.users.dev = import ./home/home-dev.nix;
27:       home-manager.users.al = import ./home/home-al.nix;
28:     };
29:   in
30:   {
31:     # Community convention: each machine is a named entry under
32:     # nixosConfigurations. Build/switch with:
33:     #   sudo nixos-rebuild switch --flake .#<hostname>
34: 
35:     # Bare-metal graphical install
36:     nixosConfigurations.alcatraz = nixpkgs.lib.nixosSystem {
37:       inherit system;
38:       specialArgs = { inherit inputs nixos-wsl; };
39:       modules = [
40:         ./hosts/alcatraz/configuration.nix
41:         home-manager.nixosModules.home-manager
42:         homeManagerModule
43:       ];
44:     };
45: 
46:     # Installer ISO
47:     nixosConfigurations.alcatraz-iso = nixpkgs.lib.nixosSystem {
48:       inherit system;
49:       specialArgs = { inherit inputs self; };
50:       modules = [
51:         "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
52:         "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
53:         ./hosts/alcatraz-iso/configuration.nix
54:       ];
55:     };
56: 
57:     # WSL2 build
58:     nixosConfigurations.alcatraz-wsl = nixpkgs.lib.nixosSystem {
59:       inherit system;
60:       specialArgs = { inherit inputs nixos-wsl; };
61:       modules = [
62:         ./hosts/alcatraz-wsl/configuration.nix
63:         home-manager.nixosModules.home-manager
64:         homeManagerModule
65:       ];
66:     };
67: 
68:     # WSL tarball builder.
69:     # The nixos-wsl module exposes a tarballBuilder script that produces a
70:     # .wsl file (tar.gz) importable by WSL on Windows.
71:     #
72:     # Build with:
73:     #   sudo nix run ./src#alcatraz-wsl-tarball
74:     #
75:     # Then on Windows:
76:     #   wsl --install --from-file nixos.wsl        (WSL >= 2.4.4)
77:     #   wsl --import NixOS <path> nixos.wsl        (older WSL)
78:     packages.${system} = {
79:       alcatraz-wsl-tarball =
80:         self.nixosConfigurations.alcatraz-wsl.config.system.build.tarballBuilder;
81: 
82:       # Build with: nix build ./src#iso
83:       # Result at: result/iso/nixos-*.iso
84:       iso =
85:         self.nixosConfigurations.alcatraz-iso.config.system.build.isoImage;
86:     };
87:   };
88: }

(End of file - total 88 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/modules/base.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/modules/base.nix</path>
<type>file</type>
<content>1: # Base module: universal configuration shared across all hosts.
2: #
3: # Community convention: shared modules live in modules/ and contain only
4: # settings that apply to every machine. Host-specific settings (hostname,
5: # locale, timezone, bootloader, hardware) belong in each host's own
6: # configuration.nix under hosts/<hostname>/.
7: 
8: { config, pkgs, ... }:
9: 
10: {
11:   # Enable networking via NetworkManager (common to all hosts)
12:   networking.networkmanager.enable = true;
13: 
14:   # User accounts
15:   users.users.dev = {
16:     isNormalUser = true;
17:     description = "dev";
18:     extraGroups = [ "networkmanager" "wheel" ];
19:   };
20: 
21:   users.users.al = {
22:     isNormalUser = true;
23:     description = "al";
24:     extraGroups = [ "networkmanager" "wheel" ];
25:   };
26: 
27:   # Allow unfree packages
28:   nixpkgs.config.allowUnfree = true;
29: 
30:   # Enable flakes and the new nix command
31:   nix.settings.experimental-features = [ "nix-command" "flakes" ];
32: 
33:   # NixOS release version for stateful data compatibility.
34:   # Set once at initial install; do not change without reading the docs.
35:   system.stateVersion = "25.11";
36: }

(End of file - total 36 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/modules/desktop.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/modules/desktop.nix</path>
<type>file</type>
<content>1: # Desktop module: graphical environment, sound, and printing.
2: #
3: # Community convention: modules are split by concern. This module contains
4: # everything needed for a GUI desktop experience. Hosts that run headless
5: # or under WSL should not import this module.
6: 
7: { config, pkgs, ... }:
8: 
9: {
10:   # Enable the X11 windowing system
11:   services.xserver.enable = true;
12: 
13:   # Enable the XFCE Desktop Environment with LightDM
14:   services.xserver.displayManager.lightdm.enable = true;
15:   services.xserver.desktopManager.xfce.enable = true;
16: 
17:   # Configure keymap in X11
18:   services.xserver.xkb = {
19:     layout = "us";
20:     variant = "";
21:   };
22: 
23:   # Enable CUPS to print documents
24:   services.printing.enable = true;
25: 
26:   # Enable sound with PipeWire
27:   services.pulseaudio.enable = false;
28:   security.rtkit.enable = true;
29:   services.pipewire = {
30:     enable = true;
31:     alsa.enable = true;
32:     alsa.support32Bit = true;
33:     pulse.enable = true;
34:   };
35: 
36:   # Install Firefox
37:   programs.firefox.enable = true;
38: }

(End of file - total 38 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/modules/wsl.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/modules/wsl.nix</path>
<type>file</type>
<content>1: # WSL module: NixOS-on-WSL2 integration.
2: #
3: # Community convention: use the nixos-wsl community module
4: # (github:nix-community/NixOS-WSL) for proper WSL2 support. It handles
5: # the virtual filesystem, Windows interop, and boot process so you don't
6: # have to configure these manually.
7: #
8: # The nixos-wsl input is passed via specialArgs from flake.nix.
9: 
10: { config, pkgs, nixos-wsl, ... }:
11: 
12: {
13:   imports = [
14:     nixos-wsl.nixosModules.wsl
15:   ];
16: 
17:   wsl.enable = true;
18:   wsl.defaultUser = "dev";
19: }

(End of file - total 19 lines)
</content>
```

---

## Assistant (Plan · claude-opus-4-6 · 7.8s)

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/hosts/alcatraz/configuration.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/hosts/alcatraz/configuration.nix</path>
<type>file</type>
<content>1: # Host: alcatraz (bare-metal graphical install)
2: #
3: # Community convention: each host gets its own directory under hosts/.
4: # The host's configuration.nix contains only settings specific to this
5: # machine: hostname, locale, timezone, bootloader, and hardware. Shared
6: # configuration is imported from modules/.
7: #
8: # When forking this repo for a new machine, copy this directory, update
9: # the values below, and run `nixos-generate-config` to produce a new
10: # hardware-configuration.nix for your hardware.
11: 
12: { config, pkgs, ... }:
13: 
14: {
15:   imports = [
16:     # Shared modules
17:     ../../modules/base.nix
18:     ../../modules/desktop.nix
19:     # Hardware scan results (machine-specific, generated by nixos-generate-config)
20:     ./hardware-configuration.nix
21:   ];
22: 
23:   # --- Host-specific settings (set by the person installing) ---
24: 
25:   # Bootloader
26:   boot.loader.grub.enable = true;
27:   boot.loader.grub.device = "/dev/nvme0n1";
28:   boot.loader.grub.useOSProber = true;
29: 
30:   # Hostname
31:   networking.hostName = "alcatraz";
32: 
33:   # Timezone and locale (set these to match your location)
34:   time.timeZone = "Europe/Amsterdam";
35: 
36:   i18n.defaultLocale = "en_US.UTF-8";
37: 
38:   i18n.extraLocaleSettings = {
39:     LC_ADDRESS = "nl_NL.UTF-8";
40:     LC_IDENTIFICATION = "nl_NL.UTF-8";
41:     LC_MEASUREMENT = "nl_NL.UTF-8";
42:     LC_MONETARY = "nl_NL.UTF-8";
43:     LC_NAME = "nl_NL.UTF-8";
44:     LC_NUMERIC = "nl_NL.UTF-8";
45:     LC_PAPER = "nl_NL.UTF-8";
46:     LC_TELEPHONE = "nl_NL.UTF-8";
47:     LC_TIME = "nl_NL.UTF-8";
48:   };
49: }

(End of file - total 49 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/hosts/alcatraz-wsl/configuration.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/hosts/alcatraz-wsl/configuration.nix</path>
<type>file</type>
<content>1: # Host: alcatraz-wsl (WSL2 build)
2: #
3: # Community convention: each host gets its own directory under hosts/.
4: # WSL hosts don't need a hardware-configuration.nix or bootloader config
5: # because WSL manages the virtual hardware and boot process.
6: #
7: # The wsl.nix module (via nixos-wsl) handles all WSL2 integration.
8: 
9: { config, pkgs, ... }:
10: 
11: {
12:   imports = [
13:     # Shared modules
14:     ../../modules/base.nix
15:     ../../modules/wsl.nix
16:   ];
17: 
18:   # --- Host-specific settings (set by the person installing) ---
19: 
20:   # Hostname
21:   networking.hostName = "alcatraz-wsl";
22: 
23:   # Timezone and locale (set these to match your location)
24:   time.timeZone = "Europe/Amsterdam";
25: 
26:   i18n.defaultLocale = "en_US.UTF-8";
27: 
28:   i18n.extraLocaleSettings = {
29:     LC_ADDRESS = "nl_NL.UTF-8";
30:     LC_IDENTIFICATION = "nl_NL.UTF-8";
31:     LC_MEASUREMENT = "nl_NL.UTF-8";
32:     LC_MONETARY = "nl_NL.UTF-8";
33:     LC_NAME = "nl_NL.UTF-8";
34:     LC_NUMERIC = "nl_NL.UTF-8";
35:     LC_PAPER = "nl_NL.UTF-8";
36:     LC_TELEPHONE = "nl_NL.UTF-8";
37:     LC_TIME = "nl_NL.UTF-8";
38:   };
39: }

(End of file - total 39 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/hosts/alcatraz-iso/configuration.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/hosts/alcatraz-iso/configuration.nix</path>
<type>file</type>
<content>1: # Host: alcatraz-iso (installer ISO image)
2: #
3: # Produces a bootable ISO containing the Alcatraz OS installer.
4: # Boot from USB, connect to the internet, then run:
5: #   alcatraz-install /dev/sdX
6: #
7: # Build with:
8: #   nix build ./src#iso
9: #
10: # Write to USB:
11: #   sudo dd bs=4M conv=fsync oflag=direct status=progress \
12: #     if=result/iso/nixos-*.iso of=/dev/sdX
13: 
14: { config, pkgs, lib, self, ... }:
15: 
16: let
17:   alcatraz-install = pkgs.writeShellScriptBin "alcatraz-install" ''
18:     set -euo pipefail
19: 
20:     if [ "$(id -u)" -ne 0 ]; then
21:       echo "Error: alcatraz-install must be run as root."
22:       exit 1
23:     fi
24: 
25:     DISK="''${1:-}"
26:     if [ -z "$DISK" ]; then
27:       echo "Alcatraz OS Installer"
28:       echo ""
29:       echo "Usage: alcatraz-install <disk>"
30:       echo "Example: alcatraz-install /dev/sda"
31:       echo ""
32:       echo "Available disks:"
33:       lsblk -d -o NAME,SIZE,MODEL | grep -v loop
34:       exit 1
35:     fi
36: 
37:     if [ ! -b "$DISK" ]; then
38:       echo "Error: $DISK is not a block device."
39:       exit 1
40:     fi
41: 
42:     if [ ! -d /sys/firmware/efi ]; then
43:       echo "Error: UEFI firmware not detected."
44:       echo "Alcatraz OS requires a UEFI-capable system."
45:       exit 1
46:     fi
47: 
48:     # NVMe and eMMC disks use a 'p' separator before partition numbers
49:     if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
50:       PART="''${DISK}p"
51:     else
52:       PART="$DISK"
53:     fi
54: 
55:     echo "=== Alcatraz OS Installer ==="
56:     echo ""
57:     echo "Target disk: $DISK"
58:     lsblk "$DISK"
59:     echo ""
60:     echo "WARNING: ALL DATA on $DISK will be erased."
61:     read -p "Type 'yes' to continue: " CONFIRM
62:     if [ "$CONFIRM" != "yes" ]; then
63:       echo "Aborted."
64:       exit 0
65:     fi
66: 
67:     echo ""
68:     echo "[1/6] Partitioning $DISK (GPT, UEFI)..."
69:     parted "$DISK" -- mklabel gpt
70:     parted "$DISK" -- mkpart ESP fat32 1MB 512MB
71:     parted "$DISK" -- set 1 esp on
72:     parted "$DISK" -- mkpart root ext4 512MB -8GB
73:     parted "$DISK" -- mkpart swap linux-swap -8GB 100%
74: 
75:     echo "[2/6] Formatting..."
76:     mkfs.fat -F 32 -n boot "''${PART}1"
77:     mkfs.ext4 -L nixos "''${PART}2"
78:     mkswap -L swap "''${PART}3"
79: 
80:     echo "[3/6] Mounting..."
81:     mount /dev/disk/by-label/nixos /mnt
82:     mkdir -p /mnt/boot
83:     mount /dev/disk/by-label/boot /mnt/boot
84:     swapon /dev/disk/by-label/swap
85: 
86:     echo "[4/6] Copying configuration..."
87:     mkdir -p /mnt/etc/nixos
88:     cp -r /etc/alcatraz/* /mnt/etc/nixos/
89: 
90:     echo "[5/6] Detecting hardware..."
91:     nixos-generate-config --root /mnt --dir /tmp/hw-config
92:     cp /tmp/hw-config/hardware-configuration.nix \
93:       /mnt/etc/nixos/src/hosts/alcatraz/hardware-configuration.nix
94: 
95:     # Replace GRUB (legacy) bootloader with systemd-boot (UEFI)
96:     CONF="/mnt/etc/nixos/src/hosts/alcatraz/configuration.nix"
97:     sed -i 's|boot.loader.grub.enable = true;|boot.loader.systemd-boot.enable = true;|' "$CONF"
98:     sed -i 's|boot.loader.grub.device = .*|boot.loader.efi.canTouchEfiVariables = true;|' "$CONF"
99:     sed -i '/boot.loader.grub.useOSProber/d' "$CONF"
100: 
101:     echo "[6/6] Installing Alcatraz OS (this will take a while)..."
102:     nixos-install --flake /mnt/etc/nixos/src#alcatraz
103: 
104:     echo ""
105:     echo "=== Installation complete ==="
106:     echo "Remove the installation media and reboot."
107:   '';
108: 
109: in
110: {
111:   environment.systemPackages = with pkgs; [
112:     alcatraz-install
113:     vim
114:     git
115:     parted
116:     gptfdisk
117:   ];
118: 
119:   # Make the flake source available at /etc/alcatraz in the live environment
120:   environment.etc."alcatraz".source = self;
121: 
122:   # Use fast compression during development. For release builds, remove this
123:   # line to use the default xz compression (smaller file, slower build).
124:   isoImage.squashfsCompression = "gzip -Xcompression-level 1";
125: }

(End of file - total 125 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/home"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/home</path>
<type>directory</type>
<entries>
home-al.nix
home-common.nix
home-dev.nix

(3 entries)
</entries>
```

---

## Assistant (Plan · claude-opus-4-6 · 4.2s)

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/home/home-common.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/home/home-common.nix</path>
<type>file</type>
<content>1: { config, pkgs, ... }:
2: 
3: {
4:   home.stateVersion = "25.11";
5: }

(End of file - total 5 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/home/home-dev.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/home/home-dev.nix</path>
<type>file</type>
<content>1: { config, pkgs, ... }:
2: 
3: {
4:   imports = [ ./home-common.nix ];
5:   home.packages = with pkgs; [
6:     git 
7:     vim 
8:     mc 
9:     htop 
10:     vscodium 
11:     opencode
12:     nixd
13:   ];
14: }

(End of file - total 14 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/src/home/home-al.nix"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/src/home/home-al.nix</path>
<type>file</type>
<content>1: { config, pkgs, ... }:
2: 
3: {
4:   imports = [ ./home-common.nix ];
5:   home.packages = with pkgs; [
6:     git
7:     ripgrep
8:     fd
9:     tree
10:   ];
11: }

(End of file - total 11 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/home/dev/code/alcatraz-os/README.md"
}
```

**Output:**
```
<path>/home/dev/code/alcatraz-os/README.md</path>
<type>file</type>
<content>1: # Alcatraz OS
2: 
3: A NixOS-based operating system for AI-assisted software development. Ships with
4: two user accounts: `dev` (human developer) and `al` (AI coding agent), each with
5: their own tailored tool set.
6: 
7: ## Getting Alcatraz OS
8: 
9: ### Option 1: Install from ISO (bare-metal)
10: 
11: Requires a UEFI-capable x86_64 machine and internet access during install.
12: 
13: 1. Build the ISO (or download from Releases):
14:    ```
15:    nix build ./src#iso
16:    ```
17: 2. Write it to a USB drive:
18:    ```
19:    sudo dd bs=4M conv=fsync oflag=direct status=progress \
20:      if=result/iso/nixos-*.iso of=/dev/sdX
21:    ```
22: 3. Boot from the USB and run:
23:    ```
24:    alcatraz-install /dev/sda
25:    ```
26: 4. Remove the USB and reboot.
27: 
28: ### Option 2: WSL 2 (Windows)
29: 
30: 1. Build the tarball (or download from Releases):
31:    ```
32:    sudo nix run ./src#alcatraz-wsl-tarball
33:    ```
34: 2. Import into WSL:
35:    ```
36:    wsl --install --from-file nixos.wsl
37:    ```
38:    For WSL older than 2.4.4:
39:    ```
40:    wsl --import NixOS <install-path> nixos.wsl
41:    ```
42: 
43: ### Option 3: Existing NixOS installation
44: 
45: 1. Clone the repo:
46:    ```
47:    git clone https://github.com/forqstudio/alcatraz-os.git
48:    ```
49: 2. Generate hardware config for your machine:
50:    ```
51:    sudo nixos-generate-config --dir ./alcatraz-os/src/hosts/alcatraz/
52:    ```
53: 3. Edit `src/hosts/alcatraz/configuration.nix` to match your bootloader and
54:    locale settings.
55: 4. Apply the configuration:
56:    ```
57:    sudo nixos-rebuild switch --flake ./alcatraz-os/src#alcatraz
58:    ```
59: 
60: ## Building from source
61: 
62: Requires Nix with flakes enabled.
63: 
64: | Artifact | Command | Output |
65: |----------|---------|--------|
66: | ISO image | `nix build ./src#iso` | `result/iso/nixos-*.iso` |
67: | WSL tarball | `sudo nix run ./src#alcatraz-wsl-tarball` | `nixos.wsl` |
68: 
69: ## Project structure
70: 
71: ```
72: src/
73:   flake.nix              # Flake entry point (inputs, outputs)
74:   hosts/
75:     alcatraz/             # Bare-metal host config
76:     alcatraz-iso/         # Installer ISO config
77:     alcatraz-wsl/         # WSL 2 host config
78:   modules/
79:     base.nix              # Shared settings (users, networking, nix)
80:     desktop.nix           # Graphical environment (XFCE, PipeWire)
81:     wsl.nix               # WSL 2 integration
82:   home/
83:     home-common.nix       # Shared home-manager base
84:     home-dev.nix          # dev user packages
85:     home-al.nix           # al (AI agent) user packages
86: ```

(End of file - total 86 lines)
</content>
```

---

## Assistant (Plan · claude-opus-4-6 · 127.0s)

_Thinking:_

Now I have a thorough understanding of the codebase. Let me think about what needs to happen to transform this from a personal NixOS config into a proper NixOS distribution, and ask some clarifying questions.

Key transformations needed:

1. **Move flake.nix to repo root** - standard convention
2. **Convert modules to proper NixOS modules with `options`** - use `mkEnableOption`/`mkOption` so consumers can toggle features
3. **Export `nixosModules`** - so other flakes can consume Alcatraz OS modules
4. **Separate "distribution" from "personal config"** - the distribution defines the modules/options/packages, the hosts are example/personal configurations that consume them


5. **Organize supporting infrastructure** - I need to set up a `lib/` directory for utility functions, a `pkgs/` directory for custom packages like the installer, and overlays to make them available
6. **Add development and validation tooling** - include dev shells for contributors, CI checks for validation, and a formatter output
7. **Refactor configuration patterns** - move state version to be per-host, extract duplicated locale and timezone settings, make user accounts configurable instead of hardcoded, and use `eachSystem` patterns for multi-architecture support

Before diving deeper, I should clarify a few things about the project's scope and design: whether this is meant to be a reusable flake that others can import, whether the existing hardcoded users should stay or become configurable, if multi-arch support matters, and whether personal host configurations should live here or be separated out.

Before I lay out a full plan, I have a few questions that will shape the approach significantly:

**Tool: question**

**Input:**
```json
{
  "questions": [
    {
      "question": "Should other people be able to consume Alcatraz OS modules in their own flakes (e.g., `inputs.alcatraz-os.nixosModules.desktop`)? Or is this primarily about making this repo follow distribution structure for your own hosts?",
      "header": "Target audience",
      "options": [
        {
          "label": "Consumable by others (Recommended)",
          "description": "Export nixosModules, overlays, and packages so anyone can add `inputs.alcatraz-os` to their flake and selectively enable Alcatraz features"
        },
        {
          "label": "Own hosts only",
          "description": "Restructure for proper conventions but keep it self-contained for your own machines"
        }
      ]
    },
    {
      "question": "The hardcoded users `dev` and `al` with their specific packages are baked into base.nix and homeManagerModule. Should these become configurable options (e.g., `alcatraz.users.dev.enable = true`) or remain fixed as the distribution's opinionated defaults?",
      "header": "User accounts",
      "options": [
        {
          "label": "Configurable options (Recommended)",
          "description": "Define alcatraz.users.dev and alcatraz.users.al as toggleable options with mkEnableOption, so consumers can opt in/out"
        },
        {
          "label": "Fixed opinionated defaults",
          "description": "Keep dev and al as always-present users, which is simpler but less flexible"
        }
      ]
    },
    {
      "question": "Should we keep the personal host configs (alcatraz, alcatraz-wsl, alcatraz-iso) in this same repo, or separate them?",
      "header": "Host configs location",
      "options": [
        {
          "label": "Keep in same repo (Recommended)",
          "description": "Keep hosts/ as reference configurations and examples of how to use the distribution modules"
        },
        {
          "label": "Separate repo",
          "description": "Move personal host configs to a different repo that imports alcatraz-os as an input"
        }
      ]
    },
    {
      "question": "The flake.nix currently lives under src/ instead of the repo root. Moving it to the root is a standard convention. Should we do this?",
      "header": "Move flake.nix to root",
      "options": [
        {
          "label": "Yes, move to root (Recommended)",
          "description": "Enables standard `nix build .#iso` instead of `nix build ./src#iso`"
        },
        {
          "label": "Keep under src/",
          "description": "Preserve current structure, accept the non-standard path"
        }
      ]
    }
  ]
}
```

**Output:**
```
User has answered your questions: "Should other people be able to consume Alcatraz OS modules in their own flakes (e.g., `inputs.alcatraz-os.nixosModules.desktop`)? Or is this primarily about making this repo follow distribution structure for your own hosts?"="Consumable by others (Recommended)", "The hardcoded users `dev` and `al` with their specific packages are baked into base.nix and homeManagerModule. Should these become configurable options (e.g., `alcatraz.users.dev.enable = true`) or remain fixed as the distribution's opinionated defaults?"="Fixed opinionated defaults", "Should we keep the personal host configs (alcatraz, alcatraz-wsl, alcatraz-iso) in this same repo, or separate them?"="Keep in same repo (Recommended)", "The flake.nix currently lives under src/ instead of the repo root. Moving it to the root is a standard convention. Should we do this?"="Yes, move to root (Recommended)". You can now continue with the user's answers in mind.
```

---

## Assistant (Plan · claude-opus-4-6 · 69.5s)

_Thinking:_

Now I have the answers. Let me construct a comprehensive plan.

Summary of decisions:
1. Consumable by others - export nixosModules, overlays, packages
2. Fixed opinionated users (dev, al)
3. Keep host configs in same repo as reference examples
4. Move flake.nix to repo root

Let me plan the transformation:

## Plan

### Phase 1: Move flake.nix to repo root
- Move `src/flake.nix` and `src/flake.lock` to repo root
- Move all `src/` contents to root (modules/, hosts/, home/, docs/)


- Update all relative import paths and README.md commands

### Phase 2: Convert modules to proper NixOS modules with options
- Each module (base, desktop, wsl) should define `options` and `config` sections with proper `mkEnableOption` declarations for their respective enable flags

### Phase 3: Extract custom packages to `pkgs/`
- Move the `alcatraz-install` script and other custom packages out of inline configs into a dedicated packages directory with an overlay

### Phase 4: Create lib/ for shared utilities
- Add helper functions to a shared library module

### Phase 5: Export flake outputs
- Expose the modules, overlays, dev shells, checks, and formatter through the flake interface

### Phase 6: Fix per-host stateVersion
- Move `system.stateVersion` from the base module into each host's individual configuration

### Phase 7: De-duplicate locale/timezone settings
- Extract common locale and timezone configuration to avoid repetition across hosts

### Phase 8: Multi-arch pattern
- Set up the flake to support multiple systems using `genAttrs`, even if only targeting x86_64-linux initially

### Phase 9: Add formatter and checks
- Include a formatter output and validation checks that ensure configurations build successfully

### Phase 10: Update README
- Revise documentation to reflect the root-level flake structure and provide usage examples for consumers

Now I'm thinking through the directory structure more carefully. The current layout has everything nested under `src/`, but moving the flake to the root would flatten things out and make the project cleaner.

For the module conversion, I need to be careful about how I structure things like `base.nix`. Defining a module with proper options and configuration...

Defining module options... Still writing module structure...

State version should be set per-host, not in the modules themselves. For the overlay, I'll expose the custom `alcatraz-install` package through it. The home-manager users (`dev` and `al`) should stay as opinionated defaults but be properly integrated into the module system rather than hardcoded.

Now I'm considering whether to create a central `modules/default.nix` that imports everything—that's a standard pattern for cleanly exposing the full module set.

Good, that gives me a clear direction. Here's the full plan to transform Alcatraz OS into a proper NixOS distribution:

---

## Plan: Alcatraz OS — Personal Config to Proper Distribution

### Phase 1: Restructure — Move flake to repo root

Move everything from `src/` to the repo root. This is the single most impactful structural change.

**Before:**
```
alcatraz-os/
  src/
    flake.nix
    flake.lock
    hosts/ modules/ home/ docs/
```

**After:**
```
alcatraz-os/
  flake.nix
  flake.lock
  hosts/          # reference host configs (examples)
  modules/        # NixOS modules with proper options
  home/           # home-manager configs
  pkgs/           # custom packages (new)
  docs/
```

All relative imports inside nix files update accordingly. README commands become `nix build .#iso` instead of `nix build ./src#iso`. The installer script's paths also need updating.

---

### Phase 2: Convert modules to proper NixOS options

This is the core architectural change. Each module gets `options` + `config` sections using `mkEnableOption`/`mkIf`.

**`modules/base.nix`** — becomes `alcatraz.base.enable`:
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.base;
in {
  options.alcatraz.base = {
    enable = lib.mkEnableOption "Alcatraz OS base configuration";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    users.users.dev = { isNormalUser = true; ... };
    users.users.al  = { isNormalUser = true; ... };
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    # NOTE: stateVersion removed — now per-host
  };
}
```

**`modules/desktop.nix`** — becomes `alcatraz.desktop.enable`:
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.desktop;
in {
  options.alcatraz.desktop = {
    enable = lib.mkEnableOption "Alcatraz desktop (XFCE, PipeWire, CUPS)";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.xfce.enable = true;
    # ... rest of desktop config
  };
}
```

**`modules/wsl.nix`** — becomes `alcatraz.wsl.enable`, with the `nixos-wsl` dependency documented (consumers must add it to their inputs and import its module):
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.wsl;
in {
  options.alcatraz.wsl = {
    enable = lib.mkEnableOption "Alcatraz WSL2 integration";
  };

  config = lib.mkIf cfg.enable {
    wsl.enable = true;
    wsl.defaultUser = "dev";
  };
}
```

**`modules/home.nix`** (new) — wraps the Home Manager user configuration:
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.home;
in {
  options.alcatraz.home = {
    enable = lib.mkEnableOption "Alcatraz Home Manager user configs";
  };

  config = lib.mkIf cfg.enable {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.dev = import ../home/home-dev.nix;
    home-manager.users.al  = import ../home/home-al.nix;
  };
}
```

**`modules/default.nix`** (new) — imports all modules so consumers can do a single import:
```nix
{ imports = [ ./base.nix ./desktop.nix ./wsl.nix ./home.nix ]; }
```

---

### Phase 3: Extract custom packages to `pkgs/`

Move the inline `alcatraz-install` script to a standalone derivation:

- **`pkgs/alcatraz-install/default.nix`** — the `writeShellScriptBin` derivation, extracted from the ISO host config
- **`pkgs/default.nix`** — aggregates all custom packages as a set (for overlay use)

---

### Phase 4: Add an overlay

**`overlays/default.nix`**:
```nix
final: prev: {
  alcatraz-install = final.callPackage ../pkgs/alcatraz-install {};
}
```

This lets consumers add `overlays.default` to their nixpkgs and get Alcatraz packages in their package set.

---

### Phase 5: Expand flake outputs

The new `flake.nix` exports a full set of standard flake outputs:

| Output | Purpose |
|--------|---------|
| `nixosModules.base` | Base system config |
| `nixosModules.desktop` | XFCE desktop environment |
| `nixosModules.wsl` | WSL2 integration |
| `nixosModules.home` | Home Manager user configs |
| `nixosModules.default` | All modules combined |
| `overlays.default` | Custom packages overlay |
| `packages.x86_64-linux.alcatraz-install` | Installer script |
| `packages.x86_64-linux.iso` | ISO image |
| `packages.x86_64-linux.alcatraz-wsl-tarball` | WSL tarball |
| `devShells.x86_64-linux.default` | Dev shell for contributors |
| `checks.x86_64-linux.*` | Validate configs build |
| `formatter.x86_64-linux` | `nix fmt` support |
| `nixosConfigurations.*` | Reference host configs |

---

### Phase 6: Fix per-host stateVersion

Move `system.stateVersion` out of `modules/base.nix` and into each host's `configuration.nix`. Same for `home.stateVersion` — move from `home-common.nix` to per-host home config or set via `extraSpecialArgs`.

---

### Phase 7: De-duplicate locale/timezone

The identical timezone and `i18n.extraLocaleSettings` blocks in `hosts/alcatraz/configuration.nix` and `hosts/alcatraz-wsl/configuration.nix` get extracted into `modules/base.nix` (as part of the `alcatraz.base` config) or a new `modules/locale.nix`.

---

### Phase 8: Update host configs to use new options

Host configs become much cleaner — they import modules and toggle options:

```nix
# hosts/alcatraz/configuration.nix
{ config, pkgs, ... }: {
  imports = [ ../../modules ./hardware-configuration.nix ];
  
  alcatraz.base.enable = true;
  alcatraz.desktop.enable = true;
  alcatraz.home.enable = true;
  
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  networking.hostName = "alcatraz";
  system.stateVersion = "25.11";
}
```

---

### Phase 9: Add devShell, checks, formatter

- **devShell**: Provides `nixfmt`, `nil` (nix LSP), and any other dev tools
- **checks**: Build each `nixosConfiguration` in check mode to catch errors
- **formatter**: `nixfmt-rfc-style` (the emerging community standard)

---

### Phase 10: Update README

- Update all commands to reflect root-level flake (`.#iso` not `./src#iso`)
- Add a "Using Alcatraz OS in your own flake" section showing how to consume the modules
- Document each `nixosModule` and its options

---

### File change summary

| Action | Files |
|--------|-------|
| **Move** | `src/*` → repo root |
| **Rewrite** | `flake.nix`, `modules/base.nix`, `modules/desktop.nix`, `modules/wsl.nix` |
| **New** | `modules/default.nix`, `modules/home.nix`, `pkgs/alcatraz-install/default.nix`, `pkgs/default.nix`, `overlays/default.nix` |
| **Edit** | All host configs, `home/home-common.nix`, `README.md`, `.gitignore` |
| **Delete** | `src/` directory (contents moved to root) |

---

Want me to proceed with implementation? If so, is there anything in this plan you'd like to change or prioritize differently?

---

## User

Add the reasoning for these changes to the plan 

---

## Assistant (Plan · claude-opus-4-6 · 90.4s)

_Thinking:_

The user wants me to add reasoning/justification for each change in the plan. Let me enrich each phase with the "why" — explaining the NixOS convention, the problem with the current approach, and the benefit of the change. I should NOT make any edits, just present the enhanced plan.

Here's the plan with reasoning added for every change:

---

## Plan: Alcatraz OS — Personal Config to Proper Distribution

### Phase 1: Restructure — Move flake to repo root

**What:** Move `src/flake.nix`, `src/flake.lock`, and all subdirectories (`modules/`, `hosts/`, `home/`, `docs/`) from `src/` to the repository root. Delete the now-empty `src/` directory. Update all relative import paths in nix files and all commands in `README.md`.

**Before:**
```
alcatraz-os/
  src/
    flake.nix
    flake.lock
    hosts/ modules/ home/ docs/
```

**After:**
```
alcatraz-os/
  flake.nix
  flake.lock
  hosts/          # reference host configs (examples)
  modules/        # NixOS modules with proper options
  home/           # home-manager configs
  pkgs/           # custom packages (new — Phase 3)
  overlays/       # nixpkgs overlays (new — Phase 4)
  docs/
```

**Why:** The Nix CLI expects `flake.nix` at the root of a Git repository. Every command currently requires `./src#` instead of `.#` (e.g., `nix build ./src#iso`). This is not just inconvenient — it breaks user expectations. Anyone who clones the repo and runs `nix flake show` at the root gets nothing. Every major NixOS distribution flake (nixpkgs, NixOS-WSL, home-manager, disko, etc.) places `flake.nix` at the repo root. Deviating from this convention means tooling like `direnv`, `nix develop`, and CI/CD templates that assume `.#` all fail without workarounds.

---

### Phase 2: Convert modules to proper NixOS options

**What:** Rewrite each module under `modules/` to declare `options` using `lib.mkEnableOption` and guard all `config` values behind `lib.mkIf`. Add a new `modules/default.nix` that imports all modules, and a new `modules/home.nix` that wraps the Home Manager user configuration.

**Affected files:**
- Rewrite: `modules/base.nix`, `modules/desktop.nix`, `modules/wsl.nix`
- New: `modules/default.nix`, `modules/home.nix`

**Example — `modules/base.nix`:**
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.base;
in {
  options.alcatraz.base = {
    enable = lib.mkEnableOption "Alcatraz OS base configuration";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    users.users.dev = { isNormalUser = true; extraGroups = [ "networkmanager" "wheel" ]; ... };
    users.users.al  = { isNormalUser = true; extraGroups = [ "networkmanager" "wheel" ]; ... };
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
```

**Example — `modules/desktop.nix`:**
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.desktop;
in {
  options.alcatraz.desktop = {
    enable = lib.mkEnableOption "Alcatraz desktop (XFCE, PipeWire, CUPS)";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    services.xserver.desktopManager.xfce.enable = true;
    services.xserver.xkb = { layout = "us"; variant = ""; };
    services.printing.enable = true;
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = { enable = true; alsa.enable = true; alsa.support32Bit = true; pulse.enable = true; };
    programs.firefox.enable = true;
  };
}
```

**Example — `modules/wsl.nix`:**
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.wsl;
in {
  options.alcatraz.wsl = {
    enable = lib.mkEnableOption "Alcatraz WSL2 integration";
  };

  config = lib.mkIf cfg.enable {
    wsl.enable = true;
    wsl.defaultUser = "dev";
  };
}
```

Note: the `nixos-wsl.nixosModules.wsl` import moves from this module to the host config (or is documented as a consumer prerequisite), because a proper exported module must not depend on `specialArgs` that only exist in this flake.

**Example — `modules/home.nix` (new):**
```nix
{ config, lib, pkgs, ... }:
let cfg = config.alcatraz.home;
in {
  options.alcatraz.home = {
    enable = lib.mkEnableOption "Alcatraz Home Manager user configs";
  };

  config = lib.mkIf cfg.enable {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.dev = import ../home/home-dev.nix;
    home-manager.users.al  = import ../home/home-al.nix;
  };
}
```

**Example — `modules/default.nix` (new):**
```nix
{ imports = [ ./base.nix ./desktop.nix ./wsl.nix ./home.nix ]; }
```

**Why:** This is the single most important change for making this a distribution rather than a personal config. The current modules are plain configuration fragments — they unconditionally set values the moment they're imported. This is the defining trait of a personal config: it works for the author's machines but is unusable by anyone else.

A proper NixOS module declares `options` (what can be configured) separately from `config` (what happens when enabled). This pattern is what every upstream NixOS module uses (see `nixos/modules/` in nixpkgs), and it's what makes NixOS composable. Without it:

- **No discoverability**: Consumers can't run `nixos-option alcatraz.desktop` to see what the module provides.
- **No opt-in**: Importing a module forces all its config on you. A consumer who wants Alcatraz base but not XFCE has to fork the code.
- **No conflict resolution**: If two modules set the same option, `lib.mkIf` and priority mechanisms resolve it cleanly. Plain config fragments cause hard errors.
- **No documentation generation**: Tools like `nixos-generate-config` and the NixOS option search only work with properly declared options.

The `modules/default.nix` aggregation file lets consumers do a single `imports = [ alcatraz-os.nixosModules.default ]` and then toggle features declaratively, which is the standard pattern used by distributions like `nixos-hardware`.

The separate `modules/home.nix` is needed because the Home Manager integration is currently an anonymous attrset inlined in `flake.nix`. Wrapping it as a toggleable module means consumers who don't want the opinionated `dev`/`al` user configs (or use standalone Home Manager) can simply not enable it.

The `wsl.nix` change (removing the `nixos-wsl` import) is necessary because exported NixOS modules must be self-contained — they cannot rely on `specialArgs` that only exist inside this flake's `nixosConfigurations`. Consumers will import `nixos-wsl.nixosModules.wsl` themselves; the Alcatraz WSL module only sets the Alcatraz-specific WSL options on top of it.

---

### Phase 3: Extract custom packages to `pkgs/`

**What:** Move the inline `alcatraz-install` shell script from `hosts/alcatraz-iso/configuration.nix:17-107` into a standalone derivation at `pkgs/alcatraz-install/default.nix`. Create `pkgs/default.nix` to aggregate all custom packages.

**New files:**
- `pkgs/alcatraz-install/default.nix`
- `pkgs/default.nix`

**Why:** The install script is currently a 90-line `writeShellScriptBin` embedded directly in a host configuration file. This creates three problems:

1. **Reusability**: The package can't be referenced from anywhere except the ISO host config. If a consumer wants to include the installer in their own ISO, they'd have to copy-paste the script.
2. **Testability**: An inline script can't be built or tested independently. Extracting it to `pkgs/` means `nix build .#alcatraz-install` works standalone, enabling CI checks and quick iteration.
3. **Convention**: NixOS distributions and overlays expose packages under `pkgs/` as standalone derivations. This is what nixpkgs itself does (`pkgs/by-name/`), and what community projects like `nix-community/nur-packages` expect. Having a `pkgs/` directory with proper `callPackage`-compatible derivations is the prerequisite for the overlay in Phase 4.

The `pkgs/default.nix` acts as an index, which is the standard pattern for a package set that can be consumed by overlays or the flake's `packages` output.

---

### Phase 4: Add an overlay

**What:** Create `overlays/default.nix` that injects Alcatraz custom packages into nixpkgs.

```nix
final: prev: {
  alcatraz-install = final.callPackage ../pkgs/alcatraz-install {};
}
```

**Why:** Overlays are the standard NixOS mechanism for extending nixpkgs with custom packages. Without an overlay, consumers who want Alcatraz packages must manually wire them in. With an overlay, a consumer adds one line to their flake:

```nix
nixpkgs.overlays = [ alcatraz-os.overlays.default ];
```

...and then `pkgs.alcatraz-install` is available everywhere in their configuration as if it were a nixpkgs package. This is the pattern used by projects like `nixos-wsl`, `rust-overlay`, and `emacs-overlay`. It's also what makes the packages available inside NixOS modules without passing them through `specialArgs` or other workarounds.

---

### Phase 5: Expand flake outputs

**What:** Rewrite `flake.nix` to export the full standard set of flake outputs.

| Output | Purpose |
|--------|---------|
| `nixosModules.base` | Base system config module |
| `nixosModules.desktop` | XFCE desktop environment module |
| `nixosModules.wsl` | WSL2 integration module |
| `nixosModules.home` | Home Manager user configs module |
| `nixosModules.default` | All modules combined |
| `overlays.default` | Custom packages overlay |
| `packages.x86_64-linux.alcatraz-install` | Installer script package |
| `packages.x86_64-linux.iso` | ISO image |
| `packages.x86_64-linux.alcatraz-wsl-tarball` | WSL tarball |
| `devShells.x86_64-linux.default` | Dev shell for contributors |
| `checks.x86_64-linux.*` | Validate configs build |
| `formatter.x86_64-linux` | `nix fmt` support |
| `nixosConfigurations.*` | Reference host configs (existing) |

**Why:** The Nix flake schema defines a set of well-known output attributes. Currently the flake only exports `nixosConfigurations` and `packages` — which is the minimum for a personal config. A distribution needs to export more because each output type serves a different consumer:

- **`nixosModules`**: This is the primary consumption interface. Without this, nobody can use Alcatraz OS in their own flake. This is what makes a project a "distribution" vs. a "config" — it exports reusable building blocks, not just complete system configurations. Every major NixOS project exports modules: `home-manager.nixosModules.home-manager`, `nixos-wsl.nixosModules.wsl`, `disko.nixosModules.disko`, etc.

- **`overlays`**: Required for custom packages (Phase 4). Without it, the custom packages are isolated inside this flake.

- **`devShells`**: Running `nix develop` in the repo should give contributors all the tools they need (formatter, linter, nix LSP). This is a quality-of-life standard for any open-source Nix project. Without it, contributors have to manually install tooling.

- **`checks`**: `nix flake check` currently does nothing useful for this flake. Adding checks that evaluate each `nixosConfiguration` catches configuration errors before deployment. This is what CI pipelines run and is the basis for automated validation.

- **`formatter`**: Defines what `nix fmt` uses. Without it, there's no canonical formatting for the project, leading to inconsistent style across contributors.

---

### Phase 6: Fix per-host stateVersion

**What:** Remove `system.stateVersion = "25.11"` from `modules/base.nix` and `home.stateVersion = "25.11"` from `home/home-common.nix`. Add both to each host's `configuration.nix` instead.

**Why:** The NixOS documentation explicitly states: *"Do not change this value [...] It is NOT supposed to be changed with each release."* The `stateVersion` records when a specific machine was first installed, and NixOS uses it to maintain backward compatibility for stateful services (database schemas, state directory layouts, etc.) on that machine.

Putting it in a shared module means all hosts share the same value. If a new host is added a year from now when NixOS is at 26.05, it would incorrectly inherit `"25.11"` from the shared module. Conversely, bumping the shared value would break existing hosts. Per-host is the only correct placement — each host records its own installation version independently. This is consistent with what `nixos-generate-config` produces (it writes `stateVersion` into the per-host `configuration.nix`).

---

### Phase 7: De-duplicate locale/timezone

**What:** The `time.timeZone` and `i18n.extraLocaleSettings` blocks are identical between `hosts/alcatraz/configuration.nix:34-48` and `hosts/alcatraz-wsl/configuration.nix:24-38`. Extract these into `modules/base.nix` as part of the `alcatraz.base` config.

**Why:** Duplicated configuration is a maintenance burden and a source of drift bugs. If someone updates the timezone in one host but forgets the other, the machines silently diverge. Since both hosts share the same locale settings (they're for the same team/region), this belongs in the shared base module. This follows the DRY principle that's central to NixOS module composition — the whole point of modules is to define shared config once.

If in the future a host needs different locale settings, it can override the base module's values using `lib.mkForce` or a higher-priority setting, which is the standard NixOS conflict resolution mechanism.

---

### Phase 8: Update host configs to use new options

**What:** Rewrite each host's `configuration.nix` to import `modules/default.nix` (or the root `modules/`) and set `alcatraz.*.enable = true` options instead of directly importing individual modules.

**Example — `hosts/alcatraz/configuration.nix`:**
```nix
{ config, pkgs, ... }: {
  imports = [
    ../../modules        # imports modules/default.nix
    ./hardware-configuration.nix
  ];

  alcatraz.base.enable = true;
  alcatraz.desktop.enable = true;
  alcatraz.home.enable = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.useOSProber = true;
  networking.hostName = "alcatraz";
  system.stateVersion = "25.11";
}
```

**Example — `hosts/alcatraz-wsl/configuration.nix`:**
```nix
{ config, pkgs, ... }: {
  imports = [
    ../../modules
    nixos-wsl.nixosModules.wsl   # consumer provides this
  ];

  alcatraz.base.enable = true;
  alcatraz.wsl.enable = true;
  alcatraz.home.enable = true;

  networking.hostName = "alcatraz-wsl";
  system.stateVersion = "25.11";
}
```

**Why:** This is the consumer-facing proof that the module system works. The host configs become the **reference examples** that demonstrate how to use Alcatraz OS modules. Compare the current `hosts/alcatraz/configuration.nix` (which has implicit behavior from direct imports) with the proposed version (which explicitly declares what features are enabled). The new style:

1. **Self-documents**: Anyone reading the host config immediately sees which Alcatraz features are active.
2. **Serves as a template**: A new user copies a host directory and toggles the options they want — no need to understand module internals.
3. **Validates the module API**: If the reference hosts work, external consumers can trust the same modules work in their flakes.

---

### Phase 9: Update README

**What:** Update all build commands to reflect the root-level flake. Add a "Using Alcatraz OS in your own flake" section with consumer usage examples.

**Why:** The README is the entry point for anyone evaluating the project. The current README documents a personal config workflow (`nix build ./src#iso`). A distribution README needs to document two audiences:

1. **End users**: How to install/use the complete OS (existing content, updated paths).
2. **Module consumers**: How to add `inputs.alcatraz-os` to their flake and enable specific modules — this is what makes it a distribution rather than a "clone and fork" project.

Without consumer documentation, the exported `nixosModules` and `overlays` are discoverable only by reading `flake.nix`, which most users won't do.

---

### Summary of changes

| Phase | Files affected | Type |
|-------|---------------|------|
| 1. Move to root | All files under `src/` | Move + path updates |
| 2. Module options | `modules/base.nix`, `modules/desktop.nix`, `modules/wsl.nix` | Rewrite |
| 2. New modules | `modules/default.nix`, `modules/home.nix` | New |
| 3. Extract packages | `pkgs/alcatraz-install/default.nix`, `pkgs/default.nix` | New |
| 4. Overlay | `overlays/default.nix` | New |
| 5. Flake outputs | `flake.nix` | Rewrite |
| 6. stateVersion | `modules/base.nix`, `home/home-common.nix`, all host configs | Edit |
| 7. De-duplicate locale | `modules/base.nix`, both host configs | Edit |
| 8. Host configs | `hosts/*/configuration.nix` | Rewrite |
| 9. README | `README.md` | Rewrite |

---

Anything you'd like adjusted before implementation?

---

