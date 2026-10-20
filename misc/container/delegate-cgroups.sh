#!/bin/sh
# The autograder image's entrypoint: hand the cgroup v2 controllers down to
# the containers podman starts in here, then run the command.
#
# A grading container is given limits (--memory, --pids-limit) for the code
# it runs, and podman sets them in a child cgroup of this container's own.
# The kernel hands a controller down only from a cgroup that holds no
# processes itself, and this container's starts out holding them all, so
# without this every limit is silently not there: a solution could fork, or
# eat memory, until the host stops it. As Docker's own docker-in-docker image
# does: every process here moved to a child cgroup, init/, and every
# controller this cgroup has turned on for its children.
if [ -f /sys/fs/cgroup/cgroup.controllers ] && [ -w /sys/fs/cgroup/cgroup.subtree_control ]; then
  mkdir -p /sys/fs/cgroup/init
  # A process gone by the time it is moved (this one's `cat`, say) is no matter.
  xargs -rn1 </sys/fs/cgroup/cgroup.procs >/sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
  sed -e 's/ / +/g' -e 's/^/+/' </sys/fs/cgroup/cgroup.controllers >/sys/fs/cgroup/cgroup.subtree_control
fi
exec "$@"
