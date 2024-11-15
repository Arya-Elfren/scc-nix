{
  inputs = {
    flake-parts.url = github:hercules-ci/flake-parts;
    nixpkgs.url = github:NixOs/nixpkgs/nixpkgs-unstable;
  };

  outputs = { self, ... }@inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    perSystem = { pkgs, config, system, ... }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      packages =
      let
        inherit (pkgs)
          lib impureUseNativeOptimizations
          gccStdenv clangStdenv
          openblas openblasCompat mkl blis amd-blis
          lapack-reference amd-libflame
          openmpi mpich mvapich
        ;
        inherit (lib)
          removeSuffix
          getName
          mapCartesianProduct
          attrsets
        ;
        buildHPLScript = stdenv: blas: lapack: mpi:
          let
            hpl = pkgs.hpl.override (prev: {
              stdenv = impureUseNativeOptimizations stdenv;
              blas = prev.blas.override { blasProvider = blas; };
              lapack = prev.lapack.override { lapackProvider = lapack; };
              mpi = mpi;
            });
          in pkgs.writeScriptBin "runHPL" "${mpi}/bin/mpirun -n $1 ${hpl}/bin/xhpl";

        buildHPLAttr = {stdenv, blas, lapack, mpi}:
        let
          compilerStr = removeSuffix "-wrapper" (getName stdenv.cc);
        in {
          "${compilerStr}_${getName blas}_${getName lapack}_${getName mpi}" =
            buildHPLScript stdenv blas lapack mpi;
        };
        allHPLAttr = mapCartesianProduct buildHPLAttr {
          stdenv = [ gccStdenv clangStdenv ];
          blas = [ openblas mkl blis amd-blis ]; # openblasCompat
          lapack = [ lapack-reference mkl amd-libflame ];
          mpi = [ openmpi mpich mvapich ];
        };
      in attrsets.mergeAttrsList allHPLAttr;
    };
  };
}

