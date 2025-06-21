{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  nur ? pkgs.nur,
}:

rec {

  mkEmacsScreenshot =
    {
      # the code that should be executed before taking the screenshot
      emacsCode,
      # change this if you want another format
      name ? "emacs-screenshot.png",
      emacs ? pkgs.emacs,
      light ? true,
      ...
    }:
    pkgs.runCommandLocal name
      {
        nativeBuildInputs = [
          (emacs.pkgs.withPackages (e: [
            e.magit-section
            e.modus-themes
            (e.tokei.overrideAttrs { src = lib.cleanSource ./.; })
          ]))
          pkgs.xvfb-run
          pkgs.iosevka
          pkgs.imagemagick
        ];
        emacsCodeFile = pkgs.writeText "emacscode.el" emacsCode;
        screenshotScript = pkgs.writeText "script.el" ''
          (run-at-time 10 nil (lambda () (kill-emacs 1)))   ; fallback killing
          (load-theme 'modus-${if light then "operandi" else "vivendi"} t )
          (menu-bar-mode -1) ; 3
          (tool-bar-mode -1)
          (toggle-scroll-bar -1)
          (message nil)                            ; clear out echo area
          (defun screenshot-this-frame-and-exit ()
            (kill-emacs
              (call-process "import" nil nil nil
                            "-window" (frame-parameter (car (frame-list)) 'window-id) (getenv "out"))))
          (run-at-time 2 nil #'screenshot-this-frame-and-exit)
        '';
      }
      ''
        HOME=$PWD \
          xvfb-run --server-args="-screen 0 1024x576x24" \
            emacs --quick -f package-initialize --fullscreen \
            -l modus-themes \
            --font Iosevka\ 18 \
            ${pkgs.emacs.pkgs.modus-themes.src} \
            -l $screenshotScript \
            -l $emacsCodeFile
      '';

  emacsTokeiScreenshot =
    {
      light ? true,
    }:
    mkEmacsScreenshot {
      inherit light;
      emacsCode = ''
        (run-at-time 1 nil #'tokei)
      '';
    };

  imageShadow =
    image:
    pkgs.runCommandLocal image.name { inherit image; } ''
      ${pkgs.imagemagick}/bin/magick "$image" \
        -gravity Northwest \
        -bordercolor black -border 1 \
        -mosaic +repage \
        \( +clone -background black -shadow "80x3+3+3" \) \
        +swap \
        -background none -mosaic +repage $out
    '';

  optimizePng =
    image:
    pkgs.runCommandLocal ("opt-" + image.name)
      {
        inherit image;
        optlevel = 9;
        nativeBuildInputs = [ pkgs.optipng ];
      }
      ''
        optipng -strip all -o$optlevel "$image" -out $out
      '';

  # fileToBase64File = input:
  #   pkgs.runCommandLocal (input.name + ".b64") { } "base64 -w0 < ${input} > $out";

  svgDualThemeText = pkgs.writeText "myfile.svg" ''
    <?xml version="1.0" encoding="utf-8"?>
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" x="0px" y="0px"
         viewBox="0 0 1024 576" xml:space="preserve">
      <defs>
        <style type="text/css">
            image.light { display: inherit; }
            image.dark { display: none; }
            @media ( prefers-color-scheme:dark ) {
                image.light { display: none; }
                image.dark { display: inherit; }
            }
        </style>
      </defs>
      <image class="light" height="576" width="1024" href="data:image/png;base64,@lightThemeB64@" ></image>
      <image class="dark" height="576" width="1024" href="data:image/png;base64,@darkThemeB64@" ></image>
    </svg>
  '';

  svgDualTheme =
    imgFunc:
    pkgs.runCommandLocal "emacs-screenshot.svg" { } ''
      lightThemeB64=$(base64 -w0 < ${imgFunc true})
      darkThemeB64=$(base64 -w0 < ${imgFunc false})
      substitute ${svgDualThemeText} $out \
        --subst-var lightThemeB64 \
        --subst-var darkThemeB64
    '';

  imageShadowEmacs =
    light:
    imageShadow (emacsTokeiScreenshot {
      inherit light;
    });

  optimizeEmacsScreenshot = light: optimizePng (imageShadowEmacs light);

  svgDualThemeEmacs = svgDualTheme optimizeEmacsScreenshot;

  pngEmacs = imageShadowEmacs true;

  gitrepo = nur.repos.nagy.lib.mkGitRepository svgDualThemeEmacs;
}
