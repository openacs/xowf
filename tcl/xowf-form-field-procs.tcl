::xo::library doc {
  XoWiki Workflow - form field procs

  @author Gustaf Neumann
  @creation-date 2008-03-05
}

::xo::db::require package xowiki

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::workflow_definition
  #
  ###########################################################

  Class create workflow_definition -superclass textarea -parameter {
    {rows 20}
    {cols 80}
    {dpi 120}
  } -extend_slot_default validator workflow

  workflow_definition instproc as_graph {} {
    set ctx [::xowf::Context new -destroy_on_cleanup -object ${:object} \
                 -all_roles true -in_role none \
                 -workflow_definition [:value] ]
    return [$ctx as_graph -dpi [:dpi] -style "max-width: 35%;"]
  }

  workflow_definition instproc check=workflow {value} {
    # Do we have a syntax error in the workflow definition?
    if {![catch {set ctx [::xowf::Context new \
                              -destroy_on_cleanup -object ${:object} \
                              -all_roles true \
                              -workflow_definition [:value]]} errorMsg]} {
      $ctx initialize_context ${:object}
      ${:object} wf_context $ctx
      unset errorMsg
      array set "" [$ctx check]
      if {$(rc) == 1} {set errorMsg $(errorMsg)}
    }

    if {[info exists errorMsg]} {
      #:msg errorMsg=$errorMsg
      :uplevel [list set errorMsg $errorMsg]
      return 0
    }
    return 1
  }
  workflow_definition instproc pretty_value {v} {
    ${:object} do_substitutions 0
    set text [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;" @ "&#64;"] [:value]]
    return "<div style='width: 65%; overflow:auto;float: left;'>
    <pre class='code'>$text</pre></div>
    <div>[:as_graph]</div><div class='visual-clear'></div>
        [${:object} include my-refers]
   "
  }


  ###########################################################
  #
  # ::xowiki::formfield::current_state
  #
  ###########################################################
  Class create current_state -superclass label -parameter {
    {as_graph true}
  }
  current_state instproc render_input {} {
    next
    if {[:as_graph]} {
      set ctx [::xowf::Context new -destroy_on_cleanup -object ${:object} \
                   -all_roles true -in_role none \
                   -workflow_definition [${:object} wf_property workflow_definition] ]
      #set ctx   [::xowf::Context require ${:object}]
      set graph [$ctx as_graph -current_state [:value] -visited [${:object} visited_states]  -style "max-height: 250px;"]
      ::html::div -style "width: 35%; float: right;" {
        ::html::t -disableOutputEscaping $graph
      }
    }
  }

  current_state instproc pretty_value {v} {
    set g ""
    if {[:as_graph]} {
      set ctx   [::xowf::Context require ${:object}]
      set graph [$ctx as_graph -current_state $v -visited [${:object} visited_states]]
      set g "<div style='width: 35%; float: right;'>$graph</div>"
    }
    return "[next]$g"
  }

}


#
# These definitions are only here for the time being
#
namespace eval ::xo::role {
  Class create Role
  Role instproc get_members args {
    error "get_members are not implemented for [self]"
  }
  Role instproc get_object_id {object} {
    return [$object package_id]
  }
  Role instproc except_clause {{-lhs} except} {
    if {[llength $except] == 0} {
      return true
    } else {
      return [subst {$lhs NOT IN ([ns_dbquotelist $except])}]
    }
  }
  Role create all
  all proc is_member {-user_id:required -package_id} {
    return 1
  }

  Role create swa
  swa proc is_member {-user_id:required -package_id} {
    return [::xo::cc cache [list acs_user::site_wide_admin_p -user_id $user_id]]
  }

  Role create registered_user
  registered_user proc is_member {-user_id:required -package_id} {
    return [expr {$user_id != 0}]
  }
  registered_user proc get_members {-object_id:required {-except ""}} {
    # return just the users with an @ sign, to avoid the users created by automated testing
    set members [::xo::dc list_of_lists get_users [subst {
      select distinct username, user_id
      from registered_users
      where username like '%@%'
      and   [:except_clause -lhs user_id $except]
    }]]
    return $members
  }

  Role create unregistered_user
  unregistered_user proc is_member {-user_id:required -package_id} {
    return [expr {$user_id == 0}]
  }

  Role create admin
  admin proc is_member {-user_id:required -package_id:required} {
    return [::xo::cc permission -object_id $package_id -privilege admin -party_id $user_id]
  }
  admin proc get_members {-object_id:required {-except ""}} {
    set members [permission::get_parties_with_permission \
                     -privilege admin \
                     -object_id $object_id]
    return [::xowiki::filter_option_list $members $except]
  }

  Role create creator
  creator proc is_member {-user_id:required -package_id -object:required} {
    $object instvar creation_user
    return [expr {$creation_user == $user_id}]
  }
  creator proc get_object_id {object} {return [$object item_id]}
  creator proc get_members {-object_id:required  {-except ""}} {
    set creator_id [xo::dc get_value get_owner [subst {
      select o.creation_user from acs_objects o
      where object_id = :object_id
      and   [:except_clause -lhs o.creation_user $except]
    }]]
    return [list [list [::xo::get_user_name $creator_id] $creator_id]]
  }
}
namespace eval ::xo::role {
  Role create app_group_member
  app_group_member proc is_member {-user_id:required -package_id} {
    return [::xo::cc cache [list application_group::contains_party_p \
                                -party_id $user_id \
                                -package_id $package_id]]
  }

  Role create community_member
  community_member proc is_member {-user_id:required -package_id} {
    if {[info commands ::dotlrn_community::get_community_id] ne ""} {
      set community_id [dotlrn_community::get_community_id -package_id $package_id]
      if {$community_id ne ""} {
        return [::xo::cc cache [list dotlrn::user_is_community_member_p \
                                    -user_id $user_id \
                                    -community_id $community_id]]
      }
    }
    return 0
  }

  #
  # RelTypeRole (role definitions based on rel types)
  #
  Class create RelTypeRole -superclass Role -parameter {{rel_type ""}}
  RelTypeRole instproc rel_type_clause {} {
    if {${:rel_type} ne ""} {
      return {r.rel_type = :rel_type}
    } else {
      return {r.rel_type <> 'composition_rel'}
    }
  }
  RelTypeRole instproc filtered_member_list {-group_id:required {-except ""}} {
    set rel_type ${:rel_type}
    set query [subst {
      select r.object_id_two as user_id from acs_rels r, membership_rels mr
      where r.object_id_one = :group_id
      and   [:rel_type_clause]
      and   r.rel_id = mr.rel_id
      and   mr.member_state = 'approved'
      and   [:except_clause -lhs r.object_id_two $except]
    }]
    set member_list [xo::dc list get_group_members $query]
    #ns_log notice "FILTERED member list $member_list"
    return [lmap p $member_list {list [person::name -person_id $p] $p}]
  }
  RelTypeRole instproc filtered_member_p {-group_id:required -user_id:required -rel_type} {
    set rel_type ${:rel_type}
    set query [subst {
      select r.object_id_two as user_id from acs_rels r, membership_rels mr
      where r.object_id_one = :group_id
      and   r.object_id_two = :user_id
      and   [:rel_type_clause]
      and   r.rel_id = mr.rel_id
      and   mr.member_state = 'approved'
    }]
    return [xo::dc 0or1row check_membership $query]
  }
  RelTypeRole instproc get_group_from_package_id {package_id} {
    #
    # Designed to work as well without connection. If we have dotlrn
    # installed, return the community group. Otherwise, return the
    # subsite application group.
    #
    if {[info commands ::dotlrn_community::get_community_id] ne ""} {
      set group_id [search::dotlrn::get_community_id -package_id $package_id]
    } else {
      set subsite_node_id [site_node::closest_ancestor_package \
                               -node_id [site_node_object_map::get_node_id -object_id $package_id] \
                               -package_key [subsite::package_keys] \
                               -include_self \
                               -element "node_id"]
      set subsite_id [site_node::get_object_id  -node_id $subsite_node_id]
      set group_id [application_group::group_id_from_package_id -package_id $subsite_id]
    }
    return $group_id
  }
  RelTypeRole instproc get_object_id {object} {
    return [:get_group_from_package_id [$object package_id]]
  }

  RelTypeRole instproc get_members {-object_id:required {-except ""}} {
    return [:filtered_member_list -group_id $object_id -except $except]
  }
  RelTypeRole instproc is_member {-user_id:required -package_id} {
    set group_id [:get_group_from_package_id $package_id]
    #ns_log notice "IS MEMBER user_id $user_id -package_id $package_id group_id $group_id"
    return [:filtered_member_p -group_id $object_id -user_id $user_id]
  }

  RelTypeRole create member
  RelTypeRole create student -rel_type dotlrn_student_rel
  RelTypeRole create instructor -rel_type dotlrn_instructor_rel
  RelTypeRole create ta -rel_type dotlrn_ta_rel
}




namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::role_member
  #
  ###########################################################

  Class create role_member -superclass candidate_box_select -parameter {
    role
    {except ""}
    {online_state off}
  }
  role_member instproc initialize {} {
    next
    set :is_party_id 1
  }
  role_member instproc render_input {} {
    #:msg role=${:role},obj=${:object}
    if {[nsf::is object ::xo::role::${:role}]} {
      set arguments [list -object_id [::xo::role::${:role} get_object_id ${:object}]]
      if {${:except} eq "current_user_id"} {
        lappend arguments -except [::xo::cc user_id]
      }
      set :options [lsort -index 0 [::xo::role::${:role} get_members {*}$arguments]]
    } elseif {[set gid [group::get_id -group_name ${:role}]] ne ""} {
      set :options [lsort -index 0 [lmap m [group::get_members -group_id $gid] {
        list [::xo::get_user_name $m] $m
      }]]
    } else {
      error "no such role or group '${:role}'"
    }
    next
  }

  role_member instproc get_entry_label {v} {
    set prefix ""
    if {[:online_state]} {
      set prefix "[::xowiki::utility user_is_active -asHTML true $v] "
    }
    return $prefix[::xo::get_user_name $v]
  }

  role_member instproc pretty_value {v} {
    set :options [:get_labels $v]
    next
  }
}

namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::mc_exercise
  #
  ###########################################################

  Class create mc_exercise -superclass CompoundField -parameter {
    {feedback full}
    {inplace true}
  }

  mc_exercise instproc initialize {} {
    :log "[self class] deprecated, you should switch to test-item procs"
    if {${:__state} ne "after_specs"} return
    :create_components  [subst {
      {text  {richtext,required,height=150px,label=#xowf.exercise-text#}}
      {alt-1 {mc_alternative,feedback=${:feedback},label=#xowf.alternative#}}
      {alt-2 {mc_alternative,feedback=${:feedback},label=#xowf.alternative#}}
      {alt-3 {mc_alternative,feedback=${:feedback},label=#xowf.alternative#}}
      {alt-4 {mc_alternative,feedback=${:feedback},label=#xowf.alternative#}}
      {alt-5 {mc_alternative,feedback=${:feedback},label=#xowf.alternative#}}
    }]
    set :__initialized 1
  }

  mc_exercise instproc render_input {} {
    ::xo::Page requireCSS /resources/xowf/myform.css
    next
  }

  mc_exercise instproc pretty_value {v} {
    return [${:object} property form ""]
  }

  mc_exercise instproc convert_to_internal {} {
    #
    # Build a form from the components of the exercise on the fly.
    # Actually, this method computes the properties "form" and
    # "form_constraints" based on the components of this form field.
    #
    set form "<FORM>\n<table class='mchoice'>\n<tbody>"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [:get_named_sub_component_value text]
    append form "<tr><td class='text' colspan='2'>$intro_text</td></tr>\n"
    foreach input_field_name {alt-1 alt-2 alt-3 alt-4 alt-5} {
      foreach f {text correct feedback_correct feedback_incorrect} {
        set value($f) [:get_named_sub_component_value $input_field_name $f]
      }
      append form \
          "<tr><td class='selection'><input type='checkbox' id='$input_field_name' name='$input_field_name' /></td>\n" \
          "<td class='value'><label for='$input_field_name'>$value(text)</label></td></tr>\n"
      set alt_fc [list]
      if {$value(correct)} {lappend alt_fc "answer=on"} else {lappend alt_fc "answer="}
      if {$value(feedback_correct) ne ""} {
        lappend alt_fc "feedback_answer_correct=[::xowiki::formfield::FormField fc_encode $value(feedback_correct)]"
      }
      if {$value(feedback_incorrect) ne ""} {
        lappend alt_fc "feedback_answer_incorrect=[::xowiki::formfield::FormField fc_encode $value(feedback_incorrect)]"
      }
      if {[llength $alt_fc] > 0} {
        append fc [list $input_field_name:checkbox,[join $alt_fc ,]] \n
      }
      #:msg "$input_field_name .correct = $value(correct)"
    }
    append form "</tbody></table></FORM>\n"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
  }

  ###########################################################
  #
  # ::xowiki::formfield::mc_alternative
  #
  ###########################################################

  Class create mc_alternative -superclass CompoundField -parameter {
    {feedback full}
    {inplace true}
  }

  mc_alternative instproc initialize {} {
    :log "[self class] deprecated, you should switch to test-item procs"
    if {${:__state} ne "after_specs"} return

    if {0} {
      set javascript [::xowiki::formfield::FormField fc_encode {
        xinha_config.toolbar = [
                                ['popupeditor', 'bold','italic','createlink','insertimage','separator'],
                                ['killword','removeformat','htmlmode']
                               ];
      }]
      set text_config [subst {editor=xinha,height=100px,label=Text,plugins=OacsFs,inplace=$:{inplace},javascript=$javascript}]
    } else {
      set text_config [subst {editor=wym,height=100px,label=Text}]
    }
    if {[:feedback] eq "full"} {
      set feedback_fields {
        {feedback_correct {textarea,label=Feedback korrekt}}
        {feedback_incorrect {textarea,label=Feedback inkorrekt}}
      }
    } else {
      set feedback_fields ""
    }
    :create_components [subst {
      {text  {richtext,$text_config}}
      {correct {boolean,horizontal=true,label=Korrekt}}
      $feedback_fields
    }]
    set :__initialized 1
  }

  ###########################################################
  #
  # ::xowiki::formfield::grading_scheme
  #
  ###########################################################

  Class create grading_scheme -superclass select -parameter {
  }

  grading_scheme instproc initialize {} {
    if {${:__state} ne "after_specs"} return

    set t1 [clock clicks -milliseconds]
    ::xowf::test_item::grading::load_grading_schemes \
        -package_id [${:object} package_id] \
        -parent_id [${:object} parent_id]

    set :options [lsort [lmap gso [::xowf::test_item::grading::Grading info instances -closure] {
      set grading [namespace tail $gso]
      list [$gso cget -title] $grading
    }]]
    #ns_log notice "#### available grading_scheme_objs (took [expr {[clock clicks -milliseconds]-$t1}]ms)\n[join [lsort ${:options}] \n]"
    next

    set :__initialized 1
  }

  ###########################################################
  #
  # ::xowiki::formfield::grade_boundary
  #
  ###########################################################
  Class create grade_boundary -superclass number -parameter {
  }
  grade_boundary instproc render_input {} {
    #
    # The definition of this validator assumes 4 grade boundaries with
    # exactly these naming conventions. The corresponding form is
    # defined in edit-grading-scheme.wf.
    #
    next
    template::add_event_listener -event input -id ${:id} -script {
      const inputField = event.target;
      const form = inputField.parentNode.parentNode;
      //console.log('check descending values');
      const grade1 = form.elements["grade1"];
      const grade2 = form.elements["grade2"];
      const grade3 = form.elements["grade3"];
      const grade4 = form.elements["grade4"];
      if (grade1.value < grade2.value) {
        console.log('error grade 1');
        grade2.setCustomValidity('percentage for grade 1 must by larger than grade 2');
      } else {
        grade2.setCustomValidity('');
      }
      if (grade2.value < grade3.value) {
        console.log('error grade 2');
        grade3.setCustomValidity('percentage for grade 2 must by larger than grade 3');
      } else {
        grade3.setCustomValidity('');
      }
      if (grade3.value < grade4.value) {
        console.log('error grade 3');
        grade4.setCustomValidity('percentage for grade 3 must by larger than grade 4');
      } else {
        grade4.setCustomValidity('');
      }
    }
  }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
