#!/bin/sh
set -ex

/usr/bin/env python -m pip install --user requests
/usr/bin/env python -c "import requests; print(requests.__version__)"
