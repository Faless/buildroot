#!/bin/bash
set -e
 
function usage() {
  echo "usage: $0 i686|x86_64|armv7"
  exit 1
}

if [ -z $1 ]; then
  usage
fi

case $1 in
  i686)
    cp config-godot-i686 .config
    toolchain_prefix=i686-godot-linux-gnu
  ;;
  x86_64)
    cp config-godot-x86_64 .config
    toolchain_prefix=x86_64-godot-linux-gnu
  ;;
  armv7)
    cp config-godot-armv7 .config
    toolchain_prefix=arm-godot-linux-gnueabihf
  ;;
  *)
    usage
  ;;
esac

if which podman &> /dev/null; then
  container=podman
elif which docker &> /dev/null; then
  container=docker
else
  echo "Podman or docker have to be in \$PATH"
  exit 1
fi

${container} build -f Dockerfile.builder -t godot-buildroot-builder
${container} run -it --rm -v $(pwd):/tmp/buildroot -w /tmp/buildroot -e FORCE_UNSAFE_CONFIGURE=1 --userns=keep-id godot-buildroot-builder scl enable devtoolset-9 "bash -c make syncconfig; make clean sdk"

mkdir -p godot-toolchains
mv output/images/${toolchain_prefix}_sdk-buildroot.tar.gz godot-toolchains

echo
echo "***************************************"
echo "Build succesful your toolchain is in the godot-toolchains directory"
