#!/bin/bash -xe

vixl_repo="https://git.linaro.org/arm/vixl.git"

mkdir -p "${HOME}/bin"
export PATH="${HOME}/bin:${PATH}"

echo 'deb http://ports.ubuntu.com/ubuntu-ports xenial main universe' \
  | sudo tee /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y clang scons clang-format-4.0 clang-tidy-4.0

wget --no-verbose --output-document "${HOME}/bin/cpplint.py" \
  https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py
chmod +x "${HOME}/bin/cpplint.py"

git config --global user.name "vixl-build-bot"
git config --global user.email "vixl-build-bot@fake-email.invalid"

git clone "${vixl_repo}" vixl
cd vixl
git pull "${vixl_repo}" "${GERRIT_REFSPEC}"
./tools/test.py ${VIXL_TEST_ARGS}
