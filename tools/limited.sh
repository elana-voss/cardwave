# Sourced by tools/check.sh: `limited SECONDS COMMAND…` runs COMMAND (a program or a shell function) under a time
# limit, so a hung check fails instead of waiting unseen. Past the limit it stops the command's process tree and
# every program running from the folder TARGET that started since it did (Git Bash's kill and timeout leave a native
# child such as a test program running; one started before, the owner's app or another run, stays) and returns 124; `timed_out SECONDS FILE` then says so, with the tests libtest reported in FILE as
# running over 60 seconds. Its test: tools/limited_test.py.

# stop_under DIR SINCE: ends every running program whose file lies under DIR, started at or after SINCE (Unix seconds).
stop_under() {
  [ -d "$1" ] || return 0
  powershell.exe -NoProfile -Command "\$since = [DateTimeOffset]::FromUnixTimeSeconds($2).LocalDateTime; Get-Process | Where-Object { \$_.Path -like '$(cygpath -w "$1")\\*' -and \$_.StartTime -ge \$since } | Stop-Process -Force" >/dev/null 2>&1
  # Its failure leaves at most a program that ended meanwhile: nothing to stop.
  return 0
}

timed_out() {
  echo "timed out after $1 s"
  grep -h "has been running for over 60 seconds" "$2"
  return 0
}

limited() {
  limit=$1
  shift
  begun=$(date +%s)
  "$@" &
  job=$!
  end=$((begun + limit))
  while kill -0 "$job" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$end" ]; then
      winpid=$(cat "/proc/$job/winpid" 2>/dev/null)
      [ -z "$winpid" ] || taskkill //F //T //PID "$winpid" >/dev/null 2>&1
      kill "$job" 2>/dev/null
      [ -z "$TARGET" ] || stop_under "$TARGET" "$begun"
      wait "$job" 2>/dev/null
      return 124
    fi
    sleep 1
  done
  wait "$job"
}
