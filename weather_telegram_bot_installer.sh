#!/bin/bash

if [ ! "$BASH" ]; then
    /bin/bash "$0" "$@"
    exit "$?"
fi

##########################################################################
# Variables declaration                                                  #
##########################################################################

DST_DIR="/opt/weather_bot"
EXE_NAME="weather_telegram_bot.py"
TMP_EXE_NAME="weather_telegram_bot.py_tmp"

SYSTEMD_UNITS_DIR="/etc/systemd/user"
SYSTEMD_UNIT_NAME="weather_telegram_bot.service"

##########################################################################
# Logging                                                                #
##########################################################################

declare -A __severity_levels=([TRACE]=0 [DEBUG]=1 [INFO]=2 [WARN]=3 [ERROR]=4)
__severity_level="DEBUG"

function log_level { echo "${__severity_level}"; }
function logging_set_severity_level { if [[ ${__severity_levels[${1}]} ]]; then __severity_level="${1}"; fi; }

function log
{
    local log_lvl=$1
    local log_msg=$2

    # Check if level exists.
    if [[ ! ${__severity_levels[${log_lvl}]} ]]; then return; fi
    # Check if level is enough.
    if (( ${__severity_levels[${log_lvl}]} < ${__severity_levels[${__severity_level}]} )); then
        return
    fi

    echo "[${log_lvl}] ${log_msg}"
}

function log_trace { log "TRACE" "$1"; }
function log_debug { log "DEBUG" "$1"; }
function log_info  { log "INFO"  "$1"; }
function log_warn  { log "WARN"  "$1"; }
function log_error { log "ERROR" "$1"; }

##########################################################################
# Private functions                                                      #
##########################################################################

function call_command
{
    local cmd="$@"
    log_debug "${cmd}"
    ${cmd}
    if [[ "$?" -ne "0" ]]; then
        log_error "Failed to execute command '${cmd}'"
        exit 1
    fi
}

function call_systemd
{
    local cmd="$@"
    call_command "systemctl ${cmd}"
}

function check_permissions
{
    if [ "$EUID" -ne 0 ]; then
        log_error "Root privileges are required"
        exit 1
    fi
}

##########################################################################
# Public functions                                                       #
##########################################################################

function build
{
    local exe_file="$1"
    local ow_appip="$2"
    local tg_token="$3"

    call_command "sed -i -e 's/<open_weather_appip>/${ow_appip}/g' ${exe_file}"
    call_command "sed -i -e 's/<telegram_bot_token>/${tg_token}/g' ${exe_file}"
}

function install
{
    local src_dir="$(pwd)"
    local dst_dir="${DST_DIR}"
    local exe_name="${EXE_NAME}"
    local tmp_exe_name="${TMP_EXE_NAME}"
    local systemd_units_dir="${SYSTEMD_UNITS_DIR}"
    local systemd_unit_name="${SYSTEMD_UNIT_NAME}"

    check_permissions

    if [[ ! -d "${dst_dir}" ]]; then
        log_info "Destination directory '${dst_dir}' does not exist. Creating directory."
        call_command "mkdir ${dst_dir}"
    fi

    call_command "mv /tmp/${tmp_exe_name} ${dst_dir}/${exe_name}"
    call_command "cp ${src_dir}/${systemd_unit_name} ${systemd_units_dir}/${systemd_unit_name}"

    call_systemd "daemon-reload"
    call_systemd "enable ${systemd_unit_name}"
    call_systemd "start ${systemd_unit_name}"
}

function uninstall
{
    local dst_dir="${DST_DIR}"
    local exe_name="${EXE_NAME}"
    local systemd_units_dir="${SYSTEMD_UNITS_DIR}"
    local systemd_unit_name="${SYSTEMD_UNIT_NAME}"
    local systemd_unit_file="${systemd_units_dir}/${systemd_unit_name}"

    check_permissions

    if [[ "${dst_dir}" != "/opt/"* ]]; then
        log_error "Invalid destination directory '${dst_dir}'"
        exit 1
    fi

    if [[ -d "${dst_dir}" ]]; then
        call_command "rm -f ${dst_dir}/"*
        call_command "rmdir ${dst_dir}"
    fi

    if [[ -f "${systemd_unit_file}" ]]; then
        call_systemd "stop ${systemd_unit_name}"
        call_systemd "disable ${systemd_unit_name}"
        call_command "rm -f ${systemd_unit_file}"
        call_systemd "daemon-reload"
    fi
}

function usage
{
    echo "Usage '"$0"' <cmd>"
    echo ""
    echo "Available commands:"
    echo "    -i|--install   - install bot"
    echo "    -u|--uninstall - uninstall bot"
    echo ""
    echo "Available install options:"
    echo "    -a|--appip - open weather map appip"
    echo "    -t|--token - telegram token"
}

##########################################################################
# Main                                                                   #
##########################################################################

_CMD_INSTALL=0
_CMD_UNINSTALL=0
_OW_APPIP=""
_TG_TOKEN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install)
            _CMD_INSTALL=1
            shift # past arg
            ;;
        -u|--uninstall)
            _CMD_UNINSTALL=1
            shift # past arg
            ;;
        -a|--appip)
            _OW_APPIP="$2"
            shift # past arg
            shift # past val
            ;;
        -t|--token)
            _TG_TOKEN="$2"
            shift # past arg
            shift # past val
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*|--*)
            echo "Unknown option '"$1"'"
            usage
            exit 1
            ;;
    esac
done

if [[ "$(($_CMD_INSTALL + $_CMD_UNINSTALL))" -ne "1" ]]; then
    echo "Invalid input parameters. The command must be one."
    echo ""
    usage
    exit 1
fi

if [[ "$_CMD_INSTALL" -eq "1" ]]; then
    install
    if [[ "${_OW_APPIP}" -ne "" && "${_TG_TOKEN}" -ne "" ]]; then
        build "${DST_DIR}/${EXE_NAME}" "${_OW_APPIP}" "${_TG_TOKEN}"
    fi
fi
if [[ "$_CMD_UNINSTALL" -eq "1" ]]; then
    uninstall
fi

