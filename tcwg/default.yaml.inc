# -*- mode: Yaml -*-

- property:
    name: default-properties
    properties:
      - authorization:
#if RR_tcwg_bmk
          tcwg-benchmark:
            - job-read
            - job-extended-read
            - job-build
            - job-cancel
#else
          anonymous:
            - job-read
            - job-extended-read
          linaro:
            - job-build
            - job-cancel
#endif
      - build-discarder:
          days-to-keep: 30
          num-to-keep: 30
