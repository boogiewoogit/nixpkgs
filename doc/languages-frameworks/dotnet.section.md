# Dotnet {#dotnet}

## Local Development Workflow {#local-development-workflow}

For local development, it's recommended to use nix-shell to create a dotnet environment:

```nix
# shell.nix
with import <nixpkgs> { };

mkShell {
  name = "dotnet-env";
  packages = [ dotnet-sdk ];
}
```

### Using many sdks in a workflow {#using-many-sdks-in-a-workflow}

It's very likely that more than one sdk will be needed on a given project. Dotnet provides several different frameworks (E.g dotnetcore, aspnetcore, etc.) as well as many versions for a given framework. Normally, dotnet is able to fetch a framework and install it relative to the executable. However, this would mean writing to the nix store in nixpkgs, which is read-only. To support the many-sdk use case, one can compose an environment using `dotnetCorePackages.combinePackages`:

```nix
with import <nixpkgs> { };

mkShell {
  name = "dotnet-env";
  packages = [
    (
      with dotnetCorePackages;
      combinePackages [
        sdk_8_0
        sdk_9_0
      ]
    )
  ];
}
```

This will produce a dotnet installation that has the dotnet 8.0 9.0 sdk. The first sdk listed will have it's cli utility present in the resulting environment. Example info output:

```ShellSession
$ dotnet --info
.NET SDK:
 Version:           9.0.100
 Commit:            59db016f11
 Workload version:  9.0.100-manifests.3068a692
 MSBuild version:   17.12.7+5b8665660

Runtime Environment:
 OS Name:     nixos
 OS Version:  25.05
 OS Platform: Linux
 RID:         linux-x64
 Base Path:   /nix/store/a03c70i7x6rjdr6vikczsp5ck3v6rixh-dotnet-sdk-9.0.100/share/dotnet/sdk/9.0.100/

.NET workloads installed:
There are no installed workloads to display.
Configured to use loose manifests when installing new manifests.

Host:
  Version:      9.0.0
  Architecture: x64
  Commit:       9d5a6a9aa4

.NET SDKs installed:
  8.0.404 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/sdk]
  9.0.100 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/sdk]

.NET runtimes installed:
  Microsoft.AspNetCore.App 8.0.11 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/shared/Microsoft.AspNetCore.App]
  Microsoft.AspNetCore.App 9.0.0 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/shared/Microsoft.AspNetCore.App]
  Microsoft.NETCore.App 8.0.11 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/shared/Microsoft.NETCore.App]
  Microsoft.NETCore.App 9.0.0 [/nix/store/6wlrjiy10wg766490dcmp6x64zb1vc8j-dotnet-core-combined/share/dotnet/shared/Microsoft.NETCore.App]

Other architectures found:
  None

Environment variables:
  Not set

global.json file:
  Not found

Learn more:
  https://aka.ms/dotnet/info

Download .NET:
  https://aka.ms/dotnet/download
```

## dotnet-sdk vs dotnetCorePackages.sdk {#dotnet-sdk-vs-dotnetcorepackages.sdk}

The `dotnetCorePackages.sdk_X_Y` is preferred over the old dotnet-sdk as both major and minor version are very important for a dotnet environment. If a given minor version isn't present (or was changed), then this will likely break your ability to build a project.

## dotnetCorePackages.sdk vs dotnetCorePackages.runtime vs dotnetCorePackages.aspnetcore {#dotnetcorepackages.sdk-vs-dotnetcorepackages.runtime-vs-dotnetcorepackages.aspnetcore}

The `dotnetCorePackages.sdk` contains both a runtime and the full sdk of a given version. The `runtime` and `aspnetcore` packages are meant to serve as minimal runtimes to deploy alongside already built applications.

## Packaging a Dotnet Application {#packaging-a-dotnet-application}

To package Dotnet applications, you can use `buildDotnetModule`. This has similar arguments to `stdenv.mkDerivation`, with the following additions:

* `projectFile` is used for specifying the dotnet project file, relative to the source root. These have `.sln` (entire solution) or `.csproj` (single project) file extensions. This can be a list of multiple projects as well. When omitted, will attempt to find and build the solution (`.sln`). If running into problems, make sure to set it to a file (or a list of files) with the `.csproj` extension - building applications as entire solutions is not fully supported by the .NET CLI.
* `nugetDeps` should be a path to a JSON file, a path to a nix file (deprecated), a derivation, or a list of derivations. A `deps.json` file can be generated using the script attached to `passthru.fetch-deps`, which is the preferred method. All `nugetDeps` packages are added to `buildInputs`.
::: {.note}
For more detail about managing the `deps.json` file, see [Generating and updating NuGet dependencies](#generating-and-updating-nuget-dependencies)
:::

* `packNupkg` is used to pack project as a `nupkg`, and installs it to `$out/share`. If set to `true`, the derivation can be used as a dependency for another dotnet project by adding it to `buildInputs`.
* `buildInputs` can be used to resolve `ProjectReference` project items. Referenced projects can be packed with `buildDotnetModule` by setting the `packNupkg = true` attribute and passing a list of derivations to `buildInputs`. Since we are sharing referenced projects as NuGets they must be added to csproj/fsproj files as `PackageReference` as well.
 For example, your project has a local dependency:
 ```xml
     <ProjectReference Include="../foo/bar.fsproj" />
 ```
 To enable discovery through `buildInputs` you would need to add:
 ```xml
     <ProjectReference Include="../foo/bar.fsproj" />
     <PackageReference Include="bar" Version="*" Condition=" '$(ContinuousIntegrationBuild)'=='true' "/>
  ```
* `executables` is used to specify which executables get wrapped to `$out/bin`, relative to `$out/lib/$pname`. If this is unset, all executables generated will get installed. If you do not want to install any, set this to `[]`. This gets done in the `preFixup` phase.
* `runtimeDeps` is used to wrap libraries into `LD_LIBRARY_PATH`. This is how dotnet usually handles runtime dependencies.
* `buildType` is used to change the type of build. Possible values are `Release`, `Debug`, etc. By default, this is set to `Release`.
* `selfContainedBuild` allows to enable the [self-contained](https://docs.microsoft.com/en-us/dotnet/core/deploying/#publish-self-contained) build flag. By default, it is set to false and generated applications have a dependency on the selected dotnet runtime. If enabled, the dotnet runtime is bundled into the executable and the built app has no dependency on .NET.
* `useAppHost` will enable creation of a binary executable that runs the .NET application using the specified root. More info in [Microsoft docs](https://learn.microsoft.com/en-us/dotnet/core/deploying/#publish-framework-dependent). Enabled by default.
* `useDotnetFromEnv` will change the binary wrapper so that it uses the .NET from the environment. The runtime specified by `dotnet-runtime` is given as a fallback in case no .NET is installed in the user's environment. This is most useful for .NET global tools and LSP servers, which often extend the .NET CLI and their runtime should match the users' .NET runtime.
* `dotnet-sdk` is useful in cases where you need to change what dotnet SDK is being used. You can also set this to the result of `dotnetSdkPackages.combinePackages`, if the project uses multiple SDKs to build.
* `dotnet-runtime` is useful in cases where you need to change what dotnet runtime is being used. This can be either a regular dotnet runtime, or an aspnetcore.
* `testProjectFile` is useful in cases where the regular project file does not contain the unit tests. It gets restored and build, but not installed. You may need to regenerate your nuget lockfile after setting this. Note that if set, only tests from this project are executed.
* `testFilters` is used to disable running unit tests based on various [filters](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-test#filter-option-details). This gets passed as: `dotnet test --filter "{}"`, with each filter being concatenated using `"&"`.
* `disabledTests` is used to disable running specific unit tests. This gets passed as: `dotnet test --filter "FullyQualifiedName!={}"`, to ensure compatibility with all unit test frameworks.
* `dotnetRestoreFlags` can be used to pass flags to `dotnet restore`.
* `dotnetBuildFlags` can be used to pass flags to `dotnet build`.
* `dotnetTestFlags` can be used to pass flags to `dotnet test`. Used only if `doCheck` is set to `true`.
* `dotnetInstallFlags` can be used to pass flags to `dotnet install`.
* `dotnetPackFlags` can be used to pass flags to `dotnet pack`. Used only if `packNupkg` is set to `true`.
* `dotnetFlags` can be used to pass flags to all of the above phases.

When packaging a new application, you need to fetch its dependencies. Create an empty `deps.json`, set `nugetDeps = ./deps.json`, then run `nix-build -A package.fetch-deps` to generate a script that will build the lockfile for you.

Here is an example `default.nix`, using some of the previously discussed arguments:
```nix
{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  ffmpeg,
}:

let
  referencedProject = import ../../bar {
    # ...
  };
in
buildDotnetModule rec {
  pname = "someDotnetApplication";
  version = "0.1";

  src = ./.;

  projectFile = "src/project.sln";
  nugetDeps = ./deps.json; # see "Generating and updating NuGet dependencies" section for details

  buildInputs = [
    referencedProject
  ]; # `referencedProject` must contain `nupkg` in the folder structure.

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  executables = [ "foo" ]; # This wraps "$out/lib/$pname/foo" to `$out/bin/foo`.
  executables = [ ]; # Don't install any executables.

  packNupkg = true; # This packs the project as "foo-0.1.nupkg" at `$out/share`.

  runtimeDeps = [ ffmpeg ]; # This will wrap ffmpeg's library path into `LD_LIBRARY_PATH`.
}
```

Keep in mind that you can tag the [`@NixOS/dotnet`](https://github.com/orgs/nixos/teams/dotnet) team for help and code review.

## Dotnet global tools {#dotnet-global-tools}

[.NET Global tools](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools) are a mechanism provided by the dotnet CLI to install .NET binaries from Nuget packages.

They can be installed either as a global tool for the entire system, or as a local tool specific to project.

The local installation is the easiest and works on NixOS in the same way as on other Linux distributions.
[See dotnet documentation](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools#install-a-local-tool) to learn more.

[The global installation method](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools#install-a-global-tool)
should also work most of the time. You have to remember to update the `PATH`
value to the location the tools are installed to (the CLI will inform you about it during installation) and also set
the `DOTNET_ROOT` value, so that the tool can find the .NET SDK package.
You can find the path to the SDK by running `nix eval --raw nixpkgs#dotnet-sdk` (substitute the `dotnet-sdk` package for
another if a different SDK version is needed).

This method is not recommended on NixOS, since it's not declarative and involves installing binaries not made for NixOS,
which will not always work.

The third, and preferred way, is packaging the tool into a Nix derivation.

### Packaging Dotnet global tools {#packaging-dotnet-global-tools}

Dotnet global tools are standard .NET binaries, just made available through a special
NuGet package. Therefore, they can be built and packaged like every .NET application,
using `buildDotnetModule`.

If however the source is not available or difficult to build, the
`buildDotnetGlobalTool` helper can be used, which will package the tool
straight from its NuGet package.

This helper has the same arguments as `buildDotnetModule`, with a few differences:

* `pname` and `version` are required, and will be used to find the NuGet package of the tool
* `nugetName` can be used to override the NuGet package name that will be downloaded, if it's different from `pname`
* `nugetHash` is the hash of the fetched NuGet package. `nugetSha256` is also supported, but not recommended. Set this to `lib.fakeHash` for the first build, and it will error out, giving you the proper hash. Also remember to update it during version updates (it will not error out if you just change the version while having a fetched package in `/nix/store`)
* `dotnet-runtime` is set to `dotnet-sdk` by default. When changing this, remember that .NET tools fetched from NuGet require an SDK.

Here is an example of packaging `pbm`, an unfree binary without source available:
```nix
{ buildDotnetGlobalTool, lib }:

buildDotnetGlobalTool {
  pname = "pbm";
  version = "1.3.1";

  nugetHash = "sha256-ZG2HFyKYhVNVYd2kRlkbAjZJq88OADe3yjxmLuxXDUo=";

  meta = {
    homepage = "https://cmd.petabridge.com/index.html";
    changelog = "https://cmd.petabridge.com/articles/RELEASE_NOTES.html";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
```
## Generating and updating NuGet dependencies {#generating-and-updating-nuget-dependencies}

When writing a new expression, you can use the generated `fetch-deps` script to initialise the lockfile.
After setting `nugetDeps` to the desired location of the lockfile (e.g. `./deps.json`),
build the script with `nix-build -A package.fetch-deps` and then run the result.
(When the root attr is your package, it's simply `nix-build -A fetch-deps`.)

There is also a manual method:
First, restore the packages to the `out` directory, ensure you have cloned
the upstream repository and you are inside it.

```bash
$ dotnet restore --packages out
  Determining projects to restore...
  Restored /home/ggg/git-credential-manager/src/shared/Git-Credential-Manager/Git-Credential-Manager.csproj (in 1.21 sec).
```

Next, use `nuget-to-json` tool provided in nixpkgs to generate a lockfile to `deps.json` from
the packages inside the `out` directory.

```bash
$ nuget-to-json out > deps.json
```
Which `nuget-to-json` will generate an output similar to below
```json
[
  {
    "pname": "Avalonia",
    "version": "11.1.3",
    "hash": "sha256-kz+k/vkuWoL0XBvRT8SadMOmmRCFk9W/J4k/IM6oYX0="
  },
  {
    "pname": "Avalonia.Angle.Windows.Natives",
    "version": "2.1.22045.20230930",
    "hash": "sha256-RxPcWUT3b/+R3Tu5E5ftpr5ppCLZrhm+OTsi0SwW3pc="
  },
  {
    "pname": "Avalonia.BuildServices",
    "version": "0.0.29",
    "hash": "sha256-WPHRMNowRnYSCh88DWNBCltWsLPyOfzXGzBqLYE7tRY="
  },
  // ...
  {
    "pname": "System.Runtime.CompilerServices.Unsafe",
    "version": "6.0.0",
    "hash": "sha256-bEG1PnDp7uKYz/OgLOWs3RWwQSVYm+AnPwVmAmcgp2I="
  },
  {
    "pname": "System.Security.Cryptography.ProtectedData",
    "version": "4.5.0",
    "hash": "sha256-Z+X1Z2lErLL7Ynt2jFszku6/IgrngO3V1bSfZTBiFIc="
  },
  {
    "pname": "Tmds.DBus.Protocol",
    "version": "0.16.0",
    "hash": "sha256-vKYEaa1EszR7alHj48R8G3uYArhI+zh2ZgiBv955E98="
  }
]

```

Finally, you move the `deps.json` file to the appropriate location to be used by `nugetDeps`, then you're all set!

If you ever need to update the dependencies of a package, you instead do

* `nix-build -A package.fetch-deps` to generate the update script for `package`
* Run `./result` to regenerate the lockfile to the path passed for `nugetDeps` (keep in mind if it can't be resolved to a local path, the script will write to `$1` or a temporary path instead)
* Finally, ensure the correct file was written and the derivation can be built.
