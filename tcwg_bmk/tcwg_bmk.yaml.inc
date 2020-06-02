# -*- mode: Yaml -*-

#include tcwg/round-robin.yaml.inc

- property:
    name: bmk-properties
    properties:
      - authorization:
          tcwg-benchmark:
            - job-read
            - job-extended-read
            - job-build
            - job-cancel
      - build-discarder:
          days-to-keep: 30
          num-to-keep: 30



