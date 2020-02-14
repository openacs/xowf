#
# Register the dav interface for the todo handler.
#
::xowf::dav-todo register

#
# Run the checker for the scheduled at-jobs.
#
# As we are trying to run as close as possible to the minute change,
# the "ns_after" is used to delay the registration past the end of the
# minute. To avoid potential misses of jobs between the execution time
# of the init script and the end of the minute, we delay both, the
# cleanup of the old entries and we start the repeating proc 60
# seconds later.
#
set secs_to_the_minute [expr {60 - ([clock seconds] % 60)}]
ns_after $secs_to_the_minute {

  # Make sure, we have not missed some at-jobs, while we were down
  ad_schedule_proc -thread t -once t 1 ::xowf::atjob check -with_older true

  # the following job is executed after 60 seconds
  ad_schedule_proc -thread t 60 ::xowf::atjob check
  
}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
