# syntax=docker/dockerfile:1
# escape=`

# ---------------- GLOBAL VARS ----------------
ARG CMAKE_VERSION=3.31.0
ARG PYTHON_VERSION=3.13.2
ARG NINJA_VERSION=1.12.1
ARG NASM_VERSION=2.16.03
ARG GIT_VERSION=2.48.1
ARG WINDOWS_11_SDK_VERSION=22621
ARG WINDOWS_SDK_VERSION=10.0.${WINDOWS_11_SDK_VERSION}.0
ARG VC_VERSION=14.42.17.12
ARG MSVC_VERSION=14.42.34433

ARG IMPL_ARTIFACTS_DIR="C:\artifacts"
ARG IMPL_NANO_BASE=mcr.microsoft.com/powershell
ARG IMPL_NANO_TAG=lts-nanoserver-ltsc2022

# ---------------- BUILD TOOLS ----------------
FROM mcr.microsoft.com/windows/servercore:ltsc2022 as buildtools

ARG WINDOWS_11_SDK_VERSION
ARG VC_VERSION
ARG MSVC_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN mkdir C:\Temp && cd C:\Temp `
&& curl -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe `
&& (start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
--remove Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.x86.x64 `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.ATL `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.MFC `
--add Microsoft.VisualStudio.Component.Windows11SDK.%WINDOWS_11_SDK_VERSION% `
--add Microsoft.VisualCpp.DIA.SDK `
--installPath %IMPL_ARTIFACTS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0) `
&& dir %IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC `
&& if exist %IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\%MSVC_VERSION% ( `
for /d %i in (%IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\*) do if /I not "%i"=="%IMPL_ARTIFACTS_DIR%\VC\Tools\MSVC\%MSVC_VERSION%" rd /s /q "%i" `
) else ( `
echo "Error: Expected MSVC version directory %MSVC_VERSION% does not exist!" && exit /b 1 `
)

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

# ---------------- NASM ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG} as nasm
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ARG NASM_VERSION
ARG IMPL_ARTIFACTS_DIR

RUN Write-Host "Installing NASM $env:NASM_VERSION" ; `
New-Item -ItemType Directory -Force -Path C:\Temp, $env:IMPL_ARTIFACTS_DIR ; `
Invoke-WebRequest -Uri "https://www.nasm.us/pub/nasm/releasebuilds/$env:NASM_VERSION/win64/nasm-$env:NASM_VERSION-win64.zip" -OutFile C:\Temp\nasm.zip ; `
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

# ---------------- FINAL IMAGE ----------------
FROM ${IMPL_NANO_BASE}:${IMPL_NANO_TAG}
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
USER ContainerAdministrator

ARG IMPL_ARTIFACTS_DIR
COPY --link --from=buildtools ["C:/Program Files (x86)/Windows Kits/10", "C:/WindowsKits10SDK"]
COPY --link --from=buildtools ["${IMPL_ARTIFACTS_DIR}", "C:/BuildTools"]
COPY --link --from=cmake ["${IMPL_ARTIFACTS_DIR}", "C:/CMake"]
COPY --link --from=python ["${IMPL_ARTIFACTS_DIR}", "C:/Python"]
COPY --link --from=ninja ["${IMPL_ARTIFACTS_DIR}", "C:/Ninja"]
COPY --link --from=nasm ["${IMPL_ARTIFACTS_DIR}", "C:/Nasm"]
COPY --link --from=git ["${IMPL_ARTIFACTS_DIR}", "C:/Git"]

COPY redist/msvc.ps1 msvc.ps1
ARG MSVC_VERSION
RUN $REDIST_PATH = 'C:/BuildTools/VC/Redist/MSVC/' + $env:MSVC_VERSION ; pwsh -File msvc.ps1 -RedistPath "$REDIST_PATH" -Arch x64

ARG CMAKE_VERSION
ARG PYTHON_VERSION
ARG NINJA_VERSION
ARG NASM_VERSION
ARG GIT_VERSION
ARG WINDOWS_11_SDK_VERSION
ARG WINDOWS_SDK_VERSION
ARG VC_VERSION


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
MSVC_TOOLSET_DIR=C:\BuildTools\VC\Tools\MSVC\${MSVC_VERSION} `
PATH="C:\Windows\system32;C:\Windows;C:\Program Files\PowerShell;C:\Git\cmd;C:\Git\bin;C:\Git\usr\bin;C:\Git\mingw64\bin;C:\CMake\cmake-${CMAKE_VERSION}-windows-x86_64\bin;C:\Python;C:\Nasm;C:\Nasm\nasm-${NASM_VERSION};C:\Ninja;"
RUN git config --global --add safe.directory '*'

CMD ["pwsh.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass"]