# Alcatraz OS - Container Isolation Plan

Upgrade path from Phase 1 (systemd hardening) to full container isolation using NixOS declarative containers (systemd-nspawn).

## Why Containers

Phase 1 (systemd hardening) provides good protection but has inherent limits:

| Limitation | Phase 1 (systemd) | Container (this plan) |
|---|---|---|
| PID isolation | No -- `al` can see host processes via `/proc` | Full PID namespace |
| Filesystem isolation | Partial -- `ProtectHome=tmpfs` + `BindPaths` | Full mount namespace |
| Network filtering | UID-based nftables (bypassable if UID changes) | Interface-based nftables (hard boundary) |
| Escape surface | Process can attempt namespace tricks | Full namespace isolation |
| Performance overhead | Zero | Negligible (~10-30MB RAM for inner systemd) |

## Architecture

```
HOST (alcatraz)
  |
  |-- dev user (human, XFCE desktop, vscodium)
  |       |
  |       |-- opencode attach http://192.168.100.11:4096
  |       |
  |       +-- /home/shared/workspace (read/write)
  |                     |
  |  ┌──────────────────┼──────────── CONTAINER BOUNDARY ──────────────┐
  |  │  al-cell          |                                              │
  |  │                   |                                              │
  |  │  al user ─── opencode serve :4096                               │
  |  │       |                                                          │
  |  │       +── /home/shared/workspace (bind-mount, read/write)       │
  |  │       +── /home/al/.config/opencode (bind-mount, read/write)    │
  |  │       +── /home/al/.local/share/opencode (bind-mount, read/write)│
  |  │                                                                  │
  |  │  Network: 192.168.100.11 (private, NAT to internet)             │
  |  │  Allowed: DNS + HTTPS only (nftables on host)                   │
  |  │  Nix store: /nix/store (shared read-only, automatic)            │
  |  └──────────────────────────────────────────────────────────────────┘
  |
  |-- NAT: ve-al-cell <-> container eth0
  |-- nftables: forward chain filters container traffic
  |-- auditd: monitors workspace writes, dev home access
```

## Prerequisites

- Phase 1 must be implemented first (user hardening, workspace group, nix settings)
- Phase 1's `systemd.services.opencode-agent` will be disabled once the container is validated
- Both can coexist during testing (different listen addresses)

---

## Phase 1: NAT Configuration

**File:** `src/alcatraz/configuration.nix`

The host needs NAT so the container can reach the internet (for LLM API calls):

```nix
networking.nat = {
  enable = true;
  internalInterfaces = [ "ve-+" ];  # wildcard: all container veth interfaces
  externalInterface = "ens3";       # adjust to actual interface (check: ip route | grep default)
};
```

**What this does:**
- Matches all veth interfaces created for containers (`ve-al-cell`, etc.)
- Sets up iptables/nftables masquerade rules
- Container traffic gets SNAT'd to the host's external IP

---

## Phase 2: Container Definition

**File:** `src/alcatraz/configuration.nix`

```nix
containers.al-cell = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "192.168.100.10";
  localAddress = "192.168.100.11";

  bindMounts = {
    # Shared workspace (read/write for both dev and al)
    "/home/shared/workspace" = {
      hostPath = "/home/shared/workspace";
      isReadOnly = false;
    };
    # OpenCode config (persists across container restarts)
    "/home/al/.config/opencode" = {
      hostPath = "/home/al/.config/opencode";
      isReadOnly = false;
    };
    # OpenCode data (sessions, auth, logs)
    "/home/al/.local/share/opencode" = {
      hostPath = "/home/al/.local/share/opencode";
      isReadOnly = false;
    };
  };

  config = { config, pkgs, lib, ... }: {

    # ── DNS fix (known NixOS container bug) ──
    networking.useHostResolvConf = lib.mkForce false;
    services.resolved.enable = true;

    # ── Container firewall ──
    networking.firewall.allowedTCPPorts = [ 4096 ];

    # ── User setup ──
    users.groups.workspace.gid = 2000;
    users.groups.al.gid = 1001;
    users.users.al = {
      isNormalUser = true;
      uid = 1001;
      group = "al";
      extraGroups = [ "workspace" ];
      home = "/home/al";
    };

    # ── Packages ──
    environment.systemPackages = with pkgs; [
      # OpenCode
      opencode

      # Core tools (used by OpenCode's built-in tools)
      git
      ripgrep
      fd
      tree

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

      # GitHub CLI & Node.js (for MCP servers)
      gh
      nodejs
    ];

    # ── Git safe directory ──
    environment.etc."gitconfig".text = ''
      [safe]
        directory = /home/shared/workspace
    '';

    # ── Environment variables ──
    environment.variables = {
      EDITOR = "vim";
      OPENCODE_DISABLE_AUTOUPDATE = "true";
      OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    };

    # ── OpenCode service ──
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
        ExecStart = "${pkgs.opencode}/bin/opencode serve --port 4096 --hostname 0.0.0.0";
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = "/home/shared/workspace";
      };
    };

    system.stateVersion = "25.11";
  };
};
```

### Key design decisions

- **No user namespacing** (`privateUsers` not set) -- UIDs match between host and container. This is required for bind-mounted workspace file ownership to work correctly. Container root = host root, but `al` inside the container never has root access.
- **`0.0.0.0` bind** -- OpenCode listens on all interfaces inside the container so the host can reach it via the veth IP.
- **Nix store** -- Shared read-only automatically by NixOS containers. No package duplication.
- **DNS** -- Container runs its own `systemd-resolved` to avoid the known `resolv.conf` bug with private networks.

---

## Phase 3: Network Filtering (Host-Side)

**File:** `src/alcatraz/configuration.nix`

Replace the Phase 1 UID-based nftables rules with interface-based rules:

```nix
networking.nftables.enable = true;
networking.nftables.tables.alcatraz-container-filter = {
  family = "inet";
  content = ''
    chain forward {
      type filter hook forward priority 0; policy accept;

      # Allow established/related connections back to container
      oifname "ve-al-cell" ct state established,related accept

      # Allow DNS from container
      iifname "ve-al-cell" udp dport 53 accept
      iifname "ve-al-cell" tcp dport 53 accept

      # Allow HTTPS from container (for api.anthropic.com)
      iifname "ve-al-cell" tcp dport 443 accept

      # Drop all other outbound from container
      iifname "ve-al-cell" drop
    }

    chain input {
      type filter hook input priority 0; policy accept;

      # Allow host to reach OpenCode inside the container
      iifname "ve-al-cell" tcp sport 4096 accept

      # Block container from accessing other host services
      iifname "ve-al-cell" drop
    }
  '';
};
```

**Why interface-based is better than UID-based:**
- UID-based rules (`meta skuid al`) can be bypassed if the agent executes a command as a different user
- Interface-based rules filter on the veth interface -- there is no way to route traffic around it from inside the container
- The container's entire network namespace is behind the `ve-al-cell` interface

---

## Phase 4: Host-Side Tmpfiles

**File:** `src/alcatraz/configuration.nix`

Ensure bind-mount source directories exist on the host before the container starts:

```nix
systemd.tmpfiles.rules = [
  "d /home/shared 0755 root root -"
  "d /home/shared/workspace 2775 dev workspace -"
  "d /home/al/.config/opencode 0755 al al -"
  "d /home/al/.local/share/opencode 0755 al al -"
];
```

---

## Phase 5: UID/GID Alignment

Both host and container must have matching UIDs/GIDs for file ownership:

```
              Host            Container
al user       UID 1001        UID 1001
al group      GID 1001        GID 1001
workspace     GID 2000        GID 2000
```

**Host** (`configuration.nix`):
```nix
users.groups.workspace.gid = 2000;
users.users.al = {
  isNormalUser = true;
  uid = 1001;
  extraGroups = [ "workspace" ];
};
```

**Container** (inside `containers.al-cell.config`):
```nix
users.groups.workspace.gid = 2000;
users.groups.al.gid = 1001;
users.users.al = {
  isNormalUser = true;
  uid = 1001;
  group = "al";
  extraGroups = [ "workspace" ];
};
```

---

## Phase 6: Update `home-dev.nix`

Add convenience aliases for the `dev` user to interact with the container:

```nix
programs.bash.shellAliases = {
  # Connect to the AI agent
  oc = "opencode attach http://192.168.100.11:4096";

  # Container management
  al-logs = "journalctl -M al-cell -u opencode-agent -f";
  al-status = "sudo systemctl status container@al-cell";
  al-restart = "sudo machinectl shell al-cell /usr/bin/env systemctl restart opencode-agent";
  al-shell = "sudo nixos-container root-login al-cell";
};
```

---

## Phase 7: Disable Phase 1 Service

Once the container is validated, disable the Phase 1 systemd service:

```nix
# Remove or comment out:
# systemd.services.opencode-agent = { ... };

# The Phase 1 UID-based nftables rules are also replaced by
# the interface-based rules in Phase 3 above.
```

---

## Migration Strategy

Phase 1 and the container can coexist during testing:

| | Phase 1 (systemd) | Container (al-cell) |
|---|---|---|
| **Address** | `127.0.0.1:4096` | `192.168.100.11:4096` |
| **Connect** | `opencode attach http://127.0.0.1:4096` | `opencode attach http://192.168.100.11:4096` |
| **Systemd unit** | `opencode-agent.service` | `container@al-cell.service` |
| **Logs** | `journalctl -u opencode-agent` | `journalctl -M al-cell -u opencode-agent` |

**Steps:**
1. Implement Phase 1 (systemd hardening) -- already planned
2. Add container definition with `autoStart = false`
3. Start container manually: `sudo nixos-container start al-cell`
4. Test: `opencode attach http://192.168.100.11:4096`
5. Validate workspace read/write, git operations, API calls
6. Set `autoStart = true`, disable Phase 1 service
7. Remove Phase 1 service definition

---

## Management Cheatsheet

```bash
# Container lifecycle
sudo nixos-container start al-cell
sudo nixos-container stop al-cell
sudo systemctl status container@al-cell

# Shell access
sudo nixos-container root-login al-cell

# Run commands inside the container
sudo nixos-container run al-cell -- systemctl status opencode-agent
sudo nixos-container run al-cell -- su - al -c "opencode --version"

# View logs
journalctl -M al-cell                          # all container logs
journalctl -M al-cell -u opencode-agent        # opencode service
journalctl -M al-cell -u opencode-agent -f     # follow

# Network diagnostics
sudo nixos-container show-ip al-cell           # container IP
ping 192.168.100.11                            # from host
sudo machinectl status al-cell                 # detailed status

# Rebuild (container is part of host config)
sudo nixos-rebuild switch                      # rebuilds host + container
```

---

## Known Gotchas

1. **DNS resolution**: Containers with `privateNetwork` must use `services.resolved.enable = true` and `networking.useHostResolvConf = lib.mkForce false` (addressed in Phase 2).

2. **Container name**: Must not contain underscores. Max 11 chars on kernels < 5.8 with `privateNetwork`. `al-cell` is 7 chars -- well within limits.

3. **NAT external interface**: `externalInterface` in `networking.nat` must match the host's actual outbound interface. Check with `ip route | grep default`.

4. **Rebuild restarts container**: `nixos-rebuild switch` will restart the container if its config changed (`restartIfChanged = true` by default). This is usually desired but causes brief downtime.

5. **No GUI inside container**: The container is headless. All interaction is via `opencode attach` from the host or `nixos-container root-login`.

6. **Security note**: Without user namespacing, root inside the container is root on the host. The `al` user inside the container does NOT have root access, but if the agent somehow gained root inside the container, it could affect the host. For maximum isolation, consider microvm.nix (future enhancement).

---

## Security Comparison

| Layer | Phase 1 (systemd) | Container (al-cell) |
|---|---|---|
| **User isolation** | homeMode 700, no wheel | Full user namespace separation |
| **PID isolation** | None | Full PID namespace |
| **Mount isolation** | ProtectHome, ProtectSystem | Full mount namespace |
| **Network** | UID-based nftables | Interface-based nftables |
| **Nix store** | trusted-users excludes al | Read-only bind mount (automatic) |
| **Audit** | auditd on host | auditd on host + container journal |
| **Escape difficulty** | Moderate | Hard |
| **Overhead** | Zero | ~10-30MB RAM, 1-3s boot |

---

## Future Enhancements

- **Ephemeral mode**: Set `ephemeral = true` for clean-slate restarts (only bind-mounted data persists)
- **microvm.nix**: Full VM isolation for untrusted workloads (stronger than containers, more overhead)
- **Forward proxy**: Run Squid/mitmproxy on host for hostname-based HTTPS filtering
- **AppArmor inside container**: Mandatory access control within the container
- **Multiple containers**: Per-project sandboxes with separate OpenCode instances
- **Resource limits**: Add `systemd.slices` inside the container for CPU/memory/IO limits
