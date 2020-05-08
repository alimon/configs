- property:
    name: default-properties
    properties:
      - authorization:
          anonymous:
            - job-read
            - job-extended-read
          linaro:
            - job-build
            - job-cancel
      - build-discarder:
          days-to-keep: 30
          num-to-keep: 30
