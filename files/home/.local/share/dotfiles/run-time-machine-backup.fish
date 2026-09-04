#!/usr/bin/env fish

function on_ac_power
    set -l power_line (/usr/bin/pmset -g batt | /usr/bin/head -n 1)
    string match -q "*AC Power*" -- $power_line
end

if not on_ac_power
    echo "Skipping Time Machine backup while on battery power"
    exit 0
end

set -l timeout_seconds 43200
set -l deadline (math (/bin/date +%s) + $timeout_seconds)

/usr/bin/tmutil startbackup --auto --block &
set -l backup_pid $last_pid
/usr/bin/caffeinate -i -t $timeout_seconds -w $backup_pid &
set -l caffeinate_pid $last_pid

while /bin/kill -0 $backup_pid 2>/dev/null
    if test (/bin/date +%s) -ge $deadline
        echo "Stopping Time Machine backup: 12-hour timeout reached"
        /usr/bin/tmutil stopbackup
        break
    end
    /bin/sleep 60
end

wait $backup_pid
set -l backup_status $status
/bin/kill $caffeinate_pid 2>/dev/null
wait $caffeinate_pid 2>/dev/null
exit $backup_status
