#!/bin/bash
##############################################
#Author : Sibel
##############################################

trap "kill 0" SIGINT

declare -a video_files
declare -a matched_words

words=("lenovo" "ZED" "usb 2.0")

extract_metadata() {
    local video_file="$1"
    v4l2-ctl --device="$device" --all 2>&1
}

search_words_in_metadata() {
    local metadata="$1"
    local device="$2"

    for word in "${words[@]}"; do
        if grep -qi "$word" <<< "$metadata"; then
            video_files+=("$device")
            matched_words+=("$word")
        fi
    done
}

for device in /dev/video* ; do
    metadata=$(extract_metadata "$device")

    search_words_in_metadata "$metadata" "$device"
done

for i in "${!video_files[@]}"; do
    echo "video: ${video_files[i]}, word: ${matched_words[i]}"
done

if [ ! -f config ]; then
    echo "Configuration file not found"
    exit 1
fi

source config

if [ -z "$target_ports" ] || [ -z "$target_ips" ]; then
    echo "Usage: $0 <target_port> <client_ip1> <client_ip2> ..."
    exit 1
fi

IFS=',' read -r -a target_ports <<< "$target_ports"
IFS=',' read -r -a clients <<< "$target_ips"

last_ip=${clients[-1]}
unset clients[-1]

for d in "${!video_files[@]}"; do
    
    if [[ "${matched_words[d]}" == "ZED" ]] && (( d % 2 == 0 )); then
        command_root="gst-launch-1.0 -e v4l2src device=${video_files[d]} ! videoconvert ! \
            x264enc tune=zerolatency bitrate=1000 speed-preset=superfast ! h264parse ! tee name=sibel ! \
            "
        for target_ip in "${clients[@]}"
        do
        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$target_ip port=${target_ports[1]} sibel. ! "
        done

        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$last_ip port=${target_ports[1]} > log/zed.log 2>&1  &"

        eval $command_root
    fi
    if [[ "${matched_words[d]}" == "lenovo" ]] && (( d % 2 == 0 )); then
        command_root="gst-launch-1.0 -e v4l2src device=${video_files[d]} ! videoconvert ! \
            x264enc tune=zerolatency bitrate=1000 speed-preset=superfast ! h264parse ! tee name=sibel ! \
            "
        for target_ip in "${clients[@]}"
        do
        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$target_ip port=${target_ports[0]} sibel. ! "
        done

        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$last_ip port=${target_ports[0]} > log/lenovo.log 2>&1 &"

        eval $command_root
    fi
    if [[ "${matched_words[d]}" == "usb 2.0" ]] && (( d % 2 == 0 )); then

        command_root="gst-launch-1.0 -e v4l2src device=${video_files[d]} ! videoconvert ! \
            x264enc tune=zerolatency bitrate=1000 speed-preset=superfast ! h264parse ! tee name=sibel ! \
            "
        for target_ip in "${clients[@]}"
        do
        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$target_ip port=${target_ports[2]} sibel. ! "
        done

        command_root+="queue ! rtph264pay config-interval=10 pt=96 ! udpsink host=$last_ip port=${target_ports[2]} > log/usb.log 2>&1  &"

        eval $command_root
    fi
done

while :
do
    sleep 1
done