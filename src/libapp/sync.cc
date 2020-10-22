#include <librlxpkg/librlxpkg.hh>
#include <unistd.h>
#include <stdlib.h>
#include <libgen.h>
#include <curl/curl.h>
#include <iomanip>
#include <openssl/md5.h>

using namespace libapp;

std::string
libapp::hash(const std::string &fname)
{
    char buff[BUFSIZ];
    uint8_t digest[MD5_DIGEST_LENGTH];
    std::stringstream ss;
    std::string md5string;

    std::ifstream ifs(fname, std::ifstream::binary);
    MD5_CTX __ctx;
    MD5_Init(&__ctx);

    while(ifs.good()) {
        ifs.read(buff, BUFSIZ);
        MD5_Update(&__ctx, buff, ifs.gcount());
    }
    ifs.close();

    int res = MD5_Final(digest, &__ctx);

    if (res == 0)
        throw err::obj(111);

    ss << std::hex << std::uppercase << std::setfill('0');

    for(uint8_t uc : digest)
        ss << std::setw(2) << (int)uc;

    return ss.str();
}



size_t write_data(void* ptr, size_t size, size_t nmemb, FILE* fptr)
{
    return fwrite(ptr, size, nmemb, fptr);
}

err::obj
ctl::obj::download_file(const std::string& url, const std::string& file, bool progress)
{
    CURL* curl;
    FILE* fp;
    CURLcode resp;
    curl = curl_easy_init();
    if (curl) {
        fp = fopen(file.c_str(), "wb");
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
        if (progress) {
            curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
        }
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
        resp = curl_easy_perform(curl);
        fclose(fp);
        long respcode;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &respcode);
        if (resp != CURLE_OK) {
            return err::obj(respcode, "failed to download file from url " + url);
        } else {
            return err::obj(respcode);
        }
        curl_easy_cleanup(curl);

    }
    return err::obj(0x12, "failed to init curl, download failed");
}

err::obj
ctl::obj::sync_modules(bool debug)
{
    for(auto a : modules)
    {
        io::process("checking updates for ",a.first);
        auto s = a.second(config);
        auto e = s->Sync(config, debug);
        delete s;
    }
    return err::obj(0);
}