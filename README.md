# ChatGPT Desktop for NixOS

> [!IMPORTANT]
> Follow [NixOS/nixpkgs PR #551713](https://github.com/NixOS/nixpkgs/pull/551713).
> Once Linux support is available in the nixpkgs revision used by your system,
> you probably no longer need this repository. Remove this flake input and use
> `pkgs.chatgpt` directly instead.

This repository packages the official ChatGPT Desktop Linux binary for NixOS.
The Nix expression and source metadata live in this repository; building and
installing it does not depend on an open nixpkgs pull request. The initial Linux
packaging work was adapted from
[NixOS/nixpkgs PR #551713](https://github.com/NixOS/nixpkgs/pull/551713).

The upstream binary is unfree and is downloaded directly from OpenAI's package
repository. Supported systems are `x86_64-linux` and `aarch64-linux`.

## Run without installing

```sh
nix run github:alioguzhan/chatgpt-desktop-flake
```

From a local checkout:

```sh
nix run .
```

## Install from a flake-based NixOS configuration

Add the repository to the `inputs` section of your `flake.nix`:

```nix
inputs.chatgpt-desktop = {
  url = "github:alioguzhan/chatgpt-desktop-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

If you fork this repository, replace `alioguzhan` with your GitHub username in
these examples. The update workflow pushes to the fork's checked-out default
branch; the fork must allow GitHub Actions to write repository contents.

`follows` makes this package use the same nixpkgs revision as the NixOS
configuration. This avoids a second nixpkgs dependency and is recommended for a
recent `nixos-unstable` configuration. Remove the `follows` line if the target
uses an older nixpkgs revision and package evaluation fails; the repository will
then use its tested, locked nixpkgs revision.

Pass the flake inputs to NixOS modules:

```nix
outputs = inputs@{ nixpkgs, ... }: {
  nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [ ./configuration.nix ];
  };
};
```

Add the package in `configuration.nix`:

```nix
{ inputs, pkgs, ... }:

{
  environment.systemPackages = [
    inputs.chatgpt-desktop.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt
  ];
}
```

Apply the configuration with the same command normally used for that host, for
example:

```sh
sudo nixos-rebuild switch --flake .#your-host
```

## Install with Home Manager

For standalone Home Manager, pass inputs through `extraSpecialArgs`:

```nix
homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = { inherit inputs; };
  modules = [ ./home.nix ];
};
```

For Home Manager integrated into NixOS, use:

```nix
home-manager.extraSpecialArgs = { inherit inputs; };
```

Then add the package in `home.nix`:

```nix
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.chatgpt-desktop.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt
  ];
}
```

Use either the NixOS installation or the Home Manager installation. Adding the
same package through both is redundant.

## Receive package updates in nixos-config

The consumer's `flake.lock` pins this repository. After the updater commits a
new ChatGPT version here, update only this input in `nixos-config` and rebuild:

```sh
nix flake update chatgpt-desktop
sudo nixos-rebuild switch --flake .#your-host
```

Without the lock-file update, an existing NixOS configuration intentionally
continues to use its previously pinned ChatGPT version.

## Automatic upstream updates

`.github/workflows/update-chatgpt.yml` runs at 00:23 and 12:23 UTC and can also
be started manually. It reads the official Debian repository metadata, updates
`package/source.json`, builds the x86_64 package, and pushes a Conventional
Commit only when the version or hash changes.

Scheduled workflows run only from the repository's default branch. GitHub also
disables schedules in public repositories after 60 days without repository
activity. Branch protection must allow `github-actions[bot]` to push, or the
workflow will fail at its final step.

Run the same updater locally from the repository root:

```sh
nix run .#update
```

## Known Intel graphics risk

Nixpkgs Mesa 26.2.0 has a reported Intel i915 GPU-hang regression. Check the
host's Mesa version before running this package on Intel graphics. Mesa 26.1.4
and 26.1.6 were reported as unaffected alternatives. See
[NixOS/nixpkgs issue #553285](https://github.com/NixOS/nixpkgs/issues/553285).
