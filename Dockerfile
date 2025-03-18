# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS buildtools

ARG WINDOWS_11_SDK_VERSION="22621"
ARG VC_VERSION="14.42.17.12"
ARG MSVC_VERSION="14.42.34433"

ENV WINDOWS_11_SDK_VERSION=${WINDOWS_11_SDK_VERSION} VC_VERSION=${VC_VERSION} MSVC_VERSION=${MSVC_VERSION} BUILD_TOOLS_DIR="C:\artifacts"

RUN mkdir C:\Temp && cd C:\Temp `
&& curl -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe `
&& (start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
--remove Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
--add Microsoft.VisualStudio.Component.VC.%VC_VERSION%.x86.x64 `
--add Microsoft.VisualStudio.Component.Windows11SDK.%WINDOWS_11_SDK_VERSION% `
--installPath %BUILD_TOOLS_DIR% `
|| IF "%ERRORLEVEL%"=="3010" EXIT 0) `
&& dir %BUILD_TOOLS_DIR%\VC\Tools\MSVC `
&& if exist %BUILD_TOOLS_DIR%\VC\Tools\MSVC\%MSVC_VERSION% ( `
for /d %i in (%BUILD_TOOLS_DIR%\VC\Tools\MSVC\*) do if /I not "%i"=="%BUILD_TOOLS_DIR%\VC\Tools\MSVC\%MSVC_VERSION%" rd /s /q "%i" `
) else ( `
echo "Error: Expected MSVC version directory %MSVC_VERSION% does not exist!" && exit /b 1 `
)

RUN (echo { "WINDOWS_SDK_VERSION": "10.0.%WINDOWS_11_SDK_VERSION%.0", "VC_VERSION": "%VC_VERSION%", "MSVC_VERSION": "%MSVC_VERSION%" }) > %BUILD_TOOLS_DIR%\env.json

FROM mcr.microsoft.com/windows/nanoserver:ltsc2022 AS nano

SHELL ["cmd", "/S", "/C"]

ARG BUILD_TOOLS_DIR="C:\BuildTools"
ARG WINDOWS_KITS_10_DIR="C:\WindowsKits10SDK"
ARG CMAKE_VERSION=3.31.0
ARG CMAKE_DIR="C:\CMake"
ARG PYTHON_VERSION=3.11.0
ARG PYTHON_DIR="C:\Python"
ARG NINJA_VERSION=1.12.1
ARG NINJA_DIR="C:\Ninja"
ARG NASM_VERSION=2.16.03
ARG NASM_DIR="C:\Nasm"

ENV CMAKE_WINDOWS_KITS_10_DIR=${WINDOWS_KITS_10_DIR} BUILD_TOOLS_DIR=${BUILD_TOOLS_DIR} `
CMAKE_VERSION=${CMAKE_VERSION} CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-windows-x86_64.zip CMAKE_DIR=${CMAKE_DIR} `
PYTHON_VERSION=${PYTHON_VERSION} PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-embed-amd64.zip PYTHON_DIR=${PYTHON_DIR} `
NINJA_VERSION=${NINJA_VERSION} NINJA_URL=https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-win.zip NINJA_DIR=${NINJA_DIR} `
NASM_VERSION=${NASM_VERSION} NASM_URL=https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/win64/nasm-${NASM_VERSION}-win64.zip NASM_DIR=${NASM_DIR}

RUN mkdir C:\Temp && cd C:\Temp && mkdir "%CMAKE_DIR%" && curl -SL --output cmake.zip %CMAKE_URL% && tar -xf cmake.zip -C "%CMAKE_DIR%" && del cmake.zip
RUN cd C:\Temp && mkdir "%PYTHON_DIR%" && curl -SL --output python.zip %PYTHON_URL% && tar -xf python.zip -C "%PYTHON_DIR%" && del python.zip
RUN cd C:\Temp && mkdir "%NINJA_DIR%" && curl -SL --output ninja.zip %NINJA_URL% && tar -xf ninja.zip -C "%NINJA_DIR%" && del ninja.zip
RUN cd C:\Temp && mkdir "%NASM_DIR%" && curl -SL --output nasm.zip %NASM_URL% && tar -xf nasm.zip -C "%NASM_DIR%" && del nasm.zip

RUN echo "test"
COPY --from=buildtools ["C:/artifacts", "${BUILD_TOOLS_DIR}"]
RUN cd %BUILD_TOOLS_DIR% && "%PYTHON_DIR%\python.exe" -c "import json, os; env=json.load(open('./env.json')); [os.system(f'setx {k} \"{v}\"') for k,v in env.items()]" `
&& setx PATH "%CMAKE_DIR%\cmake-%CMAKE_VERSION%-windows-x86_64\bin;%PYTHON_DIR%;%NINJA_DIR%;%NASM_DIR%\nasm-%NASM_VERSION%;%PATH%" `
&& setx MSVC_TOOLSET_DIR "%BUILD_TOOLS_DIR%\VC\Tools\MSVC\%MSVC_VERSION%"
COPY --from=buildtools ["C:/Program Files (x86)/Windows Kits/10", "${WINDOWS_KITS_10_DIR}"]

ENTRYPOINT ["cmd"]
