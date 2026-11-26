# SPDX-License-Identifier: MIT
# Copyright (c) 2026 alice boars
# Copyright (c) 2026 SmuJayB

set default-script := true
just := just_executable()
exiftool := require("exiftool")
uv := require("uv")
yq := require("yq")
publiciser := require("assembly-publicizer")
dotnet := require("dotnet")
grep := require("grep")
xargs := require("xargs")
env := require("env")

[private]
default:
    {{ just }} --list

# Find the assembly versions in unprocessed XML.
_raw_dependencies assembly_path:
    # Change directory, collect information.
    cd {{quote(assembly_path)}} 2>/dev/null
    {{exiftool}} -X -AssemblyVersion -ProductVersion . 2>/dev/null

# Find the assembly versions used by the game and output them as an XML element
# of 'dependencies' for the `.nuspec`.
dependencies assembly_path:
    #!{{env}} -S {{uv}} run --script
    # /// script
    # requires-python = ">=3.11"
    # dependencies = ["rdflib"]
    # ///

    # Imports.
    from rdflib import Graph
    from rdflib.term import URIRef
    from xml.dom import minidom
    from os.path import basename, splitext

    IGNORED = [
        "mscorlib",
        "Assembly-CSharp",
        "Assembly-CSharp-firstpass",
        "TwitchSDK"
    ]

    # Capture and parse RDFXML data.
    raw = Graph()
    raw.parse(data=
        """{{ shell(f'{{just}} _raw_dependencies {{quote(assembly_path)}}') }}""",
    format="application/rdf+xml")

    # Build an XML document of dependencies.
    final = minidom.Document()
    package = final.createElement("package")
    package.setAttribute("xmlns", "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd")
    metadata = final.createElement("metadata")
    dependencies = final.createElement("dependencies")
    frameworkAssemblies = final.createElement("frameworkAssemblies")
    files = final.createElement("files")
    for subject in set(raw.subjects()):
        name = splitext(basename(subject))[0]
        if name in IGNORED or name.startswith("Unity"): continue # Skip.
        is_framework = name.startswith("System")
        if is_framework:
            frameworkAssembly = final.createElement("frameworkAssembly")
            frameworkAssembly.setAttribute("assemblyName", name)
            frameworkAssemblies.appendChild(frameworkAssembly)
        else:
            assembly = raw.value(subject, URIRef("http://ns.exiftool.org/EXE/EXE/1.0/AssemblyVersion"), any=False)
            product = raw.value(subject, URIRef("http://ns.exiftool.org/EXE/EXE/1.0/ProductVersion"), any=False)
            if assembly.startswith("0") or product.startswith("0"):
                file = final.createElement("file")
                file.setAttribute("src", f"libs/3rdparty/{subject}")
                file.setAttribute("target", "lib")
                files.appendChild(file)
            else:
                dependency = final.createElement("dependency")
                dependency.setAttribute("id", basename(name))
                dependency.setAttribute("version", product)
                dependencies.appendChild(dependency)
    metadata.appendChild(dependencies)
    metadata.appendChild(frameworkAssemblies)
    package.appendChild(metadata)
    package.appendChild(files)
    final.appendChild(package)
    print(final.toprettyxml())

cleanup:
    # Do not fail. Ever.
    set -uxo
    set +e

    # Remove everything.
    rm *.nupkg *.nuspec
    rm -r libs

    # Exit with a good code.
    exit 0

build version game_directory: cleanup
    # Debugging.
    set -euxo

    # Copy assemblies.
    cp "{{game_directory}}/Goblin Cleanup_Data/Managed" libs -r
    # Inject version and dependencies.
    {{yq}} ea -p xml -o xml \
        -P '.package.metadata.dependencies |= [] + .
        | .package.metadata.frameworkAssemblies |= [] + .
        | (. as $item ireduce ({}; . *+ $item ))
        | .package.metadata += {"version": "{{version}}"}' \
        GoblinCleanup.GameLibs.nuspec.in <({{just}} dependencies libs) > GoblinCleanup.GameLibs.nuspec
    # Publicise the game assembly.
    pushd libs
    {{publiciser}} Assembly-CSharp.dll --strip -o GoblinCleanup.GameLibs.dll
    # Publicise other assemblies.
    mkdir 3rdparty && pushd 3rdparty
    cp ../*.dll .
    rm Assembly-CSharp.dll \
        Assembly-CSharp-firstpass.dll \
        GoblinCleanup.GameLibs.dll \
        System.dll \
        System.*.dll \
        Unity*.dll \
        mscorlib.dll
    cat ../../GoblinCleanup.GameLibs.nuspec \
        | {{grep}} 'dependency' \
        | {{grep}} 'id="[0-9a-zA-Z.]*"' -o \
        | {{grep}} -o '".*"' \
        | {{xargs}} -i sh -c 'rm "{}.dll" | true'
    {{publiciser}} -f .
    popd
    # Pack NuGet package.
    popd
    {{dotnet}} pack GoblinCleanup.GameLibs.nuspec
