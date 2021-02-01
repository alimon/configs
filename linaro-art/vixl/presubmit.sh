#!/bin/bash -xe

vixl_repo="https://github.com/Linaro/vixl.git"

mkdir -p "${HOME}/bin"
export PATH="${HOME}/bin:${PATH}"

# Only x86 image contains no clang tools.
if [[ "$(uname -p)" == "x86_64" ]]; then
  sudo apt-get update
  sudo apt-get install -y clang-4.0 scons clang-format-4.0 clang-tidy-4.0
fi

wget --no-verbose --output-document "${HOME}/bin/cpplint.py" \
  https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py
chmod +x "${HOME}/bin/cpplint.py"

git config --global user.name "vixl-build-bot"
git config --global user.email "vixl-build-bot@fake-email.invalid"

cd vixl/
./tools/test.py ${VIXL_TEST_ARGS}
