#ifndef NANO_MSVC_HPP_INCLUDED
#define NANO_MSVC_HPP_INCLUDED

#ifndef _MSC_VER
#error "_MSC_VER not defined!"
#endif

#ifdef NANO_SHARED_BUILD
    #if defined(NANO_BUILDING_LIB)
        #define NANO_API __declspec(dllexport)
    #else
        #define NANO_API __declspec(dllimport)
    #endif
#else
    #define NANO_API
#endif

class NANO_API NanoMSVC 
{
public: 
    NanoMSVC();
    ~NanoMSVC();

    void printCurrentPath();
    void printWindowsVersion();
};

#endif // NANO_MSVC_HPP_INCLUDED