#!/bin/bash

set -e

binutils_ver=2.35.2
gcc_ver=10.3.0
mpc_ver=1.2.1
mpfr_ver=4.1.0
gmp_ver=6.2.1
isl_ver=0.23
scons_local_ver=4.1.0
sevenz_ver=1900
# GNU Make 4.3 cannot be cross compiled
make_ver=4.2.1

binutils_file=binutils-${binutils_ver}.tar.xz
binutils_url=https://ftp.gnu.org/gnu/binutils/${binutils_file}

gcc_file=gcc-${gcc_ver}.tar.xz
gcc_url=https://ftp.gnu.org/gnu/gcc/gcc-${gcc_ver}/${gcc_file}

mpc_file=mpc-${mpc_ver}.tar.gz
mpc_url=https://ftp.gnu.org/gnu/mpc/${mpc_file}

mpfr_file=mpfr-${mpfr_ver}.tar.xz
mpfr_url=https://ftp.gnu.org/gnu/mpfr/${mpfr_file}

gmp_file=gmp-${gmp_ver}.tar.xz
gmp_url=https://ftp.gnu.org/gnu/gmp/${gmp_file}

isl_file=isl-${isl_ver}.tar.bz2
isl_url=https://libisl.sourceforge.io/${isl_file}

scons_local_file=scons-local-${scons_local_ver}.zip
scons_local_url=https://sourceforge.net/projects/scons/files/${scons_local_file}

make_file=make-${make_ver}.tar.gz
make_url=http://ftp.gnu.org/gnu/make/${make_file}

case $1 in
  arm-godot-linux-gnueabihf)
  ;;
  i686-godot-linux-gnu)
  ;;
  x86_64-godot-linux-gnu)
  ;;
  aarch64-godot-linux-gnu)
  ;;
  *)
    echo "usage: $0 <tuple>"
    echo "tuple can be one of : arm-godot-linux-gnueabihf, i686-godot-linux-gnu, x86_64-godot-linux-gnu, aarch64-godot-linux-gnu"
    exit 1
  ;;
esac

target_arch=$1
godot_toolchain_dir="$(pwd)/godot-toolchains"
base_dir="$(pwd)/windows-build"
target_dir="${base_dir}/${target_arch}_sdk-buildroot"

function unpack_linux_sdk() {
  mkdir -p "${base_dir}"
  tar xf "${godot_toolchain_dir}/${target_arch}_sdk-buildroot.tar.bz2" -C "${base_dir}"
  rm "${target_dir}/bin/"{gcc,g++,cpp,ar,ranlib,gcc-ar,gcc-ranlib}
}

function pack_windows_sdk() {
  pushd "${target_dir}/bin"
    cp ${base_dir}/../pkg-config.bat .
    unzip "${base_dir}/download/${scons_local_file}"
  popd

  pushd "${target_dir}"
    for link in $(find -type l); do
      echo "mklink \"${link}\" \"$(readlink ${link})\"" >> fix-sdk.bat
      rm "${link}"
    done

    echo "mklink \"bin/gcc.exe\" \"${target_arch}-gcc.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/g++.exe\" \"${target_arch}-g++.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/ar.exe\" \"${target_arch}-ar.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/ranlib.exe\" \"${target_arch}-ranlib.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/gcc-ar.exe\" \"${target_arch}-gcc-ar.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/gcc-ranlib.exe\" \"${target_arch}-gcc-ranlib.exe\"" >> fix-sdk.bat
    echo "mklink \"bin/lto-wrapper.exe\" \"../libexec/gcc/${target_arch}/${gcc_ver}/lto-wrapper.exe\"" >> fix-sdk.bat
  popd

  pushd ${base_dir}
    cat ../installer.nsis | sed -e "s/TARGET_ARCH/${target_arch}/g" > installer.nsis
    makensis installer.nsis
    mv "Godot-SDK-${target_arch}.exe" ../godot-toolchains
  popd
}

function download() {
  mkdir -p "${base_dir}/download"

  for component in make scons_local binutils gcc mpc mpfr gmp isl; do
    component_file=${component}_file
    component_url=${component}_url
    if [ ! -e "${base_dir}/download/${!component_file}" ]; then
      curl -L ${!component_url} --output "${base_dir}/download/${!component_file}"
    fi
  done
}

function unpack() {
  mkdir -p "${base_dir}/src"

  if [ ! -e "${base_dir}/src/gcc" ]; then
    mkdir -p "${base_dir}/src/gcc"
    pushd "${base_dir}/src/gcc"
    tar --strip-components=1 -xf "${base_dir}/download/${gcc_file}"
    for component in mpc mpfr gmp isl; do
      component_file=${component}_file
      mkdir ${component}
      pushd $component
      tar --strip-components=1 -xf "${base_dir}/download/${!component_file}"
      popd
    done
    popd
  fi

  if [ ! -e "${base_dir}/src/binutils" ]; then
     mkdir -p "${base_dir}/src/binutils"
     pushd "${base_dir}/src/binutils"
     tar --strip-components=1 -xf "${base_dir}/download/${binutils_file}"
     popd
  fi

  if [ ! -e "${base_dir}/src/make" ]; then
     mkdir -p "${base_dir}/src/make"
     pushd "${base_dir}/src/make"
     tar --strip-components=1 -xf "${base_dir}/download/${make_file}"
     popd
  fi
}

function build_gcc() {

  mkdir -p "${base_dir}/build"
  rm -rf "${base_dir}/build/gcc"
  mkdir -p "${base_dir}/build/gcc"
  pushd "${base_dir}/build/gcc"

  flags="$(${target_dir}/bin/${target_arch}-gcc -v 2>&1 | grep Configured\ with:)"
  skip="prefix sysconfdir with-sysroot with-gmp with-mpc with-mpfr with-pkgversion with-bugurl with-isl with-build-time-tools"
  newflags="--prefix=${target_dir} --sysconfdir=${target_dir}/etc --enable-static --host=x86_64-w64-mingw32  --build=x86_64-linux-gnu --with-sysroot=${target_dir}/${target_arch}/sysroot --with-static-standard-libraries"
  
  for flag in ${flags}; do
    keep=1
    if ! echo ${flag} | grep -qE '^--'; then
      keep=0
    fi
  
    for s in ${skip}; do
      if echo ${flag} | grep -qE "^--${s}"; then
        keep=0
        break
      fi
    done
  
    if [ ${keep} -eq 1 ]; then
      newflags="${newflags} ${flag}"
    fi
  done

  "${base_dir}/src/gcc/configure" ${newflags} LDFLAGS="-lssp"
  make -j
  make install-strip
  popd
}

function build_binutils() {

  mkdir -p "${base_dir}/build"
  rm -rf "${base_dir}/build/binutils"
  mkdir -p "${base_dir}/build/binutils"
  pushd "${base_dir}/build/binutils"

  "${base_dir}/src/binutils/configure" --with-static-standard-libraries --prefix=${target_dir} --with-sysroot=${target_dir}/${target_arch}/sysroot --enable-lto --host=x86_64-w64-mingw32 --build=x86_64-linux-gnu --target=${target_arch} LDFLAGS="-lssp"
  make -j
  make install-strip
  popd
}

function build_make() {

  mkdir -p "${base_dir}/build"
  rm -rf "${base_dir}/build/make"
  mkdir -p "${base_dir}/build/make"
  pushd "${base_dir}/build/make"

  "${base_dir}/src/make/configure" --prefix=${target_dir} --host=x86_64-w64-mingw32 --build=x86_64-linux-gnu LDFLAGS="-lssp"
  make -j
  make install-strip
  popd
}

function cleanup_sdk() {
  rm -f "${target_dir}/relocate-sdk.sh"

  for directory in $(find ${target_dir} -name *.exe -printf %h\\n | sort -u); do
    cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/libssp-0.dll ${directory}
    cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/libwinpthread-1.dll ${directory}
  done
  
  while read -r file; do
    rm -f $(echo $file | sed -e 's/\.exe$//')
  done < <(find ${target_dir} -name *.exe)
  
  while read -r file; do
    rm -f $(echo $file | sed -e 's/\.dll$/.so/')
  done < <(find ${target_dir} -name *.dll)
  
  find ${target_dir}/bin -type l -delete
  find ${target_dir}/bin -name 'python*' -delete

  # Filename case issues, kind of breaks the SDK for some uses but probably OK
  rm -rf "${target_dir}/${target_arch}/sysroot/usr/include/linux/netfilter"
  rm -rf "${target_dir}/${target_arch}/sysroot/usr/include/linux/netfilter_ipv4"
  rm -rf "${target_dir}/${target_arch}/sysroot/usr/include/linux/netfilter_ipv6"
  
  rm -rf ${target_dir}/lib/python*
}

export PATH=${target_dir}/bin:${PATH}
export HOSTCC=${target_arch}-gcc
export HOSTCXX=${target_arch}-g++

rm -rf "${target_dir}"

download
unpack
unpack_linux_sdk
build_make
build_binutils
build_gcc

cleanup_sdk
pack_windows_sdk
