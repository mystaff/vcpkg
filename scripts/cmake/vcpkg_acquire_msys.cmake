# Full mirror list: https://github.com/msys2/MSYS2-packages/blob/master/pacman-mirrors/mirrorlist.msys
set(Z_VCPKG_ACQUIRE_MSYS_MIRRORS
    # Alternative primary
    "https://repo.msys2.org/"
    # Tier 1
    "https://mirror.yandex.ru/mirrors/msys2/"
    "https://mirrors.tuna.tsinghua.edu.cn/msys2/"
    "https://mirrors.ustc.edu.cn/msys2/"
    "https://mirror.selfnet.de/msys2/"
)

# Downloads the given package
function(z_vcpkg_acquire_msys_download_package out_archive)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "" "URL;SHA512;FILENAME" "")
    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_download_package passed extra args: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    string(REPLACE "https://repo.msys2.org/" "https://mirror.msys2.org/" all_urls "${arg_URL}")
    foreach(mirror IN LISTS Z_VCPKG_ACQUIRE_MSYS_MIRRORS)
        string(REPLACE "https://mirror.msys2.org/" "${mirror}" mirror_url "${arg_URL}")
        list(APPEND all_urls "${mirror_url}")
    endforeach()

    vcpkg_download_distfile(msys_archive
        URLS ${all_urls}
        SHA512 "${arg_SHA512}"
        FILENAME "${arg_FILENAME}"
        QUIET
    )
    set("${out_archive}" "${msys_archive}" PARENT_SCOPE)
endfunction()

# Declares a package
# Writes to the following cache variables:
#   - Z_VCPKG_MSYS_PACKAGES_AVAILABLE
#   - Z_VCPKG_MSYS_${arg_NAME}_URL
#   - Z_VCPKG_MSYS_${arg_NAME}_SHA512
#   - Z_VCPKG_MSYS_${arg_NAME}_FILENAME
#   - Z_VCPKG_MSYS_${arg_NAME}_DEPS
#   - Z_VCPKG_MSYS_${arg_NAME}_PATCHES
#   - Z_VCPKG_MSYS_${arg_NAME}_DIRECT
#   - Z_VCPKG_MSYS_${arg_NAME}_PROVIDES
#   - Z_VCPKG_MSYS_${alias}_PROVIDED_BY
function(z_vcpkg_acquire_msys_declare_package)
    cmake_parse_arguments(PARSE_ARGV 0 arg "DIRECT" "NAME;URL;SHA512" "DEPS;PATCHES;PROVIDES")

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_declare_package passed extra args: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    foreach(required_arg IN ITEMS URL SHA512)
        if(NOT DEFINED arg_${required_arg})
            message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_declare_package requires argument: ${required_arg}")
        endif()
    endforeach()

    if(arg_DIRECT)
        if(NOT arg_NAME)
            message(FATAL_ERROR "internal error: z_vcpkg_acquire_msys_declare_package requires argument: NAME")
        endif()
        get_filename_component(filename "${arg_URL}" NAME)
    else()
        if(NOT arg_URL MATCHES [[^https://mirror\.msys2\.org/.*/(([^/]*)-[^-/]+-[^-/]+-[^-/]+\.pkg\.tar\.(xz|zst))$]])
            message(FATAL_ERROR "internal error: regex does not match supplied URL to vcpkg_acquire_msys: ${arg_URL}")
        endif()
        set(filename "msys2-${CMAKE_MATCH_1}")
        if(NOT DEFINED arg_NAME)
            set(arg_NAME "${CMAKE_MATCH_2}")
        endif()
        if(Z_VCPKG_MSYS_${arg_NAME}_DIRECT)
            return()
        endif()
        if(arg_NAME IN_LIST Z_VCPKG_MSYS_PACKAGES_AVAILABLE)
            message(FATAL_ERROR "Redeclaration of package '${arg_NAME}'")
        endif()
    endif()

    list(APPEND Z_VCPKG_MSYS_PACKAGES_AVAILABLE "${arg_NAME}")
    set(Z_VCPKG_MSYS_PACKAGES_AVAILABLE "${Z_VCPKG_MSYS_PACKAGES_AVAILABLE}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_URL "${arg_URL}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_SHA512 "${arg_SHA512}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_FILENAME "${filename}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_DEPS "${arg_DEPS}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_PATCHES "${arg_PATCHES}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_DIRECT "${arg_DIRECT}" CACHE INTERNAL "")
    set(Z_VCPKG_MSYS_${arg_NAME}_PROVIDES "${arg_PROVIDES}" CACHE INTERNAL "")
    foreach(name IN LISTS arg_PROVIDES)
        set(Z_VCPKG_MSYS_${name}_PROVIDED_BY "${arg_NAME}" CACHE INTERNAL "")
    endforeach()
endfunction()

# Collects all required packages to satisfy the given input set
# Writes to the following cache variables:
#   - Z_VCPKG_MSYS_<name>_ARCHIVE
function(z_vcpkg_acquire_msys_download_packages)
    cmake_parse_arguments(PARSE_ARGV 0 "arg" "" "OUT_UNKNOWN;OUT_RESOLVED" "PACKAGES")
    set(backlog "${arg_PACKAGES}")
    list(REMOVE_DUPLICATES backlog)

    list(FILTER arg_PACKAGES EXCLUDE REGEX "^mingw64")
    if(NOT arg_PACKAGES STREQUAL "" AND NOT "msys2-runtime" IN_LIST arg_PACKAGES)
        list(APPEND backlog "msys2-runtime")
    endif()

    set(unknown "")
    set(resolved "")
    set(need_msys_runtime 0)
    while(NOT backlog STREQUAL "")
        list(POP_FRONT backlog name)
        if(DEFINED Z_VCPKG_MSYS_${name}_PROVIDED_BY AND NOT name IN_LIST Z_VCPKG_MSYS_PACKAGES_AVAILABLE)
            set(name "${Z_VCPKG_MSYS_${name}_PROVIDED_BY}")
            if(name IN_LIST resolved)
                continue()
            endif()
        endif()
        if(NOT name IN_LIST Z_VCPKG_MSYS_PACKAGES_AVAILABLE)
            list(APPEND unknown "${name}")
            continue()
        endif()
        list(APPEND resolved "${name}")
        list(REMOVE_ITEM Z_VCPKG_MSYS_${name}_DEPS ${resolved} ${backlog})
        list(APPEND backlog ${Z_VCPKG_MSYS_${name}_DEPS})

        z_vcpkg_acquire_msys_download_package(archive
            URL "${Z_VCPKG_MSYS_${name}_URL}"
            SHA512 "${Z_VCPKG_MSYS_${name}_SHA512}"
            FILENAME "${Z_VCPKG_MSYS_${name}_FILENAME}"
        )
        set(Z_VCPKG_MSYS_${name}_ARCHIVE "${archive}" CACHE INTERNAL "")
    endwhile()
    if(DEFINED arg_OUT_UNKNOWN)
        set("${arg_OUT_UNKNOWN}" "${unknown}" PARENT_SCOPE)
    endif()
    if(DEFINED arg_OUT_RESOLVED)
        set("${arg_OUT_RESOLVED}" "${resolved}" PARENT_SCOPE)
    endif()
endfunction()

# Returns a stable collection of hashes, regardless of package order
function(z_vcpkg_acquire_msys_collect_hashes out_hash)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "" "" "PACKAGES")
    list(SORT arg_PACKAGES)
    set(result "")
    foreach(name IN LISTS arg_PACKAGES)
        if(NOT DEFINED Z_VCPKG_MSYS_${name}_SHA512)
            message(FATAL_ERROR "SHA512 unknown for '${name}'.")
        endif()
        string(APPEND result "${Z_VCPKG_MSYS_${name}_SHA512}")
        foreach(patch IN LISTS Z_VCPKG_MSYS_${name}_PATCHES)
            file(SHA512 "${patch}" patch_sha)
            string(APPEND result "${patch_sha}")
        endforeach()
    endforeach()
    set(${out_hash} "${result}" PARENT_SCOPE)
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

    z_vcpkg_acquire_msys_declare_all_packages()
    set(requested "${arg_PACKAGES}")
    if(arg_Z_ALL_PACKAGES)
        set(requested "${Z_VCPKG_MSYS_PACKAGES_AVAILABLE}")
    elseif(NOT arg_NO_DEFAULT_PACKAGES)
        list(APPEND requested bash coreutils file gawk grep gzip diffutils make pkgconf sed)
    endif()

    if(DEFINED arg_DIRECT_PACKAGES AND NOT arg_DIRECT_PACKAGES STREQUAL "")
        list(LENGTH arg_DIRECT_PACKAGES direct_packages_length)
        math(EXPR direct_packages_parity "${direct_packages_length} % 2")
        math(EXPR direct_packages_number "${direct_packages_length} / 2")
        math(EXPR direct_packages_last "${direct_packages_number} - 1")

        if(direct_packages_parity EQUAL 1)
            message(FATAL_ERROR "vcpkg_acquire_msys(... DIRECT_PACKAGES ...) requires exactly pairs of URL/SHA512")
        endif()

        set(direct_packages "")
        # direct_packages_last > direct_packages_number - 1 > 0 - 1 >= 0, so this is fine
        foreach(index RANGE "${direct_packages_last}")
            math(EXPR url_index "${index} * 2")
            math(EXPR sha512_index "${url_index} + 1")
            list(GET arg_DIRECT_PACKAGES "${url_index}" url)
            list(GET arg_DIRECT_PACKAGES "${sha512_index}" sha512)
            get_filename_component(filename "${url}" NAME)
            if(NOT filename MATCHES "^(.*)-[^-]+-[^-]+-[^-]+\.pkg\.tar\..*$")
                message(FATAL_ERROR "Cannot determine package name for '${filename}'")
            endif()
            set(pkg_name "${CMAKE_MATCH_1}")
            z_vcpkg_acquire_msys_declare_package(
                NAME "${pkg_name}"
                URL "${url}"
                SHA512 "${sha512}"
                DIRECT
            )
            list(APPEND direct_packages "${pkg_name}")
        endforeach()
        list(INSERT requested 0 ${direct_packages})
    endif()
<<<<<<< HEAD

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
        URL "https://repo.msys2.org/msys/x86_64/gzip-1.11-1-x86_64.pkg.tar.zst"
        SHA512 bcd9d7839aef5f2b73c4d39b51838e62626c201c808d512806ba0a1619aee83c7deddb0d499fd93f9815fe351d7ab656c31c9dc7ee1171d77ad6d598e04dfcbe
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/texinfo-6.8-3-x86_64.pkg.tar.zst"
        SHA512 5cc16d3b3c3b9859fe61233fa27f2146526e2b4d6e626814d283b35bfd77bc15eb4ffaec00bde6c10df93466d9155a06854a7ecf2e0d9af746dd56c4d88d192e
        DEPS bash perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/bash-5.1.008-1-x86_64.pkg.tar.zst"
        SHA512 a2ab8c958615134dc666254baca8cb13ed773036954e458de74ffb3bfe661bb33149082d38b677024da451755098a9201ab7dd435ced6e7f6b4e94c3ae368daf
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
        URL "https://repo.msys2.org/msys/x86_64/diffutils-3.8-2-x86_64.pkg.tar.zst"
        SHA512 ee74e457c417d6978b3185f2fb8e15c9c30ecfc316c2474d69c978e7eb2282a3bd050d68dbf43d694cb5ab6f159b0e7ca319d01f8192071d82a224dde87d69b5
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
        URL "https://repo.msys2.org/msys/x86_64/file-5.41-2-x86_64.pkg.tar.zst"
        SHA512 124c3983608879362acea7d487bf23690f371b3cfe0355385f0e643263b2a5568abe5cebda92ef9bc534e81f850138f589e75982f36a53f509676056d71de642
        DEPS gcc-libs zlib libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/zlib-1.2.11-1-x86_64.pkg.tar.xz"
        SHA512 b607da40d3388b440f2a09e154f21966cd55ad77e02d47805f78a9dee5de40226225bf0b8335fdfd4b83f25ead3098e9cb974d4f202f28827f8468e30e3b790d
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
        URL "https://repo.msys2.org/msys/x86_64/sed-4.8-2-x86_64.pkg.tar.zst"
        SHA512 8391be777239e0bfc19dc477995ee581ea9dbb1ba34fc27f57ba9d858e7489ac9b7200479d405712b43fa88434dd597be71d161fa8c05606e7ef991711bfc4c1
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
        URL "https://repo.msys2.org/msys/x86_64/gawk-5.1.0-2-x86_64.pkg.tar.zst"
        SHA512 d4b00e2b53ce99ddd3ee8e41c41add5ab36d26a54107acf7f5a5bf4a0033d72465cdab86f5b2eb8b7aca2cb5027a3e35cb194794c3bf563c0075ca3dbcad6987
        DEPS libintl libreadline mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/mpfr-4.1.0-1-x86_64.pkg.tar.zst"
        SHA512 d64fa60e188124591d41fc097d7eb51d7ea4940bac05cdcf5eafde951ed1eaa174468f5ede03e61106e1633e3428964b34c96de76321ed8853b398fbe8c4d072
        DEPS gmp gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gmp-6.2.1-1-x86_64.pkg.tar.zst"
        SHA512 c5c8009ef069d05c2209b69c8e87094b09aac4b5c3dfdbea474d8262e55d286b400f1360c6a9778fd5eb87fb76a6463c21188286a1a1919ad79153eae3c44b0f
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/xz-5.2.5-1-x86_64.pkg.tar.xz" # this seems to require immediate updating on version bumps.
        SHA512 99d092c3398277e47586cead103b41e023e9432911fb7bdeafb967b826f6a57d32e58afc94c8230dad5b5ec2aef4f10d61362a6d9e410a6645cf23f076736bba
        DEPS liblzma libiconv gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/liblzma-5.2.5-1-x86_64.pkg.tar.xz"
        SHA512 8d5c04354fdc7309e73abce679a4369c0be3dc342de51cef9d2a932b7df6a961c8cb1f7e373b1b8b2be40343a95fbd57ac29ebef63d4a2074be1d865e28ca6ad
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libreadline-8.1.001-1-x86_64.pkg.tar.zst"
        SHA512 4104eb0c18b8c06ab3bd4ba6420e3464df8293bec673c88da49e2f74cf1d583c922e9ead5691271fe593d424f92d1fd8668a3002174d756993d5b18337459bab
        DEPS ncurses
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/ncurses-6.2-2-x86_64.pkg.tar.zst"
        SHA512 4bf744a21ab2030ea9d65eb4d824ec5bed4532b7a489859e5e19bba11b5ba9be08613de48acb38baacfd2a7295722e4d858d7c577565f1999d2583defbbb58f2
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/automake1.16-1.16.3-3-any.pkg.tar.zst"
        SHA512 77a195a9fe8680bee55c04b8ecc0e9ee43e2d89607c745098dfac4687f4f853885cabbb005202d70e9a9cdf9facf6849cc47c6b2f25573b5af8201696d926c72
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
        URL "https://repo.msys2.org/msys/x86_64/gettext-devel-0.21-1-x86_64.pkg.tar.zst"
        SHA512 44444064b9860dbd3cb886812fb20ee97ab04a65616cca497be69c592d5507e7bc66bfe8dbd060a4df9c5d9bb44cb0f231584d65cb04351146d54d15852227af
        DEPS gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gettext-0.21-1-x86_64.pkg.tar.zst"
        SHA512 6ef5f4094c4a174550a898cac4f60215d22de09f7e5f72bdb297d18a6f027e6122b4a519aa8d5781f9b0201dcae14ad7910b181b1499d6d8bbeb5a35b3a08581
        DEPS libintl libgettextpo libasprintf tar
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/tar-1.34-2-x86_64.pkg.tar.zst"
        SHA512 127a971f5c087500ec4858697205b36ae76dba82307f1bcaaa44e746337d85d97360e46e55ef7fecbfa2a4af428ee26d804fa7d7c2b8ce6de1b86328dd14ef2d
        DEPS libiconv libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libgettextpo-0.21-1-x86_64.pkg.tar.zst"
        SHA512 bb217639deadb36734bafb8db5217e654d00b93a3ef366116cc6c9b8b8951abef9a7e9b04be3fae09074cf68576f18575a0d09f3d2f344985606c1449a17222e
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libasprintf-0.21-1-x86_64.pkg.tar.zst"
        SHA512 62dde7bfcfea75ea9adb463807d7c128019ffeec0fb23e73bc39f760e45483c61f4f29e89cdbfab1e317d520c83fe3b65306fbd7258fe11ea951612dbee479fe
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/findutils-4.8.0-1-x86_64.pkg.tar.zst"
        SHA512 74f8750636becefd3675c89957dfb8a244d2db6fec80bf352998edfef93f66d0e2a37d7f2869a79dd197acf2057ccd6aefd12c58e94154765896a432831ab49c
        DEPS libintl libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libintl-0.21-1-x86_64.pkg.tar.zst"
        SHA512 be0242eed25793e86e0560868f76cf06a358ffc0b2beb357e776d6c7819e545ac90f9358b17a85aa598584babe3ab4bb4544e360a28f5cec965f314178b930d1
        DEPS libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libiconv-1.16-2-x86_64.pkg.tar.zst"
        SHA512 3ab569eca9887ef85e7dd5dbca3143d8a60f7103f370a7ecc979a58a56b0c8dcf1f54ac3df4495bc306bd44bf36ee285aaebbb221c4eebfc912cf47d347d45fc
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gcc-libs-11.2.0-3-x86_64.pkg.tar.zst"
        SHA512 be7bb61d1b87eafbb91cf9d0fee3270b9d5e2420c403ea394967941195d52ae248ce4ffde20af41a05310527a920269018f49487be617211a5e340486babd0f8
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
        URL "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libwinpthread-git-9.0.0.6373.5be8fcd83-1-any.pkg.tar.zst"
        SHA512 a2c9e60d23b1310a6cec1fadd2b15a8c07223f3fe90d41b1579e9fc27ee2b0b408456291a55fad54a156e6a247efc20f6fcc247cc567e64fe190938aa3b672e9
    )

    if(NOT Z_VCPKG_MSYS_PACKAGES STREQUAL "")
        message(FATAL_ERROR "Unknown packages were required for vcpkg_acquire_msys(${arg_PACKAGES}): ${packages}
=======
 
    z_vcpkg_acquire_msys_download_packages(
        PACKAGES ${requested}
        OUT_RESOLVED resolved
        OUT_UNKNOWN unknown
    )
    if(NOT unknown STREQUAL "")
        message(FATAL_ERROR "Unknown packages were required for vcpkg_acquire_msys(${requested}): ${unknown}
>>>>>>> 13c3c0fcc203d179f4443fe48d252e3ff220cbeb
This can be resolved by explicitly passing URL/SHA pairs to DIRECT_PACKAGES.")
    endif()
    set(Z_VCPKG_MSYS_PACKAGES_RESOLVED "${resolved}" CACHE INTERNAL "Export for CI")

    z_vcpkg_acquire_msys_collect_hashes(hashes PACKAGES ${resolved})
    string(SHA512 total_hash "${hashes}")
    string(SUBSTRING "${total_hash}" 0 16 total_hash)
    set(path_to_root "${DOWNLOADS}/tools/msys2/${total_hash}")

    if(NOT EXISTS "${path_to_root}")
        file(REMOVE_RECURSE "${path_to_root}.tmp")
        file(MAKE_DIRECTORY "${path_to_root}.tmp/tmp")
        foreach(name IN LISTS resolved)
            file(ARCHIVE_EXTRACT
                INPUT "${Z_VCPKG_MSYS_${name}_ARCHIVE}"
                DESTINATION "${path_to_root}.tmp"
            )
            if(Z_VCPKG_MSYS_${name}_PATCHES)
                z_vcpkg_apply_patches(
                    SOURCE_PATH "${path_to_root}.tmp"
                    PATCHES ${Z_VCPKG_MSYS_${name}_PATCHES}
                )
            endif()
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

# Expand this while CMAKE_CURRENT_LIST_DIR is for this file.
set(Z_VCPKG_AUTOMAKE_CLANG_CL_PATCH "${CMAKE_CURRENT_LIST_DIR}/compile_wrapper_consider_clang-cl.patch")

macro(z_vcpkg_acquire_msys_declare_all_packages)
    set(Z_VCPKG_MSYS_PACKAGES_AVAILABLE "" CACHE INTERNAL "")

    # The following list can be updated via test port vcpkg-ci-msys2[update-all].
    # Upstream binary package information is available via
    # https://packages.msys2.org/search?t=binpkg&q=<Pkg>

    # msys subsystem
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/autoconf-wrapper-20221207-1-any.pkg.tar.zst"
        SHA512 601ceb483ddf49d744ed7e365317d64777752e35010a1087082452afd42d8d29fc5331cb3fa4654eb09eec85416c8c5b70fed91a45acfaa667f06f80e6d42f30
        PROVIDES autoconf
        DEPS autoconf2.71 bash sed
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/autoconf2.71-2.71-1-any.pkg.tar.zst"
        SHA512 bf725b7d4440764fb21061c066b765193801a03c7ded03cf19ae85aee87ea54059c4283e56877e4e2a54cfec9ef65874160c2cb76de0d08f2550c6032f07c36e
        DEPS awk bash diffutils m4 perl sed
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/autoconf-archive-2022.09.03-1-any.pkg.tar.zst"
        SHA512 d8567215c405632cd9ce232982c79aa1e8c063d13aac7c64a0ba84901c26710f0254ab72ab9ab464a9ec3fb7163ed60cb950b1f0509880f3378066b073a83d80
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/automake-wrapper-20221207-1-any.pkg.tar.zst"
        SHA512 22a65f75d1f19788cab93ecf70cb653fcedf67c18285ccbd2bb74ed1303dae8b09e9cfff40e8733920e75d8c4754d59481fa0c5b07d0c28803809448b011f45f
        PROVIDES automake
        DEPS automake1.16 bash gawk
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/automake1.16-1.16.5-1-any.pkg.tar.zst"
        SHA512 62c9dfe28d6f1d60310f49319723862d29fc1a49f7be82513a4bf1e2187ecd4023086faf9914ddb6701c7c1e066ac852c0209db2c058f3865910035372a4840a
        DEPS bash perl
        PATCHES "${Z_VCPKG_AUTOMAKE_CLANG_CL_PATCH}"
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/bash-5.2.015-1-x86_64.pkg.tar.zst"
        SHA512 2a1e35ccabe023332454cc58f6b9d8c4fdf9fb823f4c8a99127fcf69ab6f7aca35a3d7ea0f4f97378c4f696ef397f48bd30c2379f41d8b5dffd2de0d6177e612
        PROVIDES sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/binutils-2.40-1-x86_64.pkg.tar.zst"
        SHA512 d7f00f93b54fd77102cc2e535303902d0958664eeacf09865a92e572a5bdca11e0782b7b89eb6412c3340a02fc581cbfeb074a5be1b75537422a2b28ed0e6773
        DEPS libiconv libintl zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/bzip2-1.0.8-4-x86_64.pkg.tar.zst"
        SHA512 1d2ce42c6775c0cb0fe9c2863c975fd076579131d0a5bce907355315f357df4ee66869c9c58325f5b698f3aba2413b2823deda86dd27fdb6e2e5e5d4de045259
        DEPS libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/coreutils-8.32-5-x86_64.pkg.tar.zst"
        SHA512 63f99348e654440458f26e9f52ae3289759a5a03428cf2fcf5ac7b47fdf7bf7f51d08e3346f074a21102bee6fa0aeaf88b8ebeba1e1f02a45c8f98f69c8db59c
        DEPS libiconv libintl gmp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/diffutils-3.9-1-x86_64.pkg.tar.zst"
        SHA512 5858c7cfa84b2f79b8e61a34901f43af441cf6e792f534532aeafced4cee470241e72d117cffa5136ffa6ad1b04e2a4e0963080df1b380e9b2657dc7dd9bd193
        DEPS libiconv libintl sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/file-5.44-5-x86_64.pkg.tar.zst"
        SHA512 68d1df9eb548af935b4f3e7f32d0bb3599bf6d59219e229a0501e531b78c6fbecba620c8854f504b44acc48c9bacc4c2420975c598a396ae7f6ae56c742ab6d2
        DEPS gcc-libs libbz2 liblzma libzstd zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/findutils-4.9.0-3-x86_64.pkg.tar.zst"
        SHA512 1538733929ecc11bc7c19797577e4cd59cc88499b375e3c2ea4a8ed4d66a1a02f4468ff916046c76195ba92f4c591d0e351371768117a423595d2e43b3321aad
        DEPS libintl libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gawk-5.2.1-2-x86_64.pkg.tar.zst"
        SHA512 0d056ae2bd906badc4e8ac362bd848800ec0fbe53137c74eb20667b86fa18c7fc0da291c5baec129a8fdfba31216d8500d827475b8ad0e8bcbfb2a0e46ddb95e
        PROVIDES awk
        DEPS libintl libreadline mpfr sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gcc-libs-11.3.0-3-x86_64.pkg.tar.zst" # 05-Jul-2022
        SHA512 eb8dccfa7939f3cb86a585a71d3083dda814bb38ee8484446147533a355520862989716b5ff3e483741496c594314367759646153cb6a4fedc0b44a87373a3fc
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gettext-0.21-2-x86_64.pkg.tar.zst"
        SHA512 2f6b95686e6c9cabfdac22994cbd6402dc22da71ab9582205874e7967452be65a25bf73b8994cce679ef43b26a29dec25eb3f233f7126d8c4b2f5ddd28588bd4
        DEPS libasprintf libgettextpo libintl
    )
    # This package shouldn't be a here
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gettext-devel-0.21-2-x86_64.pkg.tar.zst"
        SHA512 c8852c4c8cf7810434dab18c7a002e59c2248de93b575097a30a31f4e7f41719855c0f3cf55356173576aab03119139f71dce758df1421b3f23c1ca3520e4261
        DEPS gettext # libiconv-devel
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gmp-6.2.1-2-x86_64.pkg.tar.zst"
        SHA512 b2df273243ba08ed2b1117d2b4826900706859c51c1c39ca6e47df2b44b006b2512f7db801738fdbb9411594bc8bc67d308cf205f7fa1aab179863844218e513
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/grep-1~3.0-6-x86_64.pkg.tar.zst"
        SHA512 79b4c652082db04c2ca8a46ed43a86d74c47112932802b7c463469d2b73e731003adb1daf06b08cf75dc1087f0e2cdfa6fec0e8386ada47714b4cff8a2d841e1
        DEPS libiconv libintl libpcre sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/gzip-1.12-2-x86_64.pkg.tar.zst"
        SHA512 107754050a4b0f8633d680fc05aae443ff7326f67517f0542ce2d81b8a1eea204a0006e8dcf3de42abb3be3494b7107c30aba9a4d3d03981e9cacdc9a32ea854
        DEPS bash
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libasprintf-0.21-2-x86_64.pkg.tar.zst"
        SHA512 e583ae8a6611f11ce56bdd8c0e420854d253070072776c78358ee052260fb3c7b1a7a53eed5e3f1e555e883fa489bb6154679ffe91c88e0390596805b1799d71
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libbz2-1.0.8-4-x86_64.pkg.tar.zst"
        SHA512 5a7be6d04e55e6fb1dc0770a8c020ca24a317807c8c8a4813146cd5d559c12a6c61040797b062e441645bc2257b390e12dd6df42519e56278a1fe849fe76a1c4
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libcrypt-2.1-4-x86_64.pkg.tar.zst"
        SHA512 8bd56a777326dc8793df8bc7bc837bbfd9fb888d678fbfded8c37449fcc85aa3e318b5a249f773aa38ef4e12d8c58f080dce7db9c322b649702bdba292708ebc
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libgettextpo-0.21-2-x86_64.pkg.tar.zst"
        SHA512 e5736e2d5b8a7f0df02bab3a4c0e09f5a83069f4ff5554fa176f832b455fe836210686428172a34951db7f4ce6f20ec5428440af06d481fcaa90d632aac4afd2
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libiconv-1.17-1-x86_64.pkg.tar.zst"
        SHA512 e8fc6338d499ccf3a143b3dbdb91838697de76e1c9582bb44b0f80c1d2da5dcfe8102b7512efa798c5409ba9258f4014eb4eccd24a9a46d89631c06afc615678
        DEPS gcc-libs libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libintl-0.21-2-x86_64.pkg.tar.zst"
        SHA512 fd066ea0fa9bc67fe3bcb09ba4d9dd4524611840bb3179e521fa3049dc88ba5e49851cc04cb76d8f0394c4ec1a6bf45c3f6ce6231dc5b0d3eb1f91d983b7f93b
        DEPS gcc-libs libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/liblzma-5.4.1-1-x86_64.pkg.tar.zst"
        SHA512 298a49e0c26587899e37c894f61c9e9c4702548bcc181610fc8408b773097cc3e042b5ae24a4e01ee0b592b68c8f24152f9dcc298b7d1860ffa6562c2513274d
        # This package installs only a DLL. No extra deps.
        DEPS # gettext libiconv sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libpcre-8.45-3-x86_64.pkg.tar.zst"
        SHA512 566a2723f5b078a586d80c077f9267afb7badf3640386640a098d76ef9142797e7fa8acef5e638b962d9479206fb443c924750eec00a26bccdc39fb49094963f
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libreadline-8.2.001-3-x86_64.pkg.tar.zst"
        SHA512 fe8fa6c0d9fd81eab945855b83b9ee8ae224159b3c5eb550424645f2a611e82fd92744093cbcd560a2e2717a142b0dbb3f3cbb627bf41a309483241d3340a9c3
        DEPS ncurses
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libtool-2.4.7-3-x86_64.pkg.tar.zst"
        SHA512 a202ddaefa93d8a4b15431dc514e3a6200c47275c5a0027c09cc32b28bc079b1b9a93d5ef65adafdc9aba5f76a42f3303b1492106ddf72e67f1801ebfe6d02cc
        DEPS sh tar
             # extra deps which are really needed
             awk findutils grep sed
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/libzstd-1.5.4-1-x86_64.pkg.tar.zst"
        SHA512 5aed6a9b2e40759144878f1b5f888f221016fe3fb23ba04f17d515ca51b78c592f79747d90fcc096c735d74cccfeb22c19f2154dfa49d14bedc6c306f0c07759
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/m4-1.4.19-2-x86_64.pkg.tar.zst"
        SHA512 7471099ba7e3b47e5b019dc0e563165a8660722f2bbd337fb579e6d1832c0e7dcab0ca9297c4692b18add92c4ad49e94391c621cf38874e2ff63d4f926bac38c
        DEPS bash gcc-libs libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/make-4.4.1-1-x86_64.pkg.tar.zst"
        SHA512 7e1c95b976d949db4b74c444e0d1495bbee26649aa82eadf34076dba3c1223d4e7b901e07935ba73dceda67f0a0cf25dd99fe3eed5300a5163fdaab14ca8d9fc
        DEPS libintl sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/mpfr-4.2.0-2-x86_64.pkg.tar.zst"
        SHA512 a294154a0c48bbf6673e87f5f38eda9f8a0c99f8300a795c14cd2ec4ae18b39b158b2e76ca1cda51fa76575bd70339cb3b24c4ccf8f265f0e59515f5e457b040
        DEPS gmp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/msys2-runtime-3.4.6-1-x86_64.pkg.tar.zst"
        SHA512 fbdcf2572d242b14ef3b39f29a6119ee58705bad651c9da48ffd11e80637e8d767d20ed5d562f67d92eecd01f7fc3bc351af9d4f84fb9b321d2a9aff858b3619
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/ncurses-6.4-1-x86_64.pkg.tar.zst"
        SHA512 48093633b6506f4217fbe37b43d4e128874a01e5e56f817de38112e5a5b8d3ee4f77e99fb3cd63b55616e3ae84edbc49ac78d90968a24c25dfa368103d208897
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/patch-2.7.6-2-x86_64.pkg.tar.zst"
        SHA512 eb484156e6e93da061645437859531f7b04abe6fef9973027343302f088a8681d413d87c5635a10b61ddc4a3e4d537af1de7552b3a13106639e451b95831ec91
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/perl-5.36.0-1-x86_64.pkg.tar.zst"
        SHA512 fa83a0451b949155bdba53d71d51381d99e4a28dc0f872c53912c8646a5e1858495b8dcfdb0c235975e41de57bc2464eb1e71ffeab96a25c4aa5327cdaa03414
        DEPS coreutils libcrypt sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/pkgconf-1.9.4-1-x86_64.pkg.tar.zst"
        SHA512 0a5f0d69eec591a00d1aee985458dd855100184ec845b076d8f22ca51ba106964b8cf5b0061df288cdd611aa6a6e5fcb98eafded1c46536a0d17253240966f15
        PROVIDES pkg-config
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/sed-4.9-1-x86_64.pkg.tar.zst"
        SHA512 8006a83f0cc6417e3f23ffd15d0cbca2cd332f2d2690232a872ae59795ac63e8919eb361111b78f6f2675c843758cc4782d816ca472fe841f7be8a42c36e8237
        DEPS libintl sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/tar-1.34-3-x86_64.pkg.tar.zst"
        SHA512 19e063393ef0f7eb18df2755798985e78a171f9aa4a747490a357b108d02a9a6a76cae514dd58da0e48a7dd66857dc251be30535677d9fa02e1640bc165cc004
        DEPS libiconv libintl sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/texinfo-7.0.2-1-x86_64.pkg.tar.zst"
        SHA512 f3fc972bb4f738d3a6a736285ee2574262989fdb7bec0f4a260abb1bbfeb94f3fb3795986ba121cf623a96c60eccea2ff67906275acd466c640eae2fe18a2158
        DEPS perl sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/unzip-6.0-2-x86_64.pkg.tar.xz"
        SHA512 b8a1e0ce6deff26939cb46267f80ada0a623b7d782e80873cea3d388b4dc3a1053b14d7565b31f70bc904bf66f66ab58ccc1cd6bfa677065de1f279dd331afb9
        DEPS bash libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/which-2.21-4-x86_64.pkg.tar.zst"
        SHA512 5323fd6635093adf67c24889f469e1ca8ac969188c7f087244a43b3afa0bf8f14579bd87d9d7beb16a7cd61a5ca1108515a46b331868b4817b35cebcb4eba1d1
        DEPS sh
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/xz-5.4.1-1-x86_64.pkg.tar.zst"
        SHA512 5a04e8c244c05926da4bcc63f4fdc731b508c37396629c33e98833c7b6e10c0784b1b0de72f6f11f7f2bdab5ac8eafe2e1613081efd0f973b558200c6ccb6d90
        DEPS libiconv libintl liblzma
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/msys/x86_64/zlib-1.2.13-1-x86_64.pkg.tar.zst"
        SHA512 8dc7525091cf94b1c0646fd21a336cd984385e7e163f925b1f3f786c8be8b884f6cb9b68f55fdb932104c0eb4c8e270fc8df2ec4742404d2dcd0ad9c3e29e7e8
        DEPS gcc-libs
    )

    # mingw64 subsystem
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-bzip2-1.0.8-2-any.pkg.tar.zst"
        SHA512 4f7ba44189d953d4d00e7bbf5a7697233f759c92847c074f0f2888d2a641c59ce4bd3c39617adac0ad7b53c5836e529f9ffd889f976444016976bb517e5c24a2
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-ca-certificates-20230311-1-any.pkg.tar.zst"
        SHA512 f7526ad35bccc5edba3fcf1354a85eacbd61dba5780b1bc65c7e8795ecb252432004af809052bb0ba981b1dea174c40e2d3f20655d8e2b29be95ad54d2aa5782
        DEPS mingw-w64-x86_64-p11-kit
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-expat-2.5.0-1-any.pkg.tar.zst"
        SHA512 b49ec84750387af5b73a78d654673d62cf0e2cb2b59b4d25acb7eca3830018f7a2aefe600d67d843417cfbdd97db81ecfd49a8811e312f53b42c21fb106b230d
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-gcc-libgfortran-12.2.0-10-any.pkg.tar.zst"
        SHA512 0fbe2b01a22c327affcf1581b33912494731ac32c58cc94df740604f6f5a284f89f13508f977f4e15a1345c81e3e8ada3ff5c55bff0a907631d27ed7c0f74677
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-gcc-libs-12.2.0-10-any.pkg.tar.zst"
        SHA512 94b001fa5a2cba5a5fc4b27887cf1dfc930a67dd03a889247b15d51f11280af01c509fe63b7412ec36b549a5a302e1f4d98a13685d1d10068e7d12a4446777a4
        PROVIDES mingw-w64-x86_64-libssp mingw-w64-x86_64-omp
        DEPS mingw-w64-x86_64-libwinpthread
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-gettext-0.21.1-1-any.pkg.tar.zst"
        SHA512 9002289afe530706912eb5b8feffe1d7adb23e01d6b79516ff5deef2faec1577b31890dda15426cc4cc2f30b5f12e55166a4bad492db533234b44cc89fe81117
        DEPS mingw-w64-x86_64-expat mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-gmp-6.2.1-5-any.pkg.tar.zst"
        SHA512 7d884ef1186bd6942f7a7ace28963aae679bb6c6c77c05f186323c44b11894b80f53203a6fad55a0ae112fec41b4e1a624e67021e5f2f529a7fedf35c2755245
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libffi-3.4.4-1-any.pkg.tar.zst"
        SHA512 ec88a0e0cb9b3ff3879d3fd952d3ad52f0d86a42669eddaeca47778ab0d5213abdea7d480a23aa3870e08d6b93b9c4988855e368474be7186e9719456baae5df
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libiconv-1.17-3-any.pkg.tar.zst"
        SHA512 57221118a6ed975ddde322e0d34487d4752c18c62c6184e9ed77ca14fe0a3a78a78aefe628cda3285294a5564d87cd057c56f4864b12fa8580d68b8e8a805e16
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libsystre-1.0.1-4-any.pkg.tar.xz"
        SHA512 6540e896636d00d1ea4782965b3fe4d4ef1e32e689a98d25e2987191295b319eb1de2e56be3a4b524ff94f522a6c3e55f8159c1a6f58c8739e90f8e24e2d40d8
        PROVIDES mingw-w64-x86_64-libgnurx
        DEPS mingw-w64-x86_64-libtre
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libtasn1-4.19.0-1-any.pkg.tar.zst"
        SHA512 761a7c316914d7f98ec6489fb4c06d227e5956d50f2e233ad9be119cfd6301f6b7e4f872316c0bae3913268c1aa9b224b172ab94130489fbd5d7269ff9064cfb
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libtre-git-r128.6fb7206-2-any.pkg.tar.xz"
        SHA512 d595dbcf3a3b6ed098e46f370533ab86433efcd6b4d3dcf00bbe944ab8c17db7a20f6535b523da43b061f071a3b8aa651700b443ae14ec752ae87500ccc0332d
        PROVIDES mingw-w64-x86_64-libtre
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libwinpthread-git-10.0.0.r234.g283e5b23a-1-any.pkg.tar.zst"
        SHA512 e79bb2c93f4c9426c5a5400cd0d3a871c39c56db7068d45b208778fce19a9adb18229ee826397ee2fe8e68df0c554281490315687b3f50b48d6c7f2a6a68ec4b
        PROVIDES mingw-w64-x86_64-libwinpthread
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-mpc-1.3.1-1-any.pkg.tar.zst"
        SHA512 57b86866e2439baa21f296ecb5bdfd624a155dbd260ffe157165e2f8b20bc6fbd5cc446d25dee61e9ed8c28aca941e6f478be3c2d70393f160ed5fd8438e9683
        DEPS mingw-w64-x86_64-gmp mingw-w64-x86_64-mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-mpdecimal-2.5.1-1-any.pkg.tar.zst"
        SHA512 1204c31367f9268ffd6658be04af7687c01f984c9d6be8c7a20ee0ebde1ca9a03b766ef1aeb1fa7aaa97b88a57f7a73afa7f7a7fed9c6b895a032db11e6133bf
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-mpfr-4.2.0-1-any.pkg.tar.zst"
        SHA512 5c8edf4f5ab59afa51cbf1c5ae209583feebaea576e7e3abb59d7e448fe13e143993e6f35117c26ccc221bc6efc44568119c2e25d469c726a592a026b2498d92
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gmp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-ncurses-6.4.20230211-1-any.pkg.tar.zst"
        SHA512 3a86a851805646939dadd9dc4756fea45ffdbd89dec32f8452513d6aa491760861850eec68efb6a48b8b99953d7904547c6d55ff4fd67f20fd2641591781b53c
        DEPS mingw-w64-x86_64-libsystre
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-openblas-0.3.21-7-any.pkg.tar.zst"
        SHA512 e1e49f477cb44f00b5f8760f9c25bd24746844fd076ca0c490b882cfe31204ae100692387e83de22cd89093c102ae751b99bca9dd2d328aaf5de0e401a531e8a
        PROVIDES mingw-w64-x86_64-OpenBLAS
        DEPS mingw-w64-x86_64-gcc-libgfortran mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libwinpthread mingw-w64-x86_64-omp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-openssl-3.1.0-1-any.pkg.tar.zst"
        SHA512 f146d0f2b31b767422c767f4ea39312cbe90eac86e8b248e24d28595069e6cc450351280dd5b837e27ffdd743fb7eb4880360a658f0d2b3709b8a170be3e37d2
        #DEPS mingw-w64-x86_64-ca-certificates mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-p11-kit-0.24.1-5-any.pkg.tar.zst"
        SHA512 cbdecf7bf56ce64605a77b3c700c30322f7b0fbc8efbe2cb7007ae4108815ef96530a57db5631c788b41f1d20fbcad202de92066871bb76c78ea27ea07c848e0
        DEPS mingw-w64-x86_64-gettext mingw-w64-x86_64-libffi mingw-w64-x86_64-libtasn1
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-python-3.10.10-1-any.pkg.tar.zst"
        SHA512 be778ecfd0d4a0f186f0628dab8959596c83b1f1cfaf8554fef63e3b9fd6c5506fa30cf84ad16bbb1eed6793b1f62a5770eff71fa53de6304c0c63d3bb164b00
        PROVIDES mingw-w64-x86_64-python3 mingw-w64-x86_64-python3.10
        DEPS mingw-w64-x86_64-bzip2 mingw-w64-x86_64-expat mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libffi mingw-w64-x86_64-mpdecimal mingw-w64-x86_64-ncurses mingw-w64-x86_64-openssl mingw-w64-x86_64-sqlite3 mingw-w64-x86_64-tcl mingw-w64-x86_64-tk mingw-w64-x86_64-xz mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-python-numpy-1.24.2-1-any.pkg.tar.zst"
        SHA512 0c651815fc7d553430c577d350f460f74b731951125bf44cdbf148c705cb45801c032b98b53315cf98fbf57be3c8f5b598a148f0fbf93dd55079361e05445e7e
        PROVIDES mingw-w64-x86_64-python3-numpy
        DEPS mingw-w64-x86_64-openblas mingw-w64-x86_64-python
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-readline-8.2.001-6-any.pkg.tar.zst"
        SHA512 7b09a854b2225732b8452f6df7ebb378463066da3801ea29372c52ff68b2f6be5ccf8adf3d7d15a75e6fb3d471c5ade7bd4b9fc9599116d269c00bd9adde566e
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-termcap
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-sqlite3-3.41.1-1-any.pkg.tar.zst"
        SHA512 efa7ddcb9326bf25abcac35db36d461fb0817d40f5a6ffc1b412b627df5030a1494b0c87d2f0d0231bc962362d213e6c8eaad7cf057e88f51a0cdd8d2377d327
        PROVIDES mingw-w64-x86_64-sqlite mingw-w64-x86_64-sqlite-analyzer
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-readline mingw-w64-x86_64-tcl mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-termcap-1.3.1-6-any.pkg.tar.zst"
        SHA512 602d182ba0f1e20c4c51ae09b327c345bd736e6e4f22cd7d58374ac68c705dd0af97663b9b94d41870457f46bb9110abb29186d182196133618fc460f71d1300
        DEPS mingw-w64-x86_64-gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-tcl-8.6.12-1-any.pkg.tar.zst"
        SHA512 145e4a1e3093da20cd6755ca8d2b04f7ace87e3ac952d3593880d57f6719a4767ca315543a4f82ee5cb37cff311ff29c446b36484568f65fb6d0c58706763b9b
        DEPS mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-zlib
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-tk-8.6.12-1-any.pkg.tar.zst"
        SHA512 d3eb26a0fa4986ba4f6c77baf48d6fa9d623500f0b72aac9a385ff3c242dc8842eb80b563490995c162869fe3366e8b89d65561b4810b6b661ebbff2161428bf
        DEPS mingw-w64-x86_64-tcl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-xz-5.4.1-1-any.pkg.tar.zst"
        SHA512 93e01ebade4de60f06f4485f083accd9c9e212d2fa2de63acca6d7d31f009a4fb89720da23101018fd74b99415e1fb661cc3f3a7ba4be3cea49dadd768826f33
        DEPS mingw-w64-x86_64-gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-zlib-1.2.13-3-any.pkg.tar.zst"
        SHA512 c07bea5fcc78016da74756612827b662b5dd4901d27f3a3390acc3c39b767806f48b09bd231140a40e3cd7aba76e5d869ed18278c720277e55f831f0c7809d54
    )
endmacro()
