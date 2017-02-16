#!/bin/bash

set -e

log()   { echo ">>> $1" ; }

sed -i "s|<username>|$OSC_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OSC_PASSWORD|g" /root/.oscrc

# build the spec file
log "building the spec file"
velum-git-resource/packaging/suse/make_spec.sh velum

pushd velum-osc-resource/home:m_meister:branches:Virtualization:containers:Velum/velum 1> /dev/null
  log "updating osc checkout to newest revision"
  osc up
  log "removing old specfile"
  osc rm velum.spec
  log "adding new specfile"
  cp ../../../velum-git-resource/packaging/suse/velum.spec .
popd 1> /dev/null

cp -a velum-osc-resource/home:m_meister:branches:Virtualization:containers:Velum/velum/. velum-osc-updated-resource/
