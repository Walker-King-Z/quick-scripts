#!/bin/bash

# ==============================================================================
#  install_tree_and_check_ascend.sh
#
#  Description:
#  1. Install tree on Debian/Ubuntu
#  2. Load Ascend CANN environment if available
#  3. Collect Ascend component installation status and version info
#
#  Usage:
#  sudo ./install_tree_and_check_ascend.sh
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
   echo "Error: This script must be run as root." >&2
   echo "Please use 'sudo' to run it: sudo ./install_tree_and_check_ascend.sh" >&2
   exit 1
fi

ASCEND_BASE="/usr/local/Ascend"
TOOLKIT_BASE="${ASCEND_BASE}/ascend-toolkit"
TOOLKIT_LATEST="${TOOLKIT_BASE}/latest"
SET_ENV_SH="${TOOLKIT_BASE}/set_env.sh"

print_line() {
    printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'
}

print_title() {
    echo
    print_line
    echo "$1"
    print_line
}

print_item() {
    local name="$1"
    local status="$2"
    local detail="$3"
    printf "%-24s : %-10s %s\n" "$name" "$status" "$detail"
}

read_version_info() {
    local file="$1"
    if [ -f "$file" ]; then
        tr -d '\r' < "$file" | sed '/^[[:space:]]*$/d'
        return 0
    fi
    return 1
}

get_realpath_safe() {
    local path="$1"
    if [ -e "$path" ]; then
        readlink -f "$path" 2>/dev/null || echo "$path"
    fi
}

dedup_colon_path() {
    local input="$1"
    awk -v RS=':' '!a[$0]++ && $0 != "" { if (out) out=out":"$0; else out=$0 } END { print out }' <<< "$input"
}

show_path_summary() {
    local var_name="$1"
    local var_value="$2"

    if [ -z "$var_value" ]; then
        print_item "$var_name" "EMPTY" ""
        return
    fi

    local deduped
    deduped="$(dedup_colon_path "$var_value")"
    local count
    count="$(awk -F: '{print NF}' <<< "$deduped")"

    print_item "$var_name" "SET" "entries=${count}"
    echo "  ${deduped}" | fold -s -w 100 | sed '2,$s/^/  /'
}

detect_from_version_file() {
    local name="$1"
    local path="$2"
    local version_file="$3"

    if [ -d "$path" ]; then
        if [ -f "$version_file" ]; then
            local info
            info="$(read_version_info "$version_file" | paste -sd '; ' -)"
            print_item "$name" "FOUND" "$info"
        else
            print_item "$name" "FOUND" "path=$(get_realpath_safe "$path"), version.info not found"
        fi
    else
        print_item "$name" "MISSING" "path=$path"
    fi
}

print_title "Step 1: Updating package lists..."
apt-get update

print_title "Step 2: Installing tree package..."
apt-get install -y tree

print_title "Step 3: Loading Ascend CANN environment..."
if [ -f "$SET_ENV_SH" ]; then
    # shellcheck disable=SC1090
    source "$SET_ENV_SH"
    print_item "set_env.sh" "LOADED" "$SET_ENV_SH"
elif [ -f "${ASCEND_BASE}/ascend-toolkit/set_env.sh" ]; then
    # shellcheck disable=SC1090
    source "${ASCEND_BASE}/ascend-toolkit/set_env.sh"
    print_item "set_env.sh" "LOADED" "${ASCEND_BASE}/ascend-toolkit/set_env.sh"
else
    print_item "set_env.sh" "MISSING" "Ascend environment not loaded"
fi

print_title "Step 4: Collecting Ascend environment info"

# 1) Ascend base
if [ -d "$ASCEND_BASE" ]; then
    print_item "Ascend base dir" "FOUND" "$ASCEND_BASE"
else
    print_item "Ascend base dir" "MISSING" "$ASCEND_BASE"
fi

# 2) Driver / npu-smi
if command -v npu-smi >/dev/null 2>&1; then
    local_npu_smi="$(command -v npu-smi)"
    print_item "Ascend Driver" "FOUND" "npu-smi=$local_npu_smi"
    echo
    echo "[npu-smi info]"
    npu-smi info || true
else
    print_item "Ascend Driver" "MISSING" "npu-smi not found"
fi

# 3) Toolkit
if [ -d "$TOOLKIT_BASE" ]; then
    TOOLKIT_REAL="$(get_realpath_safe "$TOOLKIT_LATEST")"
    if [ -n "$TOOLKIT_REAL" ] && [ -d "$TOOLKIT_REAL" ]; then
        print_item "CANN Toolkit" "FOUND" "latest -> $TOOLKIT_REAL"
        if [ -f "$TOOLKIT_REAL/version.info" ]; then
            echo "  version.info:"
            sed 's/^/    /' "$TOOLKIT_REAL/version.info"
        fi
    else
        print_item "CANN Toolkit" "FOUND" "path=$TOOLKIT_BASE"
    fi
else
    print_item "CANN Toolkit" "MISSING" "$TOOLKIT_BASE"
fi

# 4) Runtime：优先检测 toolkit 内，再检测独立 runtime
RUNTIME_FOUND=0
if [ -n "$TOOLKIT_REAL" ] && [ -d "$TOOLKIT_REAL/runtime" ]; then
    print_item "Ascend Runtime" "FOUND" "path=$TOOLKIT_REAL/runtime"
    [ -f "$TOOLKIT_REAL/runtime/version.info" ] && sed 's/^/    /' "$TOOLKIT_REAL/runtime/version.info"
    RUNTIME_FOUND=1
elif [ -d "${ASCEND_BASE}/runtime" ]; then
    print_item "Ascend Runtime" "FOUND" "path=${ASCEND_BASE}/runtime"
    [ -f "${ASCEND_BASE}/runtime/version.info" ] && sed 's/^/    /' "${ASCEND_BASE}/runtime/version.info"
    RUNTIME_FOUND=1
fi

if [ "$RUNTIME_FOUND" -eq 0 ]; then
    if command -v acl.json >/dev/null 2>&1 || python3 -c "import acl" >/dev/null 2>&1; then
        print_item "Ascend Runtime" "LIKELY" "python acl available, but standalone runtime dir not found"
    else
        print_item "Ascend Runtime" "UNKNOWN" "standalone runtime path not found"
    fi
fi

# 5) ATC：只判断存在，不跑 --version
if command -v atc >/dev/null 2>&1; then
    ATC_PATH="$(command -v atc)"
    print_item "ATC Compiler" "FOUND" "$ATC_PATH"
    if [ -n "$TOOLKIT_REAL" ] && [ -f "$TOOLKIT_REAL/version.info" ]; then
        print_item "ATC Version" "INHERIT" "same as Toolkit version"
    fi
else
    print_item "ATC Compiler" "MISSING" "atc not found"
fi

# 6) msprof：只判断存在，不跑 --version
if command -v msprof >/dev/null 2>&1; then
    MSPROF_PATH="$(command -v msprof)"
    print_item "msprof" "FOUND" "$MSPROF_PATH"
    if [ -n "$TOOLKIT_REAL" ] && [ -f "$TOOLKIT_REAL/version.info" ]; then
        print_item "msprof Version" "INHERIT" "usually follows Toolkit version"
    fi
else
    print_item "msprof" "MISSING" "msprof not found"
fi

# 7) Python packages
if command -v python3 >/dev/null 2>&1; then
    echo
    echo "[Python Ascend packages]"
    python3 <<'PY'
import importlib.util

mods = ["acl", "te", "tbe"]
for m in mods:
    ok = importlib.util.find_spec(m) is not None
    print(f"{m:24} : {'FOUND' if ok else 'MISSING'}")
PY
else
    print_item "Python3" "MISSING" "python3 not found"
fi

# 8) Environment variables summary
echo
echo "[Environment Variables Summary]"
show_path_summary "ASCEND_HOME_PATH" "${ASCEND_HOME_PATH:-}"
show_path_summary "ASCEND_OPP_PATH" "${ASCEND_OPP_PATH:-}"
show_path_summary "LD_LIBRARY_PATH" "${LD_LIBRARY_PATH:-}"
show_path_summary "PYTHONPATH" "${PYTHONPATH:-}"
show_path_summary "PATH" "${PATH:-}"

print_title "Completed"
echo "tree installation complete."
echo "Ascend environment check complete."

exit 0