#!/bin/bash

set -ex

docker images --filter reference="*/debian*:${kolla_tag}" --quiet|xargs docker image rm
