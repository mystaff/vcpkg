# Automatically generated by scripts/boost/generate-ports.ps1

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boostorg/bind
    REF boost-${VERSION}
    SHA512 178fa4b8396b6a76c20cff40e029ae1b36d6f0b199636bda1b34ea7c2cb827d6f09e45e364547e30120e63e5e17c8280df62ecdda6e163f83919cc21bfaeb01a
    HEAD_REF master
)

set(FEATURE_OPTIONS "")
boost_configure_and_install(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS ${FEATURE_OPTIONS}
)
