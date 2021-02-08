#!/bin/bash

set -e

if [ -z $1 ] || [ -z $2 ]; then
  echo "usage: $0 arch bits"
  exit 1
fi

arch=$1
bits=$2

bin_to_keep="aclocal autoconf autoheader automake autoreconf cmake gawk libtool m4 meson ninja pkgconf pkg-config python3 scons tar toolchain-wrapper"
lib_to_keep="cmake gcc libpkgconf libpython3.9 libz libisl libmpc libmpfr libgmp libffi python3.9 pkgconfig"
share_to_keep="aclocal autoconf buildroot cmake gcc libtool pkgconfig"
sysroot_share_to_keep="aclocal pkgconfig"

function clean_directory() {
  pushd $1
  files_to_keep="${@:2}"

  for file in $(ls -1); do
    keep_file=0
  
    if echo ${file} | grep -qe "^${arch}"; then
      keep_file=1
    fi
  
    for keep in ${files_to_keep}; do
      if echo ${file} | grep -qe "^${keep}"; then
        keep_file=1
        break
      fi
    done
  
    if [ ${keep_file} -eq 0 ]; then
      rm -rf ${file}
    fi
  done

  popd
}

rm -f $(find -name *.a | grep -vE '(nonshared|gcc|libstdc++)')
find -regex '.*\.so\(\..*\)?' -exec bin/${arch}-strip {} \; 2> /dev/null
find bin -exec bin/${arch}-strip {} \; 2> /dev/null
find ${arch}/bin -exec bin/${arch}-strip {} \; 2> /dev/null
find libexec/gcc -type f -exec bin/${arch}-strip {} \; 2> /dev/null

clean_directory bin ${bin_to_keep}
clean_directory lib ${lib_to_keep}
clean_directory share ${share_to_keep}
clean_directory ${arch}/sysroot/usr/share ${sysroot_share_to_keep}

find -name *.pyc -delete

rm -f usr lib64
rm -rf sbin var

for s in bin lib lib64 sbin; do
  if [ -L ${arch}/sysroot/${s} ]; then
    rm -f ${arch}/sysroot/${s}
  fi
done

if [ ${bits} == 64 ]; then
  libdir_to_remove=lib
  libdir_to_keep=lib64
else
  libdir_to_remove=lib64
  libdir_to_keep=lib
fi

rm -rf ${arch}/sysroot/usr/{bin,sbin}

mkdir -p ${arch}/sysroot/${libdir_to_keep}
cp ${arch}/sysroot/usr/${libdir_to_keep}/libpthread*so* ${arch}/sysroot/${libdir_to_keep}
cp ${arch}/sysroot/usr/${libdir_to_keep}/ld-linux*so* ${arch}/sysroot/${libdir_to_keep}
cp ${arch}/sysroot/usr/${libdir_to_keep}/libc*so* ${arch}/sysroot/${libdir_to_keep}

if [ -L ${arch}/sysroot/usr/${libdir_to_keep} ]; then
  rm ${arch}/sysroot/usr/${libdir_to_keep}
  mv ${arch}/sysroot/usr/${libdir_to_remove} ${arch}/sysroot/usr/${libdir_to_keep}
  mkdir ${arch}/sysroot/usr/${libdir_to_remove}
  mv ${arch}/sysroot/usr/${libdir_to_keep}/crt*.o ${arch}/sysroot/usr/${libdir_to_remove}
  mv ${arch}/sysroot/usr/${libdir_to_keep}/pkgconfig ${arch}/sysroot/usr/${libdir_to_remove}
  # But why tho
  mv ${arch}/sysroot/usr/${libdir_to_keep}/pulseaudio ${arch}/sysroot/usr/${libdir_to_remove}
fi

find -name *python2* -exec rm -rf {} \; || true
