#include <librlxpkg/librlxpkg.hh>

using namespace librlxpkg;

err::obj
obj::Remove(conf::obj& conf, bool debug)
{
    auto data_dir = conf.get("dir","data","/var/lib/app/index/");
    auto app_data_dir = io::sprint(data_dir,"/",__name);
    if (!fs::is_exist(app_data_dir + "/info")) {
        if (debug) io::info("missing app registeries ", app_data_dir);
        return err::obj(err::file_missing, app_data_dir + "/info");
    }

    auto exc = conf.get("dir","libexec","/usr/lib/appctl/exec/"),
    appctl_remove_sh = exc + "/appctl-remove.sh";

    int ret = system(
        io::sprint(appctl_remove_sh, 
            " --root-dir=",conf.get("default","specs","/usr/libexec/appctl/specs.sh")
        ).c_str()
    );


    if (WEXITSTATUS(ret) != 0) return err::obj(err::execution, "failed to execute " + appctl_remove_sh);

    return err::obj(0);
}