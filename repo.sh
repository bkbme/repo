#!/bin/bash
#Repository management script
#Author: Bernhard Kiesbauer <bernhard@kiesbauer.com>

function printUsage {
  echo "Usage: $0 <distribution> <component> <command> [<packageFile> <packageFile> ... | <packageName>]"
  echo -e "\tWhere <command> is of:"
  echo -e "\t\t-r: Rebuild for all packages"
  echo -e "\t\t-a: Add new package <packageFile>"
  echo -e "\t\t-l: List all info about repo. When <packageName> is supplied: "
  echo -e "\t\t    List only version info about <packageName>"
}

if [ $# -lt 3 ]; then
  printUsage $0
  exit -1
fi

#Vars
company="mycomp"
reporoot=/srv/repo
arch=i386
secretkeyringlocation=/srv/repo/gpg/secring.gpg

dist=$1
component=$2
pkgsrc=$reporoot/$dist/$component
override=$pkgsrc/override
packagesDest=$reporoot/dists/$dist/$component/binary-$arch

#Retrieve field of control file from package
function getField {
  echo `dpkg --info $1  | grep "$2" | awk '{print $2}'`
}

function addToOverride {
  f=$1
  override=$2

  prio=`getField $f Priority`
  section=`getField $f Section`
  name=`getField $f Package`

#Write override file
  echo -e "$name\t$prio\t$section" >> $override
}

#Recreate Packages.gz
function updatePackages {
  pkgsrc=$1
  override=$2
  packagesDest=$3

  mkdir -p $packagesDest 
  echo "Running scanpackages..."
#Info: reporoot needs to be stripped from pkgsrc because the client wont find the
#absolute path.
#The path specified for scanpackages must be accessible relative to the url of the
#repository in the clients sources.list.
  dpkg-scanpackages -m ${pkgsrc/"$reporoot/"/} $override > $packagesDest/Packages
  cat $packagesDest/Packages | gzip > $packagesDest/Packages.gz
}

#Rebuild the override file
function rebuildOverride {
  override=$1
  pkgsrc=$2

#We recreate the override file
  rm -f $override

#Loop over all packages
  debs=`find $pkgsrc -iname "*.deb"`
  for f in $debs; do
    addToOverride $f $override
  done
}

#Create the release file for pinning
function createReleaseFile {
  packagesDest=$1
  components=$2
  dist=$3
  arch=$4
  
  release=dists/$dist/Release
  
  echo "Origin: $company
Label: repo-server
Codename: $dist
Architectures: $arch 
Components: $components
Version: 1.0
MD5Sum:" > $release

  for component in $components; do
    for file in `cd dists/$dist; find $component/binary-$arch/ -type f`; do
      fullpath=dists/$dist/$file
      md5=`md5sum $fullpath | awk '{print $1}'`
      size=`ls -all $fullpath | awk '{print $5}'`
      echo -e " $md5 $size $file" >> $release
    done
  done
 
  releasesec="$release.gpg"
  rm -f $releasesec
  gpg --no-default-keyring --secret-keyring $secretkeyringlocation --output $releasesec -ba $release 
}

case $3 in
"-r")
  #Rebuild
  rebuildOverride $override $pkgsrc
  updatePackages $pkgsrc $override $packagesDest
  createReleaseFile $packagesDest $component $dist $arch
  ;;
"-a")
  #Add package
  if [ $# -lt 4 ]; then
    printUsage $0
    exit -2
  fi

  while [ $# -ge 4 ]; do
    newpkg=$4
    pkgname=`echo $newpkg | awk -F/ '{print $NF}'`
    firstLetter=`echo $pkgname | cut -b1`
    mkdir $pkgsrc/$firstLetter/ 2>/dev/null
    cp $newpkg $pkgsrc/$firstLetter/
    addToOverride $newpkg $override
    shift
  done

  updatePackages $pkgsrc $override $packagesDest
  createReleaseFile $packagesDest $component $dist $arch
  ;;
"-l")
  #List packages
  case $# in
  3)
    zcat $packagesDest/Packages.gz
    ;;
  4)
    zcat $packagesDest/Packages.gz | grep "Package: $4" -A 1
    ;;
  esac
    
  ;;
*)
  printUsage
  exit -3
esac

