# Override the arch with `make ARCH=i386`
VERSION = 1.5
ARCH   ?= $(shell flatpak --default-arch)

# Canned recipe for generating metadata
#   $1 = the input file to substitute
#   $2 = the output to create
define subst-metadata
	@echo -n "Generating ${2}... ";		\
	sed -e 's/@@ARCH@@/${ARCH}/g' 		\
	    -e 's/@@VERSION@@/${VERSION}/g'	\
	   ${1} > ${2}.tmp && mv ${2}.tmp ${2} || exit 1;
	@echo "Done.";
endef

srcdir = $(CURDIR)
builddir = $(CURDIR)
NULL=
HASH:=$(shell git rev-parse HEAD)
IMAGEDIR=images/${ARCH}
SDK_IMAGE=${IMAGEDIR}/freedesktop-contents-sdk-${ARCH}-${HASH}.tar.gz
PLATFORM_IMAGE=${IMAGEDIR}/freedesktop-contents-platform-${ARCH}-${HASH}.tar.gz
IMAGES= ${SDK_IMAGE} ${PLATFORM_IMAGE}
REF_PLATFORM=runtime/org.freedesktop.BasePlatform/${ARCH}/${VERSION}
REF_SDK=runtime/org.freedesktop.BaseSdk/${ARCH}/${VERSION}
FILE_REF_PLATFORM=repo/refs/heads/${REF_PLATFORM}
FILE_REF_SDK=repo/refs/heads/${REF_SDK}

all: ${FILE_REF_PLATFORM} ${FILE_REF_SDK}

COMMIT_ARGS=--repo=repo --owner-uid=0 --owner-gid=0 --no-xattrs

${IMAGES} allimages:
	rm -f ${IMAGEDIR}/freedesktop-contents-*.tar.gz # Remove all old images to make space
	rm -rf build/*/tmp-glibc/deploy/images/*/freedesktop-contents-*.tar.gz
	git submodule update --init
	mkdir -p build/${ARCH}
	./freedesktop-sdk-build-yocto ${srcdir}/ ${builddir}/build/ ${ARCH} ${HASH}

.PHONY: sdk platform

sdk: ${FILE_REF_SDK}

${FILE_REF_SDK}: metadata.sdk.in ${SDK_IMAGE}
	if [ !  -d repo ]; then  ostree  init --mode=archive-z2 --repo=repo;  fi
	rm -rf sdk
	mkdir sdk
	(cd sdk; tar --transform 's,^./usr,files,S' --transform 's,^./etc,files/etc,S' --exclude="./[!eu]*" -xvf ../${SDK_IMAGE}  > /dev/null)
	$(call subst-metadata,metadata.sdk.in,sdk/metadata)
	ostree commit ${COMMIT_ARGS} ${GPG_ARGS} --branch=${REF_SDK}  -s "build of ${HASH}" sdk
	ostree summary -u --repo=repo ${GPG_ARGS}
	rm -rf sdk

platform: ${FILE_REF_PLATFORM}

${FILE_REF_PLATFORM}: metadata.platform.in ${PLATFORM_IMAGE}
	if [ !  -d repo ]; then  ostree  init --mode=archive-z2 --repo=repo;  fi
	rm -rf platform
	mkdir platform
	(cd platform; tar --transform 's,^./usr,files,S' --transform 's,^./etc,files/etc,S' --exclude="./[!eu]*" -xvf ../${PLATFORM_IMAGE}  > /dev/null)
	$(call subst-metadata,metadata.platform.in,platform/metadata)
	ostree commit ${COMMIT_ARGS} ${GPG_ARGS} --branch=${REF_PLATFORM}  -s "build of ${HASH}" platform
	ostree summary -u --repo=repo ${GPG_ARGS}
	rm -rf platform
