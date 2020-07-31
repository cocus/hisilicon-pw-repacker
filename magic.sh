#!/bin/bash

# Example on how to use this script:
# ./magic.sh dump.bin output.bin
# where dump.bin is the raw image obtained by reading the
# SPI flash, and output.bin is the output filename that
# will be used to flash the SPI memory later

DUMP_FILE="dump.bin"
# If a second argument is passed, use it as the input file name
[ ! -z $1 ] && DUMP_FILE="$1"

OUT_FILE="new-dump.bin"
# If a third argument is passed, use it as the output file name
[ ! -z $2 ] && OUT_FILE="$2"

[ ! -f ${DUMP_FILE} ] && echo "Input file ${DUMP_FILE} doesn't exists, can't continue!" && exit 1

TMP_DIR="${DUMP_FILE}_out"
EXTRACTED_JFFS2_DIR="${TMP_DIR}/mtd_part"

JFFS2_ERASE_BLOCK=64
JFFS2_NEW_FILE="new-part.jffs2"

JFFS2_CUSTOM_EXTENSION="jeff"

NEW_PASSWORD_HASH="tlJwpbo6"

# Check if the system has the pre-requisites
! which binwalk && echo "binwalk is missing. try to run sudo apt install binwalk first" && exit 1
! which jefferson && echo "jefferson is missing. try to install it from it's github page first" && exit 1
! which jq && echo "jq is missing. try to run sudo apt install jq first" && exit 1
! which mkfs.jffs2 && echo "mkfs.jffs2 is missing. try to run sudo apt install mtd-utils first" && exit 1

[ -d ${TMP_DIR} ] && echo "Removing old temporary directory first" && rm -rf ${DUMP_FILE}_out

mkdir -p ${TMP_DIR}

echo "Extracting the JFFS2 partition from the dump file..."

binwalk --exclude='xz' --exclude='zlib' --exclude='squashfs' --exclude='lzma' \
    --exclude='cramfs' --exclude='gzip' \
    --dd="jffs2 filesystem:${JFFS2_CUSTOM_EXTENSION}" \
    --directory=${TMP_DIR} \
    --log=${TMP_DIR}/parts.csv --csv \
    dump.bin
[ $? -ne 0 ] && echo "Error extracting the JFFS2 from the dump file, please check the binwalk output for more info" && exit 1
echo "Done"

EXTRACTED_FILES=$(find ${TMP_DIR}/*/*.${JFFS2_CUSTOM_EXTENSION})
EXTRACTED_FILES_COUNT=$(echo "${EXTRACTED_FILES}" | wc -l)

echo "EXTRACTED_FILES = ${EXTRACTED_FILES}"
echo "EXTRACTED_FILES_COUNT = ${EXTRACTED_FILES_COUNT}"

[ "x${EXTRACTED_FILES_COUNT}" != "x1" ] && "Exactly one file should've been extracted, can't continue!" && exit 1

PART_FILE="$(basename ${EXTRACTED_FILES})"
# The filename should be the offset in hex, so take it for the re pack step
PART_OFFSET="0x$(basename ${EXTRACTED_FILES} .${JFFS2_CUSTOM_EXTENSION})"

echo "PART_FILE = ${PART_FILE}"
echo "PART_OFFSET = ${PART_OFFSET}"

echo "Extracting the contents of the JFFS2 partition..."

jefferson --dest ${EXTRACTED_JFFS2_DIR} ${EXTRACTED_FILES}
[ $? -ne 0 ] && echo "Error extracting the JFFS2 filesystem, please check jefferson's output for more info" && exit 1
echo "Done"

echo "Checking for the presence of Account1 or Account2 files"
EXTRACTED_JFFS2_DIR_FS=$(ls -d ${EXTRACTED_JFFS2_DIR}/* | head -n 1)
echo "EXTRACTED_JFFS2_DIR_FS = ${EXTRACTED_JFFS2_DIR_FS}"

[ ! -d ${EXTRACTED_JFFS2_DIR_FS} ] && echo "No fs_* directories were found on the extracted JFFS2 filesystem, can't continue!" && exit 1

EXTRACTED_JFFS2_DIR_ACCOUNT1="${EXTRACTED_JFFS2_DIR_FS}/Config/Account1"
EXTRACTED_JFFS2_DIR_ACCOUNT2="${EXTRACTED_JFFS2_DIR_FS}/Config/Account2"
[ ! -f ${EXTRACTED_JFFS2_DIR_ACCOUNT1} ] && echo "Account1 not found on the extracted JFFS2 filesystem, can't continue!" && exit 1
[ ! -f ${EXTRACTED_JFFS2_DIR_ACCOUNT2} ] && echo "Account2 not found on the extracted JFFS2 filesystem, can't continue!" && exit 1

echo "Account1 and Account2 found!"

echo "Old passwords hashes on Account1:"
echo "User0: " $(jq '.Users[0].Name,.Users[0].Password' ${EXTRACTED_JFFS2_DIR_ACCOUNT1})
echo "User1: " $(jq '.Users[1].Name,.Users[1].Password' ${EXTRACTED_JFFS2_DIR_ACCOUNT1})

echo "Setting them to the default ${NEW_PASSWORD_HASH}..."
jq '.Users[0].Password = $newVal' --arg newVal "${NEW_PASSWORD_HASH}" \
    ${EXTRACTED_JFFS2_DIR_ACCOUNT1} > ${TMP_DIR}/tmp.$$.json && \
    mv ${TMP_DIR}/tmp.$$.json ${EXTRACTED_JFFS2_DIR_ACCOUNT1}
jq '.Users[1].Password = $newVal' --arg newVal "${NEW_PASSWORD_HASH}" \
    ${EXTRACTED_JFFS2_DIR_ACCOUNT1} > ${TMP_DIR}/tmp.$$.json && \
    mv ${TMP_DIR}/tmp.$$.json ${EXTRACTED_JFFS2_DIR_ACCOUNT1}


echo "Old passwords hashes on Account2:"
echo "User0: " $(jq '.Users[0].Name,.Users[0].Password' ${EXTRACTED_JFFS2_DIR_ACCOUNT2})
echo "User1: " $(jq '.Users[1].Name,.Users[1].Password' ${EXTRACTED_JFFS2_DIR_ACCOUNT2})

echo "Setting them to the default ${NEW_PASSWORD_HASH}..."
jq '.Users[0].Password = $newVal' --arg newVal "${NEW_PASSWORD_HASH}" \
    ${EXTRACTED_JFFS2_DIR_ACCOUNT2} > ${TMP_DIR}/tmp.$$.json && \
    mv ${TMP_DIR}/tmp.$$.json ${EXTRACTED_JFFS2_DIR_ACCOUNT2}
jq '.Users[1].Password = $newVal' --arg newVal "${NEW_PASSWORD_HASH}" \
    ${EXTRACTED_JFFS2_DIR_ACCOUNT2} > ${TMP_DIR}/tmp.$$.json && \
    mv ${TMP_DIR}/tmp.$$.json ${EXTRACTED_JFFS2_DIR_ACCOUNT2}

echo "Done"

echo "Packing a new JFFS2 filesystem..."
mkfs.jffs2 -r ${EXTRACTED_JFFS2_DIR_FS} \
    -e ${JFFS2_ERASE_BLOCK} \
    -o ${TMP_DIR}/${JFFS2_NEW_FILE}
[ $? -ne 0 ] && echo "Error creating the new JFFS2 image, can't continue!" && exit 1
echo "Done"

NEW_JFFS2_SIZE=$(du --apparent-size --block-size=1 "${TMP_DIR}/${JFFS2_NEW_FILE}" | awk '{ print $1}')
echo "NEW_JFFS2_SIZE = ${NEW_JFFS2_SIZE}"

DUMP_FILE_SIZE=$(du --apparent-size --block-size=1 "${DUMP_FILE}" | awk '{ print $1}')
echo "DUMP_FILE_SIZE = ${DUMP_FILE_SIZE}"

# To calculate the padding, take the start address of the mtd partition
# from the dump size, then take the new JFFS2 image size.
PADDING="$(($DUMP_FILE_SIZE-$PART_OFFSET-$NEW_JFFS2_SIZE))"

echo "Padding should be ${PADDING} bytes, creating it..."
dd if=/dev/zero of=${TMP_DIR}/padding.bin bs=${PADDING} count=1
echo "Done"

echo "Creating the new full binary... "
# Get the full image preceding the mtd partition we're after
dd if=${DUMP_FILE} of=${TMP_DIR}/${DUMP_FILE}_beginning.bin bs="$(($PART_OFFSET))" count=1
# Now add the new JFFS2 iamge and the padding
cat ${TMP_DIR}/${DUMP_FILE}_beginning.bin \
    ${TMP_DIR}/${JFFS2_NEW_FILE} \
    ${TMP_DIR}/padding.bin > ${OUT_FILE}
echo "Done!"

echo "Sanity checking that ${DUMP_FILE} and ${OUT_FILE} have the same sizes..."
OUT_FILE_SIZE=$(du --apparent-size --block-size=1 "${OUT_FILE}" | awk '{ print $1}')
[ ${DUMP_FILE_SIZE} -ne ${OUT_FILE_SIZE} ] && echo "File sizes don't match. Output file might not work!"
echo "Finally, DONE!"