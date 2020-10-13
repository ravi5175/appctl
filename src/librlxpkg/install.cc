#include <librlxpkg/librlxpkg.hh>
#include <unistd.h>
#include <stdlib.h>
#include <libgen.h>

err::obj
librlxpkg::obj::Install(conf::obj& config, bool debug)
{
    std::string pkgname = io::sprint(
        __name,"-",__ver,"-",__rel,"-x86_64.rlx"
    );

    std::string pkgdir = config.get("dir","packages","/var/cache/packages/"),    
    pkgfile = io::sprint(pkgdir,"/",pkgname),
    exc = config.get("dir","libexec","/usr/lib/appctl/exec/"),
    appctl_install_sh = exc + "/appctl-installer.sh",

    appctl_buildtool_sh = exc + "/appctl-buildtool.sh";

    if (!fs::is_exist(appctl_install_sh)) return err::obj(err::file_missing, appctl_install_sh);

    if (fs::is_exist(pkgfile)) {
        if (debug) DEBUG("Found ", pkgname, " in cache");
    } else {
        if (!fs::is_exist(appctl_buildtool_sh )) return err::obj(err::file_missing, appctl_buildtool_sh);
        char CHDIR[FILENAME_MAX];
        getcwd(CHDIR, FILENAME_MAX);

        char* rdir = dirname((char*)__rcp_file.c_str());
        if (debug) DEBUG("switching to ",rdir);
        if (chdir(rdir)) {
            return err::obj(err::file_missing, "failed to switch to directory " + std::string(rdir));
        }

        if (debug) DEBUG("compiling ",__name);

        if (debug) DEBUG("executing ", appctl_buildtool_sh, " ");
        
        if (debug) DEBUG("-- buildtool output -----------------");
        int ret = system(
            io::sprint(appctl_buildtool_sh, 
                " --specs=",config.get("default","specs","/usr/libexec/appctl/specs.sh"),
                " --src-dir=",config.get("dir","sources","/var/cache/appctl/sources"),
                " --pkg-dir=",config.get("dir","packages","/var/cache/appctl/packages"),
                " --wrk-dir=", config.get("dir","work","/var/cache/appctl/work")
            ).c_str()
        );
        if (debug) DEBUG("------------------------------------")

        chdir(CHDIR);

        if (WEXITSTATUS(ret) != 0) {
            return err::obj(err::execution, "failed to compile " + __name);
        }

        io::success("successfully compiled ",__name);
        if (!fs::is_exist(pkgfile)) {
            return err::obj(err::execution,"but failed to generate package file "+pkgfile);
        }
    }

    io::process("Installing ",__name);
    if (debug) DEBUG("package file ", pkgfile);

    if (debug) DEBUG("-- installer output -----------------");

    int ret = system(
        io::sprint(appctl_install_sh, 
            " --specs=",config.get("default","specs","/usr/libexec/appctl/specs.sh"),
            " --root-dir=",config.get("dir","roots","/"),
            " --data-dir=",config.get("dir","data","/var/lib/app/index"),
            " ", pkgfile, (debug ? " " : " &>/dev/null")
        ).c_str()
    );

    if (debug) DEBUG("------------------------------------")

    switch (WEXITSTATUS(ret)) 
    {
        case 112:
            return err::obj(err::execution, __name + " already installed");
        
        case 0:
            io::success("installed ", __name);
            return err::obj(0);
        
        default:
            return err::obj(WEXITSTATUS(ret), "failed to install " +__name);
    }

    return err::obj(WEXITSTATUS(ret));
}