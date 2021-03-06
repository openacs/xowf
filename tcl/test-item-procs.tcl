:::xo::db::require package xowiki
namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::FormGeneratorField
  #
  ###########################################################

  Class create FormGeneratorField -superclass CompoundField -parameter {
  }
  FormGeneratorField set abstract 1
  FormGeneratorField instproc pretty_value {v} {
    return [${:object} property form ""]
  }
  FormGeneratorField instproc render_input {} {
    ::xo::Page requireCSS /resources/xowf/myform.css
    next
  }

}
namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::test_item
  #
  ###########################################################
  Class create test_item -superclass FormGeneratorField -parameter {
    {question_type mc}
    {nr_choices 5}
    {feedback_level full}
  }
  
  #
  # provide a default setting for xinha JavaScript for test-items
  #
  test_item set xinha(javascript) [::xowiki::formfield::FormField fc_encode { 
    xinha_config.toolbar = [ 
                            ['popupeditor', 'bold','italic','createlink','insertimage','separator'], 
                            ['killword','removeformat','htmlmode'] 
                           ]; 
  }]

  test_item instproc feed_back_definition {auto_correct} {
    #
    # Return the definition of the feed_back widgets depending on the
    # value of auto_correct. If we can't determine automatically,
    # what's wrong, we can't provide different feedback for right or
    # wrong.
    #
    :instvar inplace feedback_level
    if {$feedback_level eq "none"} {
      return ""
    }

    set widget "richtext,editor=ckeditor4,height=150px"
    if {$auto_correct} {
      return [subst {
        {feedback_correct   {$widget,label=#xowf.feedback_correct#}}
        {feedback_incorrect {$widget,label=#xowf.feedback_incorrect#}}
      }]
    }
    return [subst {
      {feedback {$widget,label=#xowf.feedback#}}
    }]
  }

  #
  # test_item is the wrapper for interaction to be used in
  # evaluations. Different wrapper can be defined in a similar way for
  # questionairs, which might need less input fields.
  #
  test_item instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    :instvar inplace feedback_level
    set options ""
    #
    # Provide some settings for name short-cuts
    #
    switch -- [:question_type] {
      mc { # we should support as well: minChoices, maxChoices, shuffle
        set interaction_class mc_interaction
        set options nr_choices=[:nr_choices]
      }
      sc { # we should support as well: minChoices, maxChoices, shuffle
        set interaction_class mc_interaction
        set options nr_choices=[:nr_choices],multiple=false
      }
      ot { set interaction_class text_interaction }
      default {error "unknown question type: [:question_type]"}
    }

    set auto_correct [expr {[$interaction_class exists auto_correct] && 
                            [$interaction_class set auto_correct] == false ? 0 : 1}]
    
    # For the time being, we set inplace to false, otherwise we can't
    # currently edit empty fields
    set inplace true

    #
    # handle feedback_level
    #
    # The object might be a form, just use the property, if we are on
    # a FormPage.
    if {[${:object} istype ::xowiki::FormPage]} {
      set feedback_level_property [${:object} property feedback_level]
      if {$feedback_level_property ne ""} {
        set feedback_level $feedback_level_property
      }
    }

    #
    :create_components  [subst {
      {minutes numeric,size=2,label=#xowf.Minutes#}
      {grading {select,options={exact exact} {partial partial},default=exact,label=#xowf.Grading-Schema#}}
      {interaction {$interaction_class,$options,feedback_level=$feedback_level,inplace=$inplace}}
      [:feed_back_definition $auto_correct]
    }]
    set :__initialized 1
  }


}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::mc_interaction
  #
  ###########################################################

  Class create mc_interaction -superclass FormGeneratorField -parameter {
    {feedback_level full}
    {inplace false}
    {shuffle false}
    {nr_choices 5}
    {multiple true}
  }

  mc_interaction instproc set_compound_value {value} {
    set r [next]
    if {![:multiple]} {
      # For single choice questions, we have a fake-field for denoting
      # the correct entry. We have to distribute this to the radio
      # element, which is rendered.
      set correct_field_name [:get_named_sub_component_value correct]
      if {$correct_field_name ne ""} {
        foreach c [:components] {
          if {[$c name] eq $correct_field_name} {
            ${c}::correct value $correct_field_name
          }
        }
      }
    }
    return $r
  }

  mc_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    test_item instvar {xinha(javascript) javascript}
    :instvar feedback_level inplace input_field_names nr_choices
    #
    # build choices
    #

    if {![:multiple]} {
      append choices "{correct radio,omit}\n"
    }
    #
    # create component structure
    #
    :create_components  [subst {
      {text  {richtext,required,height=150px,editor=ckeditor4,label=#xowf.exercise-text#}}
      {mc {mc_choice,feedback_level=$feedback_level,label=#xowf.alternative#,multiple=[:multiple],repeat=1..$nr_choices}}
    }]
    set :__initialized 1
  }
  mc_interaction set auto_correct true
  mc_interaction instproc convert_to_internal {} {
    #
    # Build a form from the components of the exercise on the fly.
    # Actually, this methods computes the properties "form" and
    # "form_constraints" based on the components of this form field.
    # 
    set form "<FORM>\n<table class='mchoice'>\n<tbody>"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [:get_named_sub_component_value text]
    append form "<tr><td class='text' colspan='2'><div class='question_text'>$intro_text</div></td></tr>\n"

    #my msg " input_field_names=${:input_field_names}"
    set mc [:get_named_sub_component_value mc]
    ns_log notice "MC <$mc>"
    
    if {![:multiple]} {
      set correct_field_name [:get_named_sub_component_value correct]
    }

    #set input_field_names [lmap {name .} $mc {set name}]
    set input_field_names {}
    foreach {name .} $mc {lappend input_field_names $name}

    #mc_exercise.mc.0 {mc_exercise.mc.0.text {} mc_exercise.mc.0.correct t}
    #mc_exercise.mc.1 {mc_exercise.mc.1.text a mc_exercise.mc.1.correct t}
    #ns_log notice input_field_names=$input_field_names
    
    # don't iterate over the template field
    foreach {input_field_name data} [lrange $mc 2 end] {
      foreach f {text correct feedback_correct feedback_incorrect} {
        if {[dict exists $data $input_field_name.$f]} {
          set value($f) [dict get $data $input_field_name.$f]
        } else {
          set value($f) ""
        }
        #ns_log notice "$input_field_name: value($f) = <$value($f)>"
      }
      # skip empty entries
      if {$value(text) eq ""} continue

      regsub -all {[.:]} [${:object} name] "" form_name
      set input_field_name $form_name-[lindex [split $input_field_name .] end]
      #
      # fill values into form
      #
      if {[:multiple]} {
        set correct $value(correct)
        append form \
            "<tr><td class='selection'><input type='checkbox' id='$input_field_name' name='$input_field_name' value='$input_field_name'/></td>\n" \
            "<td class='value'><label for='$input_field_name'>$value(text)</label></td></tr>\n"
      } else {
        #my msg $correct_field_name,[:name],$input_field_name
        set correct [expr {"[:name].$input_field_name" eq $correct_field_name}]
        append form \
            "<tr><td class='selection'><input id='$input_field_name' type='radio' name='radio' value='$input_field_name' /></td>\n" \
            "<td class='value'><label for='$input_field_name'>$value</label></td></tr>\n"
      }
      #ns_log notice "$input_field_name [array get value] corr=$correct"
      #my msg "[array get value] corr=$correct"

      #
      # build form constraints per input field
      #
      set if_fc [list]
      if {[string is true -strict $correct]} {lappend if_fc "answer=$input_field_name"} else {lappend if_fc "answer="}
      if {$value(feedback_correct) ne ""} {
        lappend if_fc "feedback_answer_correct=[::xowiki::formfield::FormField fc_encode $value(feedback_correct)]"
      }
      if {$value(feedback_incorrect) ne ""} {
        lappend if_fc "feedback_answer_incorrect=[::xowiki::formfield:::FormField fc_encode $value(feedback_incorrect)]"
      }
      if {[llength $if_fc] > 0} {append fc [list $input_field_name:checkbox,[join $if_fc ,]]\n}
      #my msg "$input_field_name .correct = $value(correct)"
    }

    if {![:multiple]} {
      regexp {[.]([^.]+)$} $correct_field_name _ correct_field_value
      lappend fc "radio:text,answer=$correct_field_value"
    }
    append form "</tbody></table></FORM>\n"
    #ns_log notice FORM=$form
    #ns_log notice FC=$fc
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct [[self class] set auto_correct]
    ${:object} set_property -new 1 has_solution true
  }

  ###########################################################
  #
  # ::xowiki::formfield::mc_choice
  #
  ###########################################################

  Class create mc_choice -superclass FormGeneratorField -parameter {
    {feedback_level full}
    {inplace true}
    {multiple true}
  }

  mc_choice instproc initialize {} {
    if {${:__state} ne "after_specs"} return

    if {1} {
      test_item instvar {xinha(javascript) javascript}
      set text_config [subst {height=100px,label=Text}]
    } else {
      set text_config [subst {editor=wym,height=100px,label=Text}]
    }
    if {[:feedback_level] eq "full"} {
      set feedback_fields {
        {feedback_correct {textarea,cols=60,label=#xowf.feedback_correct#}}
        {feedback_incorrect {textarea,cols=60,label=#xowf.feedback_incorrect#}}
      }
    } else {
      set feedback_fields ""
    }
    if {[:multiple]} {
      # We are in a multiple choice item; provide for editing a radio
      # group per alternative.
      :create_components [subst {
        {text  {richtext,editor=ckeditor4,$text_config}}
        {correct {boolean,horizontal=true,label=#xowf.correct#}}
        $feedback_fields
      }]
    } else {
      # We are in a single choice item; provide for editing a single
      # radio group spanning all entries.  Use as name for grouping
      # the form-field name minus the last segment.
      regsub -all {[.][^.]+$} [:name] "" groupname
      :create_components [subst {
        {text  {richtext,editor=ckeditor4,$text_config}}
        {correct {radio,label=#xowf.correct#,forced_name=$groupname.correct,options={"" [:name]}}}
        $feedback_fields
      }]
    }
    set :__initialized 1
  }
}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::text_interaction
  #
  ###########################################################

  Class create text_interaction -superclass FormGeneratorField -parameter {
    {feedback_level full}
    {inplace true}
  }
  text_interaction set auto_correct false

  text_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    test_item instvar {xinha(javascript) javascript}
    :instvar feedback_level inplace input_field_names
    #
    # create component structure
    #
    :create_components  [subst {
      {text  {richtext,required,editor=ckeditor4,height=150px,label=#xowf.exercise-text#,plugins=OacsFs,javascript=$javascript,inplace=$inplace}}
      {lines {numeric,default=10,size=3,label=#xowf.lines#}}
      {columns {numeric,default=60,size=3,label=#xowf.columns#}}
    }]
    set :__initialized 1
  }

  text_interaction instproc convert_to_internal {} {
    set form "<FORM>\n"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [:get_named_sub_component_value text]
    set lines      [:get_named_sub_component_value lines]
    set columns    [:get_named_sub_component_value columns]
    append form "<div class='question_text'>$intro_text</div>\n"
    append form "<textarea name='answer' rows='$lines' cols='$columns'></textarea>\n" 
    append fc "answer:textarea"
    append form "</FORM>\n"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct [[self class] set auto_correct]
    ${:object} set_property -new 1 has_solution false
  }
}


namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::test_section
  #
  ###########################################################

  Class create test_section -superclass {form_page} -parameter {
    {multiple true}
  }

  test_section instproc pretty_value {v} {
    return [${:object} property form ""]
  }

  test_section instproc convert_to_internal {} {
    #
    # Build a complex form composed of the specified form pages names
    # contained in the value of this field.  The form-fields have to
    # be renamed. This affects the input field names in the form and
    # the form constraints. We use the item-id contained pages as a the
    # prefix for the form-fields. This method must be most likely
    # extended for other question types.
    # 
    set form "<form>\n"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [${:object} property _text]
    append form "$intro_text\n<ol>\n"
    foreach v [:value] {
      # TODO: the next two commands should not be necessary to lookup
      # again, since the right values are already loaded into the
      # options
      set item_id [[${:object} package_id] lookup -name $v]
      set page [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      append form "<li><h2>[$item_id title]</h2>\n"
      set prefix c$item_id
      set __ia [$page set instance_attributes]
      #
      # If for some reason, we have not form entry, we ignore it.
      # TODO: We should deal here with computed forms and with true
      # ::xowiki::forms as well...
      #
      if {![dict exists $__ia form]} {
        :msg "$v has no form included"
        continue
      }
      #
      # Replace the form-field names in the form
      #
      dom parse -simple -html [dict get $__ia form] doc
      $doc documentElement root
      set alt_inputs [list]
      set alt_values [list]
      foreach html_type {input textarea} {
        foreach n [$root selectNodes "//$html_type\[@name != ''\]"] {
          set alt_input [$n getAttribute name]
          $n setAttribute name $prefix-$alt_input
          if {$html_type eq "input"} {
            set alt_value [$n getAttribute value]
          } else {
            set alt_value ""
          }
          lappend alt_inputs $alt_input
          lappend alt_values $alt_value
        }
      }
      # We have to drop the toplevel <FORM> of the included form
      foreach n [$root childNodes] {append form [$n asHTML]}
      append form "</li>\n"
      #
      # Replace the formfield names in the form constraints
      #
      foreach f [dict get $__ia form_constraints] {
        if {[regexp {^([^:]+):(.*)$} $f _ field_name definition]} {
          if {[string match @* $field_name]} continue
          # keep all form-constraints for which we have altered the name
          #my msg "old fc=$f, [list lsearch -exact $alt_inputs $field_name] => [lsearch -exact $alt_inputs $field_name] $alt_values"
          set ff [${:object} create_raw_form_field -name $field_name -spec $definition]
          #my msg "ff answer => '[$ff answer]'"
          if {$field_name in $alt_inputs} {
            lappend fc $prefix-$f
          } elseif {[$ff exists answer] && $field_name eq [$ff answer]} {
            # this rules is for single choice
            lappend fc $prefix-$f
          }
        }
      }
    }
    append form "</ol></form>\n"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    # for mixed test sections (e.g. text interaction and mc), we have
    # to combine the values of the items
    ${:object} set_property -new 1 auto_correct true ;# should be computed
    ${:object} set_property -new 1 has_solution true ;# should be computed
    #my msg "fc=$fc"
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
