#include <libapp/libapp.hh>


using namespace libapp;

err::obj
ctl::obj::Install(const std::string & app, bool debug)
{   
    try {
        auto app_ptr = get_app(app, debug);
        if (app_ptr == nullptr) return err::obj(err::file_missing, "failed to get " +app);

        auto app_data = is_installed(app, debug);
        if (app_data.installed) return err::obj(112, app + " is already installed");
        
        return app_ptr->Install(config, debug);
    } catch (err::obj e) {
        switch (e.status()) {
            case err::file_missing: 
                io::error("[FileMissing] ",e.mesg());
                break;
            
            case err::execution:
                io::error("[ExecutionError] ", e.mesg());
                break;

            default:
                io::error("[UnknownError] ",e.mesg());
                break;
        }

        return e;
    }
    return err::obj(0);
}

