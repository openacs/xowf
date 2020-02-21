::xo::library doc {
  Test Item procs - support for different kind of tests and exercises.

  @author Gustaf Neumann
}

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
    @param grading one of "exact", "none", or one of the partial grading schemes
    @param nr_choices number of choices
    @param question_type "mc", "sc", "ot", or "st"
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
        set interaction_class mc_interaction2
        set options multiple=false
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
      te -
      st {
        set interaction_class short_text_interaction
        #set options nr_choices=[:nr_choices]
        set auto_correct ${:auto_correct}
        set can_shuffle true
      }
      ul { #
        set interaction_class upload_interaction
        set options ""
        set auto_correct false
        set can_shuffle false
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

    if {${:grading} ne "none" && [llength ${:grading}] >1} {
      dict set grading_dict default [lindex ${:grading} 0]
      dict set grading_dict options {}
      foreach o ${:grading} {
        dict lappend grading_dict options [list $o $o]
      }
      dict set grading_dict form_item_wrapper_CSSclass form-inline
      dict set grading_dict label #xowf.Grading-Scheme#
      set gradingSpec [list [list grading [:dict_to_fc -type select $grading_dict]]]
    } else {
      set gradingSpec ""
    }

    if {$can_shuffle} {
      set shuffle_options "{#xowf.shuffle_none# none} {#xowf.shuffle_peruser# peruser} {#xowf.shuffle_always# always}"
      set shuffleSpec [subst {
        {shuffle {radio,horizontal=true,form_item_wrapper_CSSclass=form-inline,options=$shuffle_options,default=none,label=#xowf.Shuffle#}}
        {show_max {number,form_item_wrapper_CSSclass=form-inline,min=2,label=#xowf.show_max#}}
      }]
    } else {
      set shuffleSpec ""
    }
    :create_components  [subst {
      {minutes number,form_item_wrapper_CSSclass=form-inline,min=1,default=2,label=#xowf.Minutes#}
      $shuffleSpec
      $gradingSpec
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
    #ns_log notice "MC <$mc>"

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
      {lines {number,form_item_wrapper_CSSclass=form-inline,min=1,default=10,label=#xowf.answer_lines#}}
      {columns {number,form_item_wrapper_CSSclass=form-inline,min=1,max=80,default=60,label=#xowf.answer_columns#}}
      $autoCorrectSpec
    }]
    set :__initialized 1
  }

  text_interaction instproc convert_to_internal {} {
    set intro_text [:get_named_sub_component_value text]

    dict set fc_dict rows [:get_named_sub_component_value lines]
    dict set fc_dict cols [:get_named_sub_component_value columns]
    dict set fc_dict disabled_as_div 1
    dict set fc_dict label #xowf.answer#

    if {${:auto_correct}} {
      dict set fc_dict correct_when [:get_named_sub_component_value correct_when]
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
        "{answer:[:dict_to_fc -type textarea $fc_dict]}"

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
  # ::xowiki::formfield::short_text_interaction
  #
  ###########################################################

  Class create short_text_interaction -superclass TestItemField -parameter {
  }

  short_text_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    :create_components [subst {
      {text  {$widget,height=100px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {answer {short_text_field,repeat=1..5,label=}}
    }]
    set :__initialized 1
  }

  short_text_interaction instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set answerFields [:get_named_sub_component_value answer]

    set options {}
    set render_hints {}
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
      lappend render_hints [list \
                                  words [dict get $value $fieldName.options] \
                                  lines [dict get $value $fieldName.lines]]
    }

    dict set fc_dict shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    dict set fc_dict show_max [${:parent_field} get_named_sub_component_value show_max]
    dict set fc_dict disabled_as_div 1
    dict set fc_dict label ""
    dict set fc_dict options $options
    dict set fc_dict answer $answer
    dict set fc_dict render_hints $render_hints

    append form \
        "<form>\n" \
        "<div class='short_text_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \n \
        "</div>\n" \
        "</form>\n"

    set fc {}
    lappend fc \
        answer:[:dict_to_fc -type text_fields $fc_dict] \
        @categories:off @cr_fields:hidden

    ns_log notice "short_text_interaction $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
  }

  #
  # ::xowiki::formfield::short_text_field
  #
  Class create short_text_field -superclass TestItemField -parameter {
  }

  short_text_field instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

    #
    # Get "auto_correct" from the interaction (passing "auto_correct="
    # via form constrain would require to extend the RepeatContainer,
    # otherwise the attribute is rejected).
    #
    set p [:info parent]
    while {1} {
      if {![$p istype ::xowiki::formfield::FormField]} break
      if {![$p istype ::xowiki::formfield::short_text_interaction]} {
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
    set render_hints [join {
      "{#xowiki.number# number}"
      "{#xowiki.single_word# single_word}"
      "{#xowiki.multiple_words# multiple_words}"
      "{#xowiki.multiple_lines# multiple_lines}"
      "{#xowiki.file_upload# file_upload}"
    } " "]
    set textEntryConfigSpec [subst {
        {options {radio,horizontal=true,form_item_wrapper_CSSclass=form-inline,options=$render_hints,default=single_word,label=#xowf.answer#}}
        {lines {number,form_item_wrapper_CSSclass=form-inline,default=1,min=1,label=#xowf.lines#}}
      }]

    #:msg autoCorrectSpec=$autoCorrectSpec
    :create_components  [subst {
      {text  {$widget,height=100px,label=#xowf.sub_question#,plugins=OacsFs}}
      $textEntryConfigSpec $autoCorrectSpec
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
    {multiple true}
  }

  mc_interaction2 instproc initialize {} {

    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    #ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    :create_components  [subst {
      {text  {$widget,height=100px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {answer {mc_field,repeat=1..10,label=}}
    }]
    set :__initialized 1
  }

  mc_interaction2 instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set answerFields [:get_named_sub_component_value answer]
    set count 0
    set options {}
    set correct {}

    foreach {fieldName value} $answerFields {
      # skip template entry
      if {[lindex [split $fieldName .] end] eq 0} {
        continue
      }
      #ns_log notice ...fieldName=$fieldName->$value
      #set af answer[incr count]
      set text [dict get $value $fieldName.text]
      # trim leading <p> since this causes a newline in the checkbox label
      regexp {^\s*(<p>)(.*)$} $text . . text
      regexp {^(.*)(</p>)\s*$} $text . text .
      lappend options [list $text [incr count]]
      lappend correct [dict get $value $fieldName.correct]
    }

    dict set fc_dict richtext 1
    dict set fc_dict answer $correct
    dict set fc_dict options $options
    dict set fc_dict shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    dict set fc_dict grading [${:parent_field} get_named_sub_component_value grading]
    dict set fc_dict show_max [${:parent_field} get_named_sub_component_value show_max]

    set interaction_class [expr {${:multiple} ? "mc_interaction" : "sc_interaction"}]
    append form \
        "<form>\n" \
        "<div class='$interaction_class'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \n \
        "</div>" \n \
        "</form>\n"

    set widget [expr {${:multiple} ? "checkbox" : "radio"}]
    set fc {}
    lappend fc \
        answer:[:dict_to_fc -type $widget $fc_dict] \
        @categories:off @cr_fields:hidden

    #ns_log notice "mc_interaction2 $form\n$fc"
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
      {text  {$widget,height=50px,label=#xowf.sub_question#,plugins=OacsFs}}
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
############################################################################
# Generic Assement interface
############################################################################

namespace eval ::xowf::test_item {

  nx::Class create AssessmentInterface {
    #
    # Abstract class for common functionality
    #
    :method assert_assessment_container {o:object} {
      set ok [expr {[$o is_wf_instance] == 0 && [$o is_wf] == 1}]
      if {!$ok} {
        ns_log notice "NO ASSESSMENT CONTAINER [$o title]"
        ns_log notice "NO ASSESSMENT CONTAINER page_template [[$o page_template] title]"
        ns_log notice "NO ASSESSMENT CONTAINER iswfi [$o is_wf_instance] iswf [$o is_wf]"
        ns_log notice "[$o serialize]"
        error "'[lindex [info level -1] 0]': not an assessment container"
      }
    }

    :method assert_assessment {o:object} {
      if {[llength [$o property question]] == 0} {
        ns_log notice "NO ASSESSMENT [$o title]"
        ns_log notice "NO ASSESSMENT page_template [[$o page_template] title]"
        ns_log notice "NO ASSESSMENT iswfi [$o is_wf_instance] iswf [$o is_wf]"
        ns_log notice "[$o serialize]"
        error "'[lindex [info level -1] 0]': object has no questions"
      }
    }

    :method assert_answer_instance {o:object} {
      # we could include as well {[$o property answer] ne ""} in case we initialize it
      set ok [expr {[$o is_wf_instance] == 1 && [$o is_wf] == 0}]
      if {!$ok} {
        ns_log notice "NO ANSWER [$o title]"
        ns_log notice "NO ANSWER page_template [[$o page_template] title]"
        ns_log notice "NO ANSWER iswfi [$o is_wf_instance] iswf [$o is_wf]"
        ns_log notice "[$o serialize]"
        error "'[lindex [info level -1] 0]': not an answer instance"
      }
    }

  }
}
namespace eval ::xowf::test_item {

  nx::Class create Renaming_form_loader -superclass AssessmentInterface {
    #
    # Form loader that renames "generic" form-field-names as provided
    # by the test-item form-field classes (@answer@) into names based
    # on the form name, such that multiple of these form names can be
    # processed together without name clashes.
    #
    # - answer_attributes
    # - answer_for_form
    # - answers_for_form
    # - form_name_based_attribute_stem
    #
    # - get_form_object
    # - rename_attributes
    #

    :method map_form_constraints {form_constraints oldName newName} {
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

    :public method form_name_based_attribute_stem {formName} {
      #
      # Produce from the provided 'formName' an attribute stem for the
      # input fields of this form.
      #
      set strippedName [lindex [split $formName :] end]
      regsub -all {[-]} $strippedName _ stem
      return ${stem}_
    }


    :public method answer_attributes {instance_attributes} {
      #
      # Return all form-loader specific attributes from
      # instance_attributes.
      #
      set result ""
      foreach key [lsort [dict keys $instance_attributes]] {
        if {[string match *_ $key]} {
          lappend result $key [dict get $instance_attributes $key]
        }
      }
      return $result
    }

    :public method answer_for_form {formName instance_attributes} {
      #
      # Return answer for the provided formName from
      # instance_attributes of a single object.
      #
      set result ""
      set stem [:form_name_based_attribute_stem $formName]
      set answerAttributes [:answer_attributes $instance_attributes]
      #ns_log notice "answer_for_form\ninstance_attributes $instance_attributes"
      if {[dict exists $answerAttributes $stem]} {
        set value [dict get $answerAttributes $stem]
        if {$value ne ""} {
          lappend result $value
        }
      }
      return $result
    }

    :public method answers_for_form {formName answers} {
      #
      # Return a list of dicts for the provided formName from the
      # answers (as returned from [answer_manager get_answers ...]).
      #
      set stem [:form_name_based_attribute_stem $formName]
      set result ""
      foreach answer $answers {
        set value answer_for_form
        set answerAttributes [dict get $answer answerAttributes]
        if {[dict exists $answerAttributes $stem]} {
          set value [dict get $answerAttributes $stem]
          if {$value ne ""} {
            lappend result [list item [dict get $answer item] value $value]
          }
        }
      }
      return $result
    }

    :public method rename_attributes {form_obj:object} {

      set form [$form_obj get_property -name form]
      set fc   [$form_obj get_property -name form_constraints]

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

      #ns_log notice "RENAMED form $form\n$fc\n$disabled_fc"
      return $form_obj
    }

    :public method get_form_object {{-set_title:boolean true} ctx:object form_name} {
      set form_id [$ctx default_load_form_id $form_name]
      set obj [$ctx object]
      set form_obj [::xo::db::CrClass get_instance_from_db -item_id $form_id]
      return [:rename_attributes $form_obj]
    }

  }

  Renaming_form_loader create renaming_form_loader
}


namespace eval ::xowf::test_item {

  nx::Class create Answer_manager -superclass AssessmentInterface {

    #
    # Public API:
    #
    #  - create_workflow
    #  - delete_all_answer_data
    #  - get_answer_wf
    #  - get_wf_instances
    #  - get_answers
    #
    #  - marked_results
    #  - answers_panel
    #  - result_table
    #

    :public method create_workflow {
      {-answer_workflow /packages/xowf/lib/online-exam-answer.wf}
      {-master_workflow en:Workflow.form}
      parentObj:object
    } {
      #
      # Create a workflow based on the template provided in this
      # method for answering the question for the students. The name
      # of the workflow is derived from the workflow instance and
      # recorded in the formfield "wfName".
      #
      #:log "create_answer_workflow $parentObj"

      # first delete workflow and data, when it exists
      if {[$parentObj property wfName] ne ""} {
        set wf [:delete_all_answer_data $parentObj]
        if {$wf ne ""} {$wf delete}
      }

      #
      # Create a fresh workflow (e.g. instance of the online-exam,
      # inclass-quiz, ...).
      #
      set wfName [$parentObj name].wf
      $parentObj set_property -new 1 wfName $wfName

      set wfTitle [$parentObj property _title]
      set questionObjs [::xowf::test_item::question_manager question_objs $parentObj]

      set wfQuestionNames {}
      set wfQuestionTitles {}
      set attributeNames {}
      foreach form_obj $questionObjs {

        lappend attributeNames [xowf::test_item::renaming_form_loader \
                                    form_name_based_attribute_stem [$form_obj name]]

        lappend wfQuestionNames ../[$form_obj name]
        lappend wfQuestionTitles [$form_obj title]
      }
      set wfID [$parentObj item_id]

      set wfDef [subst -nocommands {
        set wfID $wfID
        set wfQuestionNames [list $wfQuestionNames]
        xowf::include $answer_workflow
      }]
      set attributeNames [join $attributeNames ,]

      #:log "create workflow by filling out form '$master_workflow'"
      set WF [::xowiki::Weblog instantiate_forms \
                  -parent_id    [$parentObj parent_id] \
                  -package_id   [$parentObj package_id] \
                  -default_lang [$parentObj lang] \
                  -forms        $master_workflow]
      set fc ""
      append fc \
          "@table:_item_id,_state,$attributeNames,_last_modified " \
          "@table_properties:view_field=_item_id " \
          @cr_fields:hidden

      set wf [$WF create_form_page_instance \
                  -name                $wfName \
                  -nls_language        [$parentObj nls_language] \
                  -publish_status      ready \
                  -parent_id           [$parentObj item_id] \
                  -package_id          [$parentObj package_id] \
                  -default_variables   [list title $wfTitle] \
                  -instance_attributes [list workflow_definition $wfDef \
                                            form_constraints $fc]]
      $wf save_new
      #ns_log notice "create_answer_workflow $wf DONE [$wf pretty_link] IA <[$wf instance_attributes]>"
      #ns_log notice "create_answer_workflow parent $parentObj IA <[$parentObj instance_attributes]>"
    }

    ########################################################################

    :public method delete_all_answer_data {obj:object} {
      #
      # Delete all instances of the answer workflow
      #
      set wf [:get_answer_wf $obj]
      if {$wf ne ""} {
        set items [:get_wf_instances -initialize false $wf]
        foreach i [$items children] { $i delete }
      }
      return $wf
    }


    ########################################################################

    :public method get_answer_wf {obj:object} {
      #
      # return the workflow denoted by the property wfName in obj
      #
      return [::xowiki::Weblog instantiate_forms \
                  -parent_id    [$obj item_id] \
                  -package_id   [$obj package_id] \
                  -default_lang [$obj lang] \
                  -forms        [$obj property wfName]]
    }

    ########################################################################

    :public method get_wf_instances {
      {-initialize false}
      {-orderby ""}
      wf:object
    } {
      # get_wf_instances: return the workflow instances
      :assert_assessment_container $wf

      return [::xowiki::FormPage get_form_entries \
                  -base_item_ids             [$wf item_id] \
                  -form_fields               "" \
                  -always_queried_attributes "*" \
                  -initialize                $initialize \
                  -orderby                   $orderby \
                  -publish_status            all \
                  -package_id                [$wf package_id]]
    }

    ########################################################################

    :public method get_answers {{-state ""} wf:object} {
      set results {}
      set items [:get_wf_instances $wf]
      foreach i [$items children] {
        if {$state ne "" && [$i state] ne $state} {
          continue
        }
        set answerAttributes [xowf::test_item::renaming_form_loader answer_attributes \
                                  [$i instance_attributes]]
        lappend results [list item $i answerAttributes $answerAttributes state [$i state]]
      }
      return $results
    }

    ########################################################################

    :method participant_result {
      -obj:object
      answerObj:object
      form_info
      form_field_objs
    } {

      :assert_answer_instance $answerObj
      :assert_assessment $obj

      set instance_attributes [$answerObj instance_attributes]
      set answer [list item $answerObj]

      foreach f $form_field_objs {
        set att [$f name]

        if {[dict exists $instance_attributes $att]} {
          set value [dict get $instance_attributes $att]
          #ns_log notice "### '$att' value '$value'"
          $answerObj combine_data_and_form_field_default 1 $f $value
          $f set_feedback 1
          $f add_statistics -options {word_statistics word_cloud}
          #
          # Leave the form-field in statistics mode in a state with
          # correct anwers.
          #
          $f make_correct
          #ns_log notice "FIELD $f [$f name] [$f info class] -> VALUE [$f set value]"

          lappend answer \
              [list name $att \
                   value $value \
                   correction [$f set correction] \
                   evaluated_answer_result [$f set evaluated_answer_result]]
        }
      }
      return $answer
    }

    :method answer_form_field_objs {-clear:switch -wf:object form_info} {
      set key ::__test_item_answer_form_fields
      if {$clear} {
        #
        # The -clear option is needed, when there are multiple
        # assessments protocols/tables on the same page (currently
        # not).
        #
        unset $key
      } else {
        #ns_log notice "### key exists [info exists $key]"
        if {![info exists $key]} {
          #ns_log notice "form_info: $form_info"
          set fc [dict get $form_info disabled_form_constraints]
          set pc_params [::xo::cc perconnection_parameter_get_all]
          #ns_log notice "### create_form_fields_from_form_constraints <$fc>"
          set $key [$wf create_form_fields_from_form_constraints \
                        -lookup \
                        [lsort -unique $fc]]
          ::xo::cc perconnection_parameter_set_all $pc_params
          $wf form_field_index  [set $key]
        }
        return [set $key]
      }
    }


    :public method result_table {
      -package_id:integer
      -items:object,required
      {-view_all_method print-answers}
      wf:object
    } {
      #set form_info [:combined_question_form -with_numbers $wf]
      set form_info [::xowf::test_item::question_manager combined_question_form $wf]
      set answer_form_field_objs [:answer_form_field_objs -wf $wf $form_info]

      set form_field_objs [$wf create_raw_form_field \
                               -name _online-exam-userName \
                               -spec text,label=#xowf.participant#]
      #
      # Create for every answer field a matching grading field
      #
      set ff_dict {}
      foreach answer_field_obj $answer_form_field_objs {
        #ns_log notice "LABEL [$answer_field_obj name] <[$answer_field_obj label]>"
        $answer_field_obj label [string trimright [$answer_field_obj name] _]
        $answer_field_obj mixin ::xowf::test_item::td_pretty_value

        set grading_field_obj [$wf create_raw_form_field \
                                   -name [$answer_field_obj name].score \
                                   -spec number,label=#xowf.Grading-Score#]
        lappend form_field_objs \
            $answer_field_obj \
            $grading_field_obj
        dict set ff_dict [$answer_field_obj name] $answer_field_obj
        dict set ff_dict [$grading_field_obj name] $grading_field_obj
      }

      lappend form_field_objs \
          [$wf create_raw_form_field \
               -name _creation_date \
               -spec date,label=#xowiki.Page-last_modified#]

      #
      # Take "orderby" from the query parameter. If not set, order by
      # the first field.
      #
      set orderby [::$package_id query_parameter orderby:token ""]
      if {$orderby eq "" && [llength $form_field_objs] > 0} {
        set orderby [[lindex $form_field_objs 0] name],asc
      }

      #
      # Create table widget.
      #
      set table_widget [::xowiki::TableWidget create_from_form_fields \
                            -package_id $package_id \
                            -form_field_objs $form_field_objs \
                            -orderby $orderby]
      #
      # Extend properties of every answer with corresponding ".score"
      # values.
      #
      foreach p [$items children] {
        foreach ff_obj $answer_form_field_objs {
          $ff_obj object $p
          set property [$ff_obj name]
          $ff_obj value [$p property $property]

          $ff_obj set_feedback 3
          if {[$ff_obj exists grading_score]} {
            set r [$ff_obj set grading_score]
          } else {
            set r [expr {[$ff_obj set evaluated_answer_result] eq "correct" ? 100.0 : 0.0}]*
            #ns_log notice [$ff_obj serialize]
          }
          $p set_property -new 1 $property.score $r
        }
      }

      #
      # Render table widget with extended properties.
      #
      set HTML [$table_widget render_page_items_as_table \
                    -package_id $package_id \
                    -items $items \
                    -form_field_objs $form_field_objs \
                    -csv true \
                    -uc {tcl {[$p state] ne "done"}} \
                    -view_field _online-exam-userName \
                    -view_filter_link [$wf pretty_link -query m=$view_all_method] \
                    {*}[expr {[info exists generate] ? [list -generate $generate] : ""}] \
                    -return_url [ad_return_url] \
                    -return_url_att local_return_url \
                   ]
      $table_widget destroy
      return $HTML
    }

    :public method marked_results {-obj:object -wf:object form_info} {
      set form_field_objs [:answer_form_field_objs -wf $wf $form_info]

      set items [:get_wf_instances $wf]
      set results ""
      foreach i [$items children] {
        set participantResult [:participant_result -obj $obj $i $form_info $form_field_objs]
        append results $participantResult \n
      }

      #ns_log notice "=== marked_results of [llength [$items children]] items => $results"
      return $results
    }

    :public method answers_panel {
      {-polling:switch false}
      {-heading #xowf.submitted_answers#}
      {-submission_msg #xowf.participants_answered_question#}
      {-manager_obj:object}
      {-target_state ""}
      {-wf:object}
      {-current_question ""}
      {-extra_text ""}
    } {

      set answers [xowf::test_item::answer_manager get_answers $wf]
      set nrParticipants [llength $answers]
      if {$current_question ne ""} {
        set answered [xowf::test_item::renaming_form_loader answers_for_form \
                          [$current_question name] \
                          $answers]
      } else {
        set answered [xowf::test_item::answer_manager get_answers \
                          -state $target_state $wf]
      }
      set nrAnswered [llength $answered]

      set answerStatus [subst {
        <div class='panel panel-default'>
        <div class='panel-heading'>$heading</div>
        <div class='panel-body'>
        <span id="answer-status">$nrAnswered/$nrParticipants</span> $submission_msg
        </div>
        $extra_text
        </div>
      }]

      if {$polling} {
        #
        # auto refresh: when in $parent_obj 'state' or 'position' changes,
        # do automatically a reload of the current page.
        #
        set url [$manager_obj pretty_link -query m=poll]
        template::add_body_script -script [subst {
          (function poll() {
            setTimeout(function() {
              var xhttp = new XMLHttpRequest();
              xhttp.open("GET", '$url', true);
              xhttp.onreadystatechange = function() {
                if (this.readyState == 4 && this.status == 200) {
                  var data = xhttp.responseText;
                  var el = document.querySelector('#answer-status');
                  el.innerHTML = data;
                  poll();
                }
              };
              xhttp.send();
            }, 1000);
          })();
        }]
      }

      return $answerStatus
    }

    :public method countdown_timer {
      {-target_time:required}
      {-id:required}
    } {
      # new Date('1995-12-17T03:24:00')
      template::add_body_script -script [subst {
        var countdown_target_date = new Date('$target_time').getTime();
        var countdown_days, countdown_hours, countdown_minutes, countdown_seconds;
        var countdown = document.getElementById('$id');

        setInterval(function () {
          var current_date = new Date().getTime();
          var seconds_left = (countdown_target_date - current_date) / 1000;
          var HTML = '';

          countdown_days = parseInt(seconds_left / 86400);
          seconds_left = seconds_left % 86400;
          countdown_hours = parseInt(seconds_left / 3600);
          seconds_left = seconds_left % 3600;
          countdown_minutes = parseInt(seconds_left / 60);
          countdown_seconds = parseInt(seconds_left % 60);

          if (countdown_days != 0) {
            HTML += '<span class="days">' + countdown_days + ' <b> '
                 + (countdown_days != 1 ? '[_ xowf.Days]' : '[_ xowf.Day]')
                 + '</b></span> ';
          }
          if (countdown_hours != 0 || countdown_days != 0) {
            HTML += '<span class="hours">' + countdown_hours + ' <b> '
                 + (countdown_hours != 1 ? '[_ xowf.Hours]' : '[_ xowf.Hour]')
                 + '</b></span> ';
          }
          HTML += '<span class="minutes">' + countdown_minutes + ' <b> '
               + (countdown_minutes != 1 ? '[_ xowf.Minutes]' : '[_ xowf.Minute]')
               + '</b></span> '
               + '<span class="seconds">' + countdown_seconds + ' <b> '
               + (countdown_seconds != 1 ? '[_ xowf.Seconds]' : '[_ xowf.Second]')
               + '</b></span> [_ xowf.remaining]' ;

          countdown.innerHTML = HTML;
        }, 1000);
      }]
      return "<div id='$id'></div>"
    }
  }

  Answer_manager create answer_manager
}


namespace eval ::xowf::test_item {

  nx::Class create Question_manager -superclass AssessmentInterface {
    #
    # This code manages questions and the information related to a
    # current (selected) question via qthe "position" instance
    # attribute. It provides the following public API:
    #
    #   - goto_page
    #   - more_ahead
    #
    #   - current_question_form
    #   - current_question_obj
    #   - current_question_name
    #   - current_question_title
    #   - nth_question_obj
    #   - nth_question_form
    #
    #   - combined_question_form
    #   - question_objs
    #   - question_names
    #   - question_property
    #   - total_minutes
    #
    :public method goto_page {obj:object position} {
      $obj set_property position $position
    }

    :public method more_ahead {{-position ""} obj:object} {
      if {$position eq ""} {
        set position [$obj property position]
      }
      set questions [dict get [$obj instance_attributes] question]
      return [expr {$position + 1 < [llength $questions]}]
    }

    :method load_question_objs {obj:object names} {
      set questions [lmap ref $names {
        if {![string match "*/*" $ref]} {
          set ref [[$obj parent_id] name]/$ref
        }
        set ref
      }]
      set questionNames [join $questions |]
      set questionForms [::xowiki::Weblog instantiate_forms \
                             -package_id [$obj package_id] \
                             -default_lang [$obj lang] \
                             -forms $questionNames]

      #ns_log notice "load_question_objs called with $obj $names -> $questionForms"
      return $questionForms
    }

    :public method current_question_name {obj:object} {
      set questions [dict get [$obj instance_attributes] question]
      return [lindex [dict get [$obj instance_attributes] question] [$obj property position]]
    }

    :public method current_question_obj {obj:object} {
      return [:load_question_objs $obj [:current_question_name $obj]]
    }


    :public method shuffled_question_objs {obj:object shuffle_id} {
      set form_objs [:question_objs $obj]
      set result {}
      foreach i [::xowiki::randomized_indices -seed $shuffle_id [llength $form_objs]] {
        lappend result [lindex $form_objs $i]
      }
      return $result
    }

    :public method shuffled_index {{-shuffle_id:integer -1} obj:object position} {
      if {$shuffle_id > -1} {
        set form_objs [:question_objs $obj]
        set shuffled [::xowiki::randomized_indices -seed $shuffle_id [llength $form_objs]]
        set position [lindex $shuffled $position]
      }
      return $position
    }

    :public method question_objs {{-shuffle_id:integer -1} obj:object} {
      :assert_assessment $obj
      set form_objs [:load_question_objs $obj [$obj property question]]
      if {$shuffle_id > -1} {
        set result {}
        foreach i [::xowiki::randomized_indices -seed $shuffle_id [llength $form_objs]] {
          lappend result [lindex $form_objs $i]
        }
        set form_objs $result
      }
      return $form_objs
    }

    :public method question_names {obj:object} {
      return [$obj property question]
    }

    :public method nth_question_obj {obj:object position:integer} {
      :assert_assessment $obj
      set questions [dict get [$obj instance_attributes] question]
      set result [:load_question_objs $obj [lindex $questions $position]]
      return $result
    }

    :method question_info {
      {-numbers ""}
      {-with_title:switch false}
      {-with_minutes:switch false}
      form_objs
    } {
      set full_form {}
      set full_fc {}
      set full_disabled_fc {}
      set title_infos {}

      foreach form_obj $form_objs number $numbers {
        set form_obj [::xowf::test_item::renaming_form_loader rename_attributes $form_obj]
        set form_title [$form_obj title]
        set minutes [:question_property $form_obj minutes]
        set title ""
        if {$number ne ""} {
          append title "#xowf.question# $number:"
        }
        if {$with_title} {
          append title " $form_title"
        }
        if {$with_minutes} {
          append title " - [:minutes_string $form_obj]"
        }

        append full_form "<h3>$title</h3>\n"
        append full_form [$form_obj property form] \n
        lappend title_infos [list full_title $title \
                                 title $form_title \
                                 minutes $minutes \
                                 number $number]
        lappend full_fc [$form_obj property form_constraints]
        lappend full_disabled_fc [$form_obj property disabled_form_constraints]
      }
      return [list \
                  form $full_form \
                  title_infos $title_infos \
                  form_constraints [join [lsort -unique $full_fc] \n] \
                  disabled_form_constraints [join [lsort -unique $full_disabled_fc] \n]]
    }


    :public method question_property {form_obj:object attribute {default ""}} {
      #
      # Get an attribute of the original question
      #
      set question [$form_obj get_property -name question]
      #:msg question=$question
      if {[dict exists $question question.$attribute]} {
        set value [dict get $question question.$attribute]
      } else {
        set value $default
      }
      return $value
    }

    :public method minutes_string {form_obj:object} {
      #
      # Get an attribute of the original question
      #
      set minutes [:question_property $form_obj minutes]
      if {$minutes ne ""} {
        set key [expr {$minutes eq "1" ? [_ xowiki.minute] : [_ xowiki.minutes]}]
        set minutes "($minutes $key)"
      }
    }

    :public method combined_question_form {
      {-with_numbers:switch false}
      {-with_title:switch false}
      {-with_minutes:switch false}
      {-shuffle_id:integer -1}
      obj:object
    } {
      set form_objs [:question_objs -shuffle_id $shuffle_id $obj]
      if {$with_numbers} {
        set numbers ""
        for {set i 1} {$i <= [llength $form_objs]} {incr i} {
          lappend numbers $i
        }
        set extra_flags [list -numbers $numbers]
      } else {
        set extra_flags ""
      }
      return [:question_info \
                  -with_title=$with_title \
                  -with_minutes=$with_minutes \
                  {*}$extra_flags \
                  $form_objs]
    }

    :public method total_minutes {form_info} {
      set minutes 0
      foreach title_info [dict get $form_info title_infos] {
        if {[dict exists $title_info minutes]} {
          set minutes [expr {$minutes + [dict get $title_info minutes]}]
        }
      }
      return $minutes
    }

    :public method current_question_form {
      {-with_numbers:switch false}
      {-with_title:switch false}
      obj:object
    } {
      return [:nth_question_form -with_numbers=$with_numbers -with_title=$with_title $obj]
    }

    :public method nth_question_form {
      {-position:integer}
      {-item_nr:integer}
      {-with_numbers:switch false}
      {-with_title:switch false}
      {-with_minutes:switch false}
      obj:object
    } {
      if {![info exists position]} {
        set position [$obj property position]
      }
      if {![info exists item_nr]} {
        set item_nr $position
      }
      set form_objs [:nth_question_obj $obj $position]
      if {$with_numbers} {
        set number [expr {$item_nr + 1}]
        set extra_flags [list -numbers $number]
      } else {
        set extra_flags ""
      }
      return [:question_info \
                  -with_title=$with_title \
                  -with_minutes=$with_minutes \
                  {*}$extra_flags \
                  $form_objs]
    }

    :public method current_question_number {obj:object} {
      return [expr {[$obj property position] + 1}]
    }
    :public method current_question_title {{-with_numbers:switch false} obj:object} {
      if {$with_numbers} {
        return "#xowf.question# [:current_question_number $obj]"
      }
    }
  }

  Question_manager create question_manager

}

namespace eval ::xowf::test_item {
  #
  # Define handling of form-field "td_pretty_value"
  #
  ::xotcl::Class create ::xowf::test_item::td_pretty_value \
      -superclass ::xowiki::formfield::FormField

  ::xowf::test_item::td_pretty_value instproc pretty_value {value} {
    #ns_log notice "${:name} pretty_value [:info precedence]"
    if {"::xowiki::formfield::checkbox" in [:info precedence]} {
      set v ${value}
    } else {
      set v [next]
    }
    return $v
  }
}


namespace eval ::xowf::test_item {
  #
  # Copy the default policy (policy1) from xowiki and add elements for
  # FormPages as needed by the demo workflows:
  #
  #   - online-exam.wf, online-exam-answer.wf
  #   - inclass-quiz.wf, inclass-quiz-answer.wf
  #
  ::xowiki::policy1 copy ::xowf::test_item::test-item-policy-publish
  ::xowiki::policy1 copy ::xowf::test_item::test-item-policy-answer

  #
  # Add policy rules as used in two demo workflow. We are permissive
  # for student actions and require admin right for teacher activities.
  #
  test-item-policy-publish contains {
    Class create FormPage -array set require_permission {
      answer         {{item_id read}}
      poll           admin
      edit           admin
      print-answers  admin
      print-answer-table admin
      delete         admin
      qrcode         admin
    }
  }
  test-item-policy-answer contains {
    Class create FormPage -array set require_permission {
      poll           {{item_id read}}
      edit           {{item_id read}}
    }
  }

  #ns_log notice [::xowf::test_item::test-item-policy1 serialize]
  #ns_log notice ===================================

}


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    eval: (setq tcl-type-alist (remove* "method" tcl-type-alist :test 'equal :key 'car))
#    indent-tabs-mode: nil
# End:
