{
  description = "easily update argo-cd's install.yaml";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-23.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs { inherit system; };
      updateScript = rec {
        name = "update-manifests";
        deps = with pkgs; [ git toybox bash kubectl kustomize kubernetes-helm ];
        content =
          pkgs.writeShellScriptBin
            name
            (builtins.readFile ./hack/update-manifests.sh);
      };
      ignoreScript = rec {
        name = "pick-ignored";
        deps = with pkgs; [ coreutils gnused gnugrep parallel ];
        content = pkgs.writeShellScriptBin name ''
          IN=$(cat)

          it() {
            local file=$(cat)
            cut -d"/" -f1<<<$file \
              | grep -xqf - ignoretree && echo "$file"
          }; export -f it

          echo "$IN" | uniq | it
        '';
      };
      mergeScript = rec {
        name = "merge-upstream";
        deps = with pkgs; [ git openssh less findutils (createJobFromScript ignoreScript) ];
        content = pkgs.writeShellScriptBin name ''
          set -ux

          git fetch upstream --no-tags ''${@:-master}
          git merge --no-ff --no-commit FETCH_HEAD

          STATUS=$(git status -s)

          sed -nE 's/^A\s+(.*)/\1/p' <<<$STATUS \
            | pick-ignored | tee >(xargs rm) | xargs git rm --cached
          sed -nE 's/^DU\s+(.*)/\1/p' <<<$STATUS \
            | pick-ignored | xargs git rm

          git rm  \
            manifests/install.yaml           \
            manifests/core-install.yaml      \
            manifests/namespace-install.yaml \
            manifests/ha/install.yaml        \
            manifests/ha/namespace-install.yaml

          git checkout --theirs VERSION

          find . -type d -empty -delete

          echo -e "\n\n----- RELEVANT OUTPUT STARTS HERE -----\n"
          git status
        '';
      };
      diffScript = rec {
        name = "diff-upstream";
        deps = with pkgs; [ (createJobFromScript mergeScript) ];
        content = pkgs.writeShellScriptBin name ''
          set -eux
          merge-upstream ''${@:-master}
          git diff --base -b
          git merge --abort
        '';
      };
      createJobFromScript = { name, content, deps }: pkgs.symlinkJoin {
        inherit name;
        paths = deps ++ [ content ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/${name} --set PATH $out/bin";
      };
    in rec {
      defaultPackage = packages.updateManifests;
      packages.updateManifests = createJobFromScript updateScript;
      packages.mergeUpstream = createJobFromScript mergeScript;
      packages.diffUpstream = createJobFromScript diffScript;
    }
  );
}
