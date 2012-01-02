#!/bin/bash
#Remotly invoking the repo command
#Author Bernhard Kiesbaeur <bernhard@kiesbauer.com>

function printUsage {
  echo "$0 Usage: <remote-host> <repo commands>"
}

if [ $# -lt 2 ]; then
  printUsage
  exit -1
fi

#Location of the repo command on remove host
repo=/srv/repo/repo.sh
#The remote host
host=$1

#Throw $1 away
shift

#Get all .deb files in parameters
toks=""
for t in "$@"; do
  toks="$toks\n$t"
done
debfiles=`echo -e $toks | grep ".deb"`

if [ "$debfiles" != "" ]; then
#In case of debfiles: copy them to tmpdir,
#replace the filename in the parameters
#and call the repo command with modifed parameters
  tmpdir=`ssh $host mktemp -d`
  scp $debfiles $host:$tmpdir
  repocommand="$@"
  for f in $debfiles; do
    repocommand="${repocommand/$f/$tmpdir/$f}"
  done
  ssh $host $repo $repocommand; rm -rf $tmpdir
else
#Just call the remot repo command
  ssh $host $repo $@
fi

