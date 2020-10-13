#include <librlxpkg/librlxpkg.hh>
#include <fstream>

using namespace librlxpkg;

obj::obj(const std::string& __rcp_file)
: __rcp_file(__rcp_file)
{
    std::ifstream fptr(__rcp_file);
    if (!fptr.good()) {
        throw err::obj(err::file_missing, __rcp_file);
    }

    std::string __line;
    std::string __var, __val;
    while (std::getline(fptr, __line)) {
        if (__line.size() == 0) continue;
        if (__line[0] == '#') {
            uint64_t rdx = __line.find_first_of(':');
            if (rdx == std::string::npos) continue;
            __var = __line.substr(2, rdx - 2);
            __val = __line.substr((rdx + 2), __line.size() - (rdx + 2));
        } else {
            uint64_t rdx = __line.find_first_of('=');
            if (rdx == std::string::npos) continue;

            __var = __line.substr(0, rdx);
            __val = __line.substr(rdx + 1, __line.size() - (rdx + 1));
        }

        if (__var == "name") __name = __val;
        else if (__var == "version") __ver = __val;
        else if (__var == "release") __rel = atoi(__val.c_str()); 
        else if (__var == "Description") __desc = __val;
        else if (__var == "Depends on") {
            std::stringstream ss(__val);
            std::string l;
            while(ss >> l) {
                __depends.push_back(l);
            }
        }
    }

}

extern "C" obj* module(std::string __a)
{
    return new obj(__a);
}