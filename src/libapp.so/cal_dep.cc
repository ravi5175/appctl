#include <libapp/libapp.hh>

using namespace libapp;

static app_list_t __app_list;
static std::vector<std::string> __done;

bool in_list(libapp::obj* app)
{
    return std::find(__app_list.begin(), __app_list.end(), app) != __app_list.end();
}
bool
is_done(const std::string& a)
{
    return std::find(__done.begin(), __done.end(), a) != __done.end();
}
app_list_t
ctl::obj::cal_dep(libapp::obj* app, bool debug)
{
    DEBUG("checking ",app->name());
    for(auto a : app->depends()) {
        if (is_done(a)) continue;
        if (is_installed(a, debug).installed) continue;

        __done.push_back(a);
        auto apd = get_app(a, debug);
        if (apd == nullptr) {
            io::info(a, " is missing required by ", app->name());
            throw err::obj(err::file_missing, a);
        }
        cal_dep(apd,debug);
        if (!is_installed(apd->name(), debug).installed && !in_list(apd))  __app_list.push_back(apd);
    }

    if (!is_installed(app->name(), debug).installed && !in_list(app))  __app_list.push_back(app);

    return __app_list;
}