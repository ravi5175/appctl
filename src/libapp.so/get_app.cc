#include <libapp/libapp.hh>

using namespace libapp;

libapp::obj*
ctl::obj::get_app(const std::string & app_id, bool debug)
{
    if (fs::is_exist(app_id)) {
        if (debug) io::colored_title(color::blue,"DEBUG",app_id + " exist");
        if (app_id.length() >= 6) {
            if (app_id.substr(app_id.length() - 6, 6) == "recipe") {
                io::colored_title(color::blue,"DEBUG",app_id + " found as recipe");
                return (modules["recipe"](app_id));
            }
        }
        
        if (debug) io::colored_title(color::blue,"DEBUG",app_id + " unsupported file " + app_id.substr(app_id.length() - 6, 6));
        throw err::obj(-176, "unsupported file "+ app_id);
    }

    std::string rcppath = config.get("dir","recipes","/var/cache/recipes");
    std::stringstream ss(config.get("default","repo","core"));
    std::string repo;
    while (ss >> repo) {
        std::string rcp_ = rcppath + "/" + repo + "/" + app_id + "/recipe";
        if (debug) io::colored_title(color::blue,"DEBUG",app_id + " searching recipe " + rcp_);
        if (fs::is_exist(rcp_)) {
            return (modules["recipe"](rcp_));
        }
    }

    //throw err::obj(-176, "unable to find "+ app_id + " in repository");
    return nullptr;
}