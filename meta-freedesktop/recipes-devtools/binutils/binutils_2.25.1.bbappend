FILESEXTRAPATHS_append := ":${THISDIR}/${PN}"
SRC_URI += "\
        fix-internal-error-when-applying-TLSDESC-relocs-without-TLS-segment.patch \
        "
