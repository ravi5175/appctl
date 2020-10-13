#include <libapp/libapp.hh>
#include <dlfcn.h>

using namespace libapp;

std::vector<std::string>
ctl::obj::list_files(app_db_t& app_data, bool debug)
{
    std::vector<std::string> files_list;
    if (!app_data.installed) return files_list;

    auto files_f = config.get("dir","data","/var/lib/app/index") + app_data.name + "/files";

    std::ifstream fptr(files_f);
    if (!fptr.good()) {
        DEBUG("failed to load ",files_f);
        return files_list;
    }
    std::string line;
    while(std::getline(fptr,line)) {
        if (line.substr(0,6) == ".data/") continue;
        files_list.push_back(line);
    }

    return files_list;
}

app_db_t
ctl::obj::is_installed(const std::string& app_name, bool debug)
{
    auto data_dir = config.get("dir","data","/var/lib/app/index");
    DEBUG("checking in ",data_dir);

    auto app_data_dir = data_dir+"/"+app_name;
    if (!fs::is_exist(app_data_dir+"/info")) {
        DEBUG(data_dir+"/"+app_name+"/info file not found");
        return app_db_t{};
    }

    DEBUG("found ",app_data_dir);
    app_db_t app_data;

    app_data.installed = true;

    std::ifstream fptr(app_data_dir+"/info");
    if (!fptr.good()) {
        DEBUG("failed to open ",app_data_dir +"/info");
        app_data.installed = false;
        return app_data;
    }

    std::string line;
    std::string depends = "";

    while(std::getline(fptr, line)) {
        if (line.size() == 0) continue;
        size_t rdx = line.find_first_of(':');
        if (rdx == std::string::npos) continue;

        auto var = line.substr(0, rdx);
        auto val = line.substr(rdx + 2 , line.length() - (rdx + 2));

        if (var == "name") app_data.name = val;
        else if (var == "version") app_data.version = val;
        else if (var == "release") app_data.release = val;
        else if (var == "description" ) app_data.description = val;
        else if (var == "depends") depends = val;
        else if (var == "size") app_data.size = val;
        else if (var == "build") app_data.build_time = val;
        else if (var == "installed") app_data.installed_time = val;
    }

    std::stringstream ss(depends);
    std::string l;

    while( ss >> l) {
        app_data.depends.push_back(l);
    }

    fptr.close();

    return app_data;
}

void
ctl::obj::load_modules()
{
    for(auto a : config.sections) {
        if (a.first == "modules") {
            for(auto m : a.second) {
                load_modules(m.first, m.second);
            }
        }
    }
}

void
ctl::obj::load_modules(std::string id, std::string path)
{
    void *handler = dlopen(path.c_str(), RTLD_LAZY);
    
    if (handler == nullptr) {
        io::error("failed to load module ", id, " from ", path);
        return;
    }
    module_t mod = (module_t) dlsym(handler, "module");
    if (mod == nullptr) {
        io::error("invalid module ", id, " from ", path);
        return;
    }

    modules[id] = mod;

}