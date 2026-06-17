# Nix PDF-XChange Editor

Are you on NixOS? Are you tired of seeing this when trying to open encrypted PDFs?

![Notice](https://raw.githubusercontent.com/JakeHPark/nix-pdf-xchange-editor/refs/heads/main/Notice.png)

No? Well, unless you're a plumber-in-training trying to download the plumbing code of Australia from their university database who also happens be a long-time programming enthusiast and Linux user, probably not. But just in case you are, I've packaged [PDF-XChange Editor](https://www.pdf-xchange.com/product/pdf-xchange-editor) with Wine!

First, add this repository as an input to your flake:

```nix
# ...
inputs = {
  # ...
  nix-pdf-xchange-editor = {
    url = "github:JakeHPark/nix-pdf-xchange-editor";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ...
};
# ...
```

Then apply the overlay:

```nix
# ...
nixpkgs.overlays = [
  inputs.nix-pdf-xchange-editor.overlays.default
  # ...
];
# ...
```
