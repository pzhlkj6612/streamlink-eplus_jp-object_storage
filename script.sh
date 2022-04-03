#!/usr/bin/env bash

set -e
set -o pipefail

# bash - YYYY-MM-DD format date in shell script - Stack Overflow
#   https://stackoverflow.com/a/1401495

printf -v the_datetime '%(%Y%m%d-%H%M%S)T' -1

#############
# Utilities #

function test_variable() {
    # "set -u" doesn't work in some cases.

    set -u

    if [[ -z "${!1}" ]]; then
        echo "ENV '${1}' not found."
        exit 1
    fi

    set +u
}

# Utilities #
#############

##############
# Streamlink #

function test_streamlink_variables() {
    test_variable 'EPLUS_JP_STREAM_URL'
    test_variable 'EPLUS_JP_STREAM_QUALITY'
}

function download_eplus_stream() {
    echo '------ vvvvvv Streamlink vvvvvv'

    test_streamlink_variables

    set -u

    streamlink \
        --plugin-dirs='/SL-plugins' \
        --output "${1}" \
        --force \
        --loglevel=trace \
        "${EPLUS_JP_STREAM_URL}" \
        "${EPLUS_JP_STREAM_QUALITY}"

    set +u

    echo '------ ^^^^^^ Streamlink ^^^^^^'
}

function generate_dummy_mpeg_ts() {
    # for test

    echo '------ vvvvvv FFmpeg generates MPEG-TS vvvvvv'

    set -u

    # Creating a video from a single image for a specific duration in ffmpeg - Stack Overflow
    #   https://stackoverflow.com/q/25891342
    # [FFmpeg-user] How to specify duration for an input with pipe protocol
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043163.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043165.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043166.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043175.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043176.html

    curl -L 'https://www.lovelive-anime.jp/yuigaoka/img/clear.jpg' |
        ffmpeg \
            -i - \
            -c:v 'libopenh264' \
            -filter:v 'loop=loop=-1:size=1' \
            -t '00:00:04' \
            -r 2 \
            "${1}"

    set +u

    echo '------ ^^^^^^ FFmpeg generates MPEG-TS ^^^^^^'
}

# Streamlink #
##############

##########
# FFmpeg #

function ffmpeg_transcode() {
    echo '------ vvvvvv FFmpeg transcode vvvvvv'

    set -u

    ffmpeg \
        -i "${1}" \
        -c copy \
        "${2}"

    set +u

    echo '------ ^^^^^^ FFmpeg transcode ^^^^^^'
}

function generate_dummy_mp4() {
    # for test

    echo '------ vvvvvv Generate dummy MP4 vvvvvv'

    set -u

    echo "${1}" >"${1}"

    set +u

    echo '------ ^^^^^^ Generate dummy MP4 ^^^^^^'
}

# FFmpeg #
##########

#########
# S3cmd #

function test_s3_variables() {
    test_variable 'AWS_ACCESS_KEY_ID'
    test_variable 'AWS_SECRET_ACCESS_KEY'
    test_variable 'S3_BUCKET'
    test_variable 'S3_HOSTNAME'
}

function init_s3() {
    echo '------ vvvvvv S3cmd init vvvvvv'

    test_s3_variables

    s3cmd --version

    s3cmd \
        --host="${S3_HOSTNAME}" \
        --host-bucket='%(bucket)s.'"${S3_HOSTNAME}" \
        info "${S3_BUCKET}"

    echo '------ ^^^^^^ S3cmd init ^^^^^^'
}

function upload_to_s3() {
    echo '------ vvvvvv S3cmd upload vvvvvv'

    set -u

    s3cmd \
        --host="${S3_HOSTNAME}" \
        --host-bucket='%(bucket)s.'"${S3_HOSTNAME}" \
        --progress \
        put "${1}" "${S3_BUCKET}"

    set +u

    echo '------ ^^^^^^ S3cmd upload ^^^^^^'
}

# S3cmd #
#########

#############
# Azure CLI #

function test_azure_variables() {
    test_variable 'AZURE_STORAGE_ACCOUNT'
    test_variable 'AZ_SP_APPID'
    test_variable 'AZ_SP_PASSWORD'
    test_variable 'AZ_SP_TENANT'
    test_variable 'AZ_STORAGE_CONTAINER_NAME'
}

function init_azure() {
    echo '------ vvvvvv Azure CLI init vvvvvv'

    test_azure_variables

    az version

    az login \
        --service-principal \
        --username "${AZ_SP_APPID}" \
        --password "${AZ_SP_PASSWORD}" \
        --tenant "${AZ_SP_TENANT}"

    az extension add -n storage-blob-preview

    # test if storage container is accessible. Exit code 3 if not found.
    az storage container show \
        --name "${AZ_STORAGE_CONTAINER_NAME}"

    echo '------ ^^^^^^ Azure CLI init ^^^^^^'
}

function upload_to_azure() {
    echo '------ vvvvvv Azure CLI vvvvvv'

    set -u

    file_name="${1##*/}"

    az storage blob upload \
        --container-name "${AZ_STORAGE_CONTAINER_NAME}" \
        --content-md5 "$(openssl dgst -md5 -binary "${1}" | base64)" \
        --file "${1}" \
        --name "${file_name}" \
        --tier 'Cool' \
        --validate-content

    set +u

    echo '------ ^^^^^^ Azure CLI ^^^^^^'
}

# Azure CLI #
#############

################################################
# Get file's information, rename it, upload it #

function obtain_calculate_rename_upload() {
    echo '------ vvvvvv obtain calculate rename upload vvvvvv'

    set -u

    echo "the original file path: '${1}'"

    the_file_name="$(basename -- "${1}")"
    the_file_dir="${1%/${the_file_name}}"

    the_file_byte_size="$(du -b "${1}" | awk '{ print $1 }')"
    the_file_md5="$(md5sum "${1}" | awk '{ print $1 }')"

    the_file_final_name="${the_file_name%.*}.${the_file_byte_size}.${the_file_md5}.${the_file_name##*.}"
    the_file_final_path="${the_file_dir}/${the_file_final_name}"

    echo "the final file path:    '${the_file_final_path}'"

    mv "${1}" "${the_file_final_path}"

    set +u

    if [[ -z "${NO_S3}" ]]; then
        upload_to_s3 "${the_file_final_path}"
    fi

    if [[ -z "${NO_AZURE}" ]]; then
        upload_to_azure "${the_file_final_path}"
    fi

    echo '------ ^^^^^^ obtain calculate rename upload ^^^^^^'
}

# Get file's information, rename it, upload it #
################################################

##############
# ENTRYPOINT #

function main() {
    test_variable 'OUTPUT_FILENAME_BASE'

    output_ts_base_path="/SL-downloads/${the_datetime}.${OUTPUT_FILENAME_BASE}.ts"

    output_mp4_base_path="/SL-downloads/${the_datetime}.${OUTPUT_FILENAME_BASE}.mp4"

    if [[ -z "${NO_S3}" ]]; then
        init_s3
    fi

    if [[ -z "${NO_AZURE}" ]]; then
        init_azure
    fi

    if [[ -z "${NO_DOWNLOAD_STREAM}" ]]; then
        download_eplus_stream "${output_ts_base_path}"
    else
        generate_dummy_mpeg_ts "${output_ts_base_path}"
    fi

    if [[ -z "${NO_TRANSCODE}" ]]; then
        ffmpeg_transcode "${output_ts_base_path}" "${output_mp4_base_path}"
    else
        generate_dummy_mp4 "${output_mp4_base_path}"
    fi

    obtain_calculate_rename_upload "${output_ts_base_path}"

    obtain_calculate_rename_upload "${output_mp4_base_path}"
}

# ENTRYPOINT #
##############

main

exit 0
