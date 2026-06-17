{
  description = "PDF-XChange Editor wrapped with Wine for Nix.";

  outputs =
    { ... }:
    let
      overlay = final: prev: { pdf-xchange-editor = final.callPackage ./pkgs/pdf-xchange-editor { }; };
    in
    {
      overlays.default = overlay;
      overlay = overlay;
    };
}
