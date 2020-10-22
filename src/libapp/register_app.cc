#include <libapp/libapp.hh>

using namespace libapp;

err::obj
ctl::obj::register_data(app_db_t app_db)
{
    auto data_dir = config.get("dir","data","/var/lib/app/index");
    auto app_data_dir = data_dir + "/" + app_db.name;
    auto app_data_file = app_data_dir + "/info";

    if (fs::is_exist(app_data_file))
        return err::obj(err::already_exist, app_data_file + " is already exist");

    if (!fs::is_exist(app_data_dir))
        fs::make_dir(app_data_dir);

    std::ofstream fptr(app_data_file);
    if (!fptr.good())
        return err::obj(0x123, "failed to open data file for write - " + app_data_file);

    io::sprint(
        "name: ", app_db.name,"\n",
        "version: ", app_db.version,"\n",
        "release: ",app_db.release,"\n"

    );
}