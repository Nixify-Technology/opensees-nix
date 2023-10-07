{
  description = "OpenSees";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    shell-utils.url = "github:waltermoreira/shell-utils";
    intel-mpi.url = "github:waltermoreira/intel-mpi-nix";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , shell-utils
    , intel-mpi
    }:

      with flake-utils.lib; eachSystem [
        system.x86_64-linux
      ]
        (system:
        let
          pkgs = import nixpkgs { inherit system; };
          shell = shell-utils.myShell.${system};
          mpi = intel-mpi.packages.${system}.default;

          # MKL package installation --- TODO!
          # mklDebPackages = [
          #   {
          #     package = "";
          #     hash = "";
          #   }
          # ];
          # mklDebsMap = map
          #   ({ package, hash }: pkgs.fetchurl {
          #     url = "";
          #     inherit hash;
          #   })
          #   mklDebPackages;
          # mkl = pkgs.stdenv.mkDerivation { };


          opensees_src = pkgs.fetchFromGitHub
            {
              owner = "OpenSees";
              repo = "OpenSees";
              rev = "0d95d6ee1cffe8099f4d119663ceade3071c61c1";
              hash = "sha256-NVpptUhvfzP3J7cMx2g+sgPQcQZVDc70fS3MRUXuDPw=";
            };
          mumps = pkgs.stdenv.mkDerivation
            {
              name = "mumps";
              src = pkgs.fetchurl {
                url = "http://graal.ens-lyon.fr/MUMPS/MUMPS_5.2.1.tar.gz";
                hash = "sha256-2Yj8NN/I9e7gUz42EFKpcqppzDmrGT5/mHF40kmBdEo=";
              };
              buildInputs = [
                pkgs.gnused
                pkgs.gnumake
                pkgs.ps
                pkgs.gfortran
              ];
              buildPhase = ''
                source ${mpi}/env/vars.sh
                cp Make.inc/Makefile.INTEL.PAR Makefile.inc
                sed -i 's/mpiicc/mpicc/g' Makefile.inc
                sed -i 's/mpiifort/mpif90/g' Makefile.inc
                sed -i 's/OPTF    =.*/OPTF    = -O3 -fopenmp/g' Makefile.inc
                sed -i 's/OPTL    =.*/OPTL    = -O3 -fopenmp/g' Makefile.inc
                sed -i 's/OPTC    =.*/OPTC    = -O3 -fopenmp/g' Makefile.inc
                make -j mumps_lib
              '';
              installPhase = ''
                mkdir -p $out
                mv lib $out
                mv include $out
              '';
            };
          opensees = pkgs.stdenv.mkDerivation
            {
              name = "opensees";
              src = ./.;
              buildInputs = [
                mumps
                pkgs.gnumake
                pkgs.rsync
                pkgs.gcc
                pkgs.ps
                pkgs.gfortran
                pkgs.gnused
                pkgs.tcl-8_6
                pkgs.xorg.libX11
                pkgs.libglvnd
                pkgs.python310
              ];
              buildPhase = with pkgs; ''
                mkdir -p $TMP/OpenSees 
                rsync -a ${opensees_src}/ $TMP/OpenSees/
                chmod -R a+w $TMP/OpenSees
                ls -l $TMP
                cp Makefile.def $TMP/OpenSees/Makefile.def
                source ${mpi}/env/vars.sh
                export HOME=$TMP
                export TCL=${tcl-8_6}
                export X11=${xorg.libX11}
                export GL=${libglvnd}
                export PYTHON=${python310}
                cd $TMP/OpenSees
                PROGRAMMING_MODE=PARALLEL_INTERPRETERS make -j 
              '';
              #nativeBuildInputs = [ pkgs.breakpointHook ];
              installPhase = ''
                mkdir -p $out
                false
              '';
            };
        in
        {
          devShells.default = shell {
            name = "OpenSees";
            packages = [ mumps ];
          };
          packages.default = opensees;
        });
}          
