::xo::library doc {
  Test Item procs - support for different kind of tests and exercises.

  @author Gustaf Neumann
}

::xo::db::require package xowiki
::xo::library require xowf-procs
::xo::library require -package xowiki menu-procs
::xo::library require -package xowiki form-field-procs

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
    {nr_attachments 15}
  } -ad_doc {

    Abstract class for defining common attributes for all Test Item
    fields.

    @param feedback_level "full", "single", or "none"
    @param auto_correct boolean to let user add auto correction fields
  }
  TestItemField set abstract 1

  TestItemField instproc text_attachments {} {
    set html ""
    if {[:exists_named_sub_component attachments]} {
      set attachments_ff [:get_named_sub_component attachments]
      set attachments_count [$attachments_ff count_values [$attachments_ff value]]
      set attachments_label [expr {$attachments_count > 1
                                   ? "#general-comments.Attachments# ($attachments_count)"
                                   : "#attachments.Attachment#"}]

      for {set i 1} {$i <= $attachments_count} {incr i} {
        set label [lindex [dict get [:get_named_sub_component_value -from_repeat attachments $i] name] 0]
        set encoded_label [ns_urlencode $label]
        append attachments_links \
            {<div class='attachment'>} \
            [subst -nocommands {[[file:question.interaction.attachments.$i|$label|-query filename=$encoded_label]]}] \
            </div>
      }
      if {$attachments_count > 0} {
        append html "<div class='question_attachments'>$attachments_label $attachments_links</div><br>"
      }
    }
    #ns_log notice text_attachments=>$attachments_html
    return $html
  }

  TestItemField instproc attachments_widget {nr_attachments} {

    dict set attachments_dict repeat 0..${:nr_attachments}
    dict set attachments_dict repeat_add_label #xowiki.form-repeatable-add-file#
    dict set attachments_dict label #general-comments.Attachments#

    # {attachments {file,0..${:nr_attachments},label=#general-comments.Attachments#}}
    # {attachments {bootstrap_file_input,multiple=true,label=#general-comments.Attachments#}}
    # {attachments {file,multiple=true,label=#general-comments.Attachments#}}
    return [:dict_to_fc -type file $attachments_dict]
  }

  TestItemField instproc comp_correct_when_from_value {value} {
    set correct_whens {}
    foreach {compound_key compound_entries} $value {
      if {![string match "*.0" $compound_key]} {
        # ns_log notice "key $compound_key, value $compound_entries"
        set d {}
        foreach {entry_key entry_value} $compound_entries {
          set tail [lindex [split $entry_key .] end]
          # ns_log notice "... entry_key $tail, entry_value $entry_value"
          dict set d $tail $entry_value
        }
        set text [string trim [dict get $d text]]
        if {$text ne ""} {
          set correct_when "[dict get $d operator] "
          append correct_when [expr {[dict get $d nocase] ? "-nocase " : ""}]
          append correct_when $text
          lappend correct_whens $correct_when
        } else {
          set correct_when ""
        }
      }
    }
    if {[llength $correct_whens] < 2} {
      set correct_when [lindex $correct_whens 0]
    } else {
      set correct_when "AND $correct_whens"
    }
    #ns_log notice FINAL-correct_when='$correct_when'
    return $correct_when
  }

  TestItemField instproc correct_when_widget {{-nr 10}} {
    set dict ""
    dict set dict repeat 1..10
    dict set dict repeat_add_label #xowiki.form-repeatable-add-condition#
    dict set dict help_text #xowiki.formfield-comp_correct_when-help_text#
    dict set dict label #xowf.correct_when#

    return [:dict_to_fc -type comp_correct_when $dict]
  }

  TestItemField instproc correct_when_spec {{-nr 10}} {
    if {${:auto_correct}} {
      return [list [list correct_when [:correct_when_widget -nr $nr]]]
    }
    return ""
  }

  ###########################################################
  #
  # ::xowiki::formfield::test_item_name
  #
  ###########################################################
  Class create test_item_name -superclass text \
      -extend_slot_default validator name -ad_doc {
        Name sanitizer for test items
  }
  test_item_name instproc check=name {value} {
    set valid [regexp {^[[:alnum:]:/_-]+$} $value]
    if {!$valid} {
      :uplevel {set __langPkg xowf}
    }
    return $valid
  }


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
    a question is saved, an HTML form is generated, which is used as a
    question.

    @param feedback_level "full", "single", or "none"
    @param grading one of "exact", "none", or one of the partial grading schemes
    @param nr_choices number of choices
    @param question_type "mc", "sc", "ot", or "st"
  }

  #
  # Provide a default setting for the rich-text widgets.
  #
  test_item set richtextWidget {richtext,editor=ckeditor4,ck_package=basic,displayMode=inline,extraPlugins=}

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
    set typeSpecificComponentSpec ""
    #
    # Provide some settings for name short-cuts
    #
    switch -- ${:question_type} {
      mc { # we should support as well: minChoices, maxChoices
        #
        # Old style, kept just for backwards compatibility for the
        # time being. One should use "mc2" instead.
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
      ro {
        set interaction_class reorder_interaction
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
        set typeSpecificComponentSpec {{max_nr_submission_files {number,form_item_wrapper_CSSclass=form-inline,min=1,default=1,label=Maximale Anzahl von Abgaben}}}
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
      dict set grading_dict required true
      set gradingSpec [list [list grading [:dict_to_fc -type select $grading_dict]]]
    } else {
      set gradingSpec ""
    }

    if {$can_shuffle} {
      set shuffle_options "{#xowf.shuffle_none# none} {#xowf.shuffle_peruser# peruser} {#xowf.shuffle_always# always}"
      set shuffleSpec [subst {
        {shuffle {radio,horizontal=true,form_item_wrapper_CSSclass=form-inline,options=$shuffle_options,default=none,label=#xowf.Shuffle#}}
        {show_max {number,form_item_wrapper_CSSclass=form-inline,min=1,label=#xowf.show_max#}}
      }]
    } else {
      set shuffleSpec ""
    }
    :create_components  [subst {
      {minutes number,form_item_wrapper_CSSclass=form-inline,min=1,default=2,label=#xowf.Minutes#}
      {points number,form_item_wrapper_CSSclass=form-inline,min=0.0,step=0.1,label=#xowf.Points#}
      $shuffleSpec
      $gradingSpec
      $typeSpecificComponentSpec
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
    # Actually, this method computes the properties "form" and
    # "form_constraints" based on the components of this form field.
    #
    set form "<form>\n<table class='mchoice'>\n<tbody>"
    set fc "@categories:off @cr_fields:hidden\n"
    set intro_text [:get_named_sub_component_value text]
    append form "<tr><td class='text' colspan='2'><div class='question_text'>$intro_text</div></td></tr>\n"

    #:msg " input_field_names=${:input_field_names}"
    set mc [:get_named_sub_component_value -from_repeat mc]
    #ns_log notice "MC <$mc>"

    if {!${:multiple}} {
      set correct_field_name [:get_named_sub_component_value correct]
    }

    #set input_field_names [lmap {name .} $mc {set name}]
    set input_field_names {}
    foreach {name .} $mc {lappend input_field_names $name}

    foreach {input_field_name data} $mc {
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

      regsub -all -- {[.:]} [${:object} name] "" form_name
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
      if {[string is true -strict $correct]} {
        lappend if_fc "answer=t" "options={{} $input_field_name}"
      } else {
         lappend if_fc "answer=f"
      }
      if {$value(feedback_correct) ne ""} {
        lappend if_fc "feedback_answer_correct=[::xowiki::formfield::FormField fc_encode $value(feedback_correct)]"
      }
      if {$value(feedback_incorrect) ne ""} {
        lappend if_fc "feedback_answer_incorrect=[::xowiki::formfield:::FormField fc_encode $value(feedback_incorrect)]"
      }
      if {[llength $if_fc] > 0} {
        append fc [list $input_field_name:checkbox,[join $if_fc ,]] \n
      }
      #:msg "$input_field_name .correct = $value(correct)"
    }

    if {!${:multiple}} {
      regexp {[.]([^.]+)$} $correct_field_name _ correct_field_value
      lappend fc "radio:text,answer=$correct_field_value"
    }
    append form "</tbody></table></form>\n"
    ns_log notice FORM=$form\nFC=$fc
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
      regsub -all -- {[.][^.]+$} ${:name} "" groupname
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

    :create_components  [subst {
      {text  {$widget,label=#xowf.exercise-text#,plugins=OacsFs}}
      {lines {number,form_item_wrapper_CSSclass=form-inline,min=1,default=10,label=#xowf.answer_lines#}}
      {columns {number,form_item_wrapper_CSSclass=form-inline,min=1,max=80,default=60,label=#xowf.answer_columns#}}
      [:correct_when_spec]
    }]
    set :__initialized 1
  }

  text_interaction instproc convert_to_internal {} {
    set intro_text [:get_named_sub_component_value text]

    dict set fc_dict rows [:get_named_sub_component_value lines]
    dict set fc_dict cols [:get_named_sub_component_value columns]
    dict set fc_dict disabled_as_div 1
    dict set fc_dict label #xowf.answer#
    dict set fc_dict autosave true

    if {${:auto_correct}} {
      dict set fc_dict correct_when [:comp_correct_when_from_value [:get_named_sub_component_value correct_when]]
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
    {nr 15}
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
      {attachments {[:attachments_widget ${:nr_attachments}]}}
      {answer {short_text_field,repeat=1..${:nr},label=}}
    }]
    set :__initialized 1
  }

  short_text_interaction instproc convert_to_internal {} {

    set intro_text    [:get_named_sub_component_value text]
    set answerFields  [:get_named_sub_component_value -from_repeat answer]

    set options {}
    set render_hints {}
    set answer {}
    set solution {}
    set count 0

    foreach {fieldName value} $answerFields {
      # ns_log notice ...fieldName=$fieldName->$value
      set af answer[incr count]
      lappend options  [list [dict get $value $fieldName.text] $af]
      lappend answer   [:comp_correct_when_from_value [dict get $value $fieldName.correct_when]]
      lappend solution [dict get $value $fieldName.solution]
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
    dict set fc_dict descriptions $solution
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

    :create_components  [subst {
      {text  {$widget,height=100px,label=#xowf.sub_question#,plugins=OacsFs}}
      $textEntryConfigSpec [:correct_when_spec]
      {solution {textarea,rows=2,label=#xowf.Solution#}}
    }]
    set :__initialized 1
  }

}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::reorder_interaction
  #
  ###########################################################

  Class create reorder_interaction -superclass TestItemField -parameter {
    {nr 15}
  }

  reorder_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    :create_components [subst {
      {text  {$widget,height=100px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {answer {text,repeat=1..${:nr},label=#xowf.reorder_question_elements#}}
    }]
    set :__initialized 1
  }

  reorder_interaction instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set answerFields [:get_named_sub_component_value -from_repeat answer]

    set options {}
    set answer {}
    set count 0

    foreach {fieldName value} $answerFields {
      #ns_log notice ...fieldName=$fieldName->$value
      lappend options [list $value $count]
      lappend answer $count
      incr count
    }

    #dict set fc_dict shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    #dict set fc_dict show_max [${:parent_field} get_named_sub_component_value show_max]
    dict set fc_dict disabled_as_div 1
    dict set fc_dict label ""
    dict set fc_dict options $options
    dict set fc_dict answer $answer
    dict set fc_dict grading [${:parent_field} get_named_sub_component_value grading]

    append form \
        "<form>\n" \
        "<div class='reorder_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \n \
        "</div>\n" \
        "</form>\n"

    set fc {}
    lappend fc \
        answer:[:dict_to_fc -type reorder_box $fc_dict] \
        @categories:off @cr_fields:hidden

    ns_log notice "reorder_interaction $form\n$fc"
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
  # ::xowiki::formfield::mc_interaction2
  #
  ###########################################################

  Class create mc_interaction2 -superclass TestItemField -parameter {
    {nr 15}
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
      {answer {mc_field,repeat=1..${:nr},label=}}
    }]
    set :__initialized 1
  }

  mc_interaction2 instproc convert_to_internal {} {

    set intro_text   [:get_named_sub_component_value text]
    set answerFields [:get_named_sub_component_value -from_repeat answer]
    set count 0
    set options {}
    set correct {}
    set solution {}

    foreach {fieldName value} $answerFields {
      #ns_log notice ...fieldName=$fieldName->$value
      #set af answer[incr count]
      set text [dict get $value $fieldName.text]
      # trim leading <p> since this causes a newline in the checkbox label
      regexp {^\s*(<p>)(.*)$} $text . . text
      regexp {^(.*)(</p>)\s*$} $text . text .
      lappend options [list $text [incr count]]
      lappend correct [dict get $value $fieldName.correct]
      lappend solution [dict get $value $fieldName.solution]
    }

    dict set fc_dict richtext 1
    dict set fc_dict answer $correct
    dict set fc_dict options $options
    dict set fc_dict descriptions $solution
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
    {n ""}
  }

  mc_field instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

    # {correct {boolean_checkbox,horizontal=true,label=#xowf.Correct#,form_item_wrapper_CSSclass=form-inline}}
    :create_components  [subst {
      {text  {$widget,height=50px,label=#xowf.choice_option#,plugins=OacsFs}}
      {correct {boolean_checkbox,horizontal=true,default=f,label=#xowf.Correct#,form_item_wrapper_CSSclass=form-inline}}
      {solution {textarea,rows=2,label=#xowf.Solution#,form_item_wrapper_CSSclass=form-inline}}
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
      {text        {$widget,height=150px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {attachments {[:attachments_widget ${:nr_attachments}]}}
    }]

    set :__initialized 1
  }

  upload_interaction instproc convert_to_internal {} {
    next
    set intro_text [:get_named_sub_component_value text]
    set max_nr_submission_files [${:parent_field} get_named_sub_component_value max_nr_submission_files]
    #dict set file_dict choose_file_label "Datei hochladen"

    if {$max_nr_submission_files > 1} {
      dict set file_dict repeat 1..$max_nr_submission_files
      dict set file_dict repeat_add_label #xowiki.form-repeatable-add-another-file#
      dict set file_dict label #xowf.online-exam-submission_files#
    } else {
      dict set file_dict label #xowf.online-exam-submission_file#
    }

    append intro_text [:text_attachments]
    append form \
        "<form>\n" \
        "<div class='upload_interaction'>\n" \
        "<div class='question_text'>$intro_text</div>\n" \
        "@answer@" \
        "</div>\n" \
        "</form>\n"
    append fc \
        "@categories:off @cr_fields:hidden\n" \
        "{answer:[:dict_to_fc -type file $file_dict]}"

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
    # the form constraints. We use the item_id contained pages as the
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
      # We have to drop the top-level <form> of the included form
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
            # this rule is for single choice
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
    # - name_to_question_obj_dict
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
      regsub -all -- {[-]} $strippedName _ stem
      return ${stem}_
    }

    :public method name_to_question_obj_dict {question_objs} {
      #
      # Produce a dict for attribute name to question_obj
      #
      set nameToQuestionObjDict {}
      foreach o $question_objs {
        dict set nameToQuestionObjDict [:form_name_based_attribute_stem [$o name]] $o
      }
      return $nameToQuestionObjDict
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
      #
      # Perform attribute renaming in the provided form_obj and return
      # this form_obj. In essence, this changes the generic "@answer@"
      # value in the form and in the form constraints to a name based
      # on the form name.
      #

      set form [$form_obj get_property -name form]
      set fc   [$form_obj get_property -name form_constraints]

      #
      # Map "answer" to a generic name in the form "@answer@" and in the
      # form constraints.
      #
      set newName [:form_name_based_attribute_stem [$form_obj name]]

      regsub -all -- {@answer} $form @$newName form
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

    :public method -deprecated get_form_object {ctx:object form_name} {
      #
      # Return the form object based on the provided form name. This
      # function performs attribute renaming on the returned form
      # object.
      #
      set form_id [$ctx default_load_form_id $form_name]
      set obj [$ctx object]
      set form_obj [::xo::db::CrClass get_instance_from_db -item_id $form_id]
      return [:rename_attributes $form_obj]
    }

  }

  Renaming_form_loader create renaming_form_loader
}


namespace eval ::xowf::test_item {

  ad_proc -private fc_to_dict {form_constraints} {
    #
    # Convert from form_constraint syntax to a dict. This is just a
    # partial implementation, since form constraints are interprted
    # from left to right, changing types, etc., which is not
    # supported here.
    #
    foreach fc $form_constraints {
      #ns_log notice "... fc_to_dict works on <$fc>"
      if {[regexp {^([^:]+):(.*)$} $fc _ field_name definition]} {
        if {[string match @* $field_name]} continue
        set elements [split $definition ,]
        dict set result $field_name type [lindex $elements 0]
        foreach s [lrange $elements 1 end] {
          switch -glob -- $s {
            *=* {
              set p [string first = $s]
              set attribute [string range $s 0 $p-1]
              set value [::xowiki::formfield::FormField fc_decode [string range $s $p+1 end]]
              dict set result $field_name $attribute $value
            }
            default {
              ns_log notice "... fc_to_dict ignores <$s>"
            }
          }
        }
        dict set result $field_name definition $definition
      }
    }
    return $result
  }


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
    #  - runtime_panel
    #
    #  - marked_results
    #  - answers_panel
    #  - results_table
    #  - grading_table
    #  - grade
    #  - participants_table
    #
    #  - get_duration
    #  - get_IPs
    #  - revisions_up_to
    #  - last_time_in_state
    #  - state_periods
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

      set time_window [$parentObj property time_window]
      if {$time_window ne ""} {
        :time_window_setup $parentObj -time_window $time_window
      }
    }

    ########################################################################

    :method get_label_from_options {value options} {
      foreach option $options {
        if {[lindex $option 1] eq $value} {
          return [lindex $option 0]
        }
      }
      return ""
    }


    :public method recutil_create {
      -exam_id:integer
      {-fn "answers.rec"}
      -clear:switch
    } {
      #
      # Create recfile
      #
      # @see http://www.gnu.org/software/recutils/
      #
      set export_dir [acs_root_dir]/log/exam-exports/$exam_id/
      if {![file isdirectory $export_dir]} {
        file mkdir $export_dir
      }
      if {$clear && [file exists $export_dir$fn]} {
        file delete -- $export_dir$fn
      }
      #
      # If we have no recutils, create for the time being a stub
      #
      if {![nsf::is class ::xo::recutil]} {
        ns_log warning "no recutil class available"
        set r [::xotcl::Object new -proc ins args {;}]
        return $r
      }
      return [::xo::recutil new -file $export_dir$fn]
    }

    :public method export_answer {
      -user_answers:object
      -html:required
      -combined_form_info
      -recutil:object,required
    } {
      #
      # Export the provided question and answer in GNU rectuil format.
      #
      #ns_log notice "answers: [$user_answers serialize]"

      if {[$user_answers exists __form_fields]} {
        set form_fields [$user_answers set __form_fields]
      } else {
        #
        # We do not have the newest version of xowiki, so locate the
        # objs the hard way based on the naming convention.
        #
        set form_field_objs [lmap f [::xowiki::formfield::FormField info instances -closure] {
          if {![string match *_ [$f name]]} {continue}
          set f
        }]
        foreach form_field_obj $form_field_objs {
          dict set form_fields [$form_field_obj name] $form_field_obj
        }
        ns_log notice "export_answers: old style form_fields: $form_fields"
      }

      set export_dict ""
      set user [$user_answers set creation_user]
      if {![info exists ::__running_ids]} {
         set ::__running_ids ""
      }
      if {![dict exists $::__running_ids $user]} {
        dict set ::__running_ids $user [incr ::__running_id]
      }

      set seeds [$user_answers property seeds]
      set instance_attributes [$user_answers set instance_attributes]
      set answer_attributes [lmap a $instance_attributes {
        if {![string match *_ $a]} {continue}
        set a
      }]

      #ns_log notice "export_answers: combined_form_info: $combined_form_info"
      #set title_infos [dict get $combined_form_info title_infos]

      #
      # Get the question dict, which is a mapping between question
      # names and form_obj_ids.
      #
      set question_dict [renaming_form_loader name_to_question_obj_dict \
                             [dict get $combined_form_info question_objs]]
      # ns_log notice "export_answers: question_dict: $question_dict"

      set form_constraints [lsort -unique [dict get $combined_form_info form_constraints]]
      set fc_dict [fc_to_dict $form_constraints]
      #ns_log notice "... form_constraints ([llength $form_constraints]) $form_constraints"
      #ns_log notice ".... dict $fc_dict"
      #
      # Every answer_attribute contains the answer to a test_item
      # (which potentially sub answers).
      #
      foreach a $answer_attributes {
        #ns_log notice "answers <[dict get $instance_attributes $a]>"
        foreach {alternative_id answer} [dict get $instance_attributes $a] {
          set alt_value [lindex [split $alternative_id .] 1]
          set form_obj [dict get $question_dict $a]

          #set ff [dict get $form_fields $a]
          #ns_log notice "answer $a: [dict get $instance_attributes $a] [$ff serialize]"
          #ns_log notice "answer $a: form_obj [$form_obj serialize]"
          set form_obj_ia [$form_obj instance_attributes]
          #ns_log notice "answer $a: [dict get $instance_attributes $a] [dict keys [dict get $form_obj_ia question]]"
          #ns_log notice "INTERACTION [dict get [dict get $form_obj_ia question] question.interaction]"
          set intro [dict get [dict get [dict get $form_obj_ia question] question.interaction] question.interaction.text]
          #ns_log notice "TEXT $intro"
          #set question_title [question_manager question_property $form_obj title]
          #set question_minutes [question_manager question_property $form_obj minutes]
          #ns_log notice "answer $a: [dict get $instance_attributes $a] [dict keys [dict get $form_obj_ia question]]"

          #dict set export_dict name $a
          dict set export_dict name $alternative_id
          dict set export_dict user_id $user
          dict set export_dict running_id [dict get $::__running_ids $user]
          dict set export_dict question_obj $form_obj
          dict set export_dict question_title [$form_obj title]
          dict set export_dict question_intro [ns_striphtml $intro]
          dict set export_dict question_minutes [dict get $fc_dict $a test_item_minutes]
          dict set export_dict question_points [dict get $fc_dict $a test_item_points]
          dict set export_dict question_text [ns_striphtml [:get_label_from_options $alt_value [dict get $fc_dict $a options]]]
          #dict set export_dict options [dict get $fc_dict $a options]
          dict set export_dict answer $answer

          ns_log notice "answer $a: DICT $export_dict"
          #ns_log notice "avail $a: [dict get $fc_dict $a]"
          $recutil ins $export_dict
        }
      }
    }

    ########################################################################

    :method time_window_setup {parentObj:object {-time_window:required}} {
      #
      # Check the provided time_window values, adjust it if necessary,
      # and make sure, according atjobs are provided.
      #
      set dtstart [dict get $time_window time_window.dtstart]
      set dtend [dict get $time_window time_window.dtend]

      if {$dtstart ne ""} {
        set total_minutes [question_manager total_minutes_for_exam -manager $parentObj]
        ns_log notice "#### create_workflows: atjobs for time_window <$time_window> total-mins $total_minutes"
        set start_clock [clock scan $dtstart -format %Y-%m-%dT%H:%M]

        if {$dtend eq ""} {
          #
          # No end given. set it to start + exam time + 5 minutes
          #
          set end_clock [expr {$start_clock + ($total_minutes + 5) * 60}]
          set new_dtend [clock format $end_clock -format %H:%M]
          ns_log notice "#### no dtend given. set it from $dtend to $new_dtend"

        } else {
          set end_date    [clock format $start_clock -format %Y-%m-%d]T$dtend
          set end_clock   [clock scan $end_date      -format %Y-%m-%dT%H:%M]
          if {($end_clock - $start_clock) < ($total_minutes * 60)} {
            #
            # The specified end time is too early. Set it to start +
            # exam time + 5 minutes
            #
            set end_clock [expr {$start_clock + ($total_minutes + 5)*60}]
            set new_dtend [clock format $end_clock -format %H:%M]
            ns_log notice "#### dtend is too early. Move it from $dtend to $new_dtend"

          } else {
            set new_dtend $dtend
          }
        }

        if {$new_dtend ne $dtend} {
          ns_log notice "#### create_workflows: must change dtend from <$dtend> to <$new_dtend>"
          set ia [$parentObj instance_attributes]
          dict set time_window time_window.dtend $new_dtend
          dict set ia time_window $time_window
          #ns_log notice "SAVE updated ia <${:instance_attributes}>"
          $parentObj update_attribute_from_slot [$parentObj find_slot instance_attributes] $ia
        }

        #
        # Delete previously scheduled atjobs
        #
        :delete_scheduled_atjobs $parentObj

        #
        # Schedule new atjobs
        #
        $parentObj schedule_action \
            -time [clock format $start_clock -format "%Y-%m-%d %H:%M:%S"] \
            -action publish
        $parentObj schedule_action \
            -time [clock format $end_clock -format "%Y-%m-%d %H:%M:%S"] \
            -action unpublish
      }
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
    :public method delete_scheduled_atjobs {obj:object} {
      #
      # Delete previously scheduled atjobs
      #
      ns_log notice "#### delete_scheduled_atjobs"

      set item_id [$obj item_id]
      set atjob_form_id [::xowf::atjob form_id -parent_id $item_id -package_id [ad_conn package_id]]

      set to_delete [xo::dc list get_children {
        select item_id from xowiki_form_instance_item_index
        where parent_id = :item_id
        and page_template = :atjob_form_id
      }]

      foreach id $to_delete {
        ns_log notice "#### xo::db::sql::content_item proc delete -item_id $id"
        xo::db::sql::content_item delete -item_id $id
      }
    }



    ########################################################################

    :public method get_answer_wf {obj:object} {
      #
      # return the workflow denoted by the property wfName in obj
      #
      return [::[$obj package_id] instantiate_forms \
                  -parent_id    [$obj item_id] \
                  -default_lang [$obj lang] \
                  -forms        [$obj property wfName]]
    }

    ########################################################################

    :public method get_wf_instances {
      {-initialize false}
      {-orderby ""}
      -creation_user:integer
      -item_id:integer
      wf:object
    } {
      # get_wf_instances: return the workflow instances

      :assert_assessment_container $wf
      set extra_where_clause ""
      foreach var {creation_user item_id} {
        if {[info exists $var]} {
          append extra_where_clause "AND $var = [ns_dbquotevalue [set $var]] "
        }
      }

      return [::xowiki::FormPage get_form_entries \
                  -base_item_ids             [$wf item_id] \
                  -form_fields               "" \
                  -always_queried_attributes "*" \
                  -initialize                $initialize \
                  -orderby                   $orderby \
                  -extra_where_clause        $extra_where_clause \
                  -publish_status            all \
                  -package_id                [$wf package_id]]
    }

    ########################################################################

    :public method get_answers {{-state ""} wf:object} {
      #
      # Extracts wf instances as answers (e.g. extracting their
      # answer-specific attributes)
      #
      # @param wf the workflow
      # @param state retrieve only instances in this state
      #
      # @return a list of dicts
      #

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

    :public method get_duration {{-exam_published_time ""} revision_sets} {
      #
      # Get the duration from a set of revisions and return a dict
      # containing "from", "fromClock","to", "toClock", and "duration"
      #

      set first [lindex $revision_sets 0]
      set last [lindex $revision_sets end]
      set fromClock [clock scan [::xo::db::tcl_date [ns_set get $first creation_date] tz]]
      set toClock [clock scan [::xo::db::tcl_date [ns_set get $last creation_date] tz]]
      dict set r fromClock $fromClock
      dict set r toClock $toClock
      dict set r from [clock format $fromClock -format "%H:%M:%S"]
      dict set r to [clock format $toClock -format "%H:%M:%S"]
      set timeDiff [expr {$toClock - $fromClock}]
      dict set r duration "[expr {$timeDiff/60}]m [expr {$timeDiff%60}]s"
      if {$exam_published_time ne ""} {
        set examPublishedClock [clock scan [::xo::db::tcl_date $exam_published_time tz]]
        dict set r examPublishedClock $examPublishedClock
        dict set r examPublished [clock format $examPublishedClock -format "%H:%M:%S"]
        set epTimeDiff [expr {$toClock - $examPublishedClock}]
        dict set r examPublishedDuration "[expr {$epTimeDiff/60}]m [expr {$epTimeDiff%60}]s"
      }
      return $r
    }

    ########################################################################

    :public method get_IPs {revision_sets} {
      #
      # Get the IP addresses for the given revision set. Should be
      # actually only one. The revision_set must not be empty.
      #
      set IPs ""
      foreach revision_set $revision_sets {
        set ip [ns_set get $revision_set creation_ip]
        if {$ip ne ""} {
          dict set IPs [ns_set get $revision_set creation_ip] 1
        }
      }
      return [dict keys $IPs]
    }

    ########################################################################

    :public method revisions_up_to {revision_sets revision_id} {
      #
      # Return the revisions of the provided revision set up the
      # provided revision_id. If this revision_id does not exist,
      # return the full set.
      #
      set result ""
      set stop 0
      return [lmap s $revision_sets {
        if {$stop} break
        set stop [expr {[ns_set get $s revision_id] eq $revision_id}]
        set s
      }]
    }

    ########################################################################
    :public method last_time_in_state {revision_sets -state:required -with_until:switch } {
      #
      # Loops through revision sets and retrieves the latest date
      # where state is equal the specified value.
      #
      # @param revision_sets a list of ns_sets containing revision
      #        data. List is assumed to be sorted in descending
      #        creation_date order (as retrieved by get_revision_sets)
      #
      # @return a date
      #
      set result ""
      foreach ps $revision_sets {
        if {$state eq [ns_set get $ps state]} {
          set result [ns_set get $ps creation_date]
        }
      }
      return $result
    }

    ########################################################################
    :method pretty_period {{-dayfmt %q} {-timefmt %H:%M} from to} {
      set from_day [lc_time_fmt $from $dayfmt]
      set from_time [lc_time_fmt $from $timefmt]
      if {$to ne ""} {
        set to_day [lc_time_fmt $to $dayfmt]
        set to_time [lc_time_fmt $to $timefmt]
      } else {
        set to_day ""
        set to_time ""
      }
      if {$to_day eq ""} {
        set period "$from_day, $from_time -"
      } elseif {$from_day eq $to_day} {
        set period "$from_day, $from_time - $to_time"
      } else {
        set period "$from_day, $from_time - $to_day, $to_time"
      }
      return $period
    }

    ########################################################################
    :public method state_periods {revision_sets -state:required} {
      #
      # Return for the provided revision_sets the time ranges the
      # workflow was in the provided state.
      #
      set periods ""
      set from ""
      set last_from ""
      set until ""
      foreach ps $revision_sets {
        set current_state [ns_set get $ps state]
        if {$state eq $current_state} {
          if {$until ne ""} {
            lappend periods [:pretty_period $last_from $until]
          }
          set from [ns_set get $ps creation_date]
          set until ""
        } elseif {$until eq "" && $current_state ne $state && $from ne ""} {
          set until [ns_set get $ps creation_date]
          set last_from $from
          set from ""
        }
      }
      if {$until ne ""} {
        lappend periods [:pretty_period $last_from $until]
      } elseif {$from ne ""} {
        lappend periods [:pretty_period $from ""]
      }
      #ns_log  notice "state_periods $state <$from> <$last_from> <$until> <$periods>"
      return $periods
    }

    ########################################################################
    :public method achieved_points {-answer_object:object -answer_attributes:required } {
      #
      # This method has to be called after the instance was rendered,
      # since it uses the produced form_fields.
      #
      set all_form_fields [::xowiki::formfield::FormField info instances -closure]
      set totalPoints 0
      set achievableTotalPoints 0
      set details {}
      foreach a [dict keys $answer_attributes] {
        set f [$answer_object lookup_form_field -name $a $all_form_fields]
        set points {}
        set achievablePoints [$f set test_item_points]
        set achievableTotalPoints [expr {$achievableTotalPoints + $achievablePoints}]
        if {[$f exists correction_data]} {
          set cd [$f set correction_data]
          #ns_log notice "FOO: $a <$f> $cd"
          if {[dict exists $cd points]} {
            set points [dict get $cd points]
            set totalPoints [expr {$totalPoints + $points}]
          } else {
            ns_log warning "$a: no points in correction_data, ignoring in points calculation"
          }
        }
        lappend details [dict create \
                                   attributeName $a \
                                   achieved $points \
                                   achievable $achievablePoints]
      }
      return [list achievedPoints $totalPoints \
                  details $details \
                  achievedPointsRounded [format %.0f $totalPoints] \
                  achievablePoints $achievableTotalPoints]
    }

    ########################################################################
    :public method runtime_panel {
      {-revision_id ""}
      {-view default}
      {-grading_info ""}
      answerObj:object
    } {
      #
      # Return statistics for the provided object:
      # - minimal statistics: when view default
      # - statistics with clickable revisions: when view = revision_overview
      # - per-revision statistics: when view = revision_overview and revision_id is provided
      #
      set revision_sets [$answerObj get_revision_sets]
      set parent_revsion_sets [[$answerObj parent_id] get_revision_sets]
      set item_id [$answerObj item_id]
      set live_revision_id [xo::dc get_value -prepare integer live_revision_id {
        select live_revision from cr_items where item_id = :item_id
      }]
      set current_question [expr {[dict get [$answerObj instance_attributes] position] + 1}]
      set page_info "#xowf.question#: $current_question"

      if {$view eq "default"} {
        set url [ad_return_url]&id=$item_id
        set revisionDetails "#xowf.nr_changes#: <a href='$url'>[llength $revision_sets]</a><br>"
      } elseif {$view eq "student"} {
        set revisionDetails ""
      } elseif {$view eq "revision_overview"} {
        set displayed_revision_info ""
        set live_revision_info ""
        set make_live_info ""

        set baseUrl [ns_conn url]
        set filtered_revision_sets [:revisions_up_to $revision_sets $revision_id]
        set c 0

        foreach s $revision_sets {
          set rid [ns_set get $s revision_id]
          incr c
          if {$rid == $live_revision_id} {
            set liveCSSclass "live"
            set live_revision_info "#xowf.Live_revision#: $c"
          } else {
            set liveCSSclass "other"
          }
          set revision_url $baseUrl?[::xo::update_query [ns_conn query] rid $rid]
          if {$rid == [$answerObj revision_id]} {
            set suffix "*"
            set displayed_revision_info "#xowf.Displayed_revision#: $c"

            if {$rid ne $live_revision_id} {
              set query [::xo::update_query [ns_conn query] m make-live-revision]
              set query [::xo::update_query $query revision_id $rid]
              set query [::xo::update_query $query local_return_url [ad_return_url]]
              set live_revision_link $baseUrl?$query
              set make_live_info [subst {
                <a class="button" href="$live_revision_link">#xowf.Make_live_revision#</a>
              }]
              lappend revision_list "<span class='current'>$c</span>"
            } else {
              lappend revision_list "<span class='$liveCSSclass'>$c</span>"
            }
          } else {
            lappend revision_list [subst {
              <a class="$liveCSSclass" title="#xowf.Goto_this_revision#" href="$revision_url">$c</a>
            }]
          }
        }
        set revision_sets $filtered_revision_sets
        set revisionDetails [subst {#xowiki.revisions#: [join $revision_list {, }]
          <div class="revision-details right">$displayed_revision_info<br>$live_revision_info<br>
          $make_live_info
          </div>
          <br>
        }]
      }
      if {$revision_id eq ""} {
        set revision_sets [:revisions_up_to $revision_sets $live_revision_id]
      }
      set last_published [:last_time_in_state $parent_revsion_sets -state published]
      set duration [:get_duration -exam_published_time $last_published $revision_sets]

      set state [$answerObj state]
      if {$state eq "done"} {
        set submission_info "#xowf.submitted#"
      } else {
        set submission_info "#xowf.not_submitted# ($page_info)"
      }

      if {[dict exists $duration examPublished]} {
        set publishedInfo "#xowf.Exam_published#: <span class='data'>[dict get $duration examPublished]</span><br>"
        set extraDurationInfo " - #xowf.since_published#: [dict get $duration examPublishedDuration]"
      } else {
        set publishedInfo ""
        set extraDurationInfo ""
      }
      if {$view eq "student"} {
        set IPinfo ""
        set statusInfo ""
        set extraDurationInfo ""
        set publishedInfo ""
      } else {
        set IPinfo [subst {IP: <span class="data">[:get_IPs $revision_sets]</span>}]
        set statusInfo "#xowf.Status#: <span class='data'>$submission_info</span><br>"
      }

      if {$grading_info ne ""} {
        set achievedPointsInfo [subst {
          #xowf.Achieved_points#: <span class='data'>$grading_info</span><br>
        }]
      } else {
        set achievedPointsInfo ""
      }
      set HTML [subst {
        $publishedInfo
        $revisionDetails
        $statusInfo
        #xowf.Duration#: <span class="data">[dict get $duration from] - [dict get $duration to]
        ([dict get $duration duration]$extraDurationInfo)</span><br>
        $achievedPointsInfo
        $IPinfo
      }]
      return $HTML
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
          if {[$f exists correction]} {
             set correction [$f set correction]
          } else {
             set correction ""
             ns_log warning "form-field [$f name] of type [$f info class] does not provide variable correction via 'make_correct'"
          }
          lappend answer \
              [list name $att \
                   value $value \
                   correction $correction \
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
        unset -nocomplain $key
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
          $wf form_field_index [set $key]
        }
        return [set $key]
      }
    }

    :public method grading_table {{-csv ""} grade_dict} {
      #
      # Produce HTML markup based on a dict with grades as keys and
      # counts as values.
      #
      set gradingTable {<div class="grading-info"><div class="table-responsive"><table class="table grading">}
      append gradingTable \
          "<thead><th class='text-right col-md-1'>#xowf.Grade#</th><th class='col-md-1 text-right'>#</th></thead>" \
          "<tbody>\n"
      set nrGrades 0
      foreach v [dict values $grade_dict] { incr nrGrades $v}
      foreach k [lsort [dict keys $grade_dict]] {
        set count [dict get $grade_dict $k]
        set countPercentage [format %.2f [expr {$count *100.0 / $nrGrades}]]
        append gradingTable \
            <tr> \
            [subst {<td class="text-right">$k</td><td class="text-right">$count</td>}] \
            [subst {<td><div class="progress"><div class="progress-bar"
              style="width:$countPercentage%">$countPercentage%</div></td}] \
            </tr>\n
      }
      append gradingTable "</tbody></table></div>\n<pre>$csv</pre></div>\n"
      return $gradingTable
    }

    :public method results_table {
      -package_id:integer
      -items:object,required
      {-view_all_method print-answers}
      {-with_answers:boolean true}
      {-state done}
      {-grading_scheme ::xowf::test_item::grading::wi1}
      wf:object
    } {
      #set form_info [:combined_question_form -with_numbers $wf]
      set form_info [::xowf::test_item::question_manager combined_question_form $wf]
      set answer_form_field_objs [:answer_form_field_objs -wf $wf $form_info]
      set autograde [dict get $form_info autograde]

      #if {$autograde && [llength $answer_form_field_objs] > 10} {
      #  set with_answers 0
      #}

      set form_field_objs {}
      lappend form_field_objs \
          [$wf create_raw_form_field \
               -name _online-exam-userName \
               -spec text,label=#xowf.participant#]

      if {$with_answers} {
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
      }

      if {0 && $autograde} {
        lappend form_field_objs \
            [$wf create_raw_form_field \
               -name _online-exam-total-score \
               -spec number,label=#xowf.Total-Score#] \
            [$wf create_raw_form_field \
                 -name _online-exam-grade \
                 -spec number,label=#xowf.Grade#]
      }

      lappend form_field_objs \
          [$wf create_raw_form_field \
               -name _online-exam-seconds \
               -spec number,label=#xowf.Seconds#] \
          [$wf create_raw_form_field \
               -name _creation_date \
               -spec date,label=#xowiki.Page-last_modified#]

      #
      # Check, if any of the answer form field objects is
      # randomized. If so, it is necessary to recreate these eagerly,
      # since the full object structure might be personalized.
      #
      set randomized_fields {}
      foreach ff_obj $answer_form_field_objs {
        if {[$ff_obj exists shuffle_kind] && [$ff_obj shuffle_kind] ne "none"} {
          lappend randomized_fields $ff_obj
        }
      }

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
        #
        # If we have randomized fields, we have to
        # recreate/reinitialize these to get proper correction
        # markings for this user. It might be possible to optimize
        # this, when only a few fields are randomized.
        #
        if {[llength $randomized_fields] > 0} {
          #ns_log notice "WORK ON [$p creation_user] "
          :answer_form_field_objs -clear -wf $wf $form_info
          $wf form_field_flush_cache
          xo::cc eval_as_user -user_id [$p creation_user] {
            set answer_form_field_objs [:answer_form_field_objs -wf $wf $form_info]
          }
        }

        set total_score 0
        set total_points 0
        foreach ff_obj $answer_form_field_objs {
          $ff_obj object $p
          set property [$ff_obj name]
          $ff_obj value [$p property $property]

          $ff_obj set_feedback 3

          #ns_log notice "[$p creation_user] [$ff_obj name] [$p property $property] -> [$ff_obj set evaluated_answer_result]"
          set r [expr {[$ff_obj exists grading_score] ? [$ff_obj set grading_score] : ""}]
          #
          # In case, we have a grading score, which is not starred, we
          # can compute points from this.
          #
          if {$r ne "" && ![regexp {[*]$} $r]} {
            #
            # Add exercise score weighted to the total score to
            # compute points.
            #
            if {[$ff_obj exists test_item_points]} {
              #ns_log notice "[$ff_obj name]: grading_score <$r>, test_item_points <[$ff_obj set test_item_points]>"

              set minutes [$ff_obj set test_item_points]
              set total_score [expr {$total_score + ($minutes * [$ff_obj set grading_score])}]
              set total_points [expr {$total_points + $minutes}]
            }
            #ns_log notice "==== [$ff_obj name] grading_score => $r"
          } else {
            set r [expr {[$ff_obj set evaluated_answer_result] eq "correct" ? 100.0 : 0.0}]*
            #ns_log notice [$ff_obj serialize]
          }
          $p set_property -new 1 $property.score $r
        }

        set duration [:get_duration [$p get_revision_sets]]
        $p set_property -new 1 _online-exam-seconds \
            [expr {[dict get $duration toClock] - [dict get $duration fromClock]}]

        if {0 && $autograde && $total_points > 0} {
          set final_score [expr {$total_score/$total_points}]
          $p set_property -new 1 _online-exam-total-score $final_score

          set d [list achievedPoints $total_score achievablePoints $total_score totalPoints $total_point]
          set grade [$grading_scheme grade -achieved_points $d]
          dict incr grade_count $grade
          $p set_property -new 1 _online-exam-grade $grade
        }
      }

      if {$state eq "done"} {
        set uc {tcl {[$p state] ne "done"}}
      } else {
        set uc {tcl {false}}
      }

      #
      # Render table widget with extended properties.
      #
      set HTML [$table_widget render_page_items_as_table \
                    -package_id $package_id \
                    -items $items \
                    -form_field_objs $form_field_objs \
                    -csv true \
                    -uc $uc \
                    -view_field _online-exam-userName \
                    -view_filter_link [$wf pretty_link -query m=$view_all_method] \
                    {*}[expr {[info exists generate] ? [list -generate $generate] : ""}] \
                    -return_url [ad_return_url] \
                    -return_url_att local_return_url \
                   ]
      $table_widget destroy

      if {0 && $autograde} {
        set gradingTable {<div class="table-responsive"><table class="table">}
        append gradingTable \
            "<thead><th class='text-right col-md-1'>#xowf.Grade#</th><th class='col-md-1 text-right'>#</th></thead>" \
            "<tbody>\n"
        set nrGrades 0
        foreach v [dict values $grade_count] { incr nrGrades $v}
        foreach k [lsort [dict keys $grade_count]] {
          set count [dict get $grade_count $k]
          set countPercentage [expr {$count*100.0/$nrGrades}]
          append gradingTable \
              <tr> \
              [subst {<td class="text-right">$k</td><td class="text-right">$count</td>}] \
              [subst {<td><div class="progress"><div class="progress-bar"
                style="width:$countPercentage%">$countPercentage%</div></td}] \
              </tr>\n
        }
        append gradingTable "</tbody></table></div>\n"
        append HTML <p>$gradingTable</p>
      }
      return $HTML
    }

    :public method participants_table {
      -package_id:integer
      -items:object,required
      {-view_all_method print-answers}
      {-state done}
      wf:object
    } {
      #
      # This method returns an HTML table containing a row for every
      # participant with Name and short summary information. This
      # table provides as well an interface for sending messages to
      # this student.
      #
      set form_field_objs {}
      lappend form_field_objs \
          [$wf create_raw_form_field \
               -name _online-exam-userName \
               -spec text,label=#xowf.participant#] \
          [$wf create_raw_form_field \
               -name _online-exam-fullName \
               -spec label,label=#acs-subsite.Name#,disableOutputEscaping=true] \
          [$wf create_raw_form_field \
               -name _state \
               -spec text,label=#xowf.Status#] \
          [$wf create_raw_form_field \
               -name _online-exam-seconds \
               -spec number,label=#xowf.Seconds#] \
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
      # Extend properties of individual answers and add notification
      # dialogs.
      #
      set dialogs ""
      foreach p [$items children] {

        #foreach ff_obj $answer_form_field_objs {
        #  $ff_obj object $p
        #  set property [$ff_obj name]
        #  $ff_obj value [$p property $property]
        #}

        #
        # Provide a notification dialog only before the student has
        # submitted her exam.
        #
        if {[$p state] ne "done"} {
          set dialog_info [::xowiki::includelet::personal-notification-messages \
                               modal_message_dialog -to_user_id [$p creation_user]]
          append dialogs [dict get $dialog_info dialog] \n
          set notification_dialog_button [dict get $dialog_info link]
        } else {
          set notification_dialog_button ""
        }

        #
        # Extend every answer with corresponding precomputed extra
        # "_online-exam-*" values to ease rendering:
        #
        set duration [:get_duration [$p get_revision_sets]]
        $p set_property -new 1 _online-exam-seconds \
            [expr {[dict get $duration toClock] - [dict get $duration fromClock]}]

        $p set online-exam-fullName "$notification_dialog_button [$p set online-exam-fullName]"
      }

      ::xowiki::includelet::personal-notification-messages \
          modal_message_dialog_register_submit \
          -url [$wf pretty_link -query m=send-participant-message]

      if {$state eq "done"} {
        set uc {tcl {[$p state] ne "done"}}
      } else {
        set uc {tcl {false}}
      }
      #
      # Render table widget with extended properties.
      #
      set HTML [$table_widget render_page_items_as_table \
                    -package_id $package_id \
                    -items $items \
                    -form_field_objs $form_field_objs \
                    -csv true \
                    -uc $uc \
                    -view_field _online-exam-userName \
                    -view_filter_link [$wf pretty_link -query m=$view_all_method] \
                    {*}[expr {[info exists generate] ? [list -generate $generate] : ""}] \
                    -return_url [ad_return_url] \
                    -return_url_att local_return_url \
                   ]
      $table_widget destroy
      return $dialogs$HTML
    }

    :public method marked_results {-obj:object -wf:object form_info} {
      #
      # Return for every participant the individual results for an exam
      #
      set form_field_objs [:answer_form_field_objs -wf $wf $form_info]

      set items [:get_wf_instances $wf]
      set results ""
      foreach i [$items children] {
        xo::cc eval_as_user -user_id [$i creation_user] {
          set participantResult [:participant_result -obj $obj $i $form_info $form_field_objs]
        }
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
      #
      # Produce HTML code for an answers panel, containing the number
      # of participants of an e-assessment and the number of
      # participants, who have already answered.
      #
      # @param polling when specified, provide live updates
      #        of the numbers via AJAX calls
      # @param extra_text optional extra text for the panel,
      #        has to be provided with valid HTML markup.
      #

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
      {-audio_alarm:boolean true}
      {-audio_alarm_cookie incass_exam_audio_alarm}
      {-audio_alarm_times: 60,30,20,10,5,2}
    } {
      #
      # Accepted formats for target_time, determined by JavaScript
      # ISO 8601, e.g. YYYY-MM-DDTHH:mm:ss.sss"
      #
      # Set current time based on host time instead of new
      # Date().getTime() to avoid surprises, in cases, the time at the
      # client browser is set incorrectly.
      #
      set nowMs [clock milliseconds]
      set nowIsoTime [clock format [expr {$nowMs/1000}] -format "%Y-%m-%dT%H:%M:%S"].[format %.3d [expr {$nowMs % 1000}]]

      template::add_body_script -script [subst {
        var countdown_target_date = new Date('$target_time').getTime();
        var countdown_days, countdown_hours, countdown_minutes, countdown_seconds;
        var countdown = document.getElementById('$id');

        // adjust target time by the difference between the host and client time
        countdown_target_date = countdown_target_date - (new Date('$nowIsoTime').getTime() - new Date().getTime());

        setInterval(function () {
          var current_date = new Date().getTime();
          var absolute_seconds_left = (countdown_target_date - current_date) / 1000;
          var seconds_left = absolute_seconds_left
          var HTML = '';

          countdown_days = parseInt(seconds_left / 86400);
          seconds_left = seconds_left % 86400;
          countdown_hours = parseInt(seconds_left / 3600);
          seconds_left = seconds_left % 3600;
          countdown_minutes = parseInt(seconds_left / 60);
          countdown_seconds = parseInt(seconds_left % 60);

          var alarmseconds = countdown.parentNode.dataset.alarmseconds;
          if (typeof alarmseconds !== 'undefined') {
            var full_seconds = Math.trunc(absolute_seconds_left);
            // for testing purposes, use: (full_seconds % 5 == 0)
            if (alarmseconds.includes(full_seconds)) {
              beep(200);
            }
          }

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

        var beep = (function () {
          return function (duration, finishedCallback) {
            var container = document.getElementById('$id').parentNode;

            //console.log("beep attempt " + duration + ' ' + audioContext + ' ' + container.dataset.alarm);
            if (typeof audioContext !== 'undefined' && (container.dataset.alarm == 'active')) {

              //console.log("true beep duration " + duration + ' ' + audioContext + ' ' + audioContext.state);
              var osc = audioContext.createOscillator();
              osc.type = "sine";
              osc.connect(audioContext.destination);
              if (osc.noteOn) osc.noteOn(0); // old browsers
              if (osc.start) osc.start(); // new browsers

              setTimeout(function () {
                if (osc.noteOff) osc.noteOff(0); // old browsers
                if (osc.stop) osc.stop(); // new browsers
              }, duration);
            }
          };
        })();
      }]

      if {$audio_alarm} {
        #
        # Audio alarm handling is more tricky than expected, since
        # modern browsers do not allow one to create an active sound
        # context without a "user gesture" (requires e.g. a click to
        # start).
        #
        # The code tries to remember the audio state between different
        # pages, such when e.g. being in an exam, the user has to
        # activate/deactivate the audio not on every page. However,
        # when the user does a full reload, then the user has to
        # activate the audio alarm again.
        #
        # The state is symbolized using bootstrap 3 glyphicons.  The
        # code is tested primarily with chrome.
        #
        template::add_body_script -script [subst {
          var audioContext = new AudioContext();
          var audioContext_setSate = (function (targetState) {
            var container = document.getElementById('$id').parentNode;
            //console.log('--- state = ' + audioContext.state + ' want ' + targetState);
            if (targetState == 'active') {
              var span = container.getElementsByTagName('span')\[0\];
              span.classList.remove('glyphicon-volume-off');
              span.classList.add('glyphicon-volume-up');
              container.dataset.alarm = 'active';
              document.cookie = '$audio_alarm_cookie=active; sameSite=strict';
              audioContext.resume().then(() => {console.log('Playback resumed successfully ' + targetState);});
            } else {
              var span = container.getElementsByTagName('span')\[0\];
              span.classList.remove('glyphicon-volume-up');
              span.classList.add('glyphicon-volume-off');
              container.dataset.alarm = 'inactive';
              document.cookie = '$audio_alarm_cookie=inactive; sameSite=strict';
              audioContext.suspend().then(() => {console.log('Playback suspended successfully ' + targetState);});
            }
            //console.log('setSate ' + audioContext.state + ' alarm ' + container.dataset.alarm);
          });

          var audioContext_toggle = (function (event) {
            var container = document.getElementById('$id').parentNode;
            //console.log('audioContext_toggle  ' + audioContext.state);
            if (container.dataset.alarm != 'active') {
              audioContext_setSate('active');
              beep(200);
            } else {
              audioContext_setSate('inactive');
            }
          });

          var audioContext_onload = (function (event) {
            var m = document.cookie.match('(^|;)\\s*$audio_alarm_cookie\\s*=\\s*(\[^;\]+)');
            var cookieValue = (m ? m.pop() : 'inactive');

            console.log('audioContext_onload ' + audioContext.state + ' cookie ' + cookieValue);
            //
            // When the current state is 'running' the behavior seems
            // cross browser uniform, we can set it to the state we got
            // from the cookie.
            //
            if (audioContext.state == 'running') {
              audioContext_setSate(cookieValue);
            } else {
              //
              // FireFox can switch to "active" after reload, while
              // this does not work on Chrome and friends.
              //
              if (navigator.userAgent.toLowerCase().indexOf('firefox') > -1) {
                audioContext_setSate(cookieValue);
              } else {
                audioContext_setSate('inactive');
              }
            }
          });

          document.getElementById('$id').parentNode.addEventListener('click', audioContext_toggle);
          window.addEventListener('load', audioContext_onload);
        }]

        if {[ns_conn isconnected]} {
          set alarmState [ns_getcookie $audio_alarm_cookie "inactive"]
          set glypphIcon [expr {$alarmState eq "inactive" ? "glyphicon-volume-off":"glyphicon-volume-up"}]
        } else {
          set alarmState "inactive"
          set glypphIcon "glyphicon-volume-off"
        }
        #ns_log notice "C=$alarmState"

        return [subst {
          <div data-alarm='$alarmState' data-alarmseconds='\[$audio_alarm_times\]'>
          <span class='glyphicon $glypphIcon'></span>
          <div style='display: inline-block;' id='$id'></div>
          </div>
        }]
      } else {
        return [subst {
          <div style='display: inline-block;' id='$id'></div>
        }]
      }
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
    #   - question_count
    #   - question_property
    #   - add_seeds
    #   - total_minutes
    #   - total_points
    #   - total_minutes_for_exam
    #   - exam_target_time
    #
    :public method goto_page {obj:object position} {
      #
      # Set the position (test item number) of the workflow
      # (exam). This sets the question number shown to the user.
      #
      $obj set_property position $position
    }

    :public method more_ahead {{-position ""} obj:object} {
      #
      # Return true, when this is for the current user not the last
      # question.
      #
      if {$position eq ""} {
        set position [$obj property position]
      }
      set questions [dict get [$obj instance_attributes] question]
      return [expr {$position + 1 < [:question_count $obj]}]
    }

    :method load_question_objs {obj:object names} {
      #
      # Load the question objects for the provided question names and
      # return the question objs.
      #
      set questions [lmap ref $names {
        if {![string match "*/*" $ref]} {
          set ref [[$obj parent_id] name]/$ref
        }
        set ref
      }]
      set questionNames [join $questions |]
      set questionForms [::[$obj package_id] instantiate_forms \
                             -default_lang [$obj lang] \
                             -forms $questionNames]

      #ns_log notice "load_question_objs called with $obj $names -> $questionForms"
      return $questionForms
    }

    :method current_question_name {obj:object} {
      set questions [dict get [$obj instance_attributes] question]
      return [lindex [dict get [$obj instance_attributes] question] [$obj property position]]
    }

    :public method current_question_obj {obj:object} {
      #
      # Load the current question obj based on the current question
      # name.
      #
      return [:load_question_objs $obj [:current_question_name $obj]]
    }

    :public method shuffled_index {{-shuffle_id:integer -1} obj:object position} {
      #
      # Return the shuffled index position, in case shuffling is turned on.
      #
      if {$shuffle_id > -1} {
        set form_objs [:question_objs $obj]
        set shuffled [::xowiki::randomized_indices -seed $shuffle_id [llength $form_objs]]
        set position [lindex $shuffled $position]
      }
      return $position
    }

    :public method question_objs {{-shuffle_id:integer -1} obj:object} {
      #
      # For the provided assessment object, return the question
      # objects in the right order, depending on the shuffle_id.
      #
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
      #
      # Return the names of the questions of an assessment.
      #
      return [$obj property question]
    }

    :public method question_count {obj:object} {
      #
      # Return the number questions in an exam. It is either the
      # number of defined questions, or it might be restricted by the
      # max_items (if specified).
      #
      set nr_questions [llength [$obj property question]]
      set max_items [$obj property max_items ""]
      if {$max_items ne ""} {
        if {$max_items < $nr_questions} {
          set nr_questions $max_items
        }
      }
      return $nr_questions
    }

    :public method add_seeds {-obj:object -seed:integer -number:integer} {
      #
      # Add property "seed" to the provided object, consisting of a
      # list of the specified number of random values starting with a
      # base seed. This can be used to use e.g. per user different
      # random seeds depending on the position of an item.
      #
      expr {srand($seed * [clock microseconds])}
      set seeds {}
      for {set i 0} {$i < $number} {incr i} {
        lappend seeds [expr {int(rand() * $seed * [clock microseconds])}]
      }
      $obj set_property -new 1 seeds $seeds
    }

    :public method nth_question_obj {obj:object position:integer} {
      #
      # Return the nth question object of an assessment (based on
      # position).
      #
      :assert_assessment $obj
      set questions [dict get [$obj instance_attributes] question]
      set result [:load_question_objs $obj [lindex $questions $position]]
      return $result
    }

    :public method disallow_paste {form_obj:object} {
      #
      # This function changes the form_constraints of the provided
      # form object by adding "paste=false" properties to textarea or
      # text_fields entries.
      #
      set fc {}
      foreach e [$form_obj property form_constraints] {
        if {[regexp {^[^:]+_:(textarea|text_fields)} $e]} {
          #ns_log notice "======= turn paste off"
          append e , paste=false
        }
        lappend fc $e
      }
      $form_obj set_property form_constraints $fc
    }

    :method add_to_fc {-fc:required -position -minutes -points} {
      return [lmap c $fc {
        if {[regexp {^[^:]+_:} $c]} {
          if {[info exists position]} {
            append c ,test_item_in_position=$position
          }
          if {[info exists minutes]} {
            append c ,test_item_minutes=$minutes
          }
          if {[info exists points]} {
            append c ,test_item_points=$points
          }
          #ns_log notice "APPEND $c"
        }
        set c
      }]
    }

    :method question_info {
      {-numbers ""}
      {-with_title:switch false}
      {-with_minutes:switch false}
      {-with_points:switch false}
      {-titleless_form:switch false}
      {-obj:object}
      form_objs
    } {
      set full_form {}
      set full_fc {}
      set full_disabled_fc {}
      set title_infos {}
      set position 0
      set randomizationOk 1
      set autoGrade 1
      foreach form_obj $form_objs number $numbers {
        set form_obj [::xowf::test_item::renaming_form_loader rename_attributes $form_obj]
        set form_title [$form_obj title]
        set minutes [:question_property $form_obj minutes]
        set points [:question_property $form_obj points]
        if {$points eq ""} {
          ns_log notice "[$form_obj name]: NO POINTS, default to minutes $minutes"
          set points $minutes
        }
        set time_budget [$obj property time_budget]
        ns_log notice "[$form_obj name]: TIME BUDGET '$time_budget'"
        if {$time_budget ni {"" 100}} {
          set minutes [expr {$time_budget*$minutes/100.0}]
          ns_log notice "[$form_obj name]: TIME BUDGET '$time_budget' -> minutes set to $minutes"
          ns_log notice "[$form_obj name]: [$obj instance_attributes]"
        }
        set mapping {show_points with_points show_minutes with_minutes}
        foreach property {show_points show_minutes} {
          if {[$obj property $property] ne ""} {
            set [dict get $mapping $property] [$obj property $property]
            ns_log notice "[$form_obj name]: override flag via exam setting: '$property' -> [$obj property $property]"
          }
        }
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
        if {$with_points} {
          append title " - [:points_string $form_obj]"
        }

        if {!$titleless_form} {
          append full_form \
              "<h3>$title</h3>\n"
        }
        #
        # Resolve links in the context of the resolve_object
        #
        append full_form \
            [$obj substitute_markup \
                 -context_obj $form_obj \
                 [$form_obj property form]]

        #append full_form \
        #    [$form_obj substitute_markup -context_obj $form_obj [$form_obj property form]]

        #ns_log notice "FORM=$full_form"

        lappend title_infos [list full_title $title \
                                 title $form_title \
                                 minutes $minutes \
                                 points $points \
                                 number $number]
        lappend full_fc [:add_to_fc \
                             -fc [$form_obj property form_constraints] \
                             -minutes $minutes \
                             -points $points \
                             -position $position]
        lappend full_disabled_fc [:add_to_fc \
                                      -fc [$form_obj property disabled_form_constraints] \
                                      -minutes $minutes \
                                      -points $points \
                                      -position $position]
        incr position

        set formAttributes [$form_obj instance_attributes]
        if {[dict exists $formAttributes question]} {
          #
          # Check autograding and randomization for exam.
          #
          set qd [dict get [$form_obj instance_attributes] question]
          #
          # No question should have shuffle "always".
          #
          if {[dict exists $qd question.shuffle]
              && [dict get $qd question.shuffle] eq "always"} {
            #ns_log notice "FOUND shuffle $qd"
            set randomizationOk 0
          }
          #
          # For autoGrade, we assume currently to have either a grading,
          # or a question, where every alternative is exactly provided.
          #
          if {[dict exists $qd question.grading]} {
            #
            # autograde ok on the question level
            #
          } elseif {[dict exists $formAttributes auto_correct] && [dict get $formAttributes auto_correct]} {
            #
            # autograde ok on the form level
            #
            # Check, if the correct_when specification of a short text
            # question is suited for autocorrection. On the longer
            # range, this function should be moved to a different
            # place.
            #
            if {[dict exists $formAttributes item_type] && [dict get $formAttributes item_type] eq "ShortText"} {
              set dict [lindex [fc_to_dict [dict get $formAttributes form_constraints]] 1]
              foreach a [dict get $dict answer] {
                set op ""
                regexp {^(\S+)\s} $a . op
                if {$op ni {eq lt le gt ge btwn AND}} {
                  ns_log notice "question_info: not suited for autoGrade: '$a'"
                  set autoGrade 0
                  break
                }
                if {$op eq "AND"} {
                  foreach c [lrange $a 1 end] {
                    set op ""
                    regexp {^(\S+)\s} $c . op
                    if {$op ni {eq lt le gt ge btwn}} {
                      ns_log notice "question_info: not suited for autoGrade: AND clause '$c'"
                      set autoGrade 0
                      break
                    }
                  }
                }
              }
            }
          } elseif [dict exists $qd question.interaction question.interaction.answer] {
            set answer [dict get $qd question.interaction question.interaction.answer]
            foreach k [dict keys $answer] {
              if {![dict exists $answer $k $k.correct]} {
                set autoGrade 0
              }
            }
          } else {
            set autoGrade 0
          }
          ns_log notice "question_info [$form_obj name] [$form_obj title] autoGrade $autoGrade"
        }
      }

      return [list \
                  form $full_form \
                  title_infos $title_infos \
                  form_constraints [join [lsort -unique $full_fc] \n] \
                  disabled_form_constraints [join [lsort -unique $full_disabled_fc] \n] \
                  randomization_for_exam $randomizationOk \
                  autograde $autoGrade \
                  question_objs $form_objs]
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
        set pretty_label [expr {$minutes eq "1" ? [_ xowiki.minute] : [_ xowiki.minutes]}]
        set minutes "($minutes $pretty_label)"
      }
    }

    :public method points_string {form_obj:object} {
      #
      # Get an attribute of the original question
      #
      set points [:question_property $form_obj points]
      if {$points eq ""} {
        # just for legacy, questions without points
        set points [:question_property $form_obj minutes]
      }
      if {$points ne ""} {
        set pretty_label [expr {$points eq "1" ? [_ xowf.Point] : [_ xowf.Points]}]
        set minutes "($points $pretty_label)"
      }
    }

    :public method combined_question_form {
      {-with_numbers:switch false}
      {-with_title:switch false}
      {-with_minutes:switch false}
      {-with_points:switch false}
      {-user_specific:switch false}
      {-shuffle_id:integer -1}
      obj:object
    } {
      #
      # For the provided assessment, return a combined question_form
      # as a single (combined) form, containing the content of all
      # question forms. The result is a dict, containing also title
      # information etc. depending on the provided parameters.
      #
      # @param shuffle_id used only for selecting form_objs
      #
      set form_objs [:question_objs -shuffle_id $shuffle_id $obj]
      if {$user_specific} {
        set max_items [$obj property max_items ""]
        if {$max_items ne ""} {
          set form_objs [lrange $form_objs 0 $max_items-1]
        }
      }
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
                  -with_points=$with_points \
                  {*}$extra_flags \
                  -obj $obj \
                  $form_objs]
    }

    :public method describe_form {form_obj} {
      #
      # Call for every form field of the form_obj the "describe"
      # method and return these infos in a form of a list.
      #
      # @result list of dicts describing the form fields.
      #
      set form_fields [$form_obj create_form_fields_from_form_constraints \
                           -lookup \
                           [lsort -unique [$form_obj property form_constraints]]]
      return [lmap form_field $form_fields {
        $form_field describe
      }]
    }



    :method total {-property:required title_infos} {
      set total 0
      foreach title_info $title_infos {
          if {[dict exists $title_info $property]} {
            set value [dict get $title_info  $property]
            if {$value eq ""} {
              ns_log notice "missing $property in '$title_info'"
              set value 0
            }
            set total [expr {$total + $value}]
          }
        }
      return $total
    }

    :method title_infos {{-max_items:integer,0..1 ""} form_info} {
      #
      # When max_items is nonempty, return the title infos of all
      # items. Otherwise, just the specified number of items.
      #
      set title_infos [dict get $form_info title_infos]
      if {$max_items ne ""} {
        set title_infos [lrange $title_infos 0 $max_items-1]
      }
      return $title_infos
    }

    :public method total_minutes {{-max_items:integer,0..1 ""} form_info} {
      #
      # Compute the duration of an exam based on the form_info dict.
      #
      return [:total -property minutes [:title_infos -max_items $max_items $form_info]]
    }

    :public method total_points {{-max_items:integer,0..1 ""} form_info} {
      #
      # Compute the maximal achievable points of an exam based on the
      # form_info dict.
      #
      return [:total -property points [:title_infos -max_items $max_items $form_info]]
    }

    :public method total_minutes_for_exam {-manager:object} {
      #
      # Compute the total time of an exam, based on the minutes
      # provided by the single questions.
      #
      set max_items [$manager property max_items ""]
      set combined_form_info [:combined_question_form $manager]
      set total_minutes [:total_minutes \
                             -max_items $max_items \
                             $combined_form_info]
    }

    :public method exam_target_time {-manager:object -base_time} {
      #
      # Calculate the exam target time (finishing time) based on the
      # duration of the exam plus the provided base_time (which is in
      # the format returned by SQL)
      #
      # @param manager exam workflow
      # @param base_time time in SQL format
      #
      set total_minutes [:total_minutes_for_exam -manager $manager]

      # Use "try" for backward compatibility, versions before
      # factional seconds. TODO: remove me.
      try {
        set base_clock [clock scan [::xo::db::tcl_date $base_time tz secfrac]]
        if {[string length $secfrac] > 3} {
          set secfrac [string range $secfrac 0 2]
        }
      } on error {errorMsg} {
        set base_clock [clock scan [::xo::db::tcl_date $base_time tz]]
        set secfrac 0
      }
      set target_time [clock format [expr {int($base_clock + $total_minutes * 60)}] \
                           -format %Y-%m-%dT%H:%M:%S]
      ns_log notice "exam_target_time $base_time base clock $base_clock + total_minutes $total_minutes = ${target_time}.$secfrac"
      return ${target_time}.$secfrac
    }

    :public method current_question_form {
      {-with_numbers:switch false}
      {-with_title:switch false}
      obj:object
    } {
      #
      # Return the current form object of the provided assessment.
      #
      return [:nth_question_form -with_numbers=$with_numbers -with_title=$with_title $obj]
    }

    :public method nth_question_form {
      {-position:integer}
      {-item_nr:integer}
      {-with_numbers:switch false}
      {-with_title:switch false}
      {-titleless_form:switch false}
      {-with_minutes:switch false}
      obj:object
    } {
      #
      # Return the question_info of the nth form (question) of the
      # assessment.  The information added to the title can be
      # optionally included as expressed by the non-positional
      # parameters.
      #
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
                  -titleless_form=$titleless_form \
                  -with_minutes=$with_minutes \
                  {*}$extra_flags \
                  -obj $obj \
                  $form_objs]
    }

    :public method current_question_number {obj:object} {
      #
      # Translate the position of an object into its question number
      # (as e.g. used by current_question_title).
      #
      return [expr {[$obj property position] + 1}]
    }

    :public method current_question_title {{-with_numbers:switch false} obj:object} {
      #
      # In case, with_numbers is provided, return a internationalized
      # title for the question, such as "Question 1".
      #
      if {$with_numbers} {
        return "#xowf.question# [:current_question_number $obj]"
      }
    }
  }

  Question_manager create question_manager

}

namespace eval ::xowiki::formfield {
  #
  # The following "describe" function should be moved to a more
  # generic place, probably to the formfield procs in xowiki (to the
  # relevant formfield classes). It is just kept here for the time
  # being, until we have a better understanding what's needed in
  # detail.
  #
  ::xowiki::formfield::FormField instproc describe {} {
    set d ""
    #
    # The dict keys of the result should correspond as far as possible
    # to message keys to ease multi-language communication.
    #
    switch [:info class] {
      ::xowiki::formfield::checkbox {
        # mc interaction
        #
        # The factual (displayed) answer is in ${:answer}, but we want
        # to see the list of possibilities, so use the data from the
        # original spec.
        #
        foreach s [split ${:spec} ,] {
          if {[regexp {^answer=(.*)$} $s . answer]} {
            break
          }
        }
        dict set d choice_options [llength ${answer}]
        dict set d nrcorrect [llength [lsearch -exact -all ${answer} t]]
        dict set d shuffle ${:shuffle_kind}
        if {[info exists :show_max]} {
          dict set d show_max ${:show_max}
        }
        #dict set d all [:serialize]
        #ns_log warning "describe: $d"
      }
      ::xowiki::formfield::text_fields {
        # short text interaction
        #
        # The factual (displayed) answer is in ${:answer}, but we want
        # to see the list of possibilities, so use the data from the
        # original spec (here in $options)
        #
        foreach s [split ${:spec} ,] {
          ns_log warning "s=$s"
          if {[regexp {^options=(.*)$} $s . options]} {
            break
          }
        }
        dict set d all ${:spec}
        dict set d sub_questions [llength ${options}]
        dict set d shuffle ${:shuffle_kind}
        #ns_log warning "describe: $d"
      }
      default {
        ns_log warning "describe: class [:info class] not handled"
      }
    }
    return $d
  }
}

namespace eval ::xowf::test_item {
  #
  # Define handling of form-field "td_pretty_value".  This class is
  # used as a mixin class in the result table renderer.
  #
  ::xotcl::Class create ::xowf::test_item::td_pretty_value \
      -superclass ::xowiki::formfield::FormField

  ::xowf::test_item::td_pretty_value instproc pretty_value {value} {
    #
    # In case the form_field_class has a "td_pretty_value" defined,
    # return its value. This is e.g. useful, when we have shuffled
    # fields, which are different per user. When we initiate the field
    # we would see just see the subset of fields for this user, but in
    # the tabular view, it is required to see in one columns all fields.
    #
    #ns_log notice "${:name} pretty_value [:info precedence] // [:istype ::xowiki::formfield::text_fields]"
    if {[:procsearch td_pretty_value] ne ""} {
      set v [:td_pretty_value $value]
    } else {
      set v [next]
    }
    return $v
  }
}

namespace eval ::xowf::test_item::grading {
  nx::Class create Grading {
    :property {percentage_boundaries {50.0 60.0 70.0 80.0}}

    :method calc_grade {-points -achieved_points} {
      #
      # Return a numeric grade based on achieved_points dict and
      # percentage_mapping. On invalid data, return 0.
      #
      #     achieved_points:    {achievedPoints 4.0 achievablePoints 4 totalPoints 4}
      #     percentage_mapping: {50.0 60.0 70.0 80.0}
      #
      if {[dict exists $achieved_points totalPoints] && [dict get $achieved_points totalPoints] > 0} {
        set percentage [format %.2f [expr {
                                           ($points*100/
                                            [dict get $achieved_points totalPoints]) + 0.00001
                                         }]]
        set grade 1
        set gradePos 0
        foreach boundary ${:percentage_boundaries} {
          if {$percentage < $boundary} {
            set grade [expr {5-$gradePos}]
            break
          }
          incr gradePos
        }
      } else {
        set grade 0
      }
      return $grade
    }

    :public method print {-achieved_points:required} {
      #
      # Return the achievedPoints when available (or empty).
      #
      if {[dict exists $achieved_points achievedPoints]} {
        return [dict get $achieved_points achievedPoints]
      }
    }
  }

  Grading create ::xowf::test_item::grading::wi1 -percentage_boundaries {50.0 60.0 70.0 80.0} {

    :public object method print {-achieved_points:required} {
      if {[dict exists $achieved_points achievedPoints]} {
        set totalPoints    [format %.2f [dict get $achieved_points totalPoints]]
        set achievedPoints [format %.2f [dict get $achieved_points achievedPoints]]
        set rounded        [dict get $achieved_points achievedPointsRounded]
        set percentage     [format %.2f [expr {$totalPoints > 0 ? ($achievedPoints*100.0/$totalPoints) : 0}]]
        set grade          [:grade -achieved_points $achieved_points]
        set panelHTML      [_ xowf.panel_achievied_points_wi1]
        return [list panel $panelHTML csv [subst {$achievedPoints\t$rounded\t$percentage%\t$grade}]]
      }
    }
    :public object method grade {-achieved_points:required} {
      if {[dict exists $achieved_points achievedPoints]} {
        set achieved [dict get $achieved_points achievedPoints]
        set rounded [dict get $achieved_points achievedPointsRounded]
        return [:calc_grade -points $rounded -achieved_points $achieved_points]
      }
    }
  }

  Grading create ::xowf::test_item::grading::wi1_noround -percentage_boundaries {50.0 60.0 70.0 80.0} {

    :public object method print {-achieved_points:required} {
      if {[dict exists $achieved_points achievedPoints]} {
        set totalPoints    [format %.2f [dict get $achieved_points totalPoints]]
        set achievedPoints [format %.2f [dict get $achieved_points achievedPoints]]
        set percentage     [format %.2f [expr {$totalPoints > 0 ? ($achievedPoints*100.0/$totalPoints) : 0}]]
        set grade          [:grade -achieved_points $achieved_points]
        set panelHTML      [_ xowf.panel_achievied_points_wi1_noround]
        return [list panel $panelHTML csv [subst {$achievedPoints\t$percentage%\t$grade}]]
      }
    }
    :public object method grade {-achieved_points:required} {
      if {[dict exists $achieved_points achievedPoints]} {
        set achieved [format %.2f [dict get $achieved_points achievedPoints]]
        #ns_log notice "XXXX $achieved_points -> [list calc_grade -points $achieved -achieved_points $achieved_points]"
        return [:calc_grade -points $achieved -achieved_points $achieved_points]
      }
    }
  }

}

namespace eval ::xowiki {
  ::xowiki::MenuBar instproc config=test-items {
    {-bind_vars {}}
    -current_page:required
    -package_id:required
    -folder_link:required
    -return_url
  } {
    :config=default \
        -bind_vars $bind_vars \
        -current_page $current_page \
        -package_id $package_id \
        -folder_link $folder_link \
        -return_url $return_url

    return {
      {clear_menu -menu New}

      {entry -name New.Item.TextInteraction -form en:edit-interaction.wf -query p.item_type=Text}
      {entry -name New.Item.ShortTextInteraction -form en:edit-interaction.wf -query p.item_type=ShortText}
      {entry -name New.Item.SCInteraction -form en:edit-interaction.wf -query p.item_type=SC}
      {entry -name New.Item.MCInteraction -form en:edit-interaction.wf -query p.item_type=MC}
      {entry -name New.Item.ReorderInteraction -form en:edit-interaction.wf -query p.item_type=Reorder}
      {entry -name New.Item.UploadInteraction -form en:edit-interaction.wf -query p.item_type=Upload}

      {entry -name New.App.OnlineExam -form en:online-exam.wf -disabled true}
      {entry -name New.App.InclassQuiz -form en:inclass-quiz.wf -disabled true}
      {entry -name New.App.InclassExam -form en:inclass-exam.wf}
    }
  }

  ::xowiki::MenuBar instproc config=test-item-exams {
    {-bind_vars {}}
    -current_page:required
    -package_id:required
    -folder_link:required
    -return_url
  } {
    :config=default \
        -bind_vars $bind_vars \
        -current_page $current_page \
        -package_id $package_id \
        -folder_link $folder_link \
        -return_url $return_url

    # {entry -name New.Item.ExamFolder -form en:Folder.form -query p.configure=exam_folder}

    return {
      {clear_menu -menu New}
      {entry -name New.Item.ExamFolder -form en:folder.form -query p.source=ExamFolder&publish_status=ready}
    }
  }

}

# namespace eval ::xowf {
#   ::xowf::WorkflowPage instproc configure_page=exam_folder {name} {
#     ns_log notice "configure_page=exam_folder called on [self] ${:name} ($name) [:info precedence] ia <${:instance_attributes}> "
#     ns_log notice [:serialize]
#     dict set :instance_attributes extra_menu_entries {{config -use test-items}}
#   }
# }


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
  # Add policy rules as used in two demo workflows. We are permissive
  # for student actions and require admin right for teacher activities.
  #
  test-item-policy-publish contains {
    Class create FormPage -array set require_permission {
      answer         {{item_id read}}
      view-my-exam   {{item_id read}}
      proctor-answer {{item_id read}}
      proctor        {{item_id read}}
      poll           admin
      send-participant-message admin
      edit           admin
      print-answers  admin
      print-answer-table admin
      print-participants admin
      delete         admin
      qrcode         admin
      make-live-revision admin
    }
  }
  test-item-policy-answer contains {
    Class create FormPage -array set require_permission {
      poll            {{item_id read}}
      edit            {{item_id read}}
      message-poll    {{item_id read}}
      message-dismiss {{item_id read}}
    }
  }

  #ns_log notice [::xowf::test_item::test-item-policy1 serialize]
  #ns_log notice ===================================

}
::xo::library source_dependent


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    eval: (setq tcl-type-alist (remove* "method" tcl-type-alist :test 'equal :key 'car))
#    indent-tabs-mode: nil
# End:
