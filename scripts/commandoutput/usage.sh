#!/usr/bin/env bash

cpu_usage="$(LC_ALL=C top -bn1 2>/dev/null | awk '/Cpu\\(s\\)/ {printf "%02.0f", 100 - $8; exit}')"
if [[ -z "$cpu_usage" ]]; then
    cpu_usage="--"
fi

cpu_temp="$(sensors 2>/dev/null | awk '/Package id 0:/ {gsub(/[+°C]/, "", $4); sub(/\\..*/, "", $4); print $4; exit}')"
if [[ -z "$cpu_temp" && -r /sys/class/thermal/thermal_zone0/temp ]]; then
    cpu_temp="$(awk '{printf "%d", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
fi
if [[ -z "$cpu_temp" ]]; then
    cpu_temp="--"
fi

ram_usage="$(free 2>/dev/null | awk '/Mem:/ {printf "%02.0f", ($3 / $2) * 100; exit}')"
if [[ -z "$ram_usage" ]]; then
    ram_usage="--"
fi

printf '󰍛 %s%%   %s°C  󰘚 %s%%\n' "$cpu_usage" "$cpu_temp" "$ram_usage"
