# syntax=docker/dockerfile:1
# escape=`

# ---------------- GLOBAL VARS ----------------
ARG CMAKE_VERSION=3.31.0
ARG PYTHON_VERSION=3.13.2
ARG NINJA_VERSION=1.12.1
ARG NASM_VERSION=2.16.03
ARG GIT_VERSION=2.48.1
ARG ZSTD_VERSION=1.5.7
ARG WINDOWS_11_SDK_VERSION=22621
ARG WINDOWS_SDK_VERSION=10.0.${WINDOWS_11_SDK_VERSION}.0
ARG VC_VERSION=14.43.17.13
ARG VS_BOOTSTRAP_VERSION=17.13.6
ARG VULKAN_SDK_VERSION=1.4.313.0
ARG NINJATRACING_VERSION=0.0.2

# note: it seems we cannot pass version within any workflow ID to installer, though as I look at VS package cache I see it being done in json payloads! 
# henceforth we enforce fixed versions with nasty bootstrap URL, more details:
# https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#fixed-version-bootstrappers

# note: if you update BUILD_TOOLS_URL then update also VS_BOOTSTRAP_VERSION
# default version: ${VS_BOOTSTRAP_VERSION}, channel: Current
# UPDAT ME: need to find out if there is a way to use VS_BOOTSTRAP_VERSION instead of this nasty URL which matches the bootstrap version
ARG BUILD_TOOLS_URL=https://download.visualstudio.microsoft.com/download/pr/8fada5c7-8417-4239-acc3-bd499af09222/353141457abcc59eb9c38b2f30084e7271c6bcfb4e185466d98161bada905759/vs_BuildTools.exe

# used for validation & matches internal package payloads, note: requires adjusting BUILD_TOOLS_URL
ARG MSVC_VERSION=14.43.34808
ARG CLANGCL_VERSION=19.1.1

ARG IMPL_ARTIFACTS_DIR="C:\artifacts"
ARG IMPL_COMPRESSION_OPTIONS=-T0
ARG IMPL_COMPRESSION_LEVEL=3

ARG IMPL_NANO_BASE=mcr.microsoft.com/powershell
ARG IMPL_NANO_TAG=lts-nanoserver-ltsc2022

# ---------------- REDIST ----------------
FROM mcr.microsoft.com/windows/servercore:ltsc2022 as redist

ARG BUILD_TOOLS_URL
ARG IMPL_ARTIFACTS_DIR

RUN mkdir C:\Temp && cd C:\Temp `
&& curl -SL --output vs_buildtools.exe %BUILD_TOOLS_URL% `
&& (start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
--add Microsoft.VisualStudio.Component.VC.Redist.14.Latest `
--installPath %IMPL_ARTIFACTS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0)

# ---------------- COMMON BUILD TOOLS ----------------
FROM redist as bootstrap

ARG BUILD_TOOLS_URL
ARG IMPL_ARTIFACTS_DIR

RUN (start /w C:\Temp\vs_buildtools.exe --quiet --wait --norestart --nocache `
--add Microsoft.VisualCpp.DIA.SDK `
--add Microsoft.VisualStudio.Component.VC.Llvm.Clang `
--installPath %IMPL_ARTIFACTS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0)

SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

# version depends on channel (see BUILD_TOOLS_URL)
ARG CLANGCL_VERSION
RUN $version = "$env:CLANGCL_VERSION" ; `
$clangcl = Join-Path $env:IMPL_ARTIFACTS_DIR "VC\Tools\Llvm\bin\clang-cl.exe" ; `
$pipe = & "$clangcl" -v 2>&1 ; `
if ($pipe -match "$version") { exit 0 } else { `
Write-Host "Validation failed due to requested version mismatch! Note: CLANGCL_VERSION = $version" ; `
Write-Host "$pipe" ; `
exit -1 `
}

SHELL ["cmd", "/S", "/C"]

# ---------------- WINDOWS SDK ----------------
FROM bootstrap as winsdk

ARG WINDOWS_11_SDK_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN (start /w C:\Temp\vs_buildtools.exe --quiet --wait --norestart --nocache `
--add Microsoft.VisualStudio.Component.Windows11SDK.%WINDOWS_11_SDK_VERSION% `
--installPath %IMPL_ARTIFACTS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0)

# ---------------- VC BUILD TOOLS ----------------
FROM bootstrap as buildtools

ARG VC_VERSION
ARG MSVC_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN (start /w C:\Temp\vs_buildtools.exe --quiet --wait --norestart --nocache `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.x86.x64 `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.ATL `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.MFC `
--installPath %IMPL_ARTIFACTS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0) && dir %IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC `
&& if exist %IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\%MSVC_VERSION% ( `
for /d %i in (%IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\*) do if /I not "%i"=="%IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\%MSVC_VERSION%" rd /s /q "%i" `
) else ( `
echo "Error: Expected MSVC version directory %MSVC_VERSION% does not exist!" && exit /b 1 `
)

# SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
# important note: msc ships compiler which minor version doesn't match the toolset directory name
# eg. dir name: 14.43.34808 (MSVC_VERSION) but version reported by cl.exe: 19.43.34810
# more over, all package cache payloads (by default at C:\ProgramData\Microsoft\VisualStudio)
# use MSVC_VERSION within workflow components ID - none of them contains 19.43.34810

# UPDATE ME: once I know more about CL versioning 
#
# RUN $version = "$env:MSVC_VERSION" ; `
# $cl = Join-Path $env:IMPL_ARTIFACTS_DIR "VC\Tools\MSVC\$version\bin\Hostx64\x64\cl.exe" ; `
# $pipe = & "$cl" 2>&1 ; `
# if ($pipe -match "$version") { exit 0 } else { `
# Write-Host "Validation failed due to requested version mismatch! Note: MSVC_VERSION = $version" ; `
# Write-Host "$pipe" ; `
# exit -1 `
# }

# ---------------- VULKAN SDK ----------------
FROM redist as vulkan

ARG VULKAN_SDK_VERSION
ARG IMPL_ARTIFACTS_DIR
SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

RUN Write-Host "Installing Vulkan SDK $env:VULKAN_SDK_VERSION" ; `
Remove-Item -Recurse -Force $env:IMPL_ARTIFACTS_DIR -ErrorAction SilentlyContinue ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://sdk.lunarg.com/sdk/download/$env:VULKAN_SDK_VERSION/windows/vulkansdk-windows-X64-$env:VULKAN_SDK_VERSION.exe" -OutFile C:\Temp\vulkan-sdk.exe ; `
& C:\Temp\vulkan-sdk.exe install --root "$env:IMPL_ARTIFACTS_DIR" --default-answer --accept-licenses --confirm-command ; `
Remove-Item C:\Temp\vulkan-sdk.exe

# ---------------- CMAKE ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as cmake
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG CMAKE_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing CMake $env:CMAKE_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://github.com/Kitware/CMake/releases/download/v$env:CMAKE_VERSION/cmake-$env:CMAKE_VERSION-windows-x86_64.zip" -OutFile C:\Temp\cmake.zip ; `
tar -xf C:\Temp\cmake.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\cmake.zip

# ---------------- PYTHON ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as python
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG PYTHON_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing Python $env:PYTHON_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$env:PYTHON_VERSION/python-$env:PYTHON_VERSION-embed-amd64.zip" -OutFile C:\Temp\python.zip ; `
tar -xf C:\Temp\python.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\python.zip ; `
Write-Host "Disabling isolated mode..." ; `
$pthFiles = Get-ChildItem -Path $env:IMPL_ARTIFACTS_DIR -Filter "*._pth" ; `
foreach ($file in $pthFiles) { `
    $oldName = $file.FullName ; `
    $newName = $oldName + '.disabled' ; `
    Write-Host "Renaming $oldName to $newName" ; `
    Rename-Item -Path $oldName -NewName $newName `
}

# ---------------- NINJA ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as ninja
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG NINJA_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing Ninja $env:NINJA_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://github.com/ninja-build/ninja/releases/download/v$env:NINJA_VERSION/ninja-win.zip" -OutFile C:\Temp\ninja.zip ; `
tar -xf C:\Temp\ninja.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\ninja.zip

# ---------------- NINJA ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as ninjatracing
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG NINJATRACING_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing Ninja-Tracing $env:NINJATRACING_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://github.com/Devsh-Graphics-Programming/ninjatracing/archive/refs/tags/$env:NINJATRACING_VERSION.zip" -OutFile C:\Temp\ninjatracing.zip ; `
tar -xf C:\Temp\ninjatracing.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\ninjatracing.zip

# ---------------- NASM ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as nasm
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG NASM_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing NASM $env:NASM_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://fossies.org/windows/misc/nasm-$env:NASM_VERSION-win64.zip" -OutFile C:\Temp\nasm.zip ; `
tar -xf C:\Temp\nasm.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\nasm.zip

# ---------------- GIT ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as git
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG GIT_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing Git $env:GIT_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v$env:GIT_VERSION.windows.1/MinGit-$env:GIT_VERSION-busybox-64-bit.zip" -OutFile C:\Temp\git.zip ; `
tar -xf C:\Temp\git.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\git.zip

# ---------------- ZSTD ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as zstd
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG ZSTD_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing Git $env:ZSTD_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://github.com/facebook/zstd/releases/download/v$env:ZSTD_VERSION/zstd-v$env:ZSTD_VERSION-win64.zip" -OutFile C:\Temp\zstd.zip ; `
tar -xf C:\Temp\zstd.zip -C $env:IMPL_ARTIFACTS_DIR ; `
Remove-Item C:\Temp\zstd.zip

# ---------------- COMPRESS STEP ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as compress
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG IMPL_ARTIFACTS_DIR
COPY --link --from=winsdk ["C:/Program Files (x86)/Windows Kits/10", "C:/pack/WindowsKits10SDK"]
COPY --link --from=buildtools ["${IMPL_ARTIFACTS_DIR}", "C:/pack/BuildTools"]
COPY --link --from=vulkan ["${IMPL_ARTIFACTS_DIR}", "C:/pack/vulkan-sdk"]
COPY --link --from=cmake ["${IMPL_ARTIFACTS_DIR}", "C:/pack/CMake"]
COPY --link --from=python ["${IMPL_ARTIFACTS_DIR}", "C:/pack/Python"]
COPY --link --from=ninja ["${IMPL_ARTIFACTS_DIR}", "C:/pack/Ninja"]
COPY --link --from=ninjatracing ["${IMPL_ARTIFACTS_DIR}", "C:/pack/NinjaTracing"]
COPY --link --from=nasm ["${IMPL_ARTIFACTS_DIR}", "C:/pack/Nasm"]
COPY --link --from=git ["${IMPL_ARTIFACTS_DIR}", "C:/pack/Git"]
COPY --link --from=zstd ["${IMPL_ARTIFACTS_DIR}", "C:/compress"]

ARG ZSTD_VERSION
ARG IMPL_COMPRESSION_OPTIONS
ARG IMPL_COMPRESSION_LEVEL

WORKDIR C:\pack
RUN $dirs=Get-ChildItem -Directory|Select-Object -Expand Name; `
New-Item -ItemType Directory -Force -Path "zst"; `
foreach($d in $dirs){ `
Write-Host "=== Compressing $d ==="; `
tar -cf "${d}-artifacts.tar" "$d"; `
& "C:\compress\zstd-v$env:ZSTD_VERSION-win64\zstd.exe" `
$env:IMPL_COMPRESSION_OPTIONS.Split(' ') `
"${d}-artifacts.tar" "-$env:IMPL_COMPRESSION_LEVEL" `
"-o" "zst/${d}-artifacts.tar.zst"; `
Remove-Item "${d}-artifacts.tar"; `
}

# ---------------- FINAL IMAGE ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG}
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
USER ContainerAdministrator

LABEL org.opencontainers.image.title="MSVC & ClangCL Build Tools with CMake toolchains"
LABEL org.opencontainers.image.source=https://github.com/Devsh-Graphics-Programming/docker-nanoserver-msvc-winsdk
LABEL org.opencontainers.image.description="Build MSVC/ClangCL + WinSDK projects with CMake toolchains in Windows Nano Server!"
LABEL org.opencontainers.image.licenses=Apache-2.0

ARG IMPL_ARTIFACTS_DIR
COPY --link --from=compress ["C:/pack/zst", "C:/pack"]
COPY --link --from=zstd ["${IMPL_ARTIFACTS_DIR}", "C:/compress"]

ARG CMAKE_VERSION
ARG PYTHON_VERSION
ARG NINJA_VERSION
ARG NASM_VERSION
ARG GIT_VERSION
ARG WINDOWS_11_SDK_VERSION
ARG WINDOWS_SDK_VERSION
ARG VC_VERSION
ARG MSVC_VERSION
ARG CLANGCL_VERSION
ARG BUILD_TOOLS_URL
ARG VS_BOOTSTRAP_VERSION
ARG VULKAN_SDK_VERSION
ARG NINJATRACING_VERSION
ARG ZSTD_VERSION

ENV CMAKE_WINDOWS_KITS_10_DIR="C:\WindowsKits10SDK" `
CMAKE_VERSION=${CMAKE_VERSION} `
PYTHON_VERSION=${PYTHON_VERSION} `
NINJA_VERSION=${NINJA_VERSION} `
NASM_VERSION=${NASM_VERSION} `
GIT_VERSION=${GIT_VERSION} `
WINDOWS_11_SDK_VERSION=${WINDOWS_11_SDK_VERSION} `
WINDOWS_SDK_VERSION=${WINDOWS_SDK_VERSION} `
VC_VERSION=${VC_VERSION} `
VS_INSTANCE_LOCATION=C:\BuildTools `
MSVC_VERSION=${MSVC_VERSION} `
CLANGCL_VERSION=${CLANGCL_VERSION} `
BUILD_TOOLS_URL=${BUILD_TOOLS_URL} `
VS_BOOTSTRAP_VERSION=${VS_BOOTSTRAP_VERSION} `
VULKAN_SDK_VERSION=${VULKAN_SDK_VERSION} `
NINJATRACING_VERSION=${NINJATRACING_VERSION} `
MSVC_TOOLSET_DIR=C:\BuildTools\VC\Tools\MSVC\${MSVC_VERSION} `
LLVM_TOOLSET_DIR=C:\BuildTools\VC\Tools\Llvm `
PATH="C:\Windows\system32;C:\Windows;C:\Program Files\PowerShell;C:\Git\cmd;C:\Git\bin;C:\Git\usr\bin;C:\Git\mingw64\bin;C:\CMake\cmake-${CMAKE_VERSION}-windows-x86_64\bin;C:\Python;C:\Nasm;C:\Nasm\nasm-${NASM_VERSION};C:\Ninja;C:\compress\zstd-v${ZSTD_VERSION}-win64;C:\vulkan-sdk\Bin;C:\NinjaTracing\ninjatracing-${NINJATRACING_VERSION}"

COPY . sample/
COPY unpack.ps1 .
WORKDIR C:\sample\tests
ENTRYPOINT ["pwsh.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "C:/unpack.ps1"]
CMD ["pwsh.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass"]