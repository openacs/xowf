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
  registered_user proc get_members {-object_id:required} {
    # return just the users with an @ sign, to avoid the users created by automated testing
    set members [::xo::dc list_of_lists get_users \
                     "select distinct username, user_id from registered_users where username like '%@%'"]
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
  admin proc get_members {-object_id:required} {
    set members [permission::get_parties_with_permission \
                     -privilege admin \
                     -object_id $object_id]
    #:msg members=$members
    return $members
  }

  Role create creator
  creator proc is_member {-user_id:required -package_id -object:required} {
    $object instvar creation_user
    return [expr {$creation_user == $user_id}]
  }
  creator proc get_object_id {object} {return [$object item_id]}
  creator proc get_members {-object_id:required} {
    set creator_id [xo::dc get_value get_owner {
      select o.creation_user from acs_objects o where object_id = :object_id
    }]
    return [list [list [::xo::get_user_name $creator_id] $creator_id]]
  }

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

}




namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::role_member
  #
  ###########################################################

  Class create role_member -superclass candidate_box_select -parameter {
    role
    {online_state off}
  }
  role_member instproc initialize {} {
    next
    set :is_party_id 1
  }
  role_member instproc render_input {} {
    #:msg role=${:role},obj=${:object}
    if {[info commands ::xo::role::${:role}] ne ""} {
      set object_id [::xo::role::${:role} get_object_id ${:object}]
      set :options [::xo::role::${:role} get_members -object_id $object_id]
    } elseif {[set gid [group::get_id -group_name ${:role}]] ne ""} {
      set :options [list]
      foreach m [group::get_members -group_id $gid] {
        :lappend options [list [::xo::get_user_name $m] $m] }
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
    # Actually, this methods computes the properties "form" and
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
        lappend alt_fc "feedback_answer_incorrect=[::xowiki::formfield:::FormField fc_encode $value(feedback_incorrect)]"
      }
      if {[llength $alt_fc] > 0} {append fc [list $input_field_name:checkbox,[join $alt_fc ,]]\n}
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

}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
