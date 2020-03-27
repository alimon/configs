#!/bin/bash

set -ex

docker images --filter reference="linaro/debian-source*:${kolla_tag}" --quiet|xargs docker image rm
