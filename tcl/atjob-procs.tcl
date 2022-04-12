::xo::library doc {

  Routines for AT handler (performing operations on cr objects at certain times)

  @author Gustaf Neumann (neumann@wu-wien.ac.at)
}

namespace eval ::xowf {
  #
  # Define a simple Class for atjobs. In future versions, this is a
  # good candidate to be turned into a nx class.
  #
  # Priority: should be a value between 0 and 9, where 9 is the
  # highest priority; default is 5
  #
  Class create ::xowf::atjob -slots {
    ::xo::Attribute create owner_id
    ::xo::Attribute create party_id
    ::xo::Attribute create cmd
    ::xo::Attribute create time
    ::xo::Attribute create object
    ::xo::Attribute create url
    ::xo::Attribute create priority -default 5
  }

  atjob proc sql_timestamp {tcltime} {
    # make time accurate by minute
    set sql_stamp [clock format $tcltime -format "%Y-%m-%d %H:%M"]
    return "TO_TIMESTAMP('$sql_stamp','YYYY-MM-DD HH24:MI')"
  }
  atjob proc ansi_time {tcltime} {
    return [clock format $tcltime -format "%Y-%m-%d %H:%M"]
  }

  atjob instproc init {} {
    :destroy_on_cleanup
  }

  #
  #
  # temporary cleanup
  #
  # delete from acs_objects where object_type  = '::xowf::atjob';
  # delete from acs_attributes where object_type = '::xowf::atjob';
  # delete from acs_object_types where object_type = '::xowf::atjob';
  # drop table xowf_atjob;

  atjob instproc persist {} {
    set class [self class]
    #
    # When "object" is specified, the atjob is automatically removed,
    # when the "object" is deleted.
    #
    if {![info exists :object]} {
      #
      # When there is no :object, use the global en:atjob-form object
      # as :object.
      #
      set info [xowf::Package require_site_wide_info]
      set item_id [::xo::db::CrClass lookup -name en:atjob-form -parent_id [dict get $info folder_id]]
      set :object [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      ::xo::Package require [dict get $info instance_id]
    }
    set owner_id [${:object} item_id]
    set package_id [${:object} package_id]
    set ansi_time [$class ansi_time [clock scan ${:time}]]
    if {![info exists :party_id]} {
      set :party_id [::xo::cc set untrusted_user_id]
    }

    set form_id [$class form_id -package_id $package_id -parent_id [${:object} parent_id]]
    if {$form_id != 0} {
      ::xo::db::CrClass get_instance_from_db -item_id $form_id
      set instance_attributes [dict merge [::$form_id default_instance_attributes] [list cmd ${:cmd}]]
      if {[info exists :url]} {
        dict set instance_attributes url ${:url}
      }
      set name [::xowiki::autoname new \
                    -name [::$form_id name] \
                    -parent_id $owner_id]
      set f [::xowiki::FormPage new -destroy_on_cleanup \
                 -package_id $package_id \
                 -parent_id $owner_id \
                 -name $name \
                 -title ${:priority} \
                 -nls_language [::$form_id nls_language] \
                 -publish_status "production" \
                 -publish_date $ansi_time \
                 -instance_attributes $instance_attributes \
                 -page_template $form_id]
      $f save_new -use_given_publish_date true -creation_user ${:party_id}
      #:log "--at formpage saved"
    }
  }

  atjob proc form_id {-parent_id -package_id} {
    set form_name en:atjob-form
    set form_id [::xo::db::CrClass lookup -name $form_name -parent_id $parent_id]
    if {$form_id == 0} {
      set page [::$package_id resolve_page -lang en $form_name __m]
      if {$page ne ""} {
        set form_id [$page item_id]
      }
      if {$form_id == 0} {
        ns_log error "Cannot lookup form $form_name; ignore request"
      }
    }
    return $form_id
  }

  atjob proc run_jobs {item_ids} {
    :log "--at run jobs START"

    set sql "select package_id, item_id, name, parent_id, publish_status, creation_user,
                    revision_id, page_template, instance_attributes
             from xowiki_form_instance_item_view
             where item_id in ([ns_dbquotelist $item_ids])"

    set items [::xowiki::FormPage instantiate_objects \
                   -object_class ::xowiki::FormPage \
                   -sql $sql \
                   -initialize false]

    if {[llength [$items children]] > 0} {

      :log "--at we got [llength [$items children]] scheduled items"

      foreach item [$items children] {
        #:log "--at *** job=[$item serialize] ***\n"
        set owner_id [$item parent_id]
        set party_id [$item creation_user]
        set package_id [$item package_id]
        set __ia [$item instance_attributes]

        if {![dict exists $__ia cmd]} {
          #ns_log notice "--at ignore strange entry [$item serialize]"
          ns_log notice "--at ignore strange entry, no cmd in [$item instance_attributes]"
          continue
        }
        set cmd [dict get $__ia cmd]

        set url [expr {[dict exists $__ia url] ? [dict get $__ia url] : ""}]
        if {$url eq ""} {
          set url [lindex [site_node::get_url_from_object_id -object_id $package_id] 0]
          ns_log warning "--at providing best effort url, since no valid URL was provided by caller (cmd $cmd)"
        }

        #
        # Initialize the package with the provided url and user_id.
        #
        ::xo::Package initialize \
            -package_id $package_id \
            -url $url \
            -user_id $party_id
        #
        # We require that the owner object is at least a cr-item
        #
        ::xo::db::CrClass get_instance_from_db -item_id $owner_id
        #
        # We require that the package is from the xowiki family; make
        # sure, the url looks like real
        #
        #::xo::Package initialize \
        #    -package_id [::$owner_id package_id] \
        #    -user_id $party_id \
        #    -init_url 0 -actual_query ""
        #::$package_id set_url -url [::$package_id package_url][::$owner_id name]

        :log "--at executing atjob $cmd"
        ad_try {
          $owner_id {*}$cmd
          if {[::xo::db::Class exists_in_db -id [$item revision_id]]} {
            $item set_live_revision -revision_id [$item revision_id] -publish_status "expired"
          }
        } on error {errorMsg} {
          ns_log error "\n*** atjob $owner_id $cmd lead to error ***\n$errorMsg\n$::errorInfo"
        }
        ns_set cleanup
      }
      :log "---run xowf jobs END"
    }
    ::xo::at_cleanup
  }

  atjob proc check {{-with_older false}} {
    #:log "--at START"
    #
    # Check, if there are jobs scheduled for execution.
    #
    set op [expr {$with_older ? "<=" : "=" }]
    set ansi_time [:ansi_time [clock seconds]]

    #
    # Get the entries.  The items have to be retrieved bottom up,
    # since the query iterates over all instances. In most situations,
    # we fetch the values only for the current time (when with_older
    # is not set). The entries have to be in state "'production" and
    # have to have a parent_id that is an ::xowiki::FormPage. This
    # reduced the number of hits significantly and seems sufficiently
    # fast.
    #
    # To make sure we are not fetching pages from unmounted instances
    # we check for package_id not null.
    #
    # The retrieved items are sorted first by title (priority, should
    # be a value between 0 and 9, where 9 is the highest priority;
    # default is 5) and then by item_id (earlier created items have a
    # lower item_id).
    #
    set sql "select xi.item_id
              from xowiki_form_instance_item_index xi, cr_items i2, cr_items i1, cr_revisions cr
              where i2.item_id = xi.page_template
                and i2.content_type = '::xowiki::Form'
                and i2.name = 'en:atjob-form'
                and cr.publish_date $op to_timestamp(:ansi_time,'YYYY-MM-DD HH24:MI')
                and i1.item_id = xi.item_id
                and cr.revision_id = i1.live_revision
                and xi.publish_status = 'production'
                and xi.package_id is not null
                order by cr.title desc, xi.item_id asc "

    set item_ids [::xo::dc list get_due_atjobs $sql]

    if {[llength $item_ids] > 0} {
      :log "--at we got [llength $item_ids] scheduled items"

      #
      # Running the jobs here in this proc could lead to a problem with
      # the exact match for the time, when e.g. the jobs take longer
      # than one minute. Therefore, we collect the jobs ids here but we
      # execute these in a separate thread via a job queue without
      # waiting. If the list of jobs gets large, we might consider
      # splitting the list and run multiple jobs in parallel.
      #
      if {[llength $item_ids]} {
        set queue xowfatjobs
        if {$queue ni [ns_job queues]} {
          ns_job create $queue
        }
        ns_job queue -detached $queue [list ::xowf::atjob run_jobs $item_ids]
      }

      :log "--at END"
    }
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
