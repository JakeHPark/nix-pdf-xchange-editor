{
  lib,
  stdenvNoCC,
  fetchurl,
  wineWow64Packages,
  p7zip,
  makeDesktopItem,
  copyDesktopItems,
  bash,
  coreutils,
  findutils,
}:

let
  winePackage = wineWow64Packages.stagingFull;

  wineMonoVersion = "11.1.0";

  wineMonoMsi = fetchurl {
    url = "https://dl.winehq.org/wine/wine-mono/${wineMonoVersion}/wine-mono-${wineMonoVersion}-x86.msi";
    hash = "sha256-3rA0FDH4Jgsgn/9rx53cxUFLl/jpI2q5+9ykzlngqbk=";
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pdf-xchange-editor";
  version = "11.0.1.0";

  src = fetchurl {
    url = "https://dl.dropboxusercontent.com/scl/fi/dq0000yhan2pcu8nbqhl9/PDFXChangeEditorPortable-x64.zip?rlkey=68lb3l7hc4uyhblpu0ga0g3bw";
    hash = "sha256-E9Q6yOcEN3Ycn8LCLQm1AMBE5oixHTnq+HQIWy2pkZg=";
  };

  nativeBuildInputs = [
    p7zip
    copyDesktopItems
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir -p source
    7z x -y "$src" -osource
    cd source

    find . -depth -print0 | while IFS= read -r -d "" old; do
      case "$old" in
        *\\*)
          rel="''${old#./}"
          new="./''${rel//\\/\/}"

          if [ "$old" = "$new" ]; then
            continue
          fi

          mkdir -p "$(dirname "$new")"

          if [ -e "$new" ]; then
            if [ -d "$old" ] && [ -d "$new" ]; then
              rmdir "$old" 2>/dev/null || {
                echo "Collision while normalising path: $old -> $new" >&2
                exit 1
              }
            else
              echo "Collision while normalising path: $old -> $new" >&2
              exit 1
            fi
          else
            mv "$old" "$new"
          fi
          ;;
      esac
    done

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/pdf-xchange-editor" "$out/bin"
    cp -a ./. "$out/share/pdf-xchange-editor/"

    cat > "$out/bin/pdf-xchange" <<'EOF'
    #!@BASH@
    set -euo pipefail

    export PATH="@RUNTIME_PATH@''${PATH:+:$PATH}"

    state_base="''${XDG_DATA_HOME:-$HOME/.local/share}/pdf-xchange-editor"
    appdir="$state_base/app-@VERSION@"
    store_app="@STORE_APP@"

    # Default to ~/.local/share/wineprefixes/pdf-xchange-editor unless PDFXCHANGE_WINEPREFIX is set.
    prefix="''${PDFXCHANGE_WINEPREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/pdf-xchange-editor}"
    export WINEPREFIX="$prefix"

    export WINEDEBUG="''${WINEDEBUG:--all}"

    wine="@WINE@"
    wineboot="@WINEBOOT@"
    winepath="@WINEPATH@"

    mkdir -p "$state_base" "$(dirname "$prefix")"

    app_marker="$appdir/.nix-store-source"
    current_store="$(cat "$app_marker" 2>/dev/null || true)"
    existing_exe="$(
      find "$appdir" -type f \( -iname 'PXCEditor.exe' -o -iname 'PDFXEdit.exe' \) -print -quit 2>/dev/null || true
    )"

    if [ "$current_store" != "$store_app" ] || [ -z "$existing_exe" ]; then
    rm -rf "$appdir"
    mkdir -p "$appdir"
    cp -a "$store_app"/. "$appdir"/
    chmod -R u+rwX "$appdir"
    printf '%s\n' "$store_app" > "$app_marker"
    fi

    prefix_marker="$prefix/.pdf-xchange-prefix-initialized-@VERSION@"
    mono_marker="$prefix/.pdf-xchange-wine-mono-installed-@VERSION@"

    if [ ! -e "$prefix_marker" ]; then
    mkdir -p "$prefix"

    # Prevent Wine from opening interactive Mono/Gecko prompts during first bootstrap.
    WINEDLLOVERRIDES="mscoree,mshtml=" "$wineboot" -u

    touch "$prefix_marker"
    fi

    if [ ! -e "$mono_marker" ]; then
    mono_msi="@WINE_MONO_MSI@"

    if [ ! -f "$mono_msi" ]; then
      echo "pdf-xchange: Wine Mono MSI does not exist: $mono_msi" >&2
      exit 1
    fi

    echo "Installing Wine Mono from: $mono_msi" >&2

    mono_msi_win="$("$winepath" -w "$mono_msi")"
    "$wine" msiexec /i "$mono_msi_win" /qn

    "$wineboot" -u

    touch "$mono_marker"
    fi

    exe="$(
      find "$appdir" -type f \( -iname 'PXCEditor.exe' -o -iname 'PDFXEdit.exe' \) -print -quit
    )"

    if [ -z "$exe" ]; then
    echo "pdf-xchange: could not find PXCEditor.exe or PDFXEdit.exe under $appdir" >&2
    echo "Check that the portable PDF-XChange Editor zip was used." >&2
    exit 1
    fi

    # PDF-XChange expects bundled resources, including ICU data, relative to its app tree.
    exe_dir="''${exe%/*}"

    icu_file="$(
      find "$appdir" -type f \( -iname 'icudt*.dat' -o -iname 'icudtl.dat' -o -iname '*icu*.dat' \) -print -quit 2>/dev/null || true
    )"

    if [ -n "$icu_file" ]; then
    icu_dir="''${icu_file%/*}"
    export ICU_DATA="$("$winepath" -w "$icu_dir")"
    fi

    args=()
    for arg in "$@"; do
    if [ -e "$arg" ]; then
      args+=( "$("$winepath" -w "$arg")" )
    else
      args+=( "$arg" )
    fi
    done

    cd "$exe_dir"

    exe_win="$("$winepath" -w "$exe")"

    # Wine doesn't have a necessary stub for CfGetPlaceholderInfo, so we disable cldapi instead.
    dll_overrides="''${WINEDLLOVERRIDES:-}"
    if [ -n "$dll_overrides" ]; then
      dll_overrides="$dll_overrides;cldapi="
    else
      dll_overrides="cldapi="
    fi

    exec env WINEDLLOVERRIDES="$dll_overrides" "$wine" "$exe_win" "''${args[@]}"
    EOF

    substituteInPlace "$out/bin/pdf-xchange" \
      --replace-fail '@BASH@' '${bash}/bin/bash' \
      --replace-fail '@STORE_APP@' "$out/share/pdf-xchange-editor" \
      --replace-fail '@VERSION@' '${finalAttrs.version}' \
      --replace-fail '@WINE@' '${winePackage}/bin/wine' \
      --replace-fail '@WINEBOOT@' '${winePackage}/bin/wineboot' \
      --replace-fail '@WINEPATH@' '${winePackage}/bin/winepath' \
      --replace-fail '@WINE_MONO_MSI@' '${wineMonoMsi}' \
      --replace-fail '@RUNTIME_PATH@' '${
        lib.makeBinPath [
          coreutils
          findutils
          winePackage
        ]
      }'

    chmod +x $out/bin/pdf-xchange

    install -Dm644 ${./pdf-xchange.png} $out/share/icons/hicolor/256x256/apps/pdf-xchange.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "pdf-xchange";
      desktopName = "PDF-XChange Editor";
      genericName = "PDF Viewer";
      comment = "View and edit PDFs";
      exec = "pdf-xchange %F";
      icon = "pdf-xchange";
      terminal = false;
      categories = [
        "Office"
        "Viewer"
      ];
      mimeTypes = [ "application/pdf" ];
    })
  ];

  meta = {
    description = "PDF-XChange Editor portable wrapped with Wine";
    homepage = "https://www.pdf-xchange.com/product/downloads/enduser/pdf-xchange-editor";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pdf-xchange";
  };
})
