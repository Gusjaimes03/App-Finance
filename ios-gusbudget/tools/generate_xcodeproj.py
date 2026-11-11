#!/usr/bin/env python3
"""Genera GusBudget.xcodeproj a partir de los archivos de GusBudget/.

Se vuelve a ejecutar cuando se agregan o quitan archivos:

    python3 tools/generate_xcodeproj.py
"""
import hashlib
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "GusBudget"
FUENTES = os.path.join(ROOT, APP)
PROYECTO = os.path.join(ROOT, f"{APP}.xcodeproj")
BUNDLE_ID = "com.gusjaimes.GusBudget"
OBJETIVO_IOS = "16.0"

usados = set()
REFS = {}


def uid(*partes):
    clave = "|".join(partes)
    digest = hashlib.md5(clave.encode()).hexdigest().upper()[:24]
    while digest in usados:
        clave += "!"
        digest = hashlib.md5(clave.encode()).hexdigest().upper()[:24]
    usados.add(digest)
    return digest


class Nodo:
    def __init__(self, nombre, ruta):
        self.nombre = nombre
        self.ruta = ruta
        self.grupos = []
        self.archivos = []
        self.gid = ""


def escanear(directorio, relativo):
    nodo = Nodo(os.path.basename(directorio), relativo)
    for entrada in sorted(os.listdir(directorio)):
        if entrada.startswith("."):
            continue
        completo = os.path.join(directorio, entrada)
        rel = os.path.join(relativo, entrada)
        if entrada.endswith(".xcassets"):
            nodo.archivos.append((entrada, rel))
        elif os.path.isdir(completo):
            nodo.grupos.append(escanear(completo, rel))
        elif entrada.endswith((".swift", ".plist", ".entitlements")):
            nodo.archivos.append((entrada, rel))
    return nodo


def recolectar(nodo, fuentes, recursos):
    for nombre, rel in nodo.archivos:
        if nombre.endswith(".swift"):
            fuentes.append((nombre, rel))
        elif nombre.endswith(".xcassets"):
            recursos.append((nombre, rel))
    for grupo in nodo.grupos:
        recolectar(grupo, fuentes, recursos)


def tipo(nombre):
    if nombre.endswith(".swift"):
        return "sourcecode.swift"
    if nombre.endswith(".xcassets"):
        return "folder.assetcatalog"
    if nombre.endswith(".plist"):
        return "text.plist.xml"
    return "text"


def asignar(nodo):
    nodo.gid = uid("grupo", nodo.ruta)
    for grupo in nodo.grupos:
        asignar(grupo)


def escribir_grupos(nodo, lineas, sangria="\t\t"):
    hijos = [(g.gid, g.nombre) for g in nodo.grupos]
    hijos += [(REFS[rel], nombre) for nombre, rel in nodo.archivos]

    lineas.append(f"{sangria}{nodo.gid} /* {nodo.nombre} */ = {{")
    lineas.append(f"{sangria}\tisa = PBXGroup;")
    lineas.append(f"{sangria}\tchildren = (")
    for gid, nombre in hijos:
        lineas.append(f"{sangria}\t\t{gid} /* {nombre} */,")
    lineas.append(f"{sangria}\t);")
    lineas.append(f"{sangria}\tpath = {nodo.nombre};")
    lineas.append(f"{sangria}\tsourceTree = \"<group>\";")
    lineas.append(f"{sangria}}};")
    for grupo in nodo.grupos:
        escribir_grupos(grupo, lineas, sangria)


COMUNES = [
    ("ALWAYS_SEARCH_USER_PATHS", "NO"),
    ("CLANG_ANALYZER_NONNULL", "YES"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
    ("COPY_PHASE_STRIP", "NO"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("GCC_NO_COMMON_BLOCKS", "YES"),
    ("GCC_WARN_UNUSED_VARIABLE", "YES"),
    ("IPHONEOS_DEPLOYMENT_TARGET", OBJETIVO_IOS),
    ("SDKROOT", "iphoneos"),
]

DEBUG = COMUNES + [
    ("DEBUG_INFORMATION_FORMAT", "dwarf"),
    ("ENABLE_TESTABILITY", "YES"),
    ("GCC_DYNAMIC_NO_PIC", "NO"),
    ("GCC_OPTIMIZATION_LEVEL", "0"),
    ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
    ("ONLY_ACTIVE_ARCH", "YES"),
    ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
    ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
]

RELEASE = COMUNES + [
    ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
    ("ENABLE_NS_ASSERTIONS", "NO"),
    ("MTL_ENABLE_DEBUG_INFO", "NO"),
    ("SWIFT_COMPILATION_MODE", "wholemodule"),
    ("SWIFT_OPTIMIZATION_LEVEL", '"-O"'),
    ("VALIDATE_PRODUCT", "YES"),
]

TARGET = [
    ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
    ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1"),
    ("DEVELOPMENT_TEAM", '""'),
    ("ENABLE_PREVIEWS", "YES"),
    ("GENERATE_INFOPLIST_FILE", "YES"),
    ("INFOPLIST_KEY_CFBundleDisplayName", "GusBudget"),
    ("INFOPLIST_KEY_NSFaceIDUsageDescription", '"Para que solo tu puedas ver tus finanzas."'),
    ("INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "YES"),
    ("INFOPLIST_KEY_UILaunchScreen_Generation", "YES"),
    ("INFOPLIST_KEY_UIStatusBarStyle", "UIStatusBarStyleDefault"),
    ("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad",
     '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
    ("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone",
     '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
    ("IPHONEOS_DEPLOYMENT_TARGET", OBJETIVO_IOS),
    ("LD_RUNPATH_SEARCH_PATHS", '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
    ("MARKETING_VERSION", "1.0"),
    ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
    ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
    ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ("SWIFT_VERSION", "5.0"),
    ("TARGETED_DEVICE_FAMILY", '"1,2"'),
]


def ajustes(pares, sangria="\t\t\t\t"):
    return "\n".join(f"{sangria}{clave} = {valor};" for clave, valor in pares)


def main():
    arbol = escanear(FUENTES, APP)
    asignar(arbol)

    fuentes, recursos = [], []
    recolectar(arbol, fuentes, recursos)
    if not fuentes:
        raise SystemExit("No hay archivos .swift en " + FUENTES)

    for _, rel in fuentes + recursos:
        REFS[rel] = uid("ref", rel)
    construidos = {rel: uid("build", rel) for _, rel in fuentes + recursos}

    producto = uid("producto", APP)
    grupo_productos = uid("grupo", "Products")
    grupo_raiz = uid("grupo", "raiz")
    proyecto = uid("proyecto", APP)
    objetivo = uid("objetivo", APP)
    fase_fuentes = uid("fase", "sources")
    fase_frameworks = uid("fase", "frameworks")
    fase_recursos = uid("fase", "resources")
    lista_proyecto = uid("lista", "proyecto")
    lista_objetivo = uid("lista", "objetivo")
    cfg_pd = uid("cfg", "proyecto-debug")
    cfg_pr = uid("cfg", "proyecto-release")
    cfg_td = uid("cfg", "objetivo-debug")
    cfg_tr = uid("cfg", "objetivo-release")

    salida = []
    add = salida.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")

    add("\n/* Begin PBXBuildFile section */")
    for fase, elementos in (("Sources", fuentes), ("Resources", recursos)):
        for nombre, rel in elementos:
            add(f"\t\t{construidos[rel]} /* {nombre} in {fase} */ = {{isa = PBXBuildFile; fileRef = {REFS[rel]} /* {nombre} */; }};")
    add("/* End PBXBuildFile section */")

    add("\n/* Begin PBXFileReference section */")
    add(f"\t\t{producto} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for nombre, rel in sorted(fuentes + recursos, key=lambda par: par[1]):
        add(f"\t\t{REFS[rel]} /* {nombre} */ = {{isa = PBXFileReference; lastKnownFileType = {tipo(nombre)}; path = {nombre}; sourceTree = \"<group>\"; }};")
    add("/* End PBXFileReference section */")

    add("\n/* Begin PBXFrameworksBuildPhase section */")
    add(f"\t\t{fase_frameworks} /* Frameworks */ = {{")
    add("\t\t\tisa = PBXFrameworksBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    add("\n/* Begin PBXGroup section */")
    add(f"\t\t{grupo_raiz} = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{arbol.gid} /* {APP} */,")
    add(f"\t\t\t\t{grupo_productos} /* Products */,")
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    add(f"\t\t{grupo_productos} /* Products */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{producto} /* {APP}.app */,")
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    lineas_grupos = []
    escribir_grupos(arbol, lineas_grupos)
    salida.extend(lineas_grupos)
    add("/* End PBXGroup section */")

    add("\n/* Begin PBXNativeTarget section */")
    add(f"\t\t{objetivo} /* {APP} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {lista_objetivo} /* Build configuration list for PBXNativeTarget \"{APP}\" */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{fase_fuentes} /* Sources */,")
    add(f"\t\t\t\t{fase_frameworks} /* Frameworks */,")
    add(f"\t\t\t\t{fase_recursos} /* Resources */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add(f"\t\t\tname = {APP};")
    add(f"\t\t\tproductName = {APP};")
    add(f"\t\t\tproductReference = {producto} /* {APP}.app */;")
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")

    add("\n/* Begin PBXProject section */")
    add(f"\t\t{proyecto} /* Project object */ = {{")
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    add("\t\t\t\tLastUpgradeCheck = 1500;")
    add("\t\t\t\tTargetAttributes = {")
    add(f"\t\t\t\t\t{objetivo} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f"\t\t\tbuildConfigurationList = {lista_proyecto} /* Build configuration list for PBXProject \"{APP}\" */;")
    add("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    add("\t\t\tdevelopmentRegion = es;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\tes,")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f"\t\t\tmainGroup = {grupo_raiz};")
    add(f"\t\t\tproductRefGroup = {grupo_productos} /* Products */;")
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add("\t\t\ttargets = (")
    add(f"\t\t\t\t{objetivo} /* {APP} */,")
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    add("\n/* Begin PBXResourcesBuildPhase section */")
    add(f"\t\t{fase_recursos} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for nombre, rel in recursos:
        add(f"\t\t\t\t{construidos[rel]} /* {nombre} in Resources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    add("\n/* Begin PBXSourcesBuildPhase section */")
    add(f"\t\t{fase_fuentes} /* Sources */ = {{")
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for nombre, rel in fuentes:
        add(f"\t\t\t\t{construidos[rel]} /* {nombre} in Sources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    add("\n/* Begin XCBuildConfiguration section */")
    for cfg, nombre, pares in [(cfg_pd, "Debug", DEBUG), (cfg_pr, "Release", RELEASE)]:
        add(f"\t\t{cfg} /* {nombre} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add(ajustes(pares))
        add("\t\t\t};")
        add(f"\t\t\tname = {nombre};")
        add("\t\t};")
    for cfg, nombre in [(cfg_td, "Debug"), (cfg_tr, "Release")]:
        add(f"\t\t{cfg} /* {nombre} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add(ajustes(TARGET))
        add("\t\t\t};")
        add(f"\t\t\tname = {nombre};")
        add("\t\t};")
    add("/* End XCBuildConfiguration section */")

    add("\n/* Begin XCConfigurationList section */")
    add(f"\t\t{lista_proyecto} /* Build configuration list for PBXProject \"{APP}\" */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{cfg_pd} /* Debug */,")
    add(f"\t\t\t\t{cfg_pr} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
    add(f"\t\t{lista_objetivo} /* Build configuration list for PBXNativeTarget \"{APP}\" */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{cfg_td} /* Debug */,")
    add(f"\t\t\t\t{cfg_tr} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f"\trootObject = {proyecto} /* Project object */;")
    add("}")

    if os.path.isdir(PROYECTO):
        shutil.rmtree(PROYECTO)
    esquemas = os.path.join(PROYECTO, "xcshareddata", "xcschemes")
    os.makedirs(esquemas)

    with open(os.path.join(PROYECTO, "project.pbxproj"), "w") as destino:
        destino.write("\n".join(salida) + "\n")

    with open(os.path.join(esquemas, f"{APP}.xcscheme"), "w") as destino:
        destino.write(esquema(objetivo))

    print(f"Proyecto generado: {PROYECTO}")
    print(f"  {len(fuentes)} archivos Swift, {len(recursos)} recurso(s)")


def esquema(objetivo):
    referencia = (
        '<BuildableReference\n'
        '               BuildableIdentifier = "primary"\n'
        f'               BlueprintIdentifier = "{objetivo}"\n'
        f'               BuildableName = "{APP}.app"\n'
        f'               BlueprintName = "{APP}"\n'
        f'               ReferencedContainer = "container:{APP}.xcodeproj">\n'
        '            </BuildableReference>'
    )
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {referencia}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {referencia}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {referencia}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''


if __name__ == "__main__":
    main()
