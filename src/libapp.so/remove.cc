#include <libapp/libapp.hh>


using namespace libapp;

err::obj
ctl::obj::Remove(const std::string & app, bool debug)
{   
    try {
        auto app_data = is_installed(app, debug);
        if (!app_data.installed) return err::obj(0x154, app + " is not already installed");

        auto data_dir = config.get("dir","data",DATA_DIR);
        auto app_data_dir = io::sprint(data_dir,"/",app);
        if (!fs::is_exist(app_data_dir + "/info")) {
            if (debug) io::info("missing app registeries ", app_data_dir);
            return err::obj(err::file_missing, app_data_dir + "/info");
        }

        auto exc = config.get("dir","libexec",LIBEXEC_DIR),
        appctl_remove_sh = exc + "/appctl-remove.sh";

        int ret = system(
            io::sprint(appctl_remove_sh, 
                " --root-dir=",config.get("dir","roots",ROOT_DIR),
                " --data-dir=",config.get("dir","data",DATA_DIR),
                " ", app
            ).c_str()
        );


        if (WEXITSTATUS(ret) != 0) return err::obj(err::execution, "failed to execute " + appctl_remove_sh);

        return err::obj(0);


    } catch(err::obj e) {
        io::error(e.mesg());
        return e.status();
    }

    return err::obj(0x111);
}