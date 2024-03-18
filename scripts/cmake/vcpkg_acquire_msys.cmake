# Mirror list from https://github.com/msys2/MSYS2-packages/blob/master/pacman-mirrors/mirrorlist.msys
# Sourceforge is not used because it does not keep older package versions
set(Z_VCPKG_ACQUIRE_MSYS_MIRRORS
    "https://www2.futureware.at/~nickoe/msys2-mirror/"
    "https://mirror.yandex.ru/mirrors/msys2/"
    "https://mirrors.tuna.tsinghua.edu.cn/msys2/"
    "https://mirrors.ustc.edu.cn/msys2/"
    "https://mirror.bit.edu.cn/msys2/"
    "https://mirror.selfnet.de/msys2/"
    "https://mirrors.sjtug.sjtu.edu.cn/msys2/"
)

function(z_vcpkg_acquire_msys_download_package out_archive)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "" "URL;SHA512;FILENAME" "")
    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_download_package passed extra args: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    set(all_urls "${arg_URL}")

    foreach(mirror IN LISTS Z_VCPKG_ACQUIRE_MSYS_MIRRORS)
        string(REPLACE "https://repo.msys2.org/" "${mirror}" mirror_url "${arg_URL}")
        list(APPEND all_urls "${mirror_url}")
    endforeach()

    vcpkg_download_distfile(msys_archive
        URLS ${all_urls}
        SHA512 "${arg_SHA512}"
        FILENAME "msys-${arg_FILENAME}"
        QUIET
    )
    set("${out_archive}" "${msys_archive}" PARENT_SCOPE)
endfunction()

# writes to the following variables in parent scope:
#   - Z_VCPKG_MSYS_ARCHIVES
#   - Z_VCPKG_MSYS_TOTAL_HASH
#   - Z_VCPKG_MSYS_PACKAGES
function(z_vcpkg_acquire_msys_declare_package)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAME;URL;SHA512" "DEPS")

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_declare_package passed extra args: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    foreach(required_arg IN ITEMS URL SHA512)
        if(NOT DEFINED arg_${required_arg})
            message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_declare_package requires argument: ${required_arg}")
        endif()
    endforeach()

    if(NOT arg_URL MATCHES [[^https://repo\.msys2\.org/.*/(([^-]+(-[^0-9][^-]*)*)-.+\.pkg\.tar\.(xz|zst))$]])
        message(FATAL_ERROR "internal error: regex does not match supplied URL to vcpkg_acquire_msys: ${arg_URL}")
    endif()

    set(filename "${CMAKE_MATCH_1}")
    if(NOT DEFINED arg_NAME)
        set(arg_NAME "${CMAKE_MATCH_2}")
    endif()

    if("${arg_NAME}" IN_LIST Z_VCPKG_MSYS_PACKAGES OR arg_Z_ALL_PACKAGES)
        list(REMOVE_ITEM Z_VCPKG_MSYS_PACKAGES "${arg_NAME}")
        list(APPEND Z_VCPKG_MSYS_PACKAGES ${arg_DEPS})
        set(Z_VCPKG_MSYS_PACKAGES "${Z_VCPKG_MSYS_PACKAGES}" PARENT_SCOPE)

        z_vcpkg_acquire_msys_download_package(archive
            URL "${arg_URL}"
            SHA512 "${arg_SHA512}"
            FILENAME "${filename}"
        )

        list(APPEND Z_VCPKG_MSYS_ARCHIVES "${archive}")
        set(Z_VCPKG_MSYS_ARCHIVES "${Z_VCPKG_MSYS_ARCHIVES}" PARENT_SCOPE)
        string(APPEND Z_VCPKG_MSYS_TOTAL_HASH "${arg_SHA512}")
        set(Z_VCPKG_MSYS_TOTAL_HASH "${Z_VCPKG_MSYS_TOTAL_HASH}" PARENT_SCOPE)
    endif()
endfunction()

function(vcpkg_acquire_msys out_msys_root)
    cmake_parse_arguments(PARSE_ARGV 1 "arg"
        "NO_DEFAULT_PACKAGES;Z_ALL_PACKAGES"
        ""
        "PACKAGES;DIRECT_PACKAGES"
    )

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(WARNING "vcpkg_acquire_msys was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    set(Z_VCPKG_MSYS_TOTAL_HASH)
    set(Z_VCPKG_MSYS_ARCHIVES)

    set(Z_VCPKG_MSYS_PACKAGES "${arg_PACKAGES}")

    if(NOT arg_NO_DEFAULT_PACKAGES)
        list(APPEND Z_VCPKG_MSYS_PACKAGES bash coreutils sed grep gawk gzip diffutils make pkg-config)
    endif()

    if(DEFINED arg_DIRECT_PACKAGES AND NOT arg_DIRECT_PACKAGES STREQUAL "")
        list(LENGTH arg_DIRECT_PACKAGES direct_packages_length)
        math(EXPR direct_packages_parity "${direct_packages_length} % 2")
        math(EXPR direct_packages_number "${direct_packages_length} / 2")
        math(EXPR direct_packages_last "${direct_packages_number} - 1")

        if(direct_packages_parity EQUAL 1)
            message(FATAL_ERROR "vcpkg_acquire_msys(... DIRECT_PACKAGES ...) requires exactly pairs of URL/SHA512")
        endif()

        # direct_packages_last > direct_packages_number - 1 > 0 - 1 >= 0, so this is fine
        foreach(index RANGE "${direct_packages_last}")
            math(EXPR url_index "${index} * 2")
            math(EXPR sha512_index "${url_index} + 1")
            list(GET arg_DIRECT_PACKAGES "${url_index}" url)
            list(GET arg_DIRECT_PACKAGES "${sha512_index}" sha512)

            get_filename_component(filename "${url}" NAME)
            z_vcpkg_acquire_msys_download_package(archive
                URL "${url}"
                SHA512 "${sha512}"
                FILENAME "${filename}"
            )
            list(APPEND Z_VCPKG_MSYS_ARCHIVES "${archive}")
            string(APPEND Z_VCPKG_MSYS_TOTAL_HASH "${sha512}")
        endforeach()
    endif()

    # To add new entries, use https://packages.msys2.org/package/$PACKAGE?repo=msys
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/unzip-6.0-2-x86_64.pkg.tar.xz"
        SHA512 b8a1e0ce6deff26939cb46267f80ada0a623b7d782e80873cea3d388b4dc3a1053b14d7565b31f70bc904bf66f66ab58ccc1cd6bfa677065de1f279dd331afb9
        DEPS libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libbz2-1.0.8-3-x86_64.pkg.tar.zst"
        SHA512 955420cabd45a02f431f5b685d8dc8acbd07a8dcdda5fdf8b9de37d3ab02d427bdb0a6d8b67c448e307f21094e405e916fd37a8e9805abd03610f45c02d64b9e
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/patch-2.7.6-1-x86_64.pkg.tar.xz"
        SHA512 04d06b9d5479f129f56e8290e0afe25217ffa457ec7bed3e576df08d4a85effd80d6e0ad82bd7541043100799b608a64da3c8f535f8ea173d326da6194902e8c
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gzip-1.12-1-x86_64.pkg.tar.zst"
        SHA512 207c084d08bf2d911c33b8699ea71f606420c94420a2732a916fa17b4f975d7f1ff319e7d5736bf3fdd789ded606cfc087b9bfa71e29aa5812e33931831824d6
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/texinfo-6.8-3-x86_64.pkg.tar.zst"
        SHA512 5cc16d3b3c3b9859fe61233fa27f2146526e2b4d6e626814d283b35bfd77bc15eb4ffaec00bde6c10df93466d9155a06854a7ecf2e0d9af746dd56c4d88d192e
        DEPS bash perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/bash-5.1.016-1-x86_64.pkg.tar.zst"
        SHA512 ddaca51201307495f9251c5ed54d7d4c8362ada0d22dbd69ea2fe0a1ba135f11c46907b289ede407f010502040cf2252fa4575c68661eba2e7d6417d1965d89c
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/autoconf-2.71-3-any.pkg.tar.zst"
        SHA512 f639deac9b2191c2096584cf374103bbb1e9d2476dd0ebec94b1e80da59be25b88e362ac5280487a89f0bb0ed57f99b66e314f36b7de9cda03c0974806a3a4e2
        DEPS m4 perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/autoconf-archive-2019.01.06-1-any.pkg.tar.xz"
        SHA512 77540d3d3644d94a52ade1f5db27b7b4b5910bbcd6995195d511378ca6d394a1dd8d606d57161c744699e6c63c5e55dfe6e8664d032cc8c650af9fdbb2db08b0
        DEPS m4 perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/diffutils-3.8-3-x86_64.pkg.tar.zst"
        SHA512 e22015af9a4c4e6e604711adcd4a0941114793f7490a3b9f30e7fb04fd3f596a354bd0a9b655e6b8e083cbd1b462c1fdcdcd72758e0c1e759e1daf8c25889302
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/binutils-2.37-5-x86_64.pkg.tar.zst"
        SHA512 32129cf97b53d5f6d87b42f17643e9dfc2e41b9ab4e4dfdc10e69725a9349bb25e57e0937e7504798cae91f7a88e0f4f5814e9f6a021bb68779d023176d2f311
        DEPS libiconv libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libtool-2.4.7-3-x86_64.pkg.tar.zst"
        SHA512 a202ddaefa93d8a4b15431dc514e3a6200c47275c5a0027c09cc32b28bc079b1b9a93d5ef65adafdc9aba5f76a42f3303b1492106ddf72e67f1801ebfe6d02cc
        DEPS grep sed coreutils file findutils
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/file-5.41-4-x86_64.pkg.tar.zst"
        SHA512 2d51ca6bed8cf5b4d4922b351369e7b44187af3131b764f07f9258f730b724432e4bbfdb37b3e0a7da56fc642c9232549838ec49f3a4ff605aacb3ea2d8c2bd9
        DEPS gcc-libs zlib libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/zlib-1.2.12-2-x86_64.pkg.tar.zst"
        SHA512 5470a5da1acaf1e5639c5c1f396ca5dfdef58cb652168b04291c6c1a6cd90c6427f7d5b8e6620ad110e2c8ad1fe0d62a94e385a8d60bf41022754994b9bf39eb
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/bzip2-1.0.8-3-x86_64.pkg.tar.zst"
        SHA512 9d03e8fc5677dd1386454bd27a683667e829ad5b1b87fc0879027920b2e79b25a2d773ab2556cd29844b18dd25b26fef5a57bf89e35ca318e39443dcaf0ca3ba
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libbz2-1.0.8-3-x86_64.pkg.tar.zst"
        SHA512 955420cabd45a02f431f5b685d8dc8acbd07a8dcdda5fdf8b9de37d3ab02d427bdb0a6d8b67c448e307f21094e405e916fd37a8e9805abd03610f45c02d64b9e
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/coreutils-8.32-2-x86_64.pkg.tar.zst"
        SHA512 0719e8d3683711453ff77496cad11583e877ea52806e5ea3f470444705705db20a8a9fe99987166b02c6bd240c06c7d86faa979a7bc5536c9c804d800b60b7be
        DEPS libiconv libintl gmp
    )
    z_vcpkg_acquire_msys_declare_package( #grep-3.6-1-x86_64.pkg.tar.zst.sig
        URL "https://repo.msys2.org/msys/x86_64/grep-1~3.0-6-x86_64.pkg.tar.zst"
        SHA512 79b4c652082db04c2ca8a46ed43a86d74c47112932802b7c463469d2b73e731003adb1daf06b08cf75dc1087f0e2cdfa6fec0e8386ada47714b4cff8a2d841e1
        DEPS libiconv libintl libpcre
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/sed-4.8-3-x86_64.pkg.tar.zst"
        SHA512 16ad4aa3c62770a90e66035c02efa80863d33cfaaf120f5399c15148cab0216803c9b102900eda02f3c596915d8af22282b466c127f6bb3884d2873c6e8007ea
        DEPS libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libpcre-8.45-1-x86_64.pkg.tar.zst"
        SHA512 b10a69380c44ea35367f310a7400eae26beacf347ddbb5da650b54924b80ffd791f12a9d70923567e5081e3c7098f042e47bcff1328d95b0b27ce63bcd762e88
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/m4-1.4.19-2-x86_64.pkg.tar.zst"
        SHA512 7471099ba7e3b47e5b019dc0e563165a8660722f2bbd337fb579e6d1832c0e7dcab0ca9297c4692b18add92c4ad49e94391c621cf38874e2ff63d4f926bac38c
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/automake-wrapper-11-4-any.pkg.tar.zst"
        SHA512 175940ebccb490c25d2c431dd025f24a7d0c930a7ee8cb81a44a4989c1d07f4b5a8134e1d05a7a1b206f8e19a2308ee198b1295e31b2e139f5d9c1c077252c94
        DEPS gawk
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gawk-5.1.1-1-x86_64.pkg.tar.zst"
        SHA512 909c3c77f2864d383451deecbaef7b990ed1e336baa7f6812e18e3df91ec3556e89b4f290ac9a38b1c2f11222b6831bf7c17a6999a50c6d7013a8dce6647f016
        DEPS libintl libreadline mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/mpfr-4.1.0.p13-1-x86_64.pkg.tar.zst"
        SHA512 437f4b37ed718f2a56dd8087f852aabb0dc0f0cdb55ef6e033bdb8d4ad404855f0d0d9c01b5860b6cfa8f39b41b6bb6968288a318f781b3610de9bb1335309af
        DEPS gmp gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gmp-6.2.1-2-x86_64.pkg.tar.zst"
        SHA512 b2df273243ba08ed2b1117d2b4826900706859c51c1c39ca6e47df2b44b006b2512f7db801738fdbb9411594bc8bc67d308cf205f7fa1aab179863844218e513
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/xz-5.2.5-2-x86_64.pkg.tar.zst" # this seems to require immediate updating on version bumps.
        SHA512 13a5b1a4330c0262cbb4ffb802b67c94f672442290a32bf42cb99d5e003fd326c83f8116ef1b1edd21c3bdfbc0e7c634595f3ba5e0901b06e9856f33c065f5fc
        DEPS liblzma libiconv gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/liblzma-5.2.5-2-x86_64.pkg.tar.zst"
        SHA512 9d881d4faac6c801cbfdb4085d76f8cc491966f7de2024bfdaf4dd10f1b6b4f9eda581c82d5476f5dda40353723afa890690d54599f0a0aedab6324594d168de
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libreadline-8.1.002-2-x86_64.pkg.tar.zst"
        SHA512 509454b188b78fa640c1b4219d86f8117d4001e41fd8bfc751db1f7fa015939a5949f3920381d586a18b48b0da39c17337d41c98e80a5c126558196c9fd2640e
        DEPS ncurses
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/ncurses-6.3-3-x86_64.pkg.tar.zst"
        SHA512 58b76fa93755c29b43d48ec27f3d4375334b25099e6f2d139b64558797644042469d18139edb01b5908459ff8e4f0f6514ecc5a27681865a50a64c11e4e71921
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/automake1.16-1.16.5-1-any.pkg.tar.zst"
        SHA512 62c9dfe28d6f1d60310f49319723862d29fc1a49f7be82513a4bf1e2187ecd4023086faf9914ddb6701c7c1e066ac852c0209db2c058f3865910035372a4840a
        DEPS perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/perl-5.32.1-2-x86_64.pkg.tar.zst"
        SHA512 ad21734c05bc7faa809bc4ba761fb41a3b448d31794d1fd3d430cf4afe05ae991aabece4ec9a25718c01cc323d507bf97530533f0a20aabc18a7a2ccc0ae02b1
        DEPS libcrypt
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libcrypt-2.1-3-x86_64.pkg.tar.zst"
        SHA512 15cee333a82b55ff6072b7be30bf1c33c926d8ac21a0a91bc4cbf655b6f547bc29496df5fa288eb47ca2f88af2a4696f9b718394437b65dd06e3d6669ca0c2e5
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/pkg-config-0.29.2-4-x86_64.pkg.tar.zst"
        SHA512 9f72c81d8095ca1c341998bc80788f7ce125770ec4252f1eb6445b9cba74db5614caf9a6cc7c0fcc2ac18d4a0f972c49b9f245c3c9c8e588126be6c72a8c1818
        DEPS libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/make-4.3-3-x86_64.pkg.tar.zst"
        SHA512 1d991bfc2f076c8288023c7dd71c65470ad852e0744870368a4ab56644f88c7f6bbeca89dbeb7ac8b2719340cfec737a8bceae49569bbe4e75b6b8ffdcfe76f1
        DEPS libintl msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gettext-devel-0.21-2-x86_64.pkg.tar.zst"
        SHA512 c8852c4c8cf7810434dab18c7a002e59c2248de93b575097a30a31f4e7f41719855c0f3cf55356173576aab03119139f71dce758df1421b3f23c1ca3520e4261
        DEPS gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gettext-0.21-2-x86_64.pkg.tar.zst"
        SHA512 2f6b95686e6c9cabfdac22994cbd6402dc22da71ab9582205874e7967452be65a25bf73b8994cce679ef43b26a29dec25eb3f233f7126d8c4b2f5ddd28588bd4
        DEPS libintl libgettextpo libasprintf tar
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/tar-1.34-2-x86_64.pkg.tar.zst"
        SHA512 127a971f5c087500ec4858697205b36ae76dba82307f1bcaaa44e746337d85d97360e46e55ef7fecbfa2a4af428ee26d804fa7d7c2b8ce6de1b86328dd14ef2d
        DEPS libiconv libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libgettextpo-0.21-2-x86_64.pkg.tar.zst"
        SHA512 e5736e2d5b8a7f0df02bab3a4c0e09f5a83069f4ff5554fa176f832b455fe836210686428172a34951db7f4ce6f20ec5428440af06d481fcaa90d632aac4afd2
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libasprintf-0.21-1-x86_64.pkg.tar.zst"
        SHA512 62dde7bfcfea75ea9adb463807d7c128019ffeec0fb23e73bc39f760e45483c61f4f29e89cdbfab1e317d520c83fe3b65306fbd7258fe11ea951612dbee479fe
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/findutils-4.9.0-3-x86_64.pkg.tar.zst"
        SHA512 1538733929ecc11bc7c19797577e4cd59cc88499b375e3c2ea4a8ed4d66a1a02f4468ff916046c76195ba92f4c591d0e351371768117a423595d2e43b3321aad
        DEPS libintl libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libintl-0.21-2-x86_64.pkg.tar.zst"
        SHA512 fd066ea0fa9bc67fe3bcb09ba4d9dd4524611840bb3179e521fa3049dc88ba5e49851cc04cb76d8f0394c4ec1a6bf45c3f6ce6231dc5b0d3eb1f91d983b7f93b
        DEPS libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libiconv-1.17-1-x86_64.pkg.tar.zst"
        SHA512 e8fc6338d499ccf3a143b3dbdb91838697de76e1c9582bb44b0f80c1d2da5dcfe8102b7512efa798c5409ba9258f4014eb4eccd24a9a46d89631c06afc615678
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gcc-libs-11.3.0-1-x86_64.pkg.tar.zst"
        SHA512 8720303f3e131b99b0fac1b222946356aba9b21bbf59c7e46e83de6a24c414f3a086ac8a3ef2a1e33aed292250e0a0620300a935d06b7e841bf28b5d717d8901
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/msys2-runtime-3.4.9-2-x86_64.pkg.tar.zst"
        SHA512 d0055ee6e220e5f19cc473c81832500edcb21eb3d7232dbaa480768b075e049495af62248238c8edaee4981cb27fd2d599ca0dff4b6165c7090049f93f6f0ea1
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-python-numpy-1.20.3-1-any.pkg.tar.zst"
        SHA512 ce73d4270942f61963e8307f6bec945d14e3774455684842b8fde836b19a4e9cbf8efd0663ffb28ad872493db70fa3a4e14bd0b248c2067199f4fee94e80e77e
        DEPS mingw-w64-x86_64-openblas mingw-w64-x86_64-python
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-openblas-0.3.19-1-any.pkg.tar.zst"
        SHA512 0d18a93d7804d6469b8566cf4ad3a7efbdf8a4a4b05d191b23a30e107586423c6338b9f4a5ea2cc93052e6c0336dc82a43c26189c410263a6e705e6f3ebe261a
        DEPS mingw-w64-x86_64-gcc-libgfortran mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libwinpthread
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-gcc-libgfortran-11.2.0-8-any.pkg.tar.zst"
        SHA512 8537b55633bc83d81d528378590e417ffe8c26b6c327d8b6d7ba50a8b5f4e090fbe2dc500deb834120edf25ac3c493055f4de2dc64bde061be23ce0f625a8893
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-python-3.8.9-2-any.pkg.tar.zst"
        SHA512 8a45b28b2b0471718bd1ab096958872b18ae3b25f06c30718c54d1edaf04214397330a51776f3e4eee556ac47d9e3aa5e1b211c5df0cf6be3046a6f3a79cfa7d
        DEPS mingw-w64-x86_64-bzip2 mingw-w64-x86_64-expat mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libffi mingw-w64-x86_64-mpdecimal mingw-w64-x86_64-ncurses mingw-w64-x86_64-openssl mingw-w64-x86_64-sqlite3 mingw-w64-x86_64-tcl mingw-w64-x86_64-tk mingw-w64-x86_64-xz mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-bzip2-1.0.8-2-any.pkg.tar.zst"
        SHA512 4f7ba44189d953d4d00e7bbf5a7697233f759c92847c074f0f2888d2a641c59ce4bd3c39617adac0ad7b53c5836e529f9ffd889f976444016976bb517e5c24a2
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-mpdecimal-2.5.1-1-any.pkg.tar.zst"
        SHA512 1204c31367f9268ffd6658be04af7687c01f984c9d6be8c7a20ee0ebde1ca9a03b766ef1aeb1fa7aaa97b88a57f7a73afa7f7a7fed9c6b895a032db11e6133bf
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-ncurses-6.3-3-any.pkg.tar.zst"
        SHA512 888c155d878651dc31c9a01455ab689d7b644cec759521b69b8399c20b6ddc77c90f3ee4ddeed8857084335335b4b30e182d826fb5b78719b704f13a1dfdbd54
        DEPS mingw-w64-x86_64-libsystre
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libsystre-1.0.1-4-any.pkg.tar.xz"
        SHA512 6540e896636d00d1ea4782965b3fe4d4ef1e32e689a98d25e2987191295b319eb1de2e56be3a4b524ff94f522a6c3e55f8159c1a6f58c8739e90f8e24e2d40d8
        DEPS mingw-w64-x86_64-libtre
    )
    z_vcpkg_acquire_msys_declare_package(
        NAME "mingw-w64-x86_64-libtre"
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libtre-git-r128.6fb7206-2-any.pkg.tar.xz"
        SHA512 d595dbcf3a3b6ed098e46f370533ab86433efcd6b4d3dcf00bbe944ab8c17db7a20f6535b523da43b061f071a3b8aa651700b443ae14ec752ae87500ccc0332d
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-openssl-1.1.1.m-1-any.pkg.tar.zst"
        SHA512 9471b0e5b01453f6ee5c92be6e259446c6b5be45d1da8985a4735b3e54c835d9b86286b2af126546419bf968df096442bd4f60f30efa1a901316e3c02b98525f
        DEPS mingw-w64-x86_64-ca-certificates mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-ca-certificates-20210119-1-any.pkg.tar.zst"
        SHA512 5590ca116d73572eb336ad73ea5df9da34286d8ff8f6b162b38564d0057aa23b74a30858153013324516af26671046addd6bcade221e94e7b8ed5e8f886e1c58
        DEPS mingw-w64-x86_64-p11-kit
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-p11-kit-0.24.1-1-any.pkg.tar.zst"
        SHA512 6437919cd61c8b1a59b346bbd93d960adb7f11206e8c0010311d71d0fe9aa03f950ecf08f19a5555b27f481cc0d61b88650b165ae9336ac1a1a0a9be553239b9
        DEPS mingw-w64-x86_64-gettext mingw-w64-x86_64-libffi mingw-w64-x86_64-libtasn1
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libtasn1-4.18.0-1-any.pkg.tar.zst"
        SHA512 2584a6e0bc2b7d145f026487951b8690e3d8e79f475a7b77f95fc27ca9a9f1887fe9303e340ba2635353c4a6f6a2f10a907dd8778e54be7506a15459f616d4a4
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-sqlite3-3.37.2-1-any.pkg.tar.zst"
        SHA512 0f83f10b0c8f4699a6b84deb6986fcd471cb80b995561ad793e827f9dd66110d555744918ed91982aec8d9743f6064726dd5eba3e695aa9ab5381ea4f8e76dbe
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-readline mingw-w64-x86_64-tcl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-readline-8.1.001-1-any.pkg.tar.zst"
        SHA512 b38aef9216ea2ba7edd82ce57a48dbc913b9bdcb44b96b9800342fe097d706ba39c9d5ba08d793d2c3388722479258bb05388ae09d74a1edcaaf9002e9d71853
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-termcap
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-termcap-1.3.1-6-any.pkg.tar.zst"
        SHA512 602d182ba0f1e20c4c51ae09b327c345bd736e6e4f22cd7d58374ac68c705dd0af97663b9b94d41870457f46bb9110abb29186d182196133618fc460f71d1300
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-tk-8.6.11.1-2-any.pkg.tar.zst"
        SHA512 15fd4e085fabe2281f33c8f36f4b1b0be132e5b100f6d4eaf54688842791aa2cf4e6d38a855f74f42be3f86c52e20044518f5843f8e9ca13c54a6ea4adb973a8
        DEPS mingw-w64-x86_64-tcl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-tcl-8.6.11-5-any.pkg.tar.zst"
        SHA512 9db75ff47260ea3652d1abf60cd44649d0e8cbe5c4d26c316b99a6edb08252fb87ed017c856f151da99bcaa0bd90c0bebae28234035b008c5bd6508511639852
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-xz-5.2.5-2-any.pkg.tar.zst"
        SHA512 94fcf8b9f9fbc2cfdb2ed53dbe72797806aa3399c4dcfea9c6204702c4504eb4d4204000accd965fcd0680d994bf947eae308bc576e629bbaa3a4cefda3aea52
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-gettext-0.21-3-any.pkg.tar.zst"
        SHA512 38daa0edd1a2c1efdd56baeb6805d10501a57e0c8ab98942e4a16f8b021908dac315513ea85f5278adf300bce3052a44a3f8b473adb0d5d3656aa4a48fe61081
        DEPS mingw-w64-x86_64-expat mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-gcc-libs-11.2.0-8-any.pkg.tar.zst"
        SHA512 2481f7c8db7cca549911bc71715af86ca287ffed6d673c9a6c3a4c792b68899a129dd959214af7067f434e74fc518c43749e7d928cbd2232ab4fbc65880dad98
        DEPS mingw-w64-x86_64-gmp mingw-w64-x86_64-libwinpthread mingw-w64-x86_64-mpc mingw-w64-x86_64-mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-mpc-1.2.1-1-any.pkg.tar.zst"
        SHA512 f2c137dbb0b6feea68dde9739c38b44dcb570324e3947adf991028e8f63c9ff50a11f47be15b90279ff40bcac7f320d952cfc14e69ba8d02cf8190c848d976a1
        DEPS mingw-w64-x86_64-mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-mpfr-4.1.0-3-any.pkg.tar.zst"
        SHA512 be8ad04e53804f18cfeec5b9cba1877af1516762de60891e115826fcfe95166751a68e24cdf351a021294e3189c31ce3c2db0ebf9c1d4d4ab6fea1468f73ced5
        DEPS mingw-w64-x86_64-gmp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-gmp-6.2.1-3-any.pkg.tar.zst"
        SHA512 d0d4ed1a046b64f437e72bbcf722b30311dde5f5e768a520141423fc0a3127b116bd62cfd4b5cf5c01a71ee0f9cf6479fcc31277904652d8f6ddbf16e33e0b72
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-expat-2.4.4-1-any.pkg.tar.zst"
        SHA512 479e6591d06eee2686591d7232a60d4092540deb40cf0c2c418de861b1da6b21fb4be82e603dd4a3b88f5a1b1d21cdb4f016780dda8131e32be5c3dec85dfc4d
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libffi-3.3-4-any.pkg.tar.zst"
        SHA512 1d7be396ef132289be0c33792c4e81dea6cb7b1eafa249fb3e8abc0b393d14e5114905c0c0262b6a7aed8f196ae4d7a10fbafd342b08ec76c9196921332747b5
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libiconv-1.16-2-any.pkg.tar.zst"
        SHA512 542ed5d898a57a79d3523458f8f3409669b411f87d0852bb566d66f75c96422433f70628314338993461bcb19d4bfac4dadd9d21390cb4d95ef0445669288658
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-zlib-1.2.11-9-any.pkg.tar.zst"
        SHA512 f386d3a8d8c169a62a4580af074b7fdc0760ef0fde22ef7020a349382dd374a9e946606c757d12da1c1fe68baf5e2eaf459446e653477035a63e0e20df8f4aa0
    )
    z_vcpkg_acquire_msys_declare_package(
        NAME "mingw-w64-x86_64-libwinpthread"
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libwinpthread-git-9.0.0.6373.5be8fcd83-2-any.pkg.tar.zst"
        SHA512 c5a008db60305341254b617dfd60528ebc5d6b02a55bf63e5ca5ac76a73448d5ceb4baf2223869ee86f184242c5287da98545ab2bfc15b4d2f54ce1e23652997
    )

    if(NOT Z_VCPKG_MSYS_PACKAGES STREQUAL "")
        message(FATAL_ERROR "Unknown packages were required for vcpkg_acquire_msys(${arg_PACKAGES}): ${packages}
This can be resolved by explicitly passing URL/SHA pairs to DIRECT_PACKAGES.")
    endif()

    string(SHA512 total_hash "${Z_VCPKG_MSYS_TOTAL_HASH}")
    string(SUBSTRING "${total_hash}" 0 16 total_hash)
    set(path_to_root "${DOWNLOADS}/tools/msys2/${total_hash}")
    if(NOT EXISTS "${path_to_root}")
        file(REMOVE_RECURSE "${path_to_root}.tmp")
        file(MAKE_DIRECTORY "${path_to_root}.tmp/tmp")
        set(index 0)
        foreach(archive IN LISTS Z_VCPKG_MSYS_ARCHIVES)
            vcpkg_execute_required_process(
                ALLOW_IN_DOWNLOAD_MODE
                COMMAND "${CMAKE_COMMAND}" -E tar xzf "${archive}"
                LOGNAME "msys-${TARGET_TRIPLET}-${index}"
                WORKING_DIRECTORY "${path_to_root}.tmp"
            )
            math(EXPR index "${index} + 1")
        endforeach()
        file(RENAME "${path_to_root}.tmp" "${path_to_root}")
    endif()
    # Due to skipping the regular MSYS2 installer,
    # some config files need to be established explicitly.
    if(NOT EXISTS "${path_to_root}/etc/fstab")
        # This fstab entry removes the cygdrive prefix from paths.
        file(WRITE "${path_to_root}/etc/fstab" "none  /  cygdrive  binary,posix=0,noacl,user  0  0")
    endif()
    message(STATUS "Using msys root at ${path_to_root}")
    set("${out_msys_root}" "${path_to_root}" PARENT_SCOPE)
endfunction()
