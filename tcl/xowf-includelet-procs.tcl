::xo::library doc {
  XoWiki Workflow - includelet definitions

  @author Gustaf Neumann
  @creation-date 2008-03-05
}

::xo::library require -package xotcl-core 06-package-procs
::xo::library require -package xowiki includelet-procs

namespace eval ::xowiki::includelet {
  #
  # Define additional elements for includelets
  #
  Class create form-menu-button-wf-instances -superclass ::xowiki::includelet::form-menu-button-answers
  Class create form-menu-button-wf -superclass form-menu-button -parameter {
    {method view}
  }

  #
  # Create an includelet called wf-todo, which lists the todo items
  # for a user_id from a single or multiple worflows)
  #
  ::xowiki::IncludeletClass create wf-todo \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-workflow ""}
          {-user_id}
          {-ical 0}
          {-max_entries}
        }}
      }

  wf-todo instproc initialize {} {
    :get_parameters
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}

    set sql {
      select assignee,xowiki_form_page_id,state,i.publish_status,page_template,
      p.creation_date, p.last_modified, p,description,
      i2.name as wf_name,p.title,i.name,i.parent_id,o.package_id as pid
      from xowiki_form_pagei p,cr_items i, cr_items i2, acs_objects o
      where (assignee = :user_id or acs_group__member_p(:user_id,assignee, 'f'))
      and i.live_revision = xowiki_form_page_id
      and p.page_template = i2.item_id
      and o.object_id = xowiki_form_page_id
    }
    if {$workflow ne ""} {
      # The workflow might be of one of the following forms:
      #   name
      #   <language prefix>:name
      #   /path-in-package/<language prefix>:name
      #   //package/<language prefix>:name
      #   //package/path-in-package/<language prefix>:name
      #
      # To address all workflow of a package instance, use
      #   //package/
      #
      if {[regexp {^/(/.*)/$} $workflow _ package]} {
        # all workflows from this package
        ::xowf::Package initialize -url $package
        #:msg "using package_id=$package_id"
        append sql " and o.package_id = :package_id"
      } else {
        if {[regexp {^/(/[^/]+)(/.+)$} $workflow _ package path]} {
          ::xowf::Package initialize -url $package
          #:msg "using package_id=$package_id"
        } else {
          set path $workflow
        }
        set parent_id [${:__including_page} parent_id]
        set wf_page [::$package_id get_page_from_item_ref -parent_id $parent_id $path]
        if {$wf_page eq ""} {
          :msg "cannot resolve page $workflow"
          set package_id -1; set page_template -1
        } else {
          set page_template [$wf_page item_id]
          set package_id [$wf_page package_id]
        }
        #:msg "page_template=$page_template pkg=$package_id"
        append sql " and o.package_id = :package_id and p.page_template = :page_template"
      }
    }

    append sql " order by p.last_modified desc"

    set :items [::xowiki::FormPage instantiate_objects -sql $sql]
  }

  wf-todo instproc render_ical {} {
    foreach i [${:items} children] {
      $i instvar wf_name name title state xowiki_form_page_id pid description parent_id
      ::xowf::Package initialize -package_id $pid

      $i class ::xo::ical::VTODO
      $i configure -uid $pid-$xowiki_form_page_id \
          -url [$pid pretty_link -absolute true $parent_id $name] \
          -summary "$title ($state)" \
          -description "Workflow instance of workflow $wf_name $description"
    }
    ${:items} mixin ::xo::ical::VCALENDAR
    ${:items} configure -prodid "-//WU Wien//NONSGML XoWiki Content Flow//EN"
    set text [${:items} as_ical]
    #:log "--ical sending $text"
    #ns_return 200 text/calendar $text
    ns_return 200 text/plain $text
  }

  wf-todo instproc render {} {
    :get_parameters
    if {$ical} {
      return [:render_ical]
    }
    set t [TableWidget new -volatile \
               -columns {
                 Field create package -label Package
                 AnchorField create wf -label Workflow
                 AnchorField create title -label "Todo"
                 Field create state -label [::xowiki::FormPage::slot::state set pretty_name]
               }]
    foreach i [${:items} children] {
      $i instvar wf_name name title state xowiki_form_page_id pid parent_id
      ::xowf::Package initialize -package_id $pid
      $t add \
          -wf $wf_name \
          -wf.href [$pid pretty_link -parent_id $parent_id $wf_name] \
          -title $title \
          -title.href [$pid pretty_link -parent_id $parent_id $name] \
          -state $state \
          -package [$pid package_url]
    }
    return [$t asHTML]
  }

}

namespace eval ::xowiki::includelet {
  #
  # countdown-timer based on answer_manager.countdown_timer
  #
  Class create countdown-timer -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-target_time ""}
        }}
      } -ad_doc {
        Countdown timer

        @param target_time
      }

  countdown-timer instproc render {} {
    :get_parameters
    return [xowf::test_item::answer_manager countdown_timer \
                -target_time $target_time -id [::xowiki::Includelet html_id [self]]]
  }
}

namespace eval ::xowiki::includelet {
  #
  # exam-top-includelet
  #
  Class exam-top-includelet -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-target_time ""}
          {-url_poll ""}
          {-url_dismiss ""}
          {-poll_interval 5000}          
        }}
      } -ad_doc {
        
        This is the top includelet for the in-class exam, containing a
        countdown timer and the personal notifications includelet

        @param target_time
        @param url_poll
        @param url_dismiss
        @param poll_interval
      }

  exam-top-includelet instproc render {} {
    :get_parameters

    if {$url_poll ne ""} {
      set pn [${:__including_page} include \
                  [list personal-notification-messages \
                       -url_poll $url_poll \
                       -url_dismiss $url_dismiss \
                       -poll_interval $poll_interval \
                      ]]
    } else {
      set pn ""
    }
    return [subst {
      [${:__including_page} include [list countdown-timer -target_time $target_time]]
      $pn
    }]
  }

}


::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
