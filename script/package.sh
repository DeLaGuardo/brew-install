#!/bin/bash

set -e

# Clean
echo "Cleaning"
rm -rf target

# Grab version
version=$(mvn -B help:evaluate -Dexpression=project.version 2>/dev/null| grep -v "^\[")
echo "Building scripts version $version"

# Build uberjar and filter resources
echo "Building uberjar"
mvn -B clean package -Dmaven.test.skip=true

# Make tar file of jar and script
echo "Building scripts tar file"
mkdir -p target/clojure-tools
chmod +x target/classes/clojure target/classes/clj target/classes/install.sh
cp target/classes/clojure target/classes/clj target/classes/deps.edn target/classes/example-deps.edn target/classes/install.sh "target/clojure-tools-$version.jar" doc/clojure.1 target/clojure-tools
cp doc/clojure.1 target/clojure-tools/clj.1
tar -cvzf "target/clojure-tools-$version.tar.gz" -Ctarget clojure-tools

# Make zip file of jar and windows scripts
echo "Building scripts zip file"
mkdir -p target/win/ClojureTools
cp target/classes/ClojureTools.psd1 target/classes/ClojureTools.psm1 target/classes/deps.edn target/classes/example-deps.edn "target/clojure-tools-$version.jar" target/win/ClojureTools
cd target/win
zip -r "../clojure-tools-$version.zip" ClojureTools
cd ../..

# Create formula file (brew)
echo "Creating formula file"
cp target/classes/clojure.rb target
sha=$(shasum -a 256 "target/clojure-tools-$version.tar.gz" | cut -c 1-64)
perl -pi.bak -e "s,SHA,$sha,g" target/clojure.rb

if [ -x "$(command -v rpmbuild)" ]; then
    # Create rpm package (CentOS's yum)
    echo "Building RPM file"
    mkdir -p target/rpmbuild/SOURCES
    cp target/classes/clojure.spec target
    cp "target/clojure-tools-$version.tar.gz" target/rpmbuild/SOURCES
    rpmbuild --target i386--linux \
             --define "_topdir $(pwd)/target/rpmbuild" \
             --define "_target %{nil}" \
             --define "VERSION $version" \
             -ba target/clojure.spec
else
    echo "Skip RPM build."
    echo "Missing rpmbuild tool is required to build the package."
fi

if [ -x "$(command -v makepkg)" ]; then
    # Create PKGBUILD file (Archlinux)
    echo "Building PKGBUILD file"
    mkdir -p target/aurbuild
    cp target/classes/PKGBUILD target/aurbuild/PKGBUILD
    cp "target/clojure-tools-$version.tar.gz" target/aurbuild
    perl -pi.bak -e "s,VERSION,$version,g" target/aurbuild/PKGBUILD
    perl -pi.bak -e "s,SHA,$sha,g" target/aurbuild/PKGBUILD
    pushd target/aurbuild
    makepkg -d -c
    popd
else
    echo "Skip PKGBUILD build."
    echo "Missing makepkg tool is required to build the package."
fi

# Deploy to s3
if [[ ! -z "$S3_BUCKET" ]]; then
  echo "Deploying https://download.clojure.org/install/clojure-tools-$version.tar.gz"
  aws s3 cp --only-show-errors "target/clojure-tools-$version.tar.gz" "$S3_BUCKET/install/clojure-tools.tar.gz"
  aws s3 cp --only-show-errors "target/clojure-tools-$version.tar.gz" "$S3_BUCKET/install/clojure-tools-$version.tar.gz"
  echo "Deploying https://download.clojure.org/install/clojure-$version.rb"
  aws s3 cp --only-show-errors "target/clojure.rb" "$S3_BUCKET/install/clojure.rb"
  aws s3 cp --only-show-errors "target/clojure.rb" "$S3_BUCKET/install/clojure-$version.rb"
  echo "Deploying https://download.clojure.org/install/linux-install-$version.sh for compatibility."
  aws s3 cp --only-show-errors "target/classes/install.sh" "$S3_BUCKET/install/linux-install.sh"
  aws s3 cp --only-show-errors "target/classes/install.sh" "$S3_BUCKET/install/linux-install-$version.sh"
  echo "Deploying https://download.clojure.org/install/install-$version.sh"
  aws s3 cp --only-show-errors "target/classes/install.sh" "$S3_BUCKET/install/install.sh"
  aws s3 cp --only-show-errors "target/classes/install.sh" "$S3_BUCKET/install/install-$version.sh"
  echo "Deploying https://download.clojure.org/install/clojure-tools-$version.zip"
  aws s3 cp --only-show-errors "target/clojure-tools-$version.zip" "$S3_BUCKET/install/clojure-tools.zip"
  aws s3 cp --only-show-errors "target/clojure-tools-$version.zip" "$S3_BUCKET/install/clojure-tools-$version.zip"
  echo "Deploying https://download.clojure.org/install/win-install-$version.ps1"
  aws s3 cp --only-show-errors "target/classes/win-install.ps1" "$S3_BUCKET/install/win-install.ps1"
  aws s3 cp --only-show-errors "target/classes/win-install.ps1" "$S3_BUCKET/install/win-install-$version.ps1"
fi
