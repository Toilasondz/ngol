# build.ps1 — 1-Click Cross-compile HSONModernMenu.dylib on Windows
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# SDK Search
$SDK_CANDIDATES = @(
    "$SCRIPT_DIR\sdk\iPhoneOS15.6.sdk",
    "$SCRIPT_DIR\..\sdk\iPhoneOS15.6.sdk",
    "$SCRIPT_DIR\..\VideoStarTool\sdk\iPhoneOS15.6.sdk",
    "C:\Users\hson\.gemini\antigravity\scratch\VideoStarTool\sdk\iPhoneOS15.6.sdk"
)
$SDK_DIR = ""
foreach ($cand in $SDK_CANDIDATES) {
    if (Test-Path "$cand\usr\include") {
        $SDK_DIR = (Resolve-Path $cand).Path
        break
    }
}

# Clang Search
$CLANG_CANDIDATES = @(
    "$SCRIPT_DIR\tools\llvm-mingw-20261020-msvcrt-x86_64\bin\clang.exe",
    "$SCRIPT_DIR\..\tools\llvm-mingw-20261020-msvcrt-x86_64\bin\clang.exe",
    "$SCRIPT_DIR\..\VideoStarTool\tools\llvm-mingw-20261020-msvcrt-x86_64\bin\clang.exe",
    "C:\Users\hson\.gemini\antigravity\scratch\VideoStarTool\tools\llvm-mingw-20261020-msvcrt-x86_64\bin\clang.exe"
)
$CLANG = ""
foreach ($cand in $CLANG_CANDIDATES) {
    if (Test-Path $cand) {
        $CLANG = (Resolve-Path $cand).Path
        break
    }
}
if (-not $CLANG) {
    $found = Get-Command clang -ErrorAction SilentlyContinue
    if ($found) { $CLANG = $found.Source }
}

$OUT_DIR    = "$SCRIPT_DIR\out"
$OUT_DYLIB  = "$OUT_DIR\HSONModernMenu.dylib"

Write-Host "========================================="
Write-Host " Building HSONModernMenu.dylib on Windows"
Write-Host " Compiler: $CLANG"
Write-Host " SDK:      $SDK_DIR"
Write-Host "========================================="

if (-not (Test-Path $CLANG)) {
    Write-Error "clang.exe not found at $CLANG."
    exit 1
}

if (-not (Test-Path "$SDK_DIR\usr\include")) {
    Write-Error "iOS SDK not found at $SDK_DIR."
    exit 1
}

New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null

$SOURCES = @(
    "Source\Features\HSONFeatureEngine.m",
    "Source\Tweak.m"
)

$OBJS = @()
foreach ($src in $SOURCES) {
    $srcPath = "$SCRIPT_DIR\$src"
    $objPath = "$OUT_DIR\" + [System.IO.Path]::GetFileNameWithoutExtension($src) + ".o"
    Write-Host "--> Compiling $src..."
    & $CLANG -target arm64-apple-ios15.0 -isysroot $SDK_DIR -fobjc-arc -fblocks -O2 -c $srcPath -o $objPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to compile $src"
        exit 1
    }
    $OBJS += $objPath
}

Write-Host "--> Linking HSONModernMenu.dylib with headerpad and ad-hoc code signature..."
$LINK_ARGS = @(
    "-target", "arm64-apple-ios15.0",
    "-fuse-ld=lld",
    "-isysroot", $SDK_DIR,
    "-shared",
    "-dynamiclib",
    "-Xlinker", "-undefined",
    "-Xlinker", "dynamic_lookup",
    "-Xlinker", "-install_name",
    "-Xlinker", "@rpath/HSONModernMenu.dylib",
    "-Xlinker", "-headerpad_max_install_names",
    "-Xlinker", "-headerpad",
    "-Xlinker", "0x4000",
    "-Xlinker", "-adhoc_codesign",
    "-framework", "UIKit",
    "-framework", "QuartzCore",
    "-framework", "Foundation",
    "-framework", "CoreImage",
    "-framework", "CoreMedia",
    "-framework", "AVFoundation",
    "-framework", "UniformTypeIdentifiers",
    "-o", $OUT_DYLIB
) + $OBJS

& $CLANG $LINK_ARGS
if ($LASTEXITCODE -ne 0) {
    Write-Error "Linking failed."
    exit 1
}

Copy-Item -Path $OUT_DYLIB -Destination "$SCRIPT_DIR\HSONModernMenu.dylib" -Force

$size = (Get-Item $OUT_DYLIB).Length
Write-Host ""
Write-Host "========================================="
Write-Host " BUILD SUCCESSFUL!"
Write-Host " Output : $OUT_DYLIB"
Write-Host " Size   : $([math]::Round($size/1KB,1)) KB ($size bytes)"
Write-Host " Arch   : ARM64 (iOS 15.0+)"
Write-Host " Headerpad : 16 KiB reserved for signing"
Write-Host " Signature : Embedded ad-hoc LC_CODE_SIGNATURE"
Write-Host "========================================="
