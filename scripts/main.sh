#!/usr/bin/env bash
#
# Yamada Hayao
# Twitter: @Hayao0819
# Email  : hayao@fascode.net
#
# (c) 2019-2020 Fascode Network.
#
# Repository management script
# Executed via administrator web and API of YamaD Server 
#

script_name=$(basename ${0})

script_path="$(readlink -f ${0%/*})"

arch="$(uname -m)"
git_url="https://github.com/FascodeNet/alterlinux-pkgbuilds"
repo_name="alter-stable"

work_dir="${script_path}/work"
repo_dir="${script_path}/repo"
makepkg_conf="/etc/makepkg.conf"

debug=false
nocolor=false

force=false
force_repo=false
command=""
skip_pkg=()

gpgkey="$(
    source "/etc/makepkg.conf"
    echo "${GPGKEY}"
)"

set -e

# usage <exit code>
_usage() {
    echo "usage ${0} [options] [repository] [command]"
    echo
    echo " General options:"
    echo
    echo "    -a | --arch <arch>               Specify the architecture"
    echo "    -r | --repodir <dir>             Specify the repository dir"
    echo "    -s | --skip '<pkg1> <pkg2>...'   Skip building the specified package"
    echo "    -g | --giturl <url>              Specify the URL of the repository where the PKGBUILD list is stored"
    echo "    -f | --force                     Force builds of already built packages"
    echo "         --force-repo                Overwrite the existing repository."
    echo "    -k | --gpgkey                    Specify the gpg key"
    echo "    -w | --workdir <dir>             Specify the work dir"
    echo "    -h | --help                      Show this help message"
    echo
    echo "         --nocolor                   No colored output."
    echo "         --makepkg-conf              Specift the config file for makepkg"
    echo
    echo "    list                             List packages"
    echo "    build                            Build all packages"
    echo "    clean                            Remove working directory"
    echo "    help                             Show this help message"

    if [[ -n "${1:-}" ]]; then
        exit "${1}"
    fi
}


# Color echo
# usage: echo_color -b <backcolor> -t <textcolor> -d <decoration> [Text]
#
# Text Color
# 30 => Black
# 31 => Red
# 32 => Green
# 33 => Yellow
# 34 => Blue
# 35 => Magenta
# 36 => Cyan
# 37 => White
#
# Background color
# 40 => Black
# 41 => Red
# 42 => Green
# 43 => Yellow
# 44 => Blue
# 45 => Magenta
# 46 => Cyan
# 47 => White
#
# Text decoration
# You can specify multiple decorations with ;.
# 0 => All attributs off (ノーマル)
# 1 => Bold on (太字)
# 4 => Underscore (下線)
# 5 => Blink on (点滅)
# 7 => Reverse video on (色反転)
# 8 => Concealed on

echo_color() {
    local backcolor
    local textcolor
    local decotypes
    local echo_opts
    local arg
    local OPTIND
    local OPT
    
    echo_opts="-e"
    
    while getopts 'b:t:d:n' arg; do
        case "${arg}" in
            b) backcolor="${OPTARG}" ;;
            t) textcolor="${OPTARG}" ;;
            d) decotypes="${OPTARG}" ;;
            n) echo_opts="-n -e"     ;;
        esac
    done
    
    shift $((OPTIND - 1))
    
    echo ${echo_opts} "\e[$([[ -v backcolor ]] && echo -n "${backcolor}"; [[ -v textcolor ]] && echo -n ";${textcolor}"; [[ -v decotypes ]] && echo -n ";${decotypes}")m${*}\e[m"
}


# Show an INFO message
# $1: message string
_msg_info() {
    local echo_opts="-e"
    local arg
    local OPTIND
    local OPT
    while getopts 'n' arg; do
        case "${arg}" in
            n) echo_opts="${echo_opts} -n" ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ "${nocolor}" = true ]]; then
        echo ${echo_opts} "[${script_name}]    Info ${*}"
    else
        echo ${echo_opts} "$( echo_color -t '36' "[${script_name}]")    $( echo_color -t '32' 'Info') ${*}"
    fi
}


# Show an Warning message
# $1: message string
_msg_warn() {
    local echo_opts="-e"
    local arg
    local OPTIND
    local OPT
    while getopts 'n' arg; do
        case "${arg}" in
            n) echo_opts="${echo_opts} -n" ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ "${nocolor}" = true ]]; then
        echo ${echo_opts} "[${script_name}] Warning ${*}"
    else
        echo ${echo_opts} "$( echo_color -t '36' "[${script_name}]") $( echo_color -t '33' 'Warning') ${*}" >&2
    fi
}


# Show an debug message
# $1: message string
_msg_debug() {
    local echo_opts="-e"
    local arg
    local OPTIND
    local OPT
    while getopts 'n' arg; do
        case "${arg}" in
            n) echo_opts="${echo_opts} -n" ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ "${debug}" = true ]]; then
        if [[ "${nocolor}" = true ]]; then
            echo ${echo_opts} "[${script_name}]   Debug ${*}"
        else
            echo ${echo_opts} "$( echo_color -t '36' "[${script_name}]")   $( echo_color -t '35' 'Debug') ${*}"
        fi
    fi
}


# Show an ERROR message then exit with status
# $1: message string
# $2: exit code number (with 0 does not exit)
_msg_error() {
    local echo_opts="-e"
    local arg
    local OPTIND
    local OPT
    local OPTARG
    while getopts 'n' arg; do
        case "${arg}" in
            n) echo_opts="${echo_opts} -n" ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ "${nocolor}" = true ]]; then
        echo ${echo_opts} "[${script_name}]   Error ${1}"
    else
        echo ${echo_opts} "$( echo_color -t '36' "[${script_name}]")   $( echo_color -t '31' 'Error') ${1}" >&2
    fi
    if [[ -n "${2:-}" ]]; then
        exit ${2}
    fi
}

# rm helper
# Delete the file if it exists.
# For directories, rm -rf is used.
# If the file does not exist, skip it.
# remove <file> <file> ...
remove() {
    local _list
    local _file
    _list=($(echo "$@"))
    for _file in "${_list[@]}"; do
        if [[ -f ${_file} ]]; then
            _msg_debug "Removeing ${_file}"
            rm -f "${_file}"
            elif [[ -d ${_file} ]]; then
            _msg_debug "Removeing ${_file}"
            rm -rf "${_file}"
        fi
    done
}


# check_file <path> <description> 
check_file() {
    local file_path="${1}"
    local file_description="${2}"
    if [[ ! -f "${file_path}" ]]; then
        _msg_error "${file_description} (${file_path}) does not exist." "1"
    fi
}


# check_command <command>
check_command() {
    local command="${1}"
    check_file "$(which ${command})" "${command}"
}


prepare() {
    check_command makepkg
    check_command git
    check_command pacman
}

root_check() {
    # root check
    if [[ "${UID}" = 0 ]]; then
        _msg_error "It cannot be run by the root user."
        _msg_error "Be sure to execute it from a general user." "1"
    fi
}

repo_update() {
    local _pkg_dir="${repo_dir}/${repo_name}/${arch}"
    cd "${_pkg_dir}"
    rm -rf "${_pkg_dir}/"*".db."* "${_pkg_dir}/"*".files."* "${_pkg_dir}/"*".db" "${_pkg_dir}/"*".files"
    repo-add "${repo_name}.db.tar.gz" $(ls "${_pkg_dir}/"*".pkg.tar."* | grep -v ".sig" | grep -v ".sh")
}

build() {
    root_check
    if [[ "${force_repo}"  = true ]]; then
        remove "${repo_dir}/${repo_name}/${arch}"
    fi
    #if [[ -d "${repo_dir}/${repo_name}/${arch}" ]]; then
    #    _msg_error "The repository already exists." "1"
    #fi

    # Prepare to build
    remove "${work_dir}/git_work"
    mkdir -p "${repo_dir}/${repo_name}/${arch}"
    mkdir -p "${work_dir}"
    mkdir -p "${work_dir}/lockfile/${repo_name}/${arch}"
    mkdir -p "${work_dir}/lockfile/${repo_name}/any"
    mkdir -p "${work_dir}/pkgs/${repo_name}/${arch}"
    mkdir -p "${work_dir}/pkgs/${repo_name}/any"
    git clone "${git_url}" "${work_dir}/git_work"


    local init_dir=$(pwd)
    local build_list

    for _arch in "${arch}" "any"; do
        if [[ ! -d "${work_dir}/git_work/${repo_name}/${_arch}" ]]; then
            continue
        fi
        cd "${work_dir}/git_work/${repo_name}/${_arch}"
        local pkg
        if [[ "${pkgs[@]}" = "ALL" ]]; then
            build_list=($(ls 2> /dev/null))
        else
            build_list=(${pkgs[@]})
        fi

        for pkg in ${build_list[@]}; do
            # スキップするパッケージかどうかを確認
            if [[ $(printf '%s\n' "${skip_pkg[@]}" | grep -qx "${pkg}"; echo -n ${?} ) -eq 0 ]]; then
                _msg_debug "Skipped building ${pkg} package"
                continue
            fi

            cd "${pkg}"

            makepkg_args=(--ignorearch --syncdeps --rmdeps --clean --cleanbuild --force --noconfirm --needed --skippgpcheck --config "${makepkg_conf}")
            if [[ ! "${gpgkey}" = "" ]]; then
                makepkg_args+=(--key "${gpgkey}" --sign)
            fi

            if [[ ! -f "${work_dir}/lockfile/${repo_name}/${_arch}/${pkg}" ]] || [[ "${force}" = true ]]; then
                makepkg "${makepkg_args[@]}"
                mv *.pkg.tar.* "${work_dir}/pkgs/${repo_name}/${_arch}/"
                touch "${work_dir}/lockfile/${repo_name}/${_arch}/${pkg}"
            else
                _msg_info "${pkg} is already built."
            fi
            cd ..
            #rm -rf "${pkg}"
        done
    done

    _msg_info "Copying package to repository directory..."

    if [[ -n $(ls "${work_dir}/pkgs/${repo_name}/${arch}/"* 2> /dev/null) ]]; then
        cp "${work_dir}/pkgs/${repo_name}/${arch}/"* "${repo_dir}/${repo_name}/${arch}/"
    fi

    if [[ -n $(ls "${work_dir}/pkgs/${repo_name}/any/"* 2> /dev/null ) ]]; then
        cp "${work_dir}/pkgs/${repo_name}/any/"* "${repo_dir}/${repo_name}/${arch}/"
    fi

    sudo rm -rf "${work_dir}/git_work"

    repo_update
}


clean() {
    sudo rm -rf "${work_dir}"
}


# Parse options
if [[ -z "${@}" ]]; then
    _usage 0
fi

options="${@}"
_opt_short="h,a:,g:,r:,w:,f,s:k:"
_opt_long="help,arch:,giturl:,repodir:,workdir:,force,force-repo,nocolor,skip:,gpgkey:,makepkg-conf:"
OPT=$(getopt -o ${_opt_short} -l ${_opt_long} -- "${@}")
if [[ ${?} != 0 ]]; then
    exit 1
fi

eval set -- "${OPT}"
unset OPT
unset _opt_short
unset _opt_long

while :; do
    case ${1} in
        --help | -h)
            _usage 0
            shift 1
            ;;
        --arch | -a)
            arch="${2}"
            shift 2
            ;;
        --giturl | -g)
            git_url="${2}"
            shift 2
            ;;
        --repodir | -r)
            repo_dir="$(realpath "${2}")"
            shift 2
            ;;
        --workdir | -w)
            work_dir="$(realpath "${2}")"
            shift 2
            ;;
        --force | -f)
            force=true
            shift 1
            ;;
        -k | --gpgkey)
            gpgkey="${2}"
            shift 2
            ;;
        --force-repo)
            force_repo=true
            shift 1
            ;;
        --nocolor)
            nocolor=true
            shift 1
            ;;
        -s | --skip)
            skip_pkg=(${2})
            shift 2
            ;;
        --makepkg-conf)
            makepkg_conf="${2}"
            shift 2
            ;;
        --)
            shift 1
            break
            ;;
        *)
            _msg_error "Invalid argument '${1}'"
            _usage 1
            ;;
    esac
done

if [[ -n "${1}" ]]; then
    repo_name="${1}"
    repo_config="${script_path}/${repo_name}"
    if [[ ! -f "${repo_config}" ]]; then
        _msg_error "Repository [${repo_name}] does not exist." "1"
    else
        source "${repo_config}"
    fi
else
    _usage 1
fi

if [[ -n "${2}" ]]; then
     case "${2}" in
        "list") command="list" ;;
        "build") command="build" ;;
        "clean") command="clean" ;;
        "help" ) _usage 0 ;;
        *) _msg_error "Invalid command '${2}'" "1" ;;
    esac
else
    _usage 1
fi


# Run
prepare
${command}
