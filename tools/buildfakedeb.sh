#!/bin/bash

function print_usage {
  echo "Usage:  $0 <name> <version> [<dependency>]"
  echo -e "\tCreates debian dummy package"
}

if [ $# -lt 2 ]; then
  print_usage
  exit -1
fi

name=$1
version=$2
pkg=pkg
mkdir -p $pkg/DEBIAN
echo "Package: $name
Version: $version
Section: main
Priority: optional
Architecture: all
Essential: yes
Maintainer: bernhard kiesbauer <kiesbauer@arges.de>
Description: dummpy package $1" > $pkg/DEBIAN/control

if [ $# -eq 3 ]; then
  echo "Depends: $3" >> $pkg/DEBIAN/control
fi

mkdir -p $pkg/usr/local
echo "This is $name in Version $version" > $pkg/usr/local/$name-$version.txt

dpkg-deb -b $pkg $name-$version.deb
rm -rf $pkg
