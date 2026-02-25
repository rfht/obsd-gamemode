#!/bin/ksh

########
# Copyright (c) 2026 Thomas Frohwein <thfr@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
########

###
# NOTES:
#
# - for OpenBSD
# - inspired by https://github.com/FeralInteractive/gamemode for Linux
# - see man pages:
#	* setpriority(2), renice(8)
#	* ksh(1) (for ulimit)
# - see https://wiki.archlinux.org/title/PRIME for hybrid GPU use
# - Optimizations to apply
#	* CPU power management to high performance (apm -H)
#	* datasize limit (ksh(1)'s ulimit -d)
#	* increase MESA_SHADER_CACHE_MAX_SIZE (default: 1G)
#	* disable screensaver (may not be needed, as SDL and Godot take care of this)
#	* setpriority(2) to -4 (cf. FeralInteractive's gamemode)
#	* any priority lower than sndiod(8) (default: -20) should be fine
#	* if hybrid GPU system (DRI_PRIME)
# - use new doas(1)/privdrop support to use setpriority(2) or renice(8)
# - add malloc options optimizations? (see malloc(3))
###

set -eu

USAGE="Usage:\n\t`basename $0` command [args]"

### 1. check/read command-line args

[[ $# -eq 0 ]] && ( echo $USAGE; exit 1 )

### 1.2 check for super user and privdrop ability
if [[ "$(id -u)" -eq 0 ]]; then
  have_priv=true
  if [[ -n "$DOAS_USER" ]]; then
    unpriv_user="$DOAS_USER"
  elif [[ -n "$SUDO_USER" ]]; then
    unpriv_user="$SUDO_USER"
  else
    echo "Running as root without doas(1) or sudo(1), so cannot drop privileges!"
    echo $USAGE
    exit 1
  fi
else
  have_priv=false
fi

### 2. XXX: read config

### 3. snapshot of current settings

is_service_on() {
  if rcctl ls all | grep -q "$1" && rcctl check "$1" >/dev/null 2>&1 ; then
    true
  else
    false
  fi
}

start_service() {
  if ! $have_priv ; then
    printf "permission denied: cannot start the '%s' service without super user privileges!\n" "$1"
    echo $USAGE
    exit 1
  fi
  rcctl start "$1" >/dev/null 2>&1
}

stop_service() {
  if ! $have_priv ; then
    printf "permission denied: cannot stop the '%s' service without super user privileges!\n" "$1"
    echo $USAGE
    exit 1
  fi
  rcctl stop "$1" >/dev/null 2>&1
}

### 3.1 check/save obsdfreqd settings
if ! is_service_on obsdfreqd; then
  pre_obsdfreqd=
else
  pre_obsdfreqd=true
fi

### 3.2 check/save apmd settings
if ! is_service_on apmd; then
	echo "apmd is not running; skipping..."
	pre_apm_policy=
else
	pre_apm_policy=$(apm -P)		# 0: manual, 1: auto
fi

pre_perf="$(sysctl -n hw.setperf)"	# is 0 when using apm -A or -L, 100 when -H
#pre_policy="$(sysctl -n hw.perfpolicy)"	# auto, manual, or high

pre_datasize="$(ulimit -d)"		# XXX: may not be needed if running without exec
#pre_shadercachesize="$(echo $MESA_SHADER_CACHE_MAX_SIZE)"
#pre_dri_prime="$(echo $DRI_PRIME)"	# XXX: maybe for later

### 3.5 set up handler for exit

on_exit() {
	# XXX: this assumes that only one program is running with game mode

	ulimit -d $pre_datasize		# XXX: may not be needed if running without exec

	# XXX: this needs root to adjust
	#sysctl -q hw.setperf=$pre_perf
	#sysctl -q hw.perfpolicy=$pre_policy

	if [[ -z "$pre_apm_policy" ]]; then
		true # no-op
	elif [[ $pre_apm_policy = 1 ]]; then
		apm -A
	elif [[ $pre_perf = 100 ]]; then
		apm -H
	elif [[ $pre_perf = 0 ]]; then
		apm -L
	fi

  if [[ -n "$pre_obsdfreqd" ]]; then
    start_service obsdfreqd
  fi
}

trap 'on_exit' EXIT

### 4. apply optimizations

# the following 2 lines are equivalent to calling `apm -H`
# XXX: this needs root to adjust
#sysctl -q hw.perfpolicy=manual
#sysctl -q hw.setperf=100

### 4.1 turn off obsdfreqd
if [[ -n "$pre_obsdfreqd" ]]; then
  stop_service obsdfreqd
fi

### 4.2 apm high performance mode
if [[ -n "$pre_apm_policy" ]]; then
  apm -H
fi

# set datasize to the min of physical memory (-m) and hard datasize limit (-Hd)
# XXX: this is duplicated in privdrop() and worth DRY-ing
if ! $have_priv; then
  [[ $(ulimit -Hd) > $(ulimit -m) ]] && \
    ulimit -d $(ulimit -m) || \
    ulimit -d $(ulimit -Hd)
fi

# XXX: make this compare if the environment already contains a higher value
#	for MESA_SHADER_CACHE_MAX_SIZE
run_env=MESA_SHADER_CACHE_MAX_SIZE=4G

# xset s off -dpms	# fortunately this is taken care of by SDL and Godot

### 5. run

privdrop() {
  # XXX: the ulimit has to be set in the privdropped shell, but this is
  # duplicated from above and worth DRY-ing
  env $run_env \
    LOGNAME="$unpriv_user" \
    USER="$unpriv_user" \
    HOME="$(eval "echo ~${unpriv_user}")" \
    DOAS_USER= \
    SUDO_USER= \
    su -m "$unpriv_user" \
      -s <<EOI
[[ \$(ulimit -Hd) > \$(ulimit -m) ]] && \
  ulimit -d \$(ulimit -m) || \
  ulimit -d \$(ulimit -Hd)
$@
EOI
}

if $have_priv; then
  privdrop "$@"
  r=$?
else
  env $run_env "$@"
  r=$?
fi

### 7. return (prior settings are restored via on_exit()

exit $r
