# Alcatraz OS - Security & AI Agent Environment Plan

## Goals

1. **Security & Sandboxing** - Harden the `al` (AI agent) user with systemd sandboxing, network restrictions, filesystem isolation, and audit logging
2. **AI Agent Environment** - Configure the `al` user as an optimized environment for running OpenCode as a persistent service

## Architecture

```
dev (human)                          al (AI agent)
  |                                    |
  |-- vscodium, vim, mc, htop         |-- opencode, ripgrep, fd, bat, jq, ...
  |-- opencode (attach client)        |-- runs as systemd service
  |-- wheel, networkmanager           |-- NO sudo, NO networkmanager
  |                                    |
  +-------- /home/shared/workspace --------+
                 (shared group)
```

**OpenCode runs as a persistent systemd service** (`opencode serve`) under the `al` user. The `dev` user connects to it via `opencode attach http://127.0.0.1:4096`.

---

## Phase 1: User Hardening

**File:** `src/alcatraz/configuration.nix`

### Changes

- Remove `al` from `wheel` and `networkmanager` groups (prevent sudo and network reconfiguration)
- Set `homeMode = "700"` on both users (users cannot read each other's home directories)
- Create a `workspace` group for shared file access
- Add both users to the `workspace` group
- Configure `nix.settings.trusted-users` to `[ "root" "dev" ]` only (prevent `al` from tampering with the nix store)
- Configure `nix.settings.allowed-users` to `[ "dev" "al" ]`

```nix
users.groups.workspace = {};

users.users.dev = {
  isNormalUser = true;
  description = "Developer";
  extraGroups = [ "networkmanager" "wheel" "workspace" ];
  homeMode = "700";
};

users.users.al = {
  isNormalUser = true;
  description = "AI Agent";
  extraGroups = [ "workspace" ];
  homeMode = "700";
};

nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  trusted-users = [ "root" "dev" ];
  allowed-users = [ "dev" "al" ];
};
```

---

## Phase 2: Shared Workspace

**File:** `src/alcatraz/configuration.nix`

Create `/home/shared/workspace` with setgid so new files inherit the `workspace` group:

```nix
systemd.tmpfiles.rules = [
  "d /home/shared 0755 root root -"
  "d /home/shared/workspace 2775 dev workspace -"
];
```

---

## Phase 3: Firewall & Network Allowlist

**File:** `src/alcatraz/configuration.nix`

Enable nftables with per-UID rules restricting `al` to HTTPS (port 443) and DNS only. All other outbound traffic from `al` is dropped.

```nix
networking.firewall.enable = true;
networking.nftables.enable = true;
networking.nftables.tables.alcatraz-agent-filter = {
  family = "inet";
  content = ''
    chain output {
      type filter hook output priority 0; policy accept;

      # Allow all traffic from non-al users
      meta skuid != al accept

      # Allow loopback for al
      oifname "lo" accept

      # Allow DNS (needed to resolve api.anthropic.com)
      meta skuid al udp dport 53 accept
      meta skuid al tcp dport 53 accept

      # Allow HTTPS to Anthropic API (port 443 only)
      meta skuid al tcp dport 443 accept

      # Drop everything else from al
      meta skuid al drop
    }
  '';
};
```

> **Note:** nftables cannot filter by hostname (DNS is resolved at the application layer). The rule restricts `al` to HTTPS + DNS only. For hostname-based filtering, a forward proxy would be needed (future enhancement).

---

## Phase 4: OpenCode systemd Service

**File:** `src/alcatraz/configuration.nix`

Run OpenCode as a persistent, sandboxed systemd service:

```nix
systemd.services.opencode-agent = {
  description = "OpenCode AI Agent Service";
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  wantedBy = [ "multi-user.target" ];

  environment = {
    HOME = "/home/al";
    OPENCODE_DISABLE_AUTOUPDATE = "true";
    OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    NO_PROXY = "localhost,127.0.0.1";
  };

  serviceConfig = {
    User = "al";
    Group = "al";
    Type = "simple";
    ExecStart = "${pkgs.opencode}/bin/opencode serve --port 4096 --hostname 127.0.0.1";
    Restart = "on-failure";
    RestartSec = 5;
    WorkingDirectory = "/home/shared/workspace";

    # Filesystem Hardening
    ProtectSystem = "strict";
    ProtectHome = "tmpfs";
    BindPaths = [
      "/home/shared/workspace"
      "/home/al/.config/opencode"
      "/home/al/.local/share/opencode"
    ];
    BindReadOnlyPaths = [
      "/etc/resolv.conf"
      "/etc/ssl"
      "/etc/hosts"
    ];
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;

    # Privilege Hardening
    NoNewPrivileges = true;
    RestrictSUIDSGID = true;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    LockPersonality = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    SystemCallArchitectures = "native";
    UMask = "0077";

    # Network
    RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";

    # Note: MemoryDenyWriteExecute is intentionally omitted
    # because Node.js (OpenCode runtime) requires JIT compilation.
  };
};
```

### How `dev` connects

```bash
# From the dev user's terminal:
opencode attach http://127.0.0.1:4096
```

---

## Phase 5: Audit Logging

**File:** `src/alcatraz/configuration.nix`

Enable Linux auditd to track the AI agent's actions:

```nix
security.auditd.enable = true;
security.audit = {
  enable = true;
  rules = [
    # Track all process execution by al
    "-a always,exit -F arch=b64 -S execve -F uid=1001 -k al-exec"

    # Track network connections by al
    "-a always,exit -F arch=b64 -S connect,accept -F uid=1001 -k al-network"

    # Monitor any access to dev's home directory
    "-w /home/dev -p rwxa -k dev-home-access"

    # Monitor writes to the shared workspace
    "-w /home/shared/workspace -p wa -k workspace-write"
  ];
};
```

### Viewing audit logs

```bash
# View all AI agent process executions
ausearch -k al-exec

# View all AI agent network connections
ausearch -k al-network

# View workspace write activity
ausearch -k workspace-write

# Real-time monitoring
journalctl -u opencode-agent -f
```

---

## Phase 6: AI Agent Environment

**File:** `src/home/home-al.nix`

Expand the `al` user's toolchain with everything OpenCode needs:

```nix
{ config, pkgs, ... }:

{
  imports = [ ./home-common.nix ];

  home.packages = with pkgs; [
    # Core tools (existing)
    git
    ripgrep
    fd
    tree

    # OpenCode
    opencode

    # Shell essentials (used by OpenCode's bash tool)
    bat
    jq
    curl
    wget
    less
    file
    diffutils
    gnugrep
    gnused
    gawk
    findutils

    # GitHub CLI
    gh

    # Node.js (for MCP servers)
    nodejs
  ];

  # Shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      oc = "opencode";
    };
  };

  # Environment variables
  home.sessionVariables = {
    OPENCODE_DISABLE_AUTOUPDATE = "true";
    OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    NO_PROXY = "localhost,127.0.0.1";
    EDITOR = "vim";
  };

  # XDG directories
  xdg.enable = true;

  # OpenCode global config
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    permission = {
      bash = "allow";
      edit = "allow";
      read = "allow";
    };
  };
}
```

---

## Phase 7: Update `flake.nix`

Update the project description:

```nix
description = "Alcatraz OS - NixOS for AI-assisted development with sandboxing and security";
```

---

## File Change Summary

| File | Action | Description |
|---|---|---|
| `src/flake.nix` | Modify | Update description |
| `src/alcatraz/configuration.nix` | Modify | User hardening, workspace group, nftables, systemd service, auditd |
| `src/home/home-al.nix` | Modify | Full AI agent toolchain, OpenCode config, shell setup |
| `src/home/home-common.nix` | No change | |
| `src/home/home-dev.nix` | No change | |
| `src/docs/tools.md` | No change | |

---

## Security Summary

| Layer | Mechanism | What it protects against |
|---|---|---|
| **User isolation** | No `wheel`/`networkmanager`, `homeMode 700` | Privilege escalation, cross-user file access |
| **Nix store** | `trusted-users` excludes `al` | Store tampering, arbitrary package injection |
| **Filesystem** | systemd `ProtectHome`, `ProtectSystem`, `BindPaths` | Access to system files, dev's home |
| **Network** | nftables UID-based rules | Unauthorized outbound connections |
| **Privileges** | `NoNewPrivileges`, `CapabilityBoundingSet=""` | Privilege escalation via setuid/capabilities |
| **Syscalls** | `SystemCallArchitectures = "native"` | Foreign architecture exploits |
| **Audit** | auditd rules on `al` UID | Undetected malicious activity |

---

## Future Enhancements

- **Hostname-based network filtering** via forward proxy (Squid/mitmproxy) for stricter API endpoint control
- **NixOS container (systemd-nspawn)** upgrade path for stronger isolation (see `container-isolation.md`)
- **AppArmor profiles** for per-process mandatory access control
- **Secrets management** (agenix/sops-nix) for API keys
- **LSP servers** installed via Nix for code intelligence
- **Resource limits** (CPU, memory, I/O) via systemd service config if needed
- **SSH hardening** when remote access is enabled
- **Per-project sandboxing** with separate OpenCode instances per workspace
