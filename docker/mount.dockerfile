# escape=`
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022

ARG CMAKE_WINDOWS_KITS_10_DIR="C:\mount\windowssdk"
ARG WINDOWS_SDK_VERSION="10.0.22621.0"
ARG MSVC_TOOLSET_DIR="C:\mount\msvc"
ARG CMAKE_VERSION="3.30.0"
ARG NINJA_VERSION="1.12.1"
ARG NASM_VERSION="2.16.03"

ENV CMAKE_WINDOWS_KITS_10_DIR=${CMAKE_WINDOWS_KITS_10_DIR}
ENV WINDOWS_SDK_VERSION=${WINDOWS_SDK_VERSION}
ENV MSVC_TOOLSET_DIR=${MSVC_TOOLSET_DIR}
ENV CMAKE_VERSION=${CMAKE_VERSION}
ENV NINJA_VERSION=${NINJA_VERSION}
ENV NASM_VERSION=${NASM_VERSION}

RUN mkdir C:\Temp && cd C:\Temp `
&& curl -SL --output cmake.zip https://github.com/Kitware/CMake/releases/download/v%CMAKE_VERSION%/cmake-%CMAKE_VERSION%-windows-x86_64.zip `
&& mkdir "C:\CMake" `
&& tar -xf cmake.zip -C "C:\CMake" `
&& del /q cmake.zip

RUN cd C:\Temp `
&& curl -SL --output nasm.zip https://www.nasm.us/pub/nasm/releasebuilds/%NASM_VERSION%/win64/nasm-%NASM_VERSION%-win64.zip `
&& mkdir "C:\nasm" `
&& tar -xf nasm.zip -C "C:\nasm" `
&& del /q nasm.zip

RUN cd C:\Temp `
&& curl -SL --output ninja.zip https://github.com/ninja-build/ninja/releases/download/v%NINJA_VERSION%/ninja-win.zip `
&& mkdir "C:\ninja" `
&& tar -xf ninja.zip -C "C:\ninja" `
&& del /q ninja.zip

RUN setx PATH "C:\ninja;C:\CMake\cmake-%CMAKE_VERSION%-windows-x86_64\bin;C:\nasm\nasm-%NASM_VERSION%;%MSVC_TOOLSET_DIR%\bin\Hostx64\x64;%PATH%"

