#ifndef __PKGCTL_RECIPE_HH__
#define __PKGCTL_RECIPE_HH__

#include <libapp/libapp.hh>
#include <rlx/rlx.hh>

using namespace rlx;

namespace librlxpkg {
    class obj : public libapp::obj {
        private:
            std::string __rcp_file;
        public:
            obj(const std::string&);

            std::string type() { return "recipe"; }
            err::obj Install(conf::obj& config, bool debug = false);
            err::obj Remove(conf::obj& config, bool debug = false);
    };
}

#endif