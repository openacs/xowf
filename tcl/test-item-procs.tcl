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
    ::xo::Page requireCSS /resources/xowf/form-generator.css
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::TestItemField
  #
  ###########################################################
  Class create TestItemField -superclass FormGeneratorField -parameter {
    {feedback_level full}
    {auto_correct:boolean false}
  } -ad_doc {

    Abstract class for defining common attributes for all Test Item
    fields.

    @param feedback_level "full", "single", or "none"
    @param auto_correct boolean to let user add auto correction fields
  }
  TestItemField set abstract 1


  ###########################################################
  #
  # ::xowiki::formfield::test_item
  #
  ###########################################################
  Class create test_item -superclass TestItemField -parameter {
    {question_type mc}
    {nr_choices 5}
    {grading exact}
  } -ad_doc {

    Wrapper for complex test items, containing specification for
    minutes, grading scheme, feedback levels, handling different types
    of questions ("interactions" in the terminology of QTI). When such
    a question is saved, a HTML form is generated, which is used as a
    question.

    @param feedback_level "full", "single", or "none"
    @param grading one of "exact", "partial", or "none"
    @param nr_choices number of choices
    @param question_type "mc", "sc", "ot", or "te"
  }

  #
  # Provide a default setting for the rich-text widgets.
  #
  test_item set richtextWidget {richtext,editor=ckeditor4,ck_package=standard,extraPlugins=}

  test_item instproc feed_back_definition {} {
    #
    # Return the definition of the feed_back widgets depending on the
    # value of :feedback_level.
    #
    if {${:feedback_level} eq "none"} {
      return ""
    }

    set widget [test_item set richtextWidget]
    switch ${:feedback_level} {
      "none" {
        set definition ""
      }
      "single" {
        set definition [subst {
          {feedback_correct   {$widget,height=150px,label=#xowf.feedback#}}
        }]
      }
      "full" {
        set definition [subst {
          {feedback_correct   {$widget,height=150px,label=#xowf.feedback_correct#}}
          {feedback_incorrect {$widget,height=150px,label=#xowf.feedback_incorrect#}}
        }]
      }
    }
    return $definition
  }

  #
  # "test_item" is the wrapper for interaction to be used in
  # evaluations. Different wrapper can be defined in a similar way for
  # questionnaires, which might need less input fields.
  #
  test_item instproc initialize {} {
    if {${:__state} ne "after_specs"} {
      return
    }
    set options ""
    #
    # Provide some settings for name short-cuts
    #
    switch -- ${:question_type} {
      mc { # we should support as well: minChoices, maxChoices
        #
        # Old style, kept just for backwards compatibility for the
        # time being. one should use "mc2" instead.
        #
        set interaction_class mc_interaction
        set options nr_choices=[:nr_choices]
        set options ""
        set auto_correct true
        set can_shuffle false
      }
      sc { # we should support as well: minChoices, maxChoices
        set interaction_class mc_interaction
        set options nr_choices=[:nr_choices],multiple=false
        set auto_correct true
        set can_shuffle true
      }
      mc2 { # we should support as well: minChoices, maxChoices
        set interaction_class mc_interaction2
        set options ""
        set auto_correct true
        set can_shuffle true
      }
      ot {
        set interaction_class text_interaction
        set auto_correct ${:auto_correct}
        set can_shuffle false
      }
      te {
        set interaction_class text_entry_interaction
        #set options nr_choices=[:nr_choices]
        set auto_correct ${:auto_correct}
        set can_shuffle true
      }
      default {error "unknown question type: ${:question_type}"}
    }
    :log test_item-auto_correct=$auto_correct
    #
    # Handle feedback_level.
    #
    # The object might be a form, just use the property, if we are on
    # a FormPage.
    #
    if {[${:object} istype ::xowiki::FormPage]} {
      set feedback_level_property [${:object} property feedback_level]
      if {$feedback_level_property ne ""} {
        set :feedback_level $feedback_level_property
      }
    }

    if {${:grading} ne "none"} {
      if {${:grading} ni {exact partial}} {
        error "invalid grading '$grading'; valid are 'exact' or 'partial'"
      }
      set options "{exact exact} {partial partial}"
      set gradingSpec [subst {grading {select,options=$options,default=${:grading},label=#xowf.Grading-Schema#}}]
    } else {
      set gradingSpec ""
    }

    if {$can_shuffle} {
      set shuffle_options "{None none} {{Per user} peruser} {Always always}"
      set shuffleSpec [subst {{shuffle {radio,horizontal=true,options=$shuffle_options,default=none,label=#xowf.Shuffle#}}}]
    } else {
      set shuffleSpec ""
    }
    :create_components  [subst {
      {minutes number,min=1,default=2,label=#xowf.Minutes#}
      $gradingSpec
      $shuffleSpec
      {interaction {$interaction_class,$options,feedback_level=${:feedback_level},auto_correct=${:auto_correct},label=}}
      [:feed_back_definition]
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

  Class create mc_interaction -superclass TestItemField -parameter {
    {nr_choices 5}
    {multiple true}
  }
  mc_interaction set auto_correct true

  mc_interaction instproc set_compound_value {value} {
    set r [next]
    if {!${:multiple}} {
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
    #
    # build choices
    #

    if {!${:multiple}} {
      append choices "{correct radio,omit}\n"
    }
    #
    # create component structure
    #
    set widget [test_item set richtextWidget]
    :create_components  [subst {
      {text  {$widget,required,height=150px,label=#xowf.exercise-text#}}
      {mc {mc_choice,feedback_level=${:feedback_level},label=#xowf.alternative#,multiple=${:multiple},repeat=1..${:nr_choices}}}
    }]
    set :__initialized 1
  }

  mc_interaction instproc convert_to_internal {} {
    #
    # Build a form from the components of the exercise on the fly.
    # Actually, this methods computes the properties "form" and
    # "form_constraints" based on the components of this form field.
    #
    set form "<form>\n<table class='mchoice'>\n<tbody>"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [:get_named_sub_component_value text]
    append form "<tr><td class='text' colspan='2'><div class='question_text'>$intro_text</div></td></tr>\n"

    #:msg " input_field_names=${:input_field_names}"
    set mc [:get_named_sub_component_value mc]
    ns_log notice "MC <$mc>"

    if {!${:multiple}} {
      set correct_field_name [:get_named_sub_component_value correct]
    }

    #set input_field_names [lmap {name .} $mc {set name}]
    set input_field_names {}
    foreach {name .} $mc {lappend input_field_names $name}

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
      if {${:multiple}} {
        set correct $value(correct)
        append form \
            "<tr><td class='selection'>" \
            "<input type='checkbox' id='$input_field_name' name='$input_field_name' value='$input_field_name'/>" \
            "</td>\n" \
            "<td class='value'><label for='$input_field_name'>$value(text)</label></td></tr>\n"
      } else {
        #:msg $correct_field_name,${:name},$input_field_name
        set correct [expr {"${:name}.$input_field_name" eq $correct_field_name}]
        append form \
            "<tr><td class='selection'>" \
            "<input id='$input_field_name' type='radio' name='radio' value='$input_field_name' /></td>\n" \
            "<td class='value'><label for='$input_field_name'>$value</label></td></tr>\n"
      }
      #ns_log notice "$input_field_name [array get value] corr=$correct"
      #:msg "[array get value] corr=$correct"

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
      #:msg "$input_field_name .correct = $value(correct)"
    }

    if {!${:multiple}} {
      regexp {[.]([^.]+)$} $correct_field_name _ correct_field_value
      lappend fc "radio:text,answer=$correct_field_value"
    }
    append form "</tbody></table></form>\n"
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

  Class create mc_choice -superclass TestItemField -parameter {
    {multiple true}
  }

  mc_choice instproc initialize {} {
    if {${:__state} ne "after_specs"} return

    set text_config [subst {height=100px,label=Text}]

    if {[:feedback_level] eq "full"} {
      set feedback_fields {
        {feedback_correct {textarea,cols=60,label=#xowf.feedback_correct#}}
        {feedback_incorrect {textarea,cols=60,label=#xowf.feedback_incorrect#}}
      }
    } else {
      set feedback_fields ""
    }

    set widget [test_item set richtextWidget]
    if {${:multiple}} {
      # We are in a multiple-choice item; provide for editing a radio
      # group per alternative.
      :create_components [subst {
        {text  {$widget,$text_config}}
        {correct {boolean,horizontal=true,label=#xowf.correct#}}
        $feedback_fields
      }]
    } else {
      # We are in a single-choice item; provide for editing a single
      # radio group spanning all entries.  Use as name for grouping
      # the form-field name minus the last segment.
      regsub -all {[.][^.]+$} ${:name} "" groupname
      :create_components [subst {
        {text  {$widget,$text_config}}
        {correct {radio,label=#xowf.correct#,forced_name=$groupname.correct,options={"" ${:name}}}}
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

  Class create text_interaction -superclass TestItemField -parameter {
  }
  #text_interaction set auto_correct false

  text_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

    if {${:auto_correct}} {
      set autoCorrectSpec {{correct_when {correct_when,label=#xowf.correct_when#}}}
    } else {
      set autoCorrectSpec ""
    }

    :create_components  [subst {
      {text  {$widget,label=#xowf.exercise-text#,plugins=OacsFs}}
      {lines {number,min=1,default=10,label=#xowf.answer_lines#}}
      {columns {number,min=1,max=80,default=60,label=#xowf.answer_columns#}}
      $autoCorrectSpec
    }]
    set :__initialized 1
  }

  text_interaction instproc convert_to_internal {} {
    set intro_text [:get_named_sub_component_value text]
    set lines      [:get_named_sub_component_value lines]
    set columns    [:get_named_sub_component_value columns]

    if {${:auto_correct}} {
      set correct_when [:get_named_sub_component_value correct_when]
      set correct_when [::xowiki::formfield::FormField fc_encode correct_when=$correct_when],
      #ns_log notice "correct_when <$correct_when>"

    } else {
      set correct_when ""
    }

    append form \
        "<form>\n" \
        "<div class='text_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@\n" \
        "</div>\n" \
        "</form>\n"
    append fc \
        "@categories:off @cr_fields:hidden\n" \
        "{answer:textarea,disabled_as_div=1,rows=$lines,cols=$columns,$correct_when,label=Answer}"

    #ns_log notice "text_interaction $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
  }
}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::text_entry_interaction
  #
  ###########################################################

  Class create text_entry_interaction -superclass TestItemField -parameter {
  }

  text_entry_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    :create_components [subst {
      {text  {$widget,label=#xowf.exercise-text#,plugins=OacsFs}}
      {answer {text_entry_field,repeat=1..5,label=}}
    }]
    set :__initialized 1
  }

  text_entry_interaction instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set answerFields [:get_named_sub_component_value answer]
    set shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]

    set options {}
    set answer {}
    set count 0

    foreach {fieldName value} $answerFields {
      # skip template entry
      if {[lindex [split $fieldName .] end] eq 0} {
        continue
      }
      #ns_log notice ...fieldName=$fieldName->$value
      set af answer[incr count]
      lappend options [list [dict get $value $fieldName.text] $af]
      lappend answer [dict get $value $fieldName.correct_when]
    }

    set options [::xowiki::formfield::FormField fc_encode $options]
    set answer [::xowiki::formfield::FormField fc_encode $answer]

    append form \
        "<form>\n" \
        "<div class='text_entry_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \n \
        "</div>\n" \
        "</form>\n"
    set fc {}
    lappend fc \
        "answer:text_fields,disabled_as_div=1,options=$options,shuffle_kind=$shuffle_kind,answer=$answer,label="  \
        @categories:off @cr_fields:hidden

    ns_log notice "text_entry_interaction $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
  }

  #
  # ::xowiki::formfield::text_entry_field
  #
  Class create text_entry_field -superclass TestItemField -parameter {
  }

  text_entry_field instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

    #
    # Get auto_correct from the interaction (passing "auto_correct="
    # via form constrain would requires to extend the RepeatContainer,
    # otherwise the attribute is rejected).
    #
    set p [:info parent]
    while {1} {
      if {![$p istype ::xowiki::formfield::FormField]} break
      if {![$p istype ::xowiki::formfield::text_entry_interaction]} {
        set p [$p info parent]
        continue
      }
      set :auto_correct [$p set auto_correct]
      break
    }
    #:log "[:name] auto_correct ${:auto_correct}"

    if {${:auto_correct}} {
      set autoCorrectSpec {{correct_when {correct_when,label=#xowf.correct_when#}}}
    } else {
      set autoCorrectSpec ""
    }
    #:msg autoCorrectSpec=$autoCorrectSpec
    :create_components  [subst {
      {text  {$widget,height=100px,label=Teilaufgabe,plugins=OacsFs}}
      $autoCorrectSpec
    }]
    set :__initialized 1
  }

}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::mc_interaction2
  #
  ###########################################################

  Class create mc_interaction2 -superclass TestItemField -parameter {
  }

  mc_interaction2 instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    #ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    :create_components  [subst {
      {text  {$widget,label=#xowf.exercise-text#,plugins=OacsFs}}
      {answer {mc_field,repeat=1..10,label=}}
    }]
    set :__initialized 1
  }

  mc_interaction2 instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    set answerFields [:get_named_sub_component_value answer]

    set count 0
    set options {}
    set correct {}
    foreach {fieldName value} $answerFields {
      # skip template entry
      if {[lindex [split $fieldName .] end] eq 0} {
        continue
      }
      ns_log notice ...fieldName=$fieldName->$value
      #set af answer[incr count]
      set text [dict get $value $fieldName.text]
      # trim leading <p> since this causes a newline in the checkbox label
      regexp {^\s*(<p>)(.*)$} $text . . text
      lappend options [list $text [incr count]]
      lappend correct [dict get $value $fieldName.correct]
    }
    set options [::xowiki::formfield::FormField fc_encode $options]
    set fc [list answer:checkbox,richtext=1,answer=$correct,shuffle_kind=$shuffle_kind,options=$options]

    append form \
        "<form>\n" \
        "<div class='mc_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \n \
        "</div>" \n \
        "</form>\n"
    lappend fc @categories:off @cr_fields:hidden

    ns_log notice "mc_interaction2 $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
  }

  #
  # ::xowiki::formfield::mc_field
  #
  Class create mc_field -superclass TestItemField -parameter {
  }

  mc_field instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

    if {${:auto_correct}} {
      set autoCorrectSpec {{correct_when {correct_when,label=#xowf.correct_when#}}}
    } else {
      set autoCorrectSpec ""
    }
    #:msg autoCorrectSpec=$autoCorrectSpec
    :create_components  [subst {
      {text  {$widget,height=100px,label=Teilaufgabe,plugins=OacsFs}}
      {correct {boolean,horizontal=true,label=Korrekt}}
    }]
    set :__initialized 1
  }

}


namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::upload_interaction
  #
  ###########################################################

  Class create upload_interaction -superclass TestItemField -parameter {
  }
  upload_interaction set auto_correct false

  upload_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} {
      return
    }
    set widget [test_item set richtextWidget]
    :create_components  [subst {
      {text  {$widget,height=150px,label=#xowf.exercise-text#,plugins=OacsFs}}
    }]
    set :__initialized 1
  }

  upload_interaction instproc convert_to_internal {} {
    set intro_text [:get_named_sub_component_value text]
    append form \
        "<form>\n" \
        "<div class='upload_interaction'>\n" \
    "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \
        "</div>\n" \
        "</form>\n"
    append fc \
        "@categories:off @cr_fields:hidden\n" \
        "answer:file"
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
      append form "<li><h2>[::$item_id title]</h2>\n"
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
      # We have to drop the toplevel <form> of the included form
      foreach n [$root childNodes] {append form [$n asHTML]}
      append form "</li>\n"
      #
      # Replace the formfield names in the form constraints
      #
      foreach f [dict get $__ia form_constraints] {
        if {[regexp {^([^:]+):(.*)$} $f _ field_name definition]} {
          if {[string match @* $field_name]} continue
          # keep all form-constraints for which we have altered the name
          #:msg "old fc=$f, [list lsearch -exact $alt_inputs $field_name] => [lsearch -exact $alt_inputs $field_name] $alt_values"
          set ff [${:object} create_raw_form_field -name $field_name -spec $definition]
          #:msg "ff answer => '[$ff answer]'"
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
    #:msg "fc=$fc"
  }
}

namespace eval ::xowf::test_item {

  nx::Object create renaming_form_loader {
    #
    # Form loader that renames "generic" form-field-names as provided
    # by the test-item form-field classes (@answer@) into names based
    # on the form name, such that multiple of these form names can be
    # processed together without name clashes.
    #

    :object method map_form_constraints {form_constraints oldName newName} {
      #
      # Rename form constraints starting with $oldName into $newName.
      # Handle as well "answer=$oldName" form constraint properties.
      #
      return [lmap f $form_constraints {
        #:msg check?'$f'
        if {[string match "${oldName}*" $f]} {
          regsub $oldName $f $newName f
          if {[string match "*answer=$oldName*" $f]} {
            regsub answer=$oldName $f answer=$newName f
            #:log "MAP VALUE=answer=$oldName => answer=$newName "
          }
        }
        set f
      }]
    }

    :public object method form_name_based_attribute_stem {formName} {
      #
      # Produce from the provided 'formName' an attribute stem for the
      # input fields of this form.
      #
      set strippedName [lindex [split $formName :] end]
      regsub -all {[-]} $strippedName _ stem
      return ${stem}_
    }

    :public object method get_form_object {{-set_title:boolean true} ctx form_name} {
      #:msg "renaming_form_loader for form_name <$form_name>"
      set form_id [$ctx default_load_form_id $form_name]
      set obj [$ctx object]
      set form_obj [::xo::db::CrClass get_instance_from_db -item_id $form_id]

      set form     [$form_obj get_property -name form]
      set fc       [$form_obj get_property -name form_constraints]

      #
      # Map "answer" to a generic name in the form "@answer@" and in the
      # form constraints.
      #
      set newName [:form_name_based_attribute_stem [$form_obj name]]

      regsub -all {@answer} $form @$newName form
      set fc [:map_form_constraints $fc "answer" $newName]
      set disabled_fc [lmap f $fc {
        if {[string match "$newName*" $f]} { append f ,disabled=true }
        set f
      }]

      lappend fc @cr_fields:hidden
      lappend disabled_fc @cr_fields:hidden
      #:msg fc=$fc

      $form_obj set_property -new 1 form $form
      $form_obj set_property -new 1 form_constraints $fc
      $form_obj set_property -new 1 disabled_form_constraints $disabled_fc

      return $form_obj
    }

  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
