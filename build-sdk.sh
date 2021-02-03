#!/bin/bash
set -e
 
function usage() {
  echo "usage: $0 i686|x86_64|aarch64"
  exit 1
}

if [ -z $1 ]; then
  usage
fi

case $1 in
  i686)
    cp config-godot-i686 .config
  ;;
  x86_64)
    cp config-godot-x86_64 .config
  ;;
  aarch64)
    cp config-godot-aarch64 .config
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
${container} run -it --rm -v $(pwd):/tmp/buildroot -w /tmp/buildroot -e FORCE_UNSAFE_CONFIGURE=1 --userns=keep-id godot-buildroot-builder bash -c "make olddefconfig; make clean sdk"

mkdir -p godot-toolchains
mv output/images/$1-godot-linux-gnu_sdk-buildroot.tar.gz godot-toolchains

echo
echo "***************************************"
echo "Build succesful your toolchain is in the godot-toolchains directory"
