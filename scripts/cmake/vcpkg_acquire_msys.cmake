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
#   - Z_VCPKG_MSYS_${arg_NAME}_ARCHIVE
#   - Z_VCPKG_MSYS_${arg_NAME}_PATCHES
function(z_vcpkg_acquire_msys_declare_package)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAME;URL;SHA512" "DEPS;PATCHES")

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

        list(APPEND Z_VCPKG_MSYS_ARCHIVES "${arg_NAME}")
        set(Z_VCPKG_MSYS_ARCHIVES "${Z_VCPKG_MSYS_ARCHIVES}" PARENT_SCOPE)
        set(Z_VCPKG_MSYS_${arg_NAME}_ARCHIVE "${archive}" PARENT_SCOPE)
        set(Z_VCPKG_MSYS_${arg_NAME}_PATCHES "${arg_PATCHES}" PARENT_SCOPE)
        string(APPEND Z_VCPKG_MSYS_TOTAL_HASH "${arg_SHA512}")
        foreach(patch IN LISTS arg_PATCHES)
            file(SHA512 "${patch}" patch_sha)
            string(APPEND Z_VCPKG_MSYS_TOTAL_HASH "${patch_sha}")
        endforeach()
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

    set(Z_VCPKG_MSYS_TOTAL_HASH "")
    set(Z_VCPKG_MSYS_ARCHIVES "")

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
            string(REGEX MATCH "^(([^-]+(-[^0-9][^-]*)*)-.+\.pkg\.tar\.(xz|zst))$" pkg_name "${filename}")
            set(pkg_name "${CMAKE_MATCH_2}")
            list(APPEND Z_VCPKG_MSYS_ARCHIVES "${pkg_name}")
            set(Z_VCPKG_MSYS_${pkg_name}_ARCHIVE "${archive}")
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
        URL "https://repo.msys2.org/msys/x86_64/gzip-1.12-2-x86_64.pkg.tar.zst"
        SHA512 107754050a4b0f8633d680fc05aae443ff7326f67517f0542ce2d81b8a1eea204a0006e8dcf3de42abb3be3494b7107c30aba9a4d3d03981e9cacdc9a32ea854
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/texinfo-6.8-3-x86_64.pkg.tar.zst"
        SHA512 5cc16d3b3c3b9859fe61233fa27f2146526e2b4d6e626814d283b35bfd77bc15eb4ffaec00bde6c10df93466d9155a06854a7ecf2e0d9af746dd56c4d88d192e
        DEPS bash perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/bash-5.2.015-1-x86_64.pkg.tar.zst"
        SHA512 2a1e35ccabe023332454cc58f6b9d8c4fdf9fb823f4c8a99127fcf69ab6f7aca35a3d7ea0f4f97378c4f696ef397f48bd30c2379f41d8b5dffd2de0d6177e612
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/autoconf-2.71-3-any.pkg.tar.zst"
        SHA512 f639deac9b2191c2096584cf374103bbb1e9d2476dd0ebec94b1e80da59be25b88e362ac5280487a89f0bb0ed57f99b66e314f36b7de9cda03c0974806a3a4e2
        DEPS m4 perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/autoconf-archive-2023.02.20-1-any.pkg.tar.zst"
        SHA512 0dbdba67934402eeb974e6738eb9857d013342b4e3a11200710b87fbf085d5bebf49b29b6a14b6ff2511b126549919a375b68f19cc22aa18f6ba23c57290ac72
        DEPS m4 perl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/diffutils-3.9-1-x86_64.pkg.tar.zst"
        SHA512 5858c7cfa84b2f79b8e61a34901f43af441cf6e792f534532aeafced4cee470241e72d117cffa5136ffa6ad1b04e2a4e0963080df1b380e9b2657dc7dd9bd193
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/binutils-2.40-1-x86_64.pkg.tar.zst"
        SHA512 d7f00f93b54fd77102cc2e535303902d0958664eeacf09865a92e572a5bdca11e0782b7b89eb6412c3340a02fc581cbfeb074a5be1b75537422a2b28ed0e6773
        DEPS libiconv libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libtool-2.4.7-3-x86_64.pkg.tar.zst"
        SHA512 a202ddaefa93d8a4b15431dc514e3a6200c47275c5a0027c09cc32b28bc079b1b9a93d5ef65adafdc9aba5f76a42f3303b1492106ddf72e67f1801ebfe6d02cc
        DEPS grep sed coreutils file findutils
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/file-5.44-5-x86_64.pkg.tar.zst"
        SHA512 68d1df9eb548af935b4f3e7f32d0bb3599bf6d59219e229a0501e531b78c6fbecba620c8854f504b44acc48c9bacc4c2420975c598a396ae7f6ae56c742ab6d2
        DEPS gcc-libs zlib libbz2
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/zlib-1.2.13-1-x86_64.pkg.tar.zst"
        SHA512 8dc7525091cf94b1c0646fd21a336cd984385e7e163f925b1f3f786c8be8b884f6cb9b68f55fdb932104c0eb4c8e270fc8df2ec4742404d2dcd0ad9c3e29e7e8
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/bzip2-1.0.8-4-x86_64.pkg.tar.zst"
        SHA512 1d2ce42c6775c0cb0fe9c2863c975fd076579131d0a5bce907355315f357df4ee66869c9c58325f5b698f3aba2413b2823deda86dd27fdb6e2e5e5d4de045259
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libbz2-1.0.8-4-x86_64.pkg.tar.zst"
        SHA512 5a7be6d04e55e6fb1dc0770a8c020ca24a317807c8c8a4813146cd5d559c12a6c61040797b062e441645bc2257b390e12dd6df42519e56278a1fe849fe76a1c4
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/coreutils-8.32-5-x86_64.pkg.tar.zst"
        SHA512 63f99348e654440458f26e9f52ae3289759a5a03428cf2fcf5ac7b47fdf7bf7f51d08e3346f074a21102bee6fa0aeaf88b8ebeba1e1f02a45c8f98f69c8db59c
        DEPS libiconv libintl gmp
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/grep-1~3.0-6-x86_64.pkg.tar.zst"
        SHA512 79b4c652082db04c2ca8a46ed43a86d74c47112932802b7c463469d2b73e731003adb1daf06b08cf75dc1087f0e2cdfa6fec0e8386ada47714b4cff8a2d841e1
        DEPS libiconv libintl libpcre
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/sed-4.9-1-x86_64.pkg.tar.zst"
        SHA512 8006a83f0cc6417e3f23ffd15d0cbca2cd332f2d2690232a872ae59795ac63e8919eb361111b78f6f2675c843758cc4782d816ca472fe841f7be8a42c36e8237
        DEPS libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libpcre-8.45-3-x86_64.pkg.tar.zst"
        SHA512 566a2723f5b078a586d80c077f9267afb7badf3640386640a098d76ef9142797e7fa8acef5e638b962d9479206fb443c924750eec00a26bccdc39fb49094963f
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/m4-1.4.19-2-x86_64.pkg.tar.zst"
        SHA512 7471099ba7e3b47e5b019dc0e563165a8660722f2bbd337fb579e6d1832c0e7dcab0ca9297c4692b18add92c4ad49e94391c621cf38874e2ff63d4f926bac38c
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/automake-wrapper-20221207-1-any.pkg.tar.zst"
        SHA512 22a65f75d1f19788cab93ecf70cb653fcedf67c18285ccbd2bb74ed1303dae8b09e9cfff40e8733920e75d8c4754d59481fa0c5b07d0c28803809448b011f45f
        DEPS gawk
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gawk-5.2.1-2-x86_64.pkg.tar.zst"
        SHA512 0d056ae2bd906badc4e8ac362bd848800ec0fbe53137c74eb20667b86fa18c7fc0da291c5baec129a8fdfba31216d8500d827475b8ad0e8bcbfb2a0e46ddb95e
        DEPS libintl libreadline mpfr
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/mpfr-4.2.0.p12-1-x86_64.pkg.tar.zst"
        SHA512 6a21c4f6c863b53478a0b59d5c541c91e13faae1118fb7a4c4b5b5cfe30cf2548445ac6400cba318393dc8b62fd51433a32115204aac95e45348d7cb8628e133
        DEPS gmp gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gmp-6.2.1-2-x86_64.pkg.tar.zst"
        SHA512 b2df273243ba08ed2b1117d2b4826900706859c51c1c39ca6e47df2b44b006b2512f7db801738fdbb9411594bc8bc67d308cf205f7fa1aab179863844218e513
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/xz-5.4.2-1-x86_64.pkg.tar.zst" # this seems to require immediate updating on version bumps.
        SHA512 d5a5b834c1c236a1cdcb9a385501fa3a425ba8660d24975e4fb1fa0fba792650bb49dc68ab8604a926e7cf980c4ea606a32efb349a0f75824c10079f5bbd50e8
        DEPS liblzma libiconv gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/liblzma-5.4.2-1-x86_64.pkg.tar.zst"
        SHA512 69561b09ee46fc4d516e50a5b3f6a85ea36328018eca48dc8246afbe0dd27cc61bb8f3e7a894495d93d040f2f92de6f89290c37b9710abb2b0bbdd46e78cf994
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libreadline-8.2.001-3-x86_64.pkg.tar.zst"
        SHA512 fe8fa6c0d9fd81eab945855b83b9ee8ae224159b3c5eb550424645f2a611e82fd92744093cbcd560a2e2717a142b0dbb3f3cbb627bf41a309483241d3340a9c3
        DEPS ncurses
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/ncurses-6.4-1-x86_64.pkg.tar.zst"
        SHA512 48093633b6506f4217fbe37b43d4e128874a01e5e56f817de38112e5a5b8d3ee4f77e99fb3cd63b55616e3ae84edbc49ac78d90968a24c25dfa368103d208897
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/automake1.16-1.16.5-1-any.pkg.tar.zst"
        SHA512 62c9dfe28d6f1d60310f49319723862d29fc1a49f7be82513a4bf1e2187ecd4023086faf9914ddb6701c7c1e066ac852c0209db2c058f3865910035372a4840a
        DEPS perl
        PATCHES "${SCRIPTS}/msys/compile_wrapper_consider_clang-cl.patch"
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/perl-5.36.0-1-x86_64.pkg.tar.zst"
        SHA512 fa83a0451b949155bdba53d71d51381d99e4a28dc0f872c53912c8646a5e1858495b8dcfdb0c235975e41de57bc2464eb1e71ffeab96a25c4aa5327cdaa03414
        DEPS libcrypt
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libcrypt-2.1-4-x86_64.pkg.tar.zst"
        SHA512 8bd56a777326dc8793df8bc7bc837bbfd9fb888d678fbfded8c37449fcc85aa3e318b5a249f773aa38ef4e12d8c58f080dce7db9c322b649702bdba292708ebc
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/pkg-config-0.29.2-4-x86_64.pkg.tar.zst"
        SHA512 9f72c81d8095ca1c341998bc80788f7ce125770ec4252f1eb6445b9cba74db5614caf9a6cc7c0fcc2ac18d4a0f972c49b9f245c3c9c8e588126be6c72a8c1818
        DEPS libiconv
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/make-4.4.1-1-x86_64.pkg.tar.zst"
        SHA512 7e1c95b976d949db4b74c444e0d1495bbee26649aa82eadf34076dba3c1223d4e7b901e07935ba73dceda67f0a0cf25dd99fe3eed5300a5163fdaab14ca8d9fc
        DEPS libintl msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gettext-devel-0.21-1-x86_64.pkg.tar.zst"
        SHA512 44444064b9860dbd3cb886812fb20ee97ab04a65616cca497be69c592d5507e7bc66bfe8dbd060a4df9c5d9bb44cb0f231584d65cb04351146d54d15852227af
        DEPS gettext
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/gettext-0.21-2-x86_64.pkg.tar.zst"
        SHA512 2f6b95686e6c9cabfdac22994cbd6402dc22da71ab9582205874e7967452be65a25bf73b8994cce679ef43b26a29dec25eb3f233f7126d8c4b2f5ddd28588bd4
        DEPS libintl libgettextpo libasprintf tar
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/tar-1.34-3-x86_64.pkg.tar.zst"
        SHA512 19e063393ef0f7eb18df2755798985e78a171f9aa4a747490a357b108d02a9a6a76cae514dd58da0e48a7dd66857dc251be30535677d9fa02e1640bc165cc004
        DEPS libiconv libintl
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libgettextpo-0.21-2-x86_64.pkg.tar.zst"
        SHA512 e5736e2d5b8a7f0df02bab3a4c0e09f5a83069f4ff5554fa176f832b455fe836210686428172a34951db7f4ce6f20ec5428440af06d481fcaa90d632aac4afd2
        DEPS gcc-libs
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/libasprintf-0.21-2-x86_64.pkg.tar.zst"
        SHA512 e583ae8a6611f11ce56bdd8c0e420854d253070072776c78358ee052260fb3c7b1a7a53eed5e3f1e555e883fa489bb6154679ffe91c88e0390596805b1799d71
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
        URL "https://repo.msys2.org/msys/x86_64/gcc-libs-11.3.0-3-x86_64.pkg.tar.zst"
        SHA512 eb8dccfa7939f3cb86a585a71d3083dda814bb38ee8484446147533a355520862989716b5ff3e483741496c594314367759646153cb6a4fedc0b44a87373a3fc
        DEPS msys2-runtime
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/msys2-runtime-3.3-3.3.6-11-x86_64.pkg.tar.zst"
        SHA512 ea3a503ea5aaa0264d507efd4d929bb071fce4e86afd1666b97e23cf999863e165526d43a28e7fbf986df344f5cbbb75040c6c3ec138f1b185766f0e8e934e38
    )
    z_vcpkg_acquire_msys_declare_package(
        URL "https://repo.msys2.org/msys/x86_64/which-2.21-4-x86_64.pkg.tar.zst"
        SHA512 5323fd6635093adf67c24889f469e1ca8ac969188c7f087244a43b3afa0bf8f14579bd87d9d7beb16a7cd61a5ca1108515a46b331868b4817b35cebcb4eba1d1
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
        URL "https://repo.msys2.org/mingw/mingw32/mingw-w64-i686-libwinpthread-git-11.0.0.r107.gd367cc9d7-1-any.pkg.tar.zst"
        SHA512 b0ca0b737226b97fd7e6abb70980a5c8cfbf6b34d27ae0081e649ef830d5d5a3e92394186c25620b1164def734dd3d79e45552c6de89f3614296a944938d2649
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
                COMMAND "${CMAKE_COMMAND}" -E tar xzf "${Z_VCPKG_MSYS_${archive}_ARCHIVE}"
                LOGNAME "msys-${TARGET_TRIPLET}-${index}"
                WORKING_DIRECTORY "${path_to_root}.tmp"
            )
            math(EXPR index "${index} + 1")
            if(Z_VCPKG_MSYS_${archive}_PATCHES)
                z_vcpkg_apply_patches(
                    SOURCE_PATH "${path_to_root}.tmp"
                    PATCHES ${Z_VCPKG_MSYS_${archive}_PATCHES}
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
