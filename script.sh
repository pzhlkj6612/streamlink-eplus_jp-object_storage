#!/usr/bin/env bash

set -e
set -o pipefail

# bash - YYYY-MM-DD format date in shell script - Stack Overflow
#   https://stackoverflow.com/a/1401495

TZ=UTC printf -v the_datetime '%(%Y%m%dT%H%M%SZ)T' -1

echo "------ the_datetime = ${the_datetime}"

# How do I kill background processes / jobs when my shell script exits? - Stack Overflow
#   https://stackoverflow.com/q/360201/360275#comment112697932_360275
trap 'jobs -pr | xargs -r kill' SIGINT SIGTERM EXIT

#############
# Utilities #

function test_variable() {
    if [[ -z "${!1}" ]]; then
        echo "ENV '${1}' not found."
        exit 1
    fi
}

# Utilities #
#############

############
# Commands #

streamlink_record_stdout_no_url_no_default_stream_partial_command=(
    'streamlink'
        '--plugin-dirs=''/SL-plugins'
        '--stdout'
        '--loglevel=trace'
        ${STREAMLINK_OPTIONS}
        # '--url'
        # '--default-stream'
)

if [[ -n "${HTTPS_PROXY}" ]]; then
    streamlink_record_stdout_no_url_no_default_stream_partial_command+=(
        '--http-proxy' "${HTTPS_PROXY}"
    )
fi

ytdlp_record_stdout_no_url_no_format_partial_command=(
    'yt-dlp'
        '--output' '-'
        '--verbose'
        ${YTDLP_OPTIONS}
        # '--format'
        # 'URL'
)

if [[ -f '/YTDLP/cookies.txt' ]]; then
    ytdlp_record_stdout_no_url_no_format_partial_command+=(
        '--cookies' '/YTDLP/cookies.txt'
    )
fi

if [[ -n "${HTTPS_PROXY}" ]]; then
    ytdlp_record_stdout_no_url_no_format_partial_command+=(
        '--proxy' "${HTTPS_PROXY}"
    )
fi

n_m3u8dl_re_record_stdout_no_url_no_format_partial_command=(
    'RE_LIVE_PIPE_OPTIONS=" -f flv -flvflags no_duration_filesize"'
    'N_m3u8DL-RE'
        '--live-pipe-mux'
        '--no-ansi-color'
        '--auto-select'
        '--log-level' 'DEBUG'
        ${N_m3u8DL_RE_OPTIONS}
        # 'URL'
)

if [[ -n "${HTTPS_PROXY}" ]]; then
    n_m3u8dl_re_record_stdout_no_url_no_format_partial_command+=(
        '--custom-proxy' "${HTTPS_PROXY}"
    )
fi

curl_download_stdout_no_url_partial_command=(
    'curl'
        '--verbose' '--trace-time'
        '--location'
        # 'URL'
)

ffmpeg_common_global_arguments=(
    '-loglevel' 'level+info'
)

ffmpeg_online_image_generate_still_image_mpegts_video_stdout_command=(
    # Creating a video from a single image for a specific duration in ffmpeg - Stack Overflow
    #   https://stackoverflow.com/q/25891342
    # [FFmpeg-user] How to specify duration for an input with pipe protocol
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043163.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043165.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043166.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043175.html
    #   http://ffmpeg.org/pipermail/ffmpeg-user/2019-February/043176.html

    'ffmpeg'
        "${ffmpeg_common_global_arguments[@]}"
        '-i' 'https://www.lovelive-anime.jp/yuigaoka/img/clear.jpg'
        '-c:v' 'libopenh264'
        '-filter:v' 'loop=loop=-1:size=1'
        '-t' '00:00:04'
        '-r' '2'
        '-f' 'mpegts'
        '-'
)

if [[ -n "${RTMP_FFMPEG_USE_AAC_ENCODING}" ]]; then
    ffmpeg_audio_encoding_arguments=(
        '-c:a' 'aac'
    )
else
    ffmpeg_audio_encoding_arguments=(
        '-c:a' 'copy'
    )
fi

if [[ -n "${RTMP_FFMPEG_USE_LIBX264_ENCODING}" ]]; then
    ffmpeg_video_encoding_arguments=(
        '-c:v' 'libx264'
            '-preset' 'ultrafast'
            '-tune' 'zerolatency'
            '-profile:v' 'baseline'
            '-crf' "${RTMP_FFMPEG_CRF:-23}"
    )
else
    ffmpeg_video_encoding_arguments=(
        '-c:v' 'copy'
    )
fi

ffmpeg_stdin_stream_transcode_flv_rtmp_no_target_url_partial_command=(
    # ffmpeg - Explanation of x264 tune - Super User
    #   https://superuser.com/q/564402

    'ffmpeg'
        "${ffmpeg_common_global_arguments[@]}"
        '-re'
        '-i' '-'
        "${ffmpeg_audio_encoding_arguments[@]}"
        "${ffmpeg_video_encoding_arguments[@]}"
        '-f' 'flv'
            '-flvflags' 'no_duration_filesize'
        # 'URL'
)

# Commands #
############

#############
# Processor #

#
# $1: output_ts_base_path
#
function process_stream_and_video() {
    echo '------ vvvvvv process stream and video vvvvvv'

    # Prepare input

    in_pipe="$(mktemp -u)"
    mkfifo --mode=600 "${in_pipe}"

    if [[ -n "${USE_EXISTING_MPEG_TS_VIDEO_FILE}" ]]; then
        # (.ts)-> pipe

        0<"${1}" \
        1>"${in_pipe}" \
        dd &

    elif [[ -n "${STREAMLINK_STREAM_URL}" ]]; then
        # streamlink --(.ts)-> pipe

        streamlink_record_stdout_command=(
            "${streamlink_record_stdout_no_url_no_default_stream_partial_command[@]}"
            '--url' "${STREAMLINK_STREAM_URL}"
            '--default-stream' "${STREAMLINK_STREAM_QUALITY:-best}"
        )

        1>"${in_pipe}" \
        "${streamlink_record_stdout_command[@]}" &

    elif [[ -n "${YTDLP_STREAM_URL}" ]]; then
        # yt-dlp --(.ts)-> pipe

        ytdlp_record_stdout_command=(
            "${ytdlp_record_stdout_no_url_no_format_partial_command[@]}"
            "${YTDLP_STREAM_URL}"
        )

        1>"${in_pipe}" \
        "${ytdlp_record_stdout_command[@]}" &

    elif [[ -n "${N_m3u8DL_RE_STREAM_URL}" ]]; then
        # yt-dlp --(.ts)-> pipe

        n_m3u8dl_re_record_stdout_command=(
            "${n_m3u8dl_re_record_stdout_no_url_no_format_partial_command[@]}"
            "${N_m3u8DL_RE_STREAM_URL}"
        )

        1>"${in_pipe}" \
        "${n_m3u8dl_re_record_stdout_command[@]}" &

    elif [[ -n "${VIDEO_FILE_URL}" ]]; then
        # curl -> pipe

        curl_download_stdout_command=(
            "${curl_download_stdout_no_url_partial_command[@]}"
            "${VIDEO_FILE_URL}"
        )

        1>"${in_pipe}" \
        "${curl_download_stdout_command[@]}" &

    elif [[ -n "${GENERATE_STILL_IMAGE_MPEG_TS}" ]]; then
        # ffmpeg --(.ts)-> pipe

        1>"${in_pipe}" \
        "${ffmpeg_online_image_generate_still_image_mpegts_video_stdout_command[@]}" &

    fi

    in_pid="$!"

    if [[ -z "${in_pid}" ]]; then
        echo "No input specified."
        exit 2
    fi

    # Prepare outputs

    out_pipes=()

    if [[ -n "${USE_EXISTING_MPEG_TS_VIDEO_FILE}" ]]; then
        NO_DOWNLOAD_TS=1
    fi

    if [[ -z "${NO_DOWNLOAD_TS}" ]]; then
        # pipe ->(.ts)

        if [[ -f "${1}" ]]; then
            echo "File exists, no overwriting it. Path: ${1}"
            exit 3
        fi

        copy_ts_pipe="$(mktemp -u)"
        mkfifo --mode=600 "${copy_ts_pipe}"

        0<"${copy_ts_pipe}" \
        1>"${1}" \
        dd &

        out_pipes+=("${copy_ts_pipe}")

    fi

    if [[ -n "${RTMP_TARGET_URL}" ]]; then
        # pipe -> ffmpeg --(.flv)-> rtmp

        ffmpeg_stdin_stream_transcode_flv_rtmp_command=(
            "${ffmpeg_stdin_stream_transcode_flv_rtmp_no_target_url_partial_command[@]}"
            "${RTMP_TARGET_URL}"
        )

        rtmp_ts_pipe="$(mktemp -u)"
        mkfifo --mode=600 "${rtmp_ts_pipe}"

        0<"${rtmp_ts_pipe}" \
        "${ffmpeg_stdin_stream_transcode_flv_rtmp_command[@]}" &

        out_pipes+=("${rtmp_ts_pipe}")

    fi

    # to T, or not to T.

    output_number="${#out_pipes[@]}"

    echo "The number of outputs = ${output_number}"

    if [[ "${output_number}" -gt '0' ]]; then
        # do piping

        the_last_out_pipe="${out_pipes[-1]}"
        remaining_out_pipes=("${out_pipes[@]:0:$((${#out_pipes[@]} - 1))}")

        0<"${in_pipe}" \
        1>"${the_last_out_pipe}" \
        tee "${remaining_out_pipes[@]}" &

        # list all background processes
        jobs

        # wait for the input process to be finished
        wait "${in_pid}"

        # wait for all other background processes
        wait

        rm "${out_pipes[@]}"

    else
        # remove the sender of `in_pipe`.

        kill "${in_pid}"

    fi

    # Cleanup

    rm "${in_pipe}"

    if [[ "${output_number}" -eq '0' ]]; then
        echo "no output specified."
        exit 5
    fi

    echo '------ ^^^^^^ process stream and video ^^^^^^'
}

# Processor #
#############

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
        --multipart-chunk-size-mb="${S3CMD_MULTIPART_CHUNK_SIZE_MB:-15}" \
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

    set +u

    the_file_name="$(basename -- "${1}")"
    the_file_dir="${1%/${the_file_name}}"
    the_file_ext="${the_file_name##*.}"
    the_file_basename="${the_file_name%.*}"

    if [[ -z "${NO_AUTO_FILESIZE}" ]]; then
        the_file_byte_size="$(du -b "${1}" | awk '{ print $1 }')"
        the_file_basename="${the_file_basename}.${the_file_byte_size}"
    fi

    if [[ -z "${NO_AUTO_MD5}" ]]; then
        the_file_md5="$(md5sum "${1}" | awk '{ print $1 }')"
        the_file_basename="${the_file_basename}.${the_file_md5}"
    fi

    the_file_final_name="${the_file_basename}.${the_file_ext}"
    the_file_final_path="${the_file_dir}/${the_file_final_name}"

    echo "the final file path:    '${the_file_final_path}'"

    if [[ -f "${the_file_final_path}" ]]; then
        echo 'The existing file has not been renamed.'
    else
        mv "${1}" "${the_file_final_path}"
    fi

    if [[ -n "${ENABLE_S3}" ]]; then
        upload_to_s3 "${the_file_final_path}"
    fi

    if [[ -n "${ENABLE_AZURE}" ]]; then
        upload_to_azure "${the_file_final_path}"
    fi

    echo '------ ^^^^^^ obtain calculate rename upload ^^^^^^'
}

# Get file's information, rename it, upload it #
################################################

##############
# ENTRYPOINT #

function main() {
    output_file_basename="${OUTPUT_FILENAME_BASE:-$(mktemp -u 'XXX')}"

    if [[ -z "${NO_AUTO_PREFIX_DATETIME}" ]]; then
        output_file_basename="${the_datetime}.${output_file_basename}"
    fi

    # It could be a MKV. PLease believe our media player.
    output_ts_base_path="/SL-downloads/${output_file_basename}.ts"

    if [[ -n "${ENABLE_S3}" ]]; then
        init_s3
    fi

    if [[ -n "${ENABLE_AZURE}" ]]; then
        init_azure
    fi

    process_stream_and_video "${output_ts_base_path}"

    if [[ -f "${output_ts_base_path}" ]]; then
        obtain_calculate_rename_upload "${output_ts_base_path}"
    else
        echo 'Downloaded file not found'
    fi
}

# ENTRYPOINT #
##############

main

exit 0
