#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project. Python 3, no packages required."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent

def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def q(value): return '"' + value.replace('"', '\\"') + '"'
objects = []
def obj(key, value):
    objects.append(f'{uid(key)} = {{ {value} }};')
    return uid(key)
sources = sorted((root / 'ClipDock').rglob('*.swift'))
refs, builds = [], []
for source in sources:
    path = str(source.relative_to(root))
    ref = obj(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    builds.append(obj('build:' + path, f'isa = PBXBuildFile; fileRef = {ref};'))
icon = obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = ClipDock/Resources/ClipDock.icns; sourceTree = SOURCE_ROOT;')
refs.append(icon)
icon_build = obj('iconbuild', f'isa = PBXBuildFile; fileRef = {icon};')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({icon_build},); runOnlyForDeploymentPostprocessing = 0;')
app = obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = ClipDock.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({app},); name = Products; sourceTree = "<group>";')
main = obj('group', f'isa = PBXGroup; children = ({",".join(refs)},{products},); sourceTree = "<group>";')
phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
configs = []
project_configs = []
for name in ['Debug', 'Release']:
    settings = '''PRODUCT_BUNDLE_IDENTIFIER = com.clipdock.app;
        PRODUCT_NAME = ClipDock; SWIFT_VERSION = 5.0; MACOSX_DEPLOYMENT_TARGET = 14.0;
        SDKROOT = macosx; INFOPLIST_FILE = ClipDock/Resources/Info.plist;
        CODE_SIGN_STYLE = Automatic; ENABLE_HARDENED_RUNTIME = YES;
        COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";'''
    if name == 'Debug': settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;'
    else: settings += ' SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_COMPILATION_MODE = wholemodule;'
    configs.append(obj('target:' + name, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {name};'))
    project_configs.append(obj('project:' + name, f'isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; }}; name = {name};'))
tcl = obj('targetconfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pcl = obj('projectconfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tcl}; buildPhases = ({phase},{resources},); buildRules = (); dependencies = (); name = ClipDock; productName = ClipDock; productReference = {app}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {pcl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
folder = root / 'ClipDock.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
schemes = folder / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ClipDock.app" BlueprintName="ClipDock" ReferencedContainer="container:ClipDock.xcodeproj"/>'
(schemes / 'ClipDock.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n''')
print('Generated ClipDock.xcodeproj')
