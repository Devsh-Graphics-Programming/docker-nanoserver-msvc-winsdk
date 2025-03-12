#include "nanomsvc.hpp"

#include <filesystem>
#include <iomanip>
#include <iostream>
#include <vector>
#include <Windows.h>

NanoMSVC::NanoMSVC() {}
NanoMSVC::~NanoMSVC() {}

void NanoMSVC::printCurrentPath()
{
    try 
    {
        std::cout << "Current path: " << std::filesystem::current_path() << std::endl;
    }
    catch (const std::exception& e) 
    {
        std::cerr << "Failed to retrieve current path: " << e.what() << std::endl;
        exit(-1);
    }
}

void NanoMSVC::printWindowsVersion()
{
    try 
    {
        const auto system = L"kernel32.dll";
        DWORD dummy;
        const auto cbInfo = ::GetFileVersionInfoSizeExW(FILE_VER_GET_NEUTRAL, system, &dummy);
        std::vector<char> buffer(cbInfo);
        ::GetFileVersionInfoExW(FILE_VER_GET_NEUTRAL, system, dummy, buffer.size(), &buffer[0]);
        void* p = nullptr;
        UINT size = 0;
        ::VerQueryValueW(buffer.data(), L"\\", &p, &size);

        if(size < sizeof(VS_FIXEDFILEINFO) or not p)
            throw std::runtime_error("Internal error while retrieving Windows build info.");

        auto pFixed = static_cast<const VS_FIXEDFILEINFO*>(p);
        std::cout << "Windows build: " << HIWORD(pFixed->dwFileVersionMS) << '.'
            << LOWORD(pFixed->dwFileVersionMS) << '.'
            << HIWORD(pFixed->dwFileVersionLS) << '.'
            << LOWORD(pFixed->dwFileVersionLS) << '\n';
    }
    catch (const std::exception& e) 
    {
        std::cerr << e.what() << std::endl;
        exit(-1);
    }
}