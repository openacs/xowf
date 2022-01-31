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

  TestItemField instproc twocol_layout {} {
    return [expr {[${:parent_field} get_named_sub_component_value -default 0 twocol]
                  ? "col-sm-6" : "col-xs-12"}]
  }

  TestItemField instproc form_markup {
    -interaction
    -intro_text
    -body
  } {
    set twocol [:twocol_layout]
    return [string cat \
                "<form>\n" \
                "<div class='${interaction}_interaction row row-$twocol'>\n" \
                "<div class='question_text first-column $twocol'>$intro_text</div>\n" \
                "<div class='second-column $twocol'>$body</div>\n" \
                "</div>\n" \
                "</form>\n"]
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

    Wrapper for composite test items, containing specification for
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
      section -
      case {
        set interaction_class test_section
        set options ""
        set auto_correct false
        set can_shuffle false
      }
      pool {
        set interaction_class pool_question
        set options ""
        set auto_correct false
        set can_shuffle false
      }
      default {error "unknown question type: ${:question_type}"}
    }
    #:log test_item-auto_correct=$auto_correct

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
      set grading_dict {_name grading _type select}
      dict set grading_dict default [lindex ${:grading} 0]
      dict set grading_dict options {}
      foreach o ${:grading} {
        dict lappend grading_dict options [list $o $o]
      }
      dict set grading_dict form_item_wrapper_CSSclass form-inline
      dict set grading_dict label #xowf.Grading-Scheme#
      dict set grading_dict required true
      set gradingSpec [list [:dict_to_spec -aspair $grading_dict]]
    } else {
      set gradingSpec ""
    }

    if {$can_shuffle} {
      set shuffle_dict {_name shuffle _type radio}
      dict set shuffle_dict horizontal true
      dict set shuffle_dict form_item_wrapper_CSSclass form-inline
      dict set shuffle_dict default peruser
      dict set shuffle_dict label #xowf.Shuffle#
      dict set shuffle_dict options \
          "{#xowf.shuffle_none# none} {#xowf.shuffle_peruser# peruser} {#xowf.shuffle_always# always}"
      set shuffleSpec [subst {
        [list [:dict_to_spec -aspair $shuffle_dict]]
        {show_max {number,form_item_wrapper_CSSclass=form-inline,min=1,label=#xowf.show_max#}}
      }]
    } else {
      set shuffleSpec ""
    }

    #
    # Default twocol spec
    #
    set twocolDict {
      _name twocol
      _type boolean_checkbox
      label #xowf.Twocol_layout#
      default f
      form_item_wrapper_CSSclass form-inline
    }

    if {${:question_type} in {section case}} {
      #
      # Don't show "minutes" and "points" in the full composite test
      # item form but still define it, such we can compute and update
      # it in convert_to_internal with little effort, since all
      # "question" content is built based on included form fields.
      #
      set pointsSpec {
        {minutes hidden}
        {points hidden}
      }
      set typeSpecificComponentSpec {
        {show_minutes boolean_checkbox,form_item_wrapper_CSSclass=form-inline,default=t,label=#xowf.Composite_Show_minutes#}
        {show_points boolean_checkbox,form_item_wrapper_CSSclass=form-inline,default=f,label=#xowf.Composite_Show_points#}
        {show_title boolean_checkbox,form_item_wrapper_CSSclass=form-inline,default=f,label=#xowf.Composite_Show_title#}
      }
      #
      # Things different between "section" and "case".
      #
      switch ${:question_type} {
        "section" {}
        "case" {
          dict set twocolDict default t
        }
        default {error "this can't happen"}
      }
    } else {
      set pointsSpec {
        {minutes number,form_item_wrapper_CSSclass=form-inline,min=1,default=2,label=#xowf.Minutes#}
        {points number,form_item_wrapper_CSSclass=form-inline,min=0.0,step=0.1,label=#xowf.Points#}
      }
    }
    if {${:question_type} eq "pool"} {
      set twocolDict ""
    }

    :create_components [subst {
      $pointsSpec
      $shuffleSpec
      $gradingSpec
      $typeSpecificComponentSpec
      [list [:dict_to_spec -aspair $twocolDict]]
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
  mc_interaction set closed_question_type true
  #mc_interaction set item_type MC  ;# just used for reverse lookup in pool questions,
  #                                    where the old MC questions are not supported

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
    :create_components [subst {
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
        lappend if_fc "feedback_answer_incorrect=[::xowiki::formfield::FormField fc_encode $value(feedback_incorrect)]"
      }
      if {[llength $if_fc] > 0} {
        lappend fc [list $input_field_name:checkbox,[join $if_fc ,]]
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
    ${:object} set_property -new 1 auto_correct [[self class] set closed_question_type]
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
  text_interaction set closed_question_type false
  text_interaction set item_type Text

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
      {attachments {[:attachments_widget ${:nr_attachments}]}}
      [:correct_when_spec]
    }]
    set :__initialized 1
  }

  text_interaction instproc convert_to_internal {} {
    next

    set intro_text [:get_named_sub_component_value text]
    append intro_text [:text_attachments]

    set fc_dict {
      _name answer
      _type textarea
      disabled_as_div 1
      label #xowf.answer#
      autosave true
    }
    dict set fc_dict rows [:get_named_sub_component_value lines]
    dict set fc_dict cols [:get_named_sub_component_value columns]

    if {${:auto_correct}} {
      dict set fc_dict correct_when [:comp_correct_when_from_value [:get_named_sub_component_value correct_when]]
    }

    set form [:form_markup -interaction text -intro_text $intro_text -body @answer@]
    lappend fc \
        @categories:off @cr_fields:hidden \
        [:dict_to_spec $fc_dict]

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
  short_text_interaction set item_type ShortText
  short_text_interaction set closed_question_type false

  short_text_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]
    ns_log notice "[self] [:info class] auto_correct=${:auto_correct}"

    if {[acs_user::site_wide_admin_p]} {
      set substvalues "{substvalues {textarea,label=Substitution Values}}"
    } else {
      set substvalues ""
    }
    #{substvalues {textarea,label=Substitution Values}}
    :create_components [subst {
      {text  {$widget,height=100px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {attachments {[:attachments_widget ${:nr_attachments}]}}
      {answer {short_text_field,repeat=1..${:nr},label=}}
      $substvalues
    }]
    set :__initialized 1
  }

  short_text_interaction instproc convert_to_internal {} {
    next

    set intro_text    [:get_named_sub_component_value text]
    append intro_text [:text_attachments]
    set answerFields  [:get_named_sub_component_value -from_repeat answer]
    if {[acs_user::site_wide_admin_p]} {
      set substvalues [:get_named_sub_component_value substvalues]
    } else {
      set substvalues ""
    }
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

    set fc_dict { _name answer _type text_fields disabled_as_div 1 label ""}
    dict set fc_dict shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    dict set fc_dict show_max [${:parent_field} get_named_sub_component_value show_max]
    dict set fc_dict options $options
    dict set fc_dict answer $answer
    dict set fc_dict descriptions $solution
    dict set fc_dict render_hints $render_hints
    dict set fc_dict substvalues $substvalues

    set form [:form_markup -interaction short_text -intro_text $intro_text -body @answer@]

    set fc {}
    lappend fc \
        [:dict_to_spec $fc_dict] \
        @categories:off @cr_fields:hidden

    #ns_log notice "short_text_interaction $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
    ${:object} set_property -new 1 substvalues $substvalues
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
    #
    # The options field is made "required" to avoid deselecting.
    #
    set textEntryConfigSpec [subst {
      {options {radio,horizontal=true,form_item_wrapper_CSSclass=form-inline,options=$render_hints,value=multiple_words,required,label=#xowf.answer#}}
      {lines {number,form_item_wrapper_CSSclass=form-inline,value=1,min=1,label=#xowf.lines#}}
    }]

    :create_components [subst {
      {text {$widget,height=100px,label=#xowf.sub_question#,plugins=OacsFs}}
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
  reorder_interaction set item_type {Reorder}
  reorder_interaction set closed_question_type true

  reorder_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} return
    #
    # Create component structure.
    #
    set widget [test_item set richtextWidget]

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

    set fc_dict {_name answer _type reorder_box}
    dict set fc_dict disabled_as_div 1
    dict set fc_dict label ""
    dict set fc_dict options $options
    dict set fc_dict answer $answer
    dict set fc_dict grading [${:parent_field} get_named_sub_component_value grading]

    set form [:form_markup -interaction reorder -intro_text $intro_text -body @answer@]
    set fc {}
    lappend fc \
        [:dict_to_spec $fc_dict] \
        @categories:off @cr_fields:hidden

    #ns_log notice "reorder_interaction $form\n$fc"
    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct ${:auto_correct}
    ${:object} set_property -new 1 has_solution false
    #ns_log notice "${:name} FINAL FC $fc"
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
  mc_interaction2 set item_type {SC MC}
  mc_interaction2 set closed_question_type true

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

    dict set fc_dict _name answer
    dict set fc_dict _type [expr {${:multiple} ? "checkbox" : "radio"}]
    dict set fc_dict richtext 1
    dict set fc_dict answer $correct
    dict set fc_dict options $options
    dict set fc_dict descriptions $solution
    dict set fc_dict shuffle_kind [${:parent_field} get_named_sub_component_value shuffle]
    dict set fc_dict grading [${:parent_field} get_named_sub_component_value grading]
    dict set fc_dict show_max [${:parent_field} get_named_sub_component_value show_max]

    set interaction [expr {${:multiple} ? "mc" : "sc"}]
    set form [:form_markup -interaction $interaction -intro_text $intro_text -body @answer@]
    set fc {}
    lappend fc \
        [:dict_to_spec $fc_dict] \
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
    :create_components [subst {
      {text    {$widget,height=50px,label=#xowf.choice_option#,plugins=OacsFs}}
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
  upload_interaction set closed_question_type false
  upload_interaction set item_type Upload

  upload_interaction instproc initialize {} {
    if {${:__state} ne "after_specs"} {
      return
    }
    set widget [test_item set richtextWidget]
    :create_components [subst {
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

    set file_dict {_name answer _type file}
    if {$max_nr_submission_files > 1} {
      dict set file_dict repeat 1..$max_nr_submission_files
      dict set file_dict repeat_add_label #xowiki.form-repeatable-add-another-file#
      dict set file_dict label #xowf.online-exam-submission_files#
    } else {
      dict set file_dict label #xowf.online-exam-submission_file#
    }

    append intro_text [:text_attachments]
    set form [:form_markup -interaction upload -intro_text $intro_text -body @answer@]
    lappend fc \
        @categories:off @cr_fields:hidden \
        [:dict_to_spec $file_dict]

    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
    ${:object} set_property -new 1 auto_correct [[self class] set closed_question_type]
    ${:object} set_property -new 1 has_solution false
  }
}


namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::test_section
  #
  ###########################################################

  Class create test_section -superclass {TestItemField} -parameter {
    {multiple true}
    {form en:edit-interaction.wf}
  }
  test_section set item_type Composite
  test_section set closed_question_type false

  test_section instproc initialize {} {

    if {${:__state} ne "after_specs"} {
      return
    }
    next
    set widget [test_item set richtextWidget]

    # We could exclude the "self" item (inclusion would lead to
    # infinite loops), but that is as well excluded, when no Composite
    # items are allowed.
    #
    #  set item_id [${:object} item_id]
    #  {selection {form_page,form=en:edit-interaction.wf,unless=_item_id=$item_id,multiple=true}}

    :create_components [subst {
      {text        {$widget,height=150px,label=#xowf.exercise-text#,plugins=OacsFs}}
      {selection   {form_page,form=en:edit-interaction.wf,unless=item_type=Composite|PoolQuestion,multiple=true,label=#xowf.question_selection#}}
    }]

    set :__initialized 1
  }

  test_section instproc pretty_value {v} {
    return [${:object} property form ""]
  }

  test_section instproc convert_to_internal {} {
    #
    # Build a complex form composed of the specified form pages names
    # contained in the value of this field.  The form-fields have to
    # be renamed. This affects the input field names in the form and
    # the form constraints.
    #
    set intro_text [:get_named_sub_component_value text]
    set selection [:get_named_sub_component_value selection]

    #
    # Load the forms specified via "selection".
    #
    set package_id [${:object} package_id]
    set formObjs [::$package_id instantiate_forms \
                      -forms [join [split $selection \n] |] \
                      -default_lang en]

    # foreach formObj $formObjs {
    #   set substvalues [$formObj property substvalues]
    #   if {$substvalues ne ""} {
    #     ns_log notice ".... [$formObj name] has substvalues $substvalues"
    #     set d [:QM percent_substitute_in_form \
    #                -obj ${:object} \
    #                -form_obj $formObj \
    #                -position $position \
    #                $html]
    #     $form_obj set_property form [dict get $d form]
    #     $form_obj set_property form_constraints [dict get $d form_constraints]
    #     $form_obj set_property disabled_form_constraints [dict get $d disabled_form_constraints]
    #   }
    # }

    #
    # Build a form with the usual numbering containing all the
    # formObjs and remove all form tags.
    #
    set number 0
    set numbers [lmap formObj $formObjs {incr number}]

    set option_dict {with_minutes t with_points f with_title f}
    foreach field {show_minutes show_points show_title} {
      set value [${:parent_field} get_named_sub_component_value -default "" $field]
      if {$value ne ""} {
        dict set option_dict $field $value
      }
    }
    set title_options [lmap kind {minutes points title} {
      if {![dict get $option_dict show_$kind]} {
        continue
      }
      set result "-with_$kind"
    }]
    set question_infos [:QM question_info \
                            -question_number_label "#xowf.subquestion#" \
                            {*}$title_options \
                            -numbers $numbers \
                            -no_position \
                            -obj ${:object} \
                            $formObjs]
    # ns_log notice "SELECTION question_info '$question_infos'"

    #
    # Build a single clean form based on the question infors,
    # containing all selected items.
    #
    set aggregatedForm [:QM aggregated_form \
                            -with_grading_box hidden \
                            $question_infos]
    set aggregatedFC [dict get $question_infos form_constraints]
    #ns_log notice "SELECTION aggregatedFC\n$aggregatedFC"

    #
    # The following regexps are dangerous (esp. on form
    # constraints). I think, we have already a better function for
    # this.
    #
    set names [regexp -inline -all {@([^@]+_)@} $aggregatedForm]
    foreach {. name} $names {
      regsub -all "@$name@" $aggregatedForm "@answer_$name@" aggregatedForm
      regsub -all ${name}: $aggregatedFC "answer_${name}:" aggregatedFC
    }

    ns_log notice "AGGREGATED FORM $aggregatedForm\nFC\n$aggregatedFC\n"

    #
    # Automatically compute the minutes and points of the composite
    # field and update the form field.
    #
    set total_minutes [:QM total_minutes $question_infos]
    set total_points  [:QM total_points $question_infos]

    [${:parent_field} get_named_sub_component minutes] value $total_minutes
    [${:parent_field} get_named_sub_component points] value $total_points

    set form [:form_markup -interaction composite -intro_text $intro_text -body $aggregatedForm]

    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $aggregatedFC
    set anon_instances true ;# TODO make me configurable
    ${:object} set_property -new 1 anon_instances $anon_instances
  }
}

namespace eval ::xowiki::formfield {
  ###########################################################
  #
  # ::xowiki::formfield::pool_question
  #
  ###########################################################

  Class create pool_question -superclass TestItemField -parameter {
  }
  pool_question set closed_question_type false ; # the replacement query might be or not autocorrection capable
  pool_question set item_type PoolQuestion

  pool_question set item_types {
      Composite
      MC
      Reorder
      SC
      ShortText
      Text
      Upload
  }
  pool_question proc all_item_types_selected {item_types} {
    #
    # Check, if all item types were selected
    #
    foreach item_type [pool_question set item_types] {
      if {$item_type ni $item_types} {
        return 0
      }
    }
    return 1
  }
  pool_question instproc initialize {} {
    if {${:__state} ne "after_specs"} {
      return
    }
    set item_types [pool_question set item_types]
    set item_type_options [lmap item_type $item_types {
      list #xowf.menu-New-Item-${item_type}Interaction# $item_type
    }]

    set current_folder_id [[${:object} parent_id] item_id]
    set parent_folder_id [::$current_folder_id parent_id]
    set fi [::xowiki::includelet::folders new -destroy_on_cleanup]
    set folder_objs [$fi collect_folders \
                         -package_id [${:object} package_id] \
                         -parent_id $parent_folder_id]
    set folder_options [list]
    lappend folder_options {*}[lmap folder_obj $folder_objs {
      if {[$folder_obj parent_id] ne $parent_folder_id} {
        continue
      }
      list [$folder_obj title] ../[$folder_obj name]
    }]

    set pool_dict {_name folder _type select}
    dict set pool_dict required true
    dict set pool_dict options $folder_options
    dict set pool_dict default ../[::$current_folder_id name]
    dict set pool_dict label #xowf.pool_question_folder#

    set item_dict {_name item_types _type checkbox}
    dict set item_dict options $item_type_options
    dict set item_dict default $item_types
    dict set item_dict label #xowf.pool_question_item_types#

    :create_components [subst {
      [list [:dict_to_spec -aspair $pool_dict]]
      [list [:dict_to_spec -aspair $item_dict]]
      {pattern {text,default=*,label=#xowf.pool_question_pattern#}}
    }]

    set :__initialized 1
  }

  pool_question instproc convert_to_internal {} {
    next
    set allowed_item_types [:get_named_sub_component_value item_types]

    set fc_dict {_name answer _type pool_question_placeholder}
    dict set fc_dict folder [:get_named_sub_component_value folder]
    dict set fc_dict pattern [:get_named_sub_component_value pattern]
    dict set fc_dict item_types $allowed_item_types

    set form "<form>@answer@</form>"
    lappend fc \
        @categories:off @cr_fields:hidden \
        [:dict_to_spec $fc_dict]

    ${:object} set_property -new 1 form $form
    ${:object} set_property -new 1 form_constraints $fc

    #
    # Turn on "auto_correct" when for every selected item_type, *all*
    # items are fully closed and therefore suited for
    # auto_correction. For example, for composite questions, this might
    # or might not be true (to handle this more aggressively, we would
    # have to iterate over all exercises of this question types and
    # check their detailed subcomponents).
    #
    set auto_correct 1
    foreach class [::xowiki::formfield::TestItemField info subclass -closure] {
      if {[$class exists item_type]} {
        foreach item_type [$class set item_type] {
          if {$item_type in $allowed_item_types && ![$class set closed_question_type]} {
            set auto_correct 0
            break
          }
        }
      }
    }
    #ns_log notice "... FINAL auto_correct $auto_correct (allowed $allowed_item_types)"
    ${:object} set_property -new 1 auto_correct $auto_correct
  }

  Class create pool_question_placeholder -superclass {TestItemField} -parameter {
    folder
    pattern
    item_types
  }

}



############################################################################
# Generic Assement interface
############################################################################

namespace eval ::xowf::test_item {

  # the fillowing is not yet ready for prime time.
  if {0 && [acs::icanuse "nx::alias object"]} {
    set register_command "alias"
  } else {
    set register_command "forward"
  }

  nx::Class create AssessmentInterface {
    #
    # Abstract class for common functionality
    #

    :public alias dict_value ::xowiki::formfield::dict_value
    :alias fc_to_dict ::xowiki::formfield::fc_to_dict

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


    #----------------------------------------------------------------------
    # Class:  AssessmentInterface
    # Method: add_to_fc
    #----------------------------------------------------------------------
    :method add_to_fc {-fc:required -position -minutes -points} {
      return [lmap c $fc {
        if {[regexp {^[^:]+_:} $c]} {
          if {[info exists position] && ![string match *,position=* $c]} {
            append c ,test_item_in_position=$position
          }
          if {[info exists minutes] && ![string match *,minutes=* $c]} {
            append c ,test_item_minutes=$minutes
          }
          if {[info exists points] && ![string match *,test_item_points=* $c]} {
            append c ,test_item_points=$points
          }
          #ns_log notice "APPEND $c"
        }
        set c
      }]
    }

    #----------------------------------------------------------------------
    # Class:  AssessmentInterface
    # Method: replace_in_fc
    #----------------------------------------------------------------------
    :method replace_in_fc {-fc:required property value} {
      return [lmap c $fc {
        if {[regexp {^[^:]+_:} $c]} {
          set pairs {}
          foreach pair [split $c ,] {
            set p [string first = $pair]
            set attribute [string range $pair 0 $p-1]
            #set old_value [string range $pair $p+1 end]
            if {$attribute eq $property} {
              set pair $property=$value
            }
            lappend pairs $pair
          }
          set c [join $pairs ,]
          #ns_log notice "APPEND $c"
        }
        set c
      }]
    }

    #----------------------------------------------------------------------
    # Class:  AssessmentInterface
    # Method: list_equal
    #----------------------------------------------------------------------
    :method list_equal { l1 l2 } {
      #
      # Compare two lists for equality. This function has to be used,
      # when lists contain the same elements in the same order, but
      # these are not literally equal due to, e.g., line breaks
      # between list elements, etc.
      #
      if {[llength $l1] != [llength $l2]} {
        return 0
      }
      foreach e1 $l1 e2 $l2 {
        if {$e1 ne $e2} {
          return 0
        }
      }
      return 1
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
      # answers (as returned from [answer_manager get_answer_attributes ...]).
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
      # Map "answer" to a generic name "@answer@" in the form and in
      # the form constraints.
      #
      set newName [:form_name_based_attribute_stem [$form_obj name]]
      #ns_log notice "renaming form loader: MAP '[$form_obj name]' -> '$newName'"

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

    # :method -deprecated get_form_object {ctx:object form_name} {
    #   #
    #   # Return the form object based on the provided form name. This
    #   # function performs attribute renaming on the returned form
    #   # object.
    #   #
    #   set form_id [$ctx default_load_form_id $form_name]
    #   set obj [$ctx object]
    #   set form_obj [::xowiki::FormPage get_instance_from_db -item_id $form_id]
    #   return [:rename_attributes $form_obj]
    # }
  }

  AssessmentInterface {*}$register_command FL \
      [Renaming_form_loader create renaming_form_loader]
}


namespace eval ::xowf::test_item {

  ad_proc -private tdom_render {script} {
    #
    # Render a snippet of tdom-html commands (as e.g. form-fields) into
    # HTML text.
    #
    dom createDocument html doc
    set root [$doc documentElement]
    $root appendFromScript {uplevel $script}
    set n [$root childNode]
    if {$n ne ""} {
      return [$n asHTML]
    }
    ns_log warning "tdom_render: $script returns empty"
  }

  nx::Class create Answer_manager -superclass AssessmentInterface {

    #
    # Public API:
    #
    #  - create_workflow
    #  - delete_all_answer_data
    #  - get_answer_wf
    #  - get_wf_instances
    #  - get_answer_attributes
    #  - student_submissions_exist
    #
    #  - runtime_panel
    #  - render_answers_with_edit_history
    #  - render_answers
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
    #  - last_time_switched_to_state
    #  - state_periods
    #

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: create_workflow
    #----------------------------------------------------------------------
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
      set questionObjs [:QM question_objs $parentObj]

      set wfQuestionNames {}
      set wfQuestionTitles {}
      set attributeNames {}
      foreach form_obj $questionObjs {
        lappend attributeNames \
            [:FL form_name_based_attribute_stem [$form_obj name]]

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
      set WF [::[$parentObj package_id] instantiate_forms \
                  -parent_id    [$parentObj parent_id] \
                  -forms $master_workflow \
                  -default_lang [$parentObj lang]]

      set fc {}
      lappend fc \
          "@table:_item_id,_state,$attributeNames,_last_modified" \
          "@table_properties:view_field=_item_id" \
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_label_from_options
    #----------------------------------------------------------------------
    :method get_label_from_options {value options} {
      foreach option $options {
        if {[lindex $option 1] eq $value} {
          return [lindex $option 0]
        }
      }
      return ""
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: recutil_create
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: export_answer
    #----------------------------------------------------------------------
    :public method export_answer {
      -combined_form_info
      -html:required
      -recutil:object,required
      -submission:object
    } {
      #
      # Export the provided question and answer in GNU rectuil format.
      #
      #ns_log notice "answers: [$submission serialize]"

      if {[$submission exists __form_fields]} {
        set form_fields [$submission set __form_fields]
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
      set user [$submission set creation_user]
      if {![info exists ::__running_ids]} {
        set ::__running_ids ""
      }
      if {![dict exists $::__running_ids $user]} {
        dict set ::__running_ids $user [incr ::__running_id]
      }

      set seeds [$submission property seeds]
      set instance_attributes [$submission set instance_attributes]
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
      set question_dict [:FL name_to_question_obj_dict \
                             [dict get $combined_form_info question_objs]]
      # ns_log notice "export_answers: question_dict: $question_dict"

      set form_constraints [lsort -unique [dict get $combined_form_info form_constraints]]
      set fc_dict [:fc_to_dict $form_constraints]
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: time_window_setup
    #----------------------------------------------------------------------
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
          # No end given. set it to start + exam time + 5 minutes.
          # The value of "total_minutes" might contain fractions of a
          # minute, so make sure that the end_clock is an integer as
          # needed by "clock format",
          set end_clock [expr {int($start_clock + ($total_minutes + 5) * 60)}]
          set new_dtend [clock format $end_clock -format %H:%M]
          ns_log notice "#### no dtend given. set it from $dtend to $new_dtend"

        } else {
          set end_date    [clock format $start_clock -format %Y-%m-%d]T$dtend
          set end_clock   [clock scan $end_date      -format %Y-%m-%dT%H:%M]
          if {($end_clock - $start_clock) < ($total_minutes * 60)} {
            #
            # The specified end time is too early. Set it to start +
            # exam time + 5 minutes.
            #
            set end_clock [expr {int($start_clock + ($total_minutes + 5)*60)}]
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: delete_all_answer_data
    #----------------------------------------------------------------------
    :public method delete_all_answer_data {obj:object} {
      #
      # Delete all instances of the answer workflow
      #
      set wf [:get_answer_wf $obj]
      if {$wf ne ""} {
        set items [:get_wf_instances -initialize false $wf]
        foreach i [$items children] {
          $i www-delete
        }
      }
      #
      # Delete as well the manual gradings for this exam.
      #
      #$obj set_property -new 1 manual_gradings {}
      :AM set_exam_results -obj $obj manual_gradings {}

      return $wf
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: delete_scheduled_atjobs
    #----------------------------------------------------------------------
    :public method delete_scheduled_atjobs {obj:object} {
      #
      # Delete previously scheduled atjobs
      #
      #ns_log notice "#### delete_scheduled_atjobs"

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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_answer_wf
    #----------------------------------------------------------------------
    :public method get_answer_wf {obj:object} {
      #
      # return the workflow denoted by the property wfName in obj
      #
      return [::[$obj package_id] instantiate_forms \
                  -parent_id    [$obj item_id] \
                  -default_lang [$obj lang] \
                  -forms        [$obj property wfName]]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_wf_instances
    #----------------------------------------------------------------------
    :public method get_wf_instances {
      {-initialize false}
      {-orderby ""}
      -creation_user:integer
      -item_id:integer
      -state
      wf:object
    } {
      # get_wf_instances: return the workflow instances

      :assert_assessment_container $wf
      set extra_where_clause ""
      foreach var {creation_user item_id state} {
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_answer_attributes
    #----------------------------------------------------------------------
    :public method get_answer_attributes {{-state ""} {-extra_attributes {}} wf:object} {
      #
      # Extracts wf instances as answers (e.g., extracting their
      # answer-specific attributes)
      #
      # @param wf the workflow
      # @param state retrieve only instances in this state
      # @param extra_attributes return these attributes additionally
      #        as key/value pairs per tuple
      #
      # @return a list of dicts
      #

      set results {}
      set items [:get_wf_instances $wf]
      foreach i [$items children] {
        if {$state ne "" && [$i state] ne $state} {
          continue
        }

        set answerAttributes [:FL answer_attributes [$i instance_attributes]]
        foreach extra $extra_attributes {
          lappend answerAttributes $extra [$i property $extra]
        }
        #ns_log notice "get_answer_attributes $i: <$answerAttributes> ALL [$i instance_attributes]"
        lappend results [list item $i answerAttributes $answerAttributes state [$i state]]
      }
      return $results
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_duration
    #----------------------------------------------------------------------
    :public method get_duration {{-exam_published_time ""} revision_sets} {
      #
      # Get the duration from a set of revisions and return a dict
      # containing "from", "fromClock","to", "toClock", "seconds", and
      # "duration".
      #
      set first [lindex $revision_sets 0]
      set last [lindex $revision_sets end]
      set fromClock [clock scan [::xo::db::tcl_date [ns_set get $first creation_date] tz]]
      set toClock [clock scan [::xo::db::tcl_date [ns_set get $last last_modified] tz]]
      dict set r fromClock $fromClock
      dict set r toClock $toClock
      dict set r from [clock format $fromClock -format "%H:%M:%S"]
      dict set r to [clock format $toClock -format "%H:%M:%S"]
      set timeDiff [expr {$toClock - $fromClock}]
      dict set r duration "[expr {$timeDiff/60}]m [expr {$timeDiff%60}]s"
      dict set r seconds $timeDiff
      if {$exam_published_time ne ""} {
        set examPublishedClock [clock scan [::xo::db::tcl_date $exam_published_time tz]]
        dict set r examPublishedClock $examPublishedClock
        dict set r examPublished [clock format $examPublishedClock -format "%H:%M:%S"]
        set epTimeDiff [expr {$toClock - $examPublishedClock}]
        dict set r examPublishedDuration "[expr {$epTimeDiff/60}]m [expr {$epTimeDiff%60}]s"
        #ns_log notice "EP examPublishedDuration [dict get $r examPublishedDuration]" \
            "EP [dict get $r examPublished] $exam_published_time"
        dict set r examPublishedSeconds $epTimeDiff
      }
      return $r
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_IPs
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: revisions_up_to
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: last_time_in_state
    #----------------------------------------------------------------------
    :public method last_time_in_state {revision_sets -state:required} {
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
          set result [ns_set get $ps last_modified]
        }
      }
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: last_time_switched_to_state
    #----------------------------------------------------------------------
    :public method last_time_switched_to_state {revision_sets -state:required {-before ""}} {
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
      set last_state ""
      foreach ps $revision_sets {
        if {$before ne ""} {
          set currentClock [clock scan [::xo::db::tcl_date [ns_set get $ps last_modified] tz]]
          if {$currentClock > $before} {
            break
          }
        }
        if {$last_state ne $state && $state eq [ns_set get $ps state]} {
          set result [ns_set get $ps last_modified]
        }
        set last_state [ns_set get $ps state]
      }
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: pretty_period
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: state_periods
    #----------------------------------------------------------------------
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
          set until [ns_set get $ps last_modified]
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: achieved_points
    #----------------------------------------------------------------------
    :method achieved_points {
      {-manual_grading ""}
      -submission:object
      -exam_question_dict
      -answer_attributes:required
    } {
      #
      # Calculate the achieved_points dict for an exam submission. This
      # function iterates of every question and sums up the achievable
      # and achieved points of the questions. The per-question results
      # are placed in the dict entry "details".
      #
      # This method has to be called after the instance was rendered,
      # since it uses the produced form_fields.
      #
      # @return dict containing "achievedPoints", "achievablePoints" and "details"
      #
      set all_form_fields [::xowiki::formfield::FormField info instances -closure]
      set question_dict $exam_question_dict

      if {[$submission property question] ne ""} {
        #
        # When the submission has a property "question" set then we
        # have a submission from a pool question. In this case, we
        # want - at least for the time being - the id of the pool
        # question and not the id of the replacement
        # question. Therefore, we have to create a dict for the
        # mapping of these values and to create a question_dict
        # (mapping from question_names to ids) updated with the id of
        # the pool question.
        #
        set question_ids_exam [lmap {k v} $exam_question_dict {set v}]
        set form_objs_submission [:QM load_question_objs $submission [$submission property question]]
        set question_ids_submission [lmap form_obj $form_objs_submission {$form_obj item_id}]
        #ns_log notice "=== achieved_points IDs examwf     <$question_ids_exam>"
        #ns_log notice "=== achieved_points IDs submission <$question_ids_submission>"
        set map ""
        foreach id_exam $question_ids_exam id_submission $question_ids_submission {
          if {$id_exam != $id_submission} {
            #ns_log notice "=== achieved_points must use $id_exam instead of $id_submission"
            dict set map $id_submission $id_exam
          }
        }
        set question_dict [:FL name_to_question_obj_dict $form_objs_submission]
        foreach {k v} $question_dict {
          if {[dict exists $map $v]} {
            dict set question_dict $k [dict get $map $v]
          }
        }
      }

      #ns_log notice "=== achieved_points question_dict <$question_dict>"

      set totalPoints 0
      set achievableTotalPoints 0
      set details {}

      foreach a [dict keys $answer_attributes] {
        set f [$submission lookup_form_field -name $a $all_form_fields]
        set points {}
        if {![$f exists test_item_points]} {
          ns_log warning "question $f [$f name] [$f info precedence] HAS NO POINTS"
          $f set test_item_points 0
        }
        set achievablePoints [$f set test_item_points]
        set achievableTotalPoints [expr {$achievableTotalPoints + $achievablePoints}]

        if {[$f exists correction_data]} {
          set auto_correct_achieved [:dict_value [$f set correction_data] points]
        } else {
          set auto_correct_achieved ""
        }
        #ns_log notice "=== achieved_points <$a> auto_correct_achieved $auto_correct_achieved"

        #
        # Manual grading has higher priority than autograding.
        #
        set achieved [:dict_value [:dict_value $manual_grading $a] achieved]
        if {$achieved eq ""} {
          set achieved $auto_correct_achieved
        }

        if {$achieved ne ""} {
          set totalPoints [expr {$totalPoints + $achieved}]
        } else {
          ns_log warning "$a: no points via automated or manual grading," \
              "ignoring question in achieved points calculation"
        }
        lappend details [dict create \
                             attributeName $a \
                             question_id [:dict_value $question_dict $a] \
                             achieved $achieved \
                             auto_correct_achieved $auto_correct_achieved \
                             achievable $achievablePoints]
      }

      #ns_log notice "final details <$details>"
      return [list achievedPoints $totalPoints \
                  details $details \
                  achievablePoints $achievableTotalPoints]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: grading_dialog_setup
    #----------------------------------------------------------------------
    :public method grading_dialog_setup {examWf} {
      #
      # Define the modal dialog and everything necessary for reusing
      # this dialog for multiple occasions. This method registers the
      # pop-up and dismiss handlers for JavaScript and returns the
      # HTML markup of the modal dialog.
      #
      # @return HTML block for the modal dialog
      #
      set url [$examWf pretty_link -query m=grade-single-item]

      ::template::add_body_script -script [subst -novariables {
        $(document).ready(function(){
          $('.modal .confirm').on('click', function(ev) {
            //
            // Submit button of grading dialog was pressed.
            //
            var id = ev.currentTarget.dataset.id;
            var gradingBox  = document.getElementById(id);
            var pointsInput = document.querySelector('#grading-points');
            var helpBlock   = document.querySelector('#grading-points-help-block');
            var comment     = document.querySelector('#grading-comment').value;
            var points      = pointsInput.value;
            var pointsFormGroup = pointsInput.parentElement.parentElement;
            var percentage  = "";

            if (points != "") {
              //
              // Number valdation
              //
              if (parseFloat(points) > parseFloat(pointsInput.max) || parseFloat(points) < parseFloat(pointsInput.min)){
                if (parseFloat(points) > parseFloat(pointsInput.max)) {
                  helpBlock.textContent = '[_ xowf.Value_max] ' + pointsInput.max;
                } else {
                  helpBlock.textContent = '[_ xowf.Value_min] ' + pointsInput.min;
                }
                pointsFormGroup.classList.add('has-error');
                helpBlock.classList.remove('hidden');
                ev.preventDefault();
                return false;
              } else {
                pointsFormGroup.classList.remove('has-error');
                helpBlock.classList.add('hidden');
              }
              var achievable = gradingBox.dataset.achievable;
              if (achievable != "") {
                percentage = "(" + (points*100.0/achievable).toFixed(2) + "%)";
              }

            } else {
              pointsFormGroup.removeClass('has-error');
              helpBlock.classList.add('hidden');
            }

            document.querySelector('#' + id + ' .points').textContent = points;
            document.querySelector('#' + id + ' .percentage').textContent = percentage;
            document.querySelector('#' + id + ' .comment').textContent = comment;
            gradingBox.dataset.achieved = points;
            gradingBox.dataset.comment = comment;
            if (comment == "") {
              document.querySelector('#' + id + ' .feedback-label').classList.add('hidden');
            } else {
              document.querySelector('#' + id + ' .feedback-label').classList.remove('hidden');
            }

            var user_id = gradingBox.dataset.user_id;
            var examGradingBox = document.getElementById('runtime-panel-' + user_id);

            var data = new FormData();
            data.append('question_name', gradingBox.dataset.question_name);
            data.append('user_id', user_id);
            data.append('achieved', points);
            data.append('comment', comment);
            data.append('grading_scheme', examGradingBox.dataset.grading_scheme);
            data.append('achieved_points', examGradingBox.dataset.achieved_points);

            var xhttp = new XMLHttpRequest();
            xhttp.open('POST', '[set url]', true);
            xhttp.onload = function () {
              if (this.readyState == 4) {
                if (this.status == 200) {
                  var text = this.responseText;
                  var span = document.querySelector('#runtime-panel-' + user_id + ' .achieved-points');
                  span.textContent = text;
                } else {
                  console.log('sent NOT ok');
                }
              }
            };
            xhttp.send(data);

            return true;
          });

          $('.modal-dialog form').keypress(function(e){
            if(e.keyCode == 13) {
              e.preventDefault();
              return false;
            }
          });

          $('#grading-modal').on('shown.bs.modal', function (ev) {
            //
            // Pop-up of grading dialog.
            // Copy values from data attributes to input fields.
            //
            var gradingBox = ev.relatedTarget.parentElement;
            document.getElementById('grading-question-title').textContent = gradingBox.dataset.title;
            document.getElementById('grading-participant').textContent = gradingBox.dataset.full_name;

            var pointsInput = document.getElementById('grading-points');
            pointsInput.value = gradingBox.dataset.achieved;
            pointsInput.max = gradingBox.dataset.achievable;
            document.getElementById('grading-comment').value = gradingBox.dataset.comment;

            // Tell confirm button to which grading box it belongs
            var confirmButton = document.querySelector('#grading-modal-confirm');
            confirmButton.dataset.id = gradingBox.id;
          });
        });
      }]

      return [ns_trim -delimiter | {
        |<div class="modal fade" id="grading-modal" tabindex="-1" role="dialog"
        |     aria-labelledby="grading-modal-label" aria-hidden="true">
        |  <div class="modal-dialog" role="document">
        |    <div class="modal-content">
        |      <div class="modal-header">
        |        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
        |          <span aria-hidden="true">&#215;</span>
        |        </button>
        |        <h4 class="modal-title" id="gradingModalTitle">#xowf.Grading#:
        |            <span id='grading-participant'></span></h4>
        |         <p class="modal-subtitle">#xowf.question#: <span id='grading-question-title'></span></p>
        |      </div>
        |      <div class="modal-body">
        |        <form class="form-horizontal" role="form" action='#' method="post">
        |          <div class="form-group">
        |             <label for="grading-points" class="control-label col-sm-2">#xowf.Points#:</label>
        |             <div class="col-sm-9">
        |                <input class="form-control" id="grading-points" placeholder="#xowf.Points#"
        |                       type="number" step="0.1" min="0">
        |                <span id="grading-points-help-block" class="help-block hidden"></span>
        |             </div>
        |          </div>
        |          <div class="form-group">
        |             <label for="grading-comment" class="control-label col-sm-2">#xowf.feedback#:</label>
        |             <div class="col-sm-9">
        |                <textarea lines="2" class="form-control" id="grading-comment"
        |                 placeholder="..."></textarea>
        |             </div>
        |          </div>
        |        </form>
        |      </div>
        |      <div class="modal-footer">
        |        <button type="button" class="btn btn-secondary"
        |                data-dismiss="modal">#acs-kernel.common_Cancel#
        |        </button>
        |        <button id="grading-modal-confirm" type="button" class="btn btn-primary confirm"
        |                data-dismiss="modal">#acs-subsite.Confirm#
        |        </button>
        |      </div>
        |    </div>
        |  </div>
        |</div>
      }]

    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: runtime_panel
    #----------------------------------------------------------------------
    :public method runtime_panel {
      {-revision_id ""}
      {-view default}
      {-grading_info ""}
      answerObj:object
    } {
      #
      # Return statistics for the provided object in the form of HTML:
      # - minimal statistics: when view default
      # - statistics with clickable revisions: when view = revision_overview
      # - per-revision statistics: when view = revision_overview and revision_id is provided
      #
      # @return HTML block
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
      set toClock [clock scan [::xo::db::tcl_date [ns_set get [lindex $revision_sets end] last_modified] tz]]
      set last_published [:last_time_switched_to_state $parent_revsion_sets -state published -before $toClock]
      #ns_log notice "LAST PUBLISHED $last_published"
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
          #xowf.Achieved_points#: <span class='data achieved-points'>$grading_info</span><br>
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_submission=edit_history
    #----------------------------------------------------------------------
    :method render_submission=edit_history {
      {-submission:object}
      {-examWf:object}
      {-nameToQuestionObj}
    } {
      set last_answers {}
      set rev_nr 1
      set q_nr 0
      set qnames ""
      set report ""
      set student_href [$examWf pretty_link -query m=print-answers&id=[$submission set item_id]]

      set revision_sets [$submission get_revision_sets -with_instance_attributes]
      foreach s $revision_sets {
        set msgs {}
        set ia [ns_set get $s instance_attributes]
        foreach key [dict keys $ia *_] {
          if {![dict exists $qnames $key]} {
            dict set qnames $key [incr q_nr]
          }
          set value [dict get $ia $key]
          #
          # Determine the question type
          #
          set form_obj [dict get $nameToQuestionObj $key]
          set template_obj [$form_obj page_template]
          if {[$template_obj name] eq "en:edit-interaction.wf"} {
            set item_type [dict get [$form_obj instance_attributes] item_type]
          } else {
            switch [$template_obj name] {
              en:TestItemShortText.form {set item_type ShortText}
              en:TestItemText.form {set item_type Text}
              default {set item_type unknown}
            }
          }
          #ns_log notice "Template name = [$template_obj name] -> item_type '$item_type'"

          #
          # For the time being, compute the differences just for short text questions
          #
          if {$item_type in {ShortText}} {
            foreach answer_key [dict keys $value] {
              set answer_value [string trim [dict get $value $answer_key]]
              set what ""
              set last_value [:dict_value $last_answers $answer_key ""]
              if {$last_value ne ""} {
                if {$answer_value eq ""} {
                  set what cleared
                  ns_log notice "  ==> $answer_key: answer_value '$last_value' cleared in revision $rev_nr"
                } elseif {$answer_value ne $last_value} {
                  set what updated
                }
              } else {
                # last answer was empty
                if {$answer_value ne ""} {
                  set what added
                }
              }
              #
              # Remember last answer values
              #
              dict set last_answers $answer_key $answer_value
              if {$what ne ""} {
                if {$what eq "cleared"} {
                  set answer_value $last_value
                }
                lappend msgs [subst {
                  <span class='alert-[dict get {cleared warning added success updated info "" ""} $what]'>
                  q[string map [list answer "" {*}$qnames] $answer_key] $what [ns_quotehtml '$answer_value']
                  </span>
                }]
              }
            }
          } else {
            #
            # Show the full content of the field
            #
            if {$value ne ""} {
              lappend msgs [subst {
                <span class=''>q[string map [list answer "" {*}$qnames] $key]:
                [ns_quotehtml '$value']</span>
              }]
            }
          }
        }
        append report [subst {
          <a href='$student_href&rid=[ns_set get $s revision_id]'>[format %02d $rev_nr]</a>:
          [join $msgs {; }]<br>
        }]
        incr rev_nr
      }

      append HTML [subst {
        <tr>
        <td><a href='$student_href'>[$submission set online-exam-userName]</td>
        <td>[$submission set online-exam-fullName]</td>
        <td>$report</td>
        </tr>
      }]

      return $HTML
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_submissions=edit_history
    #----------------------------------------------------------------------
    :method render_submissions=edit_history {
      {-examWf:object}
      {-submissions:object}
    } {
      set combined_form_info [:QM combined_question_form $examWf]
      set nameToQuestionObj [:FL name_to_question_obj_dict \
                                 [dict get $combined_form_info question_objs]]
      #
      # Sort items by username
      #
      $submissions orderby online-exam-userName

      return [subst {
        <h2>Quick Submission Analysis</h2>
        <table class='table table-condensed'>
        <tr><th></th><th>Name</th><th>Revisions</th></tr>
        [join [lmap submission [$submissions children] {
          :render_submission=edit_history \
              -submission $submission -examWf $examWf \
              -nameToQuestionObj $nameToQuestionObj}]]
        </table>
      }]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_answers_with_edit_history
    #----------------------------------------------------------------------
    :public method render_answers_with_edit_history {
      examWf:object
    } {
      #
      # Analyze the student submissions an find situations, where input
      # is "cleared" between revisions and return the HTML rendering.
      #
      # TODO: we should resolve this, move the exam protocol rendering
      # (www-print-answers) also into the answer manager and make it
      # configurable to provide this as an alternate item renderer.
      # The current result is provided for all submission,s, but in
      # general, this could be as well made available per question or
      # per-student.
      #
      # @return HTML
      #
      set wf [:get_answer_wf $examWf]
      if {$wf eq ""} {
        return ""
      }

      set submissions [:submissions -wf $wf]
      set HTML [:render_submissions=edit_history -examWf $examWf -submissions $submissions]

      return $HTML
    }

    ########################################################################
    :method render_proctor_images {
      {-submission:object}
      {-revisions}
      {-examWf:object}
      {-revision_id}
    } {
      #
      # Render proctor images the provided submission.
      #
      # @return HTML
      #
      set user_id [$submission creation_user]
      set img_url [$examWf pretty_link -query m=proctor-image&user_id=$user_id]

      set proctoring_dir [proctoring::folder \
                              -object_id [$examWf item_id] \
                              -user_id $user_id]
      set files [glob -nocomplain -directory $proctoring_dir *.*]
      #ns_log notice "proctoring_dir $proctoring_dir files $files"

      if {$revision_id ne ""} {
        set filtered_revisions [:revisions_up_to $revisions $revision_id]
      } else {
        set filtered_revisions $revisions
      }

      set start_date  [ns_set get [lindex $filtered_revisions 0] creation_date]
      set end_date    [ns_set get [lindex $filtered_revisions end] last_modified]
      set start_clock [clock scan [::xo::db::tcl_date $start_date tz_var]]
      set end_clock   [clock scan [::xo::db::tcl_date $end_date tz_var]]

      set image ""
      #ns_log notice "start date $start_date end_date $end_date / $start_clock $end_clock"
      foreach f $files {
        #ns_log notice "check: $f"
        if {[regexp {/([^/]+)-(\d+)[.](webm|png|jpeg)$} $f . type stamp ext]} {
          set inWindow [expr {$stamp >= $start_clock && $stamp <= $end_clock}]
          ns_log notice "parsed $type $stamp $ext $inWindow $stamp " \
              [clock format $stamp -format {%m-%d %H:%M:%S}] >= \
              $start_clock ([expr {$stamp >= $start_clock}]) \
              && $stamp <= $end_clock ([expr {$stamp <= $end_clock}])
          if {$inWindow} {
            dict set image $stamp $type $ext
          }
        }
      }
      set markup ""
      foreach ts [lsort -integer [dict keys $image]] {
        #ns_log notice "ts $ts [dict get $image $ts]"
        append markup [subst {<div>[clock format $ts -format {%Y-%m-%d %H:%M:%S}]</div>}]
        append markup {<div style="display: flex">}
        foreach type {camera-image desktop-image} {
          if {[dict exists $image $ts $type]} {
            set ext [dict get $image $ts $type]
            append markup [subst {<img height="240" src="$img_url&type=$type&ts=$ts&e=$ext">}]
          }
        }
        if {[dict exists $image $ts camera-audio]} {
          set ext [dict get $image $ts camera-audio]
          append markup [subst {<audio controls src="$img_url&type=camera-audio&ts=$ts&e=$ext" type="video/webm"></audio>}]
        }
        append markup </div>\n
      }
      return $markup
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: student_submissions_exist
    #----------------------------------------------------------------------
    :public method student_submissions_exist {wf:object} {
      #
      # Returns 1 if there are student submissions. The method returns
      # already true, when a student has started to work on this exam.
      #
      # This method could be optimized if necessary via caching the
      # wf_instances or a more specific database query.
      #
      set items [:get_wf_instances $wf]
      foreach i [$items children] {
        if {[$i property try_out_mode] ne "1"} {
          #ns_log notice "==================== student_submissions_exist 1"
          return 1
        }
      }
      #ns_log notice "==================== student_submissions_exist 0"
      return 0
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: submissions
    #----------------------------------------------------------------------
    :method submissions {
      {-creation_user:integer,0..1 ""}
      {-filter_submission_id:integer,0..1 ""}
      {-revision_id:integer,0..1 ""}
      {-wf:object}
    } {
      #
      # Return an ordered composite built form all student submission,
      # potentially filtered via the provided values.
      #
      if {$revision_id ne ""} {
        #
        # In case we have a revision_id, return this single
        # revision.
        #
        set r [::xowiki::FormPage get_instance_from_db -revision_id $revision_id]
        set submissions [::xo::OrderedComposite new -destroy_on_cleanup]
        $submissions add $r
      } else {
        set submissions [:get_wf_instances \
                             {*}[expr {$creation_user ne "" ? "-creation_user $creation_user" : ""}] \
                             {*}[expr {$filter_submission_id ne "" ? "-item_id $filter_submission_id" : ""}] \
                             $wf]
      }

      #
      # Provide additional attributes to the instances such as the
      # userName and fullName.
      #
      foreach submission [$submissions children] {
        $submission set online-exam-userName \
            [acs_user::get_element \
                 -user_id [$submission creation_user] \
                 -element username]
        $submission set online-exam-fullName \
            [::xo::get_user_name [$submission creation_user]]
      }

      return $submissions
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_print_button
    #----------------------------------------------------------------------
    :method render_print_button {} {
      #
      # Render a simple print button for the unaware that makes it
      # easy to print the exam protocol to PDF and use e.g. a pdf-tool
      # to annotate free text answers. The function is designed to
      # work with streaming HTML output.
      #
      # @return HTML rendering
      #

      template::add_event_listener \
          -id print-button \
          -event click \
          -preventdefault=false \
          -script "window.print();"

      return [subst {
        <button id="print-button">
        <span class='glyphicon glyphicon-print' aria-hidden='true'></span> print
        </button>
        [template::collect_body_scripts]
      }]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_full_submission_form
    #----------------------------------------------------------------------
    :method render_full_submission_form {
      -wf:object
      -submission:object
      -filter_form_ids:integer,0..n
    } {
      #
      # Compute the HTML of the full submission with all form fields
      # instantiated according to randomization.
      #
      # @param filter_form_ids used for filtering questions
      # @return HTML of question form object containing all (wanted) questions
      #

      #
      # Flush all form fields, since their contents depends on
      # randomization. In later versions, we should introduce a more
      # intelligent caching respecting randomization.
      #
      foreach f [::xowiki::formfield::FormField info instances -closure] {
        #ns_log notice "FF could DESTROY $f [$f name]"
        if {[string match *_ [$f name]]} {
          #ns_log notice "FF DESTROY $f [$f name]"
          $f destroy
        }
      }
      $wf form_field_flush_cache

      #
      # The call to "render_content" calls actually the
      # "summary_form" of online/inclass-exam-answer.wf when the submit
      # instance is in state "done". We set the __feedback_mode to
      # get the auto-correction included.
      #
      xo::cc eval_as_user -user_id [$submission creation_user] {
        $submission set __feedback_mode 2
        $submission set __form_objs $filter_form_ids
        set question_form [$submission render_content]
      }

      return $question_form
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_non_empty_file_formfields
    #----------------------------------------------------------------------
    :method get_non_empty_file_formfields {
      {-submission:object}
    } {
      if {[$submission exists __form_fields]} {
        set objs [lmap {name obj} [$submission set __form_fields] {set obj}]

        #
        # Filter out the form-fields, which have a nonempty
        # revision_id.
        #
        return [::xowiki::formfield::child_components \
                    -filter {[$_ hasclass "::xowiki::formfield::file"]
                      && [dict exists [$_ value] revision_id]
                      && [dict get [$_ value] revision_id] ne ""} \
                    $objs]
      } else {
        return ""
      }
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: pretty_formfield_name
    #----------------------------------------------------------------------
    :method pretty_formfield_name {f_obj} {
      regsub {_[.]answer([0-9]+)} [$f_obj name] {-\1} exercise_name
      #ns_log notice "PRETTY '[$f_obj name]' -> '$exercise_name'"
      return $exercise_name
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: export_file_submission
    #----------------------------------------------------------------------
    :method export_file_submission {
      {-submission:object}
      {-zipFile:object}
      {-check_for_file_submission_exists:boolean false}
    } {
      #
      # Get all nonempty file form-fields and add these to a zip
      # file.  The filename is composed of the user, the exercise and
      # the provided file-name.
      #
      foreach f_obj [:get_non_empty_file_formfields -submission $submission] {
        set exercise_name [:pretty_formfield_name $f_obj]
        foreach file_revision_id  [dict get [$f_obj value] revision_id] {
          set file_object [::xo::db::CrClass get_instance_from_db -revision_id $file_revision_id]
          set download_file_name ""
          append download_file_name \
              [$submission set online-exam-userName] "-" \
              $exercise_name "-" \
              [$file_object title]
          $zipFile addFile \
              [$file_object full_file_name] \
              [$zipFile cget -name]/[ad_sanitize_filename $download_file_name]
        }
      }
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: dom ensemble for tdom manipluations
    #----------------------------------------------------------------------
    :method "dom node replace" {domNode xquery script} {
      set node [$domNode selectNodes $xquery]
      if {$node ne ""} {
        foreach child [$node childNodes] {
          $child delete
        }
        :uplevel [list $node appendFromScript $script]
      }
    }
    :method "dom node delete" {domNode xquery} {
      set nodes [$domNode selectNodes $xquery]
      foreach node $nodes {
        $node delete
      }
    }
    :method "dom class add" {domNode xquery class} {
      set nodes [$domNode selectNodes $xquery]
      foreach node $nodes {
        set oldClass [$node getAttribute class]
        if {$class ni $oldClass} {
          $node setAttribute class "$oldClass $class"
        }
      }
    }
    :method "dom class remove" {domNode xquery class} {
      set nodes [$domNode selectNodes $xquery]
      foreach node $nodes {
        set oldClass [$node getAttribute class]
        set pos [lsearch $oldClass $class]
        if {$pos != -1} {
          $node setAttribute class [lreplace $oldClass $pos $pos]
        }
      }
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: postprocess_question_html
    #----------------------------------------------------------------------
    :method postprocess_question_html {
      {-question_form:required}
      {-achieved_points:required}
      {-manual_grading:required}
      {-submission:object,required}
      {-runtime_panel_view:required}
      {-exam_state:required}
    } {
      #
      # Post-process the HTML of a question by adding information of
      # the student as data attributes, such as achieved and
      # achievable points, setting CSS classes, mangling names of
      # composite questions to match with the data in achieved_points,
      #
      # @return HTML block

      #ns_log notice "QF=$question_form"
      dom parse -simple -html $question_form doc
      $doc documentElement root
      if {$root eq ""} {
        error "form '$form' is not valid"
      }

      set per_question_points ""
      foreach pd [:dict_value $achieved_points details] {
        set qn [dict get $pd attributeName]
        dict set per_question_points $qn achieved [dict get $pd achieved]
        dict set per_question_points $qn achievable [dict get $pd achievable]
      }

      #
      # For every composite question:
      #
      # - update the question_name of the subquestion by prefixing it
      #   with the name of the composite, since this is what we have
      #   in the details of achieved_points.
      # - hide the grading box of the composite
      # - unhide the grading box of the composite children
      #
      set composite_grading_boxes \
          [$root selectNodes \
               {//div[@data-item_type='Composite']/div[contains(@class,'grading-box')]}]
      foreach composite_grading_box $composite_grading_boxes {
        set composite_qn [$composite_grading_box getAttribute "data-question_name"]
        set parentNode [$composite_grading_box parentNode]
        :dom class add $composite_grading_box {.} hidden
        foreach grading_box [$parentNode selectNodes {div//div[contains(@class,'grading-box')]}] {
          set qn [$grading_box getAttribute data-question_name]
          regsub {^answer_} $qn ${composite_qn}_ new_qn
          #ns_log notice "CHILD of Composite: rename QN from $qn to $new_qn"
          $grading_box setAttribute data-question_name $new_qn
          $grading_box setAttribute id ${composite_qn}_[$grading_box getAttribute id]
          :dom class remove $grading_box {.} hidden
        }
      }

      set submission_state [$submission state]
      #set noManualGrading [expr {$submission_state ne "done" || $exam_state eq "published"}]
      set noManualGrading [expr {$exam_state eq "published"}]

      set grading_boxes [${root} selectNodes {//div[contains(@class,'grading-box')]}]
      foreach grading_box $grading_boxes {
        set qn [$grading_box getAttribute "data-question_name"]
        set item_node [$grading_box parentNode]
        set item_type [expr {[$item_node hasAttribute "data-item_type"]
                             ? [$item_node getAttribute "data-item_type"]
                             : ""}]
        ns_log notice "... QN '$qn' item_type '$item_type'" \
            "submission state $submission_state" \
            "exam state $exam_state noManualGrading $noManualGrading"
        if {$noManualGrading} {
          :dom class add $grading_box {a[contains(@class,'manual-grade')]} hidden
        }

        #
        # Get manual gradings, if these were already provided.
        #
        if {[dict exists $manual_grading $qn]} {
          set achieved [dict get $manual_grading $qn achieved]
          set comment [dict get $manual_grading $qn comment]
        } else {
          set achieved ""
          set comment ""
        }

        if {[dict exists $per_question_points $qn achieved]} {
          #
          # Manual grading has higher priority than automated grading.
          #
          if {$achieved eq ""} {
            set achieved [dict get $per_question_points $qn achieved]
          }
          set achievable [dict get $per_question_points $qn achievable]
          $grading_box setAttribute data-autograde 1
        } else {
          set achievable ""
        }
        #ns_log notice "... QN '$qn' item_type $item_type achieved '$achieved' achievable '$achievable'"

        if {$achieved eq ""} {
          :dom node replace $grading_box {span[@class='points']} {
            ::html::span -class "glyphicon glyphicon-alert text-warn" -aria-hidden "true" {}
          }
        } else {
          :dom node replace $grading_box {span[@class='points']} {::html::t $achieved}
          if {$achievable ne ""} {
            set percentage [format %.2f [expr {$achieved*100.0/$achievable}]]
            :dom node replace $grading_box {span[@class='percentage']} {::html::t ($percentage%)}
          }
        }
        #
        # When "comment" is empty, do not show the label.
        #
        :dom node replace $grading_box {span[@class='comment']} {::html::t $comment}
        if {$comment eq ""} {
          :dom class add $grading_box {span[@class='feedback-label']} hidden
        } else {
          :dom class remove $grading_box {span[@class='feedback-label']} hidden
        }

        $grading_box setAttribute data-user_id [$submission creation_user]
        $grading_box setAttribute data-user_name [$submission set online-exam-userName]
        $grading_box setAttribute data-full_name [$submission set online-exam-fullName]
        $grading_box setAttribute data-achieved $achieved
        $grading_box setAttribute data-achievable $achievable
        $grading_box setAttribute data-comment $comment

        #
        # In student review mode ('Einsicht'), remove edit controls.
        #
        if {$runtime_panel_view eq "student"} {
          :dom node delete $grading_box {a}
        }
      }
      return [$root asHTML]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_submission=exam_protocol
    #----------------------------------------------------------------------
    :method render_submission=exam_protocol {
      {-autograde:boolean false}
      {-combined_form_info}
      {-examWf:object}
      {-exam_question_dict}
      {-filter_submission_id:integer,0..1 ""}
      {-filter_form_ids:integer,0..n ""}
      {-grading_scheme:object}
      {-recutil:object,0..1 ""}
      {-zipFile:object,0..1 ""}
      {-revision_id:integer,0..1 ""}
      {-submission:object}
      {-totalPoints:double}
      {-runtime_panel_view default}
      {-wf:object}
      {-with_signature:boolean false}
      {-with_exam_heading:boolean true}
    } {
      set userName [$submission set online-exam-userName]
      set fullName [$submission set online-exam-fullName]
      set user_id  [$submission set creation_user]
      set manual_gradings [:get_exam_results -obj $examWf manual_gradings]
      set results ""

      #if {[$submission state] ne "done"} {
      #  ns_log notice "online-exam: submission of $userName is not finished (state [$submission state])"
      #  return ""
      #}

      set revisions [$submission get_revision_sets]
      if {[llength $revisions] == 1 } {
        #
        # We have always an initial revision. This revision might be
        # already updated via autosave, in which case we show the
        # content.
        #
        set rev [lindex $revisions 0]
        set unmodified [string equal [ns_set get $rev last_modified] [ns_set get $rev creation_date]]
        if {$unmodified} {
          ns_log notice "online-exam: submission of $userName is empty. Ignoring."
          return ""
        }
      }

      #
      # We have to distinguish between the answered attributes (based
      # on the instance attributes in the database) and the answer
      # attributes, which should be rendered. The latter one might be
      # a subset, especially in cases, where filtering (e.g., show
      # only one question of all candidates) happens.
      #
      set exam_question_objs [dict values $exam_question_dict]

      set answeredAnswerAttributes \
          [:FL answer_attributes [$submission instance_attributes]]
      set formAnswerAttributeNames \
          [dict keys [:FL name_to_question_obj_dict $exam_question_objs]]
      set usedAnswerAttributes {}
      foreach {k v} $answeredAnswerAttributes {
        if {$k in $formAnswerAttributeNames} {
          dict set usedAnswerAttributes $k $v
        }
      }

      #ns_log notice "filter_form_ids <$filter_form_ids>"
      #ns_log notice "question_objs <[dict get $combined_form_info question_objs]>"
      #ns_log notice "answeredAnswerAttributes <$answeredAnswerAttributes>"
      #ns_log notice "formAnswerAttributeNames <$formAnswerAttributeNames> [:FL name_to_question_obj_dict $filter_form_ids]"
      #ns_log notice "usedAnswerAttributes <$usedAnswerAttributes>"

      #
      # "render_full_submission_form" calls "summary_form" to obtain the
      # user's answers to all questions.
      #
      set question_form [:render_full_submission_form \
                             -wf $wf \
                             -submission $submission \
                             -filter_form_ids $filter_form_ids]

      if {$recutil ne ""} {
        :export_answer \
            -submission $submission \
            -html $question_form \
            -combined_form_info $combined_form_info \
            -recutil $recutil
      }

      if {$zipFile ne ""} {
        :export_file_submission -submission $submission -zipFile $zipFile
      }

      #
      # Achieved_points are computed for autograded and manually
      # graded exams.
      #
      set achieved_points [:achieved_points \
                               -manual_grading [:dict_value $manual_gradings $user_id] \
                               -submission $submission \
                               -exam_question_dict $exam_question_dict \
                               -answer_attributes $usedAnswerAttributes]
      dict set achieved_points totalPoints $totalPoints

      #ns_log notice "user $user_id: achieved_points [dict get $achieved_points details]"
      #ns_log notice "user $user_id: manual_gradings [:dict_value $manual_gradings $user_id]"

      foreach pd [:dict_value $achieved_points details] {
        set qn [dict get $pd attributeName]
        dict set results $qn achieved [dict get $pd achieved]
        dict set results $qn achievable [dict get $pd achievable]
        dict set results $qn question_id [dict get $pd question_id]
      }

      set question_form [:postprocess_question_html \
                             -question_form $question_form \
                             -achieved_points $achieved_points \
                             -manual_grading [:dict_value $manual_gradings $user_id] \
                             -submission $submission \
                             -exam_state [$examWf state] \
                             -runtime_panel_view $runtime_panel_view]

      if {$with_signature} {
        set sha256 [ns_md string -digest sha256 $answerAttributes]
        set signatureString "<div class='signature'>online-exam-actual_signature: $sha256</div>\n"
        set submissionSignature [$submission property signature ""]
        if {$submissionSignature ne ""} {
          append signatureString "<div>#xowf.online-exam-submission_signature#: $submissionSignature</div>\n"
        }
      } else {
        set signatureString ""
      }

      set time [::xo::db::tcl_date [$submission property _last_modified] tz_var]
      set pretty_date [clock format [clock scan $time] -format "%Y-%m-%d"]

      #
      # If we filter by student and the exam is proctored, display
      # the procoring images as well.
      #
      if {$filter_submission_id ne "" && [$examWf property proctoring] eq "t"} {
        set markup [:render_proctor_images \
                        -submission $submission \
                        -revisions $revisions \
                        -examWf $examWf \
                        -revision_id $revision_id]
        set question_form [subst {
          <div class="container">
          <div class="row">
          <div class="col-md-6">$question_form</div>
          <div class="col-md-6">$markup</div>
          </div>
          </div>
        }]
      }

      if {$runtime_panel_view ne ""} {
        set gradingInfo [$grading_scheme print -achieved_points $achieved_points]
        set gradingPanel [:dict_value $gradingInfo panel ""]
        set runtime_panel [:runtime_panel \
                               -revision_id $revision_id \
                               -view $runtime_panel_view \
                               -grading_info $gradingPanel \
                               $submission]
        if {$autograde} {
          set grade [$grading_scheme grade -achieved_points $achieved_points]
          ns_log notice "CSV $userName\t[dict get $gradingInfo csv]"
          dict incr :grade_dict $grade
          append :grade_csv $userName\t[dict get $gradingInfo csv]\n
        }
      } else {
        set runtime_panel ""
      }

      #
      # Don't add details to exam-review for student.
      #
      if {$runtime_panel_view eq "student"} {
        set grading_scheme ""
        set achieved_points ""
      }
      set heading "$userName · $fullName · $pretty_date"
      append HTML [subst [ns_trim {
        <div class='single_exam'>
        <div class='runtime-panel' id='runtime-panel-$user_id'
             data-grading_scheme='[namespace tail $grading_scheme]'
             data-achieved_points='$achieved_points'>
        [expr {$with_exam_heading ? "<h2>$heading</h2>" : ""}]
        $runtime_panel
        </div>
        $signatureString
        $question_form
        </div>
      }]]

      return [list HTML $HTML results $results]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: grading_scheme
    #----------------------------------------------------------------------
    :method grading_scheme {
      {-examWf:object,required}
      {-grading:token,0..n ""}
      {-total_points}
    } {
      #
      # Return the grading scheme object based on the provided short
      # name.  In case the grading scheme belongs to the predefined
      # grading schemes, the object can be directly loaded. When the
      # name refers to a user-defined grading object, this might have
      # to be loaded.
      #
      # We could consider some hints about the usefulness of the
      # chosen grading scheme, E.g., when an exam has 40 points or
      # less, rounding has the potential effect that a high percentage
      # of the grade is just due to rounding. So, in such cases a
      # non-rounding scheme should be preferred.
      #
      # @return fully qualified grading scheme object
      #
      if {$grading eq ""} {
        #set grading [expr {$total_points < 40 ? "round-none" : "round-points"}]
        set grading "none"
        ns_log notice "--- legacy grading scheme -> none"
      }

      set grading_scheme ::xowf::test_item::grading::$grading
      if {![nsf::is object $grading_scheme]} {
        #
        # Maybe we have to load this grading scheme...
        #
        ::xowf::test_item::grading::load_grading_schemes \
            -package_id [$examWf package_id] \
            -parent_id [$examWf parent_id]
        ns_log notice "--- grading schemes loaded"
      }
      if {![nsf::is object $grading_scheme]} {
        set grading_scheme ::xowf::test_item::grading::round-points
        ns_log notice "--- fallback to default grading scheme object"
      }
      #ns_log notice "USE grading_scheme $grading_scheme"
      return $grading_scheme
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: render_answers
    #----------------------------------------------------------------------
    :public method render_answers {
      {-as_student:boolean false}
      {-filter_submission_id:integer,0..1 ""}
      {-creation_user:integer,0..1 ""}
      {-revision_id:integer,0..1 ""}
      {-filter_form_ids:integer,0..n ""}
      {-export:boolean false}
      {-orderby:token "online-exam-userName"}
      {-grading:token,0..n ""}
      {-with_grading_table:boolean false}
      examWf:object
    } {
      #
      # Return the answers in HTML format in a somewhat printer
      # friendly way, e.g. as the exam protocol.
      #
      # @return dict containing "do_stream" and "HTML"
      #
      set combined_form_info [:QM combined_question_form $examWf]
      set autograde   [dict get $combined_form_info autograde]
      set totalPoints [:QM total_points \
                           -max_items [$examWf property max_items ""] \
                           $combined_form_info]

      set withSignature [$examWf property signature 0]
      set examTitle [$examWf title]
      set ctx [::xowf::Context require $examWf]

      set wf [:get_answer_wf $examWf]
      if {$wf eq ""} {
        return [list do_stream 0 HTML ""]
      }

      if {$filter_form_ids ne "" && $filter_form_ids ni [dict get $combined_form_info question_objs]} {
        ns_log warning "inclass-exam: ignore invalid form_obj '$filter_form_ids';" \
            "valid [dict get $combined_form_info question_objs]"
        set filter_form_ids ""
      }
      ns_log notice "--- grading '$grading'"
      set grading_scheme [:grading_scheme -examWf $examWf -grading $grading -total_points $totalPoints]
      #ns_log notice "--- grading_scheme $grading_scheme from grading '$grading'"

      set :grade_dict {}
      set :grade_csv ""

      set items [:submissions \
                     -creation_user $creation_user \
                     -filter_submission_id $filter_submission_id \
                     -revision_id $revision_id \
                     -wf $wf]
      #
      # In case we have many items to render (which might take a
      # while), use streaming mode.
      #
      set do_stream [expr {[llength [$items children]] > 100}]

      set HTML [:render_print_button]
      ::xo::cc set_parameter template_file view-plain-master
      ::xo::cc set_parameter MenuBar 0

      if {[llength $filter_form_ids] > 0} {
        #
        # Filter by questions. For the time being, we allow only a
        # single question, ... and we take the first ones.
        #
        append HTML "<h2>#xowf.question#: [ns_quotehtml [[lindex $filter_form_ids 0] title]]</h2>\n"
        set runtime_panel_view ""

      } elseif {$as_student} {
        #
        # Show the student his own submission
        #
        set userName [acs_user::get_element -user_id [ad_conn user_id] -element username]
        set fullName [::xo::get_user_name  [ad_conn user_id]]
        set heading "$userName - $fullName"
        append HTML "<h2>#xowf.online-exam-review-protocol# - $heading</h2>\n"
        set runtime_panel_view "student"

      } else {
        #
        # Provide the full protocol (or a subset of it)
        #
        append HTML "<h2>#xowf.online-exam-protocol#</h2>\n"
        if {$filter_submission_id ne ""} {
          set runtime_panel_view "revision_overview"
        } else {
          set runtime_panel_view "default"
        }
      }
      append HTML [:grading_dialog_setup $examWf]

      if {$do_stream} {
        # ns_log notice STREAM-[info level]-$::template::parse_level
        #
        # The following line is tricky: set on the parsing level the
        # title of and context of the page, since this is needed by
        # the streaming template.
        #
        uplevel #$::template::parse_level [subst {set title "$examTitle"; set context .}]
        ad_return_top_of_page [ad_parse_template \
                                   -params [list context title] \
                                   [template::streaming_template]]
        ns_write [subst {
          <div class=''main-content>
          <div class='xowiki-content' style='padding-left:15px;'>
          <h1>[ns_quotehtml $examTitle]</h1>
          [lang::util::localize $HTML]
        }]
        set HTML ""
      }

      if {$export} {
        set recutil [:recutil_create \
                         -clear \
                         -exam_id [$wf parent_id] \
                         -fn [expr {$filter_submission_id eq "" ? "all.rec" : "$filter_submission_id.rec"}]
                    ]
      } else {
        set recutil ""
      }

      #
      # Create zip file from file submissions
      #
      set create_zip_file [::xo::cc query_parameter create-file-submission-zip-file:boolean 0]
      if {$create_zip_file} {
        package req nx::zip

        [$examWf package_id] get_lang_and_name -name [$examWf set name] lang stripped_name

        if {[string equal [nx::zip::Archive info lookup parameters create name] -name]} {
          set zipFile [nx::zip::Archive new -name [ad_sanitize_filename $stripped_name]]
        } else {
          set zipFile [::nx::zip::Archive new]
          #
          # Post-register property, since it is not yet available in
          # this version of nx.
          #
          $zipFile object property name
          $zipFile configure -name [ad_sanitize_filename $stripped_name]
        }
      } else {
        set zipFile ""
      }

      set file_submission_exists 0

      set form_objs_exam [:QM load_question_objs $examWf [$examWf property question]]
      set question_dict [:FL name_to_question_obj_dict $form_objs_exam]
      #ns_log notice "passed filter_form_ids <$filter_form_ids> form_objs_exam <$form_objs_exam>"

      #
      # Iterate over the items sorted by orderby.
      #
      $items orderby $orderby
      foreach submission [$items children] {

        set d [:render_submission=exam_protocol \
                   -submission $submission \
                   -wf $wf \
                   -examWf $examWf \
                   -exam_question_dict $question_dict \
                   -autograde $autograde \
                   -combined_form_info $combined_form_info \
                   -filter_submission_id $filter_submission_id \
                   -filter_form_ids $filter_form_ids \
                   -grading_scheme $grading_scheme \
                   -recutil $recutil \
                   -zipFile $zipFile \
                   -revision_id $revision_id \
                   -totalPoints $totalPoints \
                   -runtime_panel_view $runtime_panel_view \
                   -with_exam_heading [expr {!$as_student}] \
                   -with_signature $withSignature]

        set html [:dict_value $d HTML]
        dict set results [$submission set creation_user] [:dict_value $d results]

        if {$do_stream && $html ne ""} {
          ns_write [lang::util::localize $html]
        } else {
          append HTML $html
        }

        #
        # Check if we have found a file submission
        #
        if {!$file_submission_exists
            && !$export
            && [llength [:get_non_empty_file_formfields -submission $submission]] > 0
          } {
          set file_submission_exists 1
        }

      }

      if {$export} {
        $recutil destroy
      }

      if {$with_grading_table && $autograde} {
        append HTML <p>[:grading_table -csv ${:grade_csv} ${:grade_dict}]</p>
        #
        # The following lines are conveniant for debugging
        #
        #set manual_gradings [$examWf property manual_gradings]
        #set manual_gradings [:get_exam_results -obj $examWf manual_gradings]
        #append HTML <pre>$manual_gradings</pre>
        #append HTML <pre>[:results_export -manual_gradings $manual_gradings $results]</pre>
      }

      if {$create_zip_file} {
        $zipFile ns_returnZipFile [$zipFile cget -name].zip
        $zipFile destroy
        ad_script_abort
      }

      #
      # If we have already some file submission we are showing a link
      # for bulk-downloading the submissions
      #
      if {$file_submission_exists} {
        #
        # Avoid empty entries for query parameters
        #
        if {[llength $filter_form_ids] > 0} {
          set fos $filter_form_ids
        }
        foreach value {revision_id filter_submission_id} var {rid id} {
          if {[set $value] ne ""} {
            set $var [set $value]
          }
        }
        set href [$examWf pretty_link -query [export_vars {
          {m print-answers} {create-file-submission-zip-file 1}
          fos rid id
        }]]
        append HTML [ns_trim -delimiter | [subst {
          |<a href='$href'>
          |<span class='download-submissions glyphicon glyphicon-download' aria-hidden='true'></span>
          |#xowf.Download_file_submissions#</a>
        }]]
      }

      #
      # Store statistics only in autograding cases, and only, when it
      # was a full evaluation of the exam. This has the advantage
      # that we do no have to partially update the statistics. These
      # are somewhat overly conservative assumptions for now, which
      # might be partially relaxed in the future.
      #
      if {$with_grading_table
          && !$as_student && $filter_submission_id eq "" && $creation_user eq "" && $revision_id eq ""
        } {
        set statistics {}
        set ia [$examWf instance_attributes]
        if {$autograde} {
          foreach var {__stats_success __stats_count} key {success count} {
            if {[$examWf exists $var]} {
              dict set statistics $key [$examWf set $var]
              $examWf unset $var
            }
          }
          :AM set_exam_results -obj $examWf statistics $statistics
        }
        :AM set_exam_results -obj $examWf results $results
      }

      return [list do_stream $do_stream HTML $HTML]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: participant_result
    #----------------------------------------------------------------------
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

          #
          # TODO: world-cloud statistics make mostly sense for the
          # inclass quizzes, but there these require still an
          # interface via "reporting_obj" instead of "add_statistics"
          # (although, for the purposes of the inclass-quiz,
          # randomization is not an issue.
          #
          #$f add_statistics -options {word_statistics word_cloud}

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
            ns_log warning "form-field [$f name] of type [$f info class] " \
                "does not provide variable correction via 'make_correct'"
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: answer_form_field_objs
    #----------------------------------------------------------------------
    :public method answer_form_field_objs {-clear:switch -wf:object -generic:switch form_info} {
      #
      # Instantiate the form_field objects of the provided form based on
      # form_info.
      #
      set key ::__test_item_answer_form_fields
      if {$clear} {
        #
        # The -clear option is needed, when there are multiple
        # assessments protocols/tables on the same page (currently
        # not).
        #
        unset -nocomplain $key
      } else {
        #ns_log notice "### answer_form_field_objs key exists [info exists $key]"
        if {![info exists $key]} {
          #ns_log notice "form_info: $form_info"
          set fc [lsort -unique [dict get $form_info disabled_form_constraints]]
          #ns_log notice "### FC $fc"
          set pc_params [::xo::cc perconnection_parameter_get_all]
          if {$generic} {
            set fc [:replace_in_fc -fc $fc shuffle_kind none]
            set fc [:replace_in_fc -fc $fc show_max ""]
          }
          set $key [$wf create_form_fields_from_form_constraints -lookup $fc]
          ::xo::cc perconnection_parameter_set_all $pc_params
          $wf form_field_index [set $key]
        }
        return [set $key]
      }
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: results_export
    #----------------------------------------------------------------------
    :public method results_export {
      {-manual_gradings "" }
      {-reply:switch false}
      results_dict
    } {
      #
      # Exports results as csv
      #
      # @param reply when false, csv will be returned as text, when
      #              true, it will be returned as response to the
      #              browser.
      # @param results_dict the results to format as csv, every key in
      #                     the dict represents a user_id.
      #
      # @return csv as value or as response to the client
      #
      set t [::xo::Table new -volatile \
                 -name results \
                 -columns {
                   Field create participant -label participant
                   Field create query_name -label query_name
                   Field create achieved -label achieved
                   Field create achievable -label achievable
                   Field create comment -label comment
                 }]
      foreach user_id [dict keys $results_dict] {
        set manual_grading [:dict_value $manual_gradings $user_id]
        foreach qn [dict keys [dict get $results_dict $user_id]] {
          set l [::xo::Table::Line new]
          $t add \
              -participant [acs_user::get_element \
                            -user_id $user_id \
                            -element username] \
              -query_name [string trimright $qn _] \
              -achievable [dict get $results_dict $user_id $qn achievable] \
              -achieved [dict get $results_dict $user_id $qn achieved] \
              -comment [:dict_value [:dict_value $manual_grading $qn] comment]
        }
      }
      if {$reply} {
        $t write_csv
      } else {
        $t format_csv
      }
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: grading_table
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: results_table
    #----------------------------------------------------------------------
    :public method results_table {
      -package_id:integer
      -items:object,required
      {-view_all_method print-answers}
      {-with_answers:boolean true}
      {-state done}
      {-grading_scheme ::xowf::test_item::grading::none}
      wf:object
    } {
      #
      # Render the results in format of a table and return HTML.
      # Currently deactivated.
      #

      #set form_info [:combined_question_form -with_numbers $wf]
      set form_info [:QM combined_question_form $wf]
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

      # if {0 && $autograde} {
      #   lappend form_field_objs \
          #       [$wf create_raw_form_field \
          #          -name _online-exam-total-score \
          #          -spec number,label=#xowf.Total-Score#] \
          #       [$wf create_raw_form_field \
          #            -name _online-exam-grade \
          #            -spec number,label=#xowf.Grade#]
      # }

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
        $p set_property -new 1 _online-exam-seconds [dict get $duration seconds]

        # if {0 && $autograde && $total_points > 0} {
        #   set final_score [expr {$total_score/$total_points}]
        #   $p set_property -new 1 _online-exam-total-score $final_score
        #
        #   set d [list achievedPoints $total_score achievablePoints $total_points totalPoints $total_points]
        #   set grade [$grading_scheme grade -achieved_points $d]
        #   dict incr grade_count $grade
        #   $p set_property -new 1 _online-exam-grade $grade
        # }
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: participants_table
    #----------------------------------------------------------------------
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
      set user_list {}
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
          lappend user_list [$p creation_user]
        } else {
          set notification_dialog_button ""
        }

        #
        # Extend every answer with corresponding precomputed extra
        # "_online-exam-*" values to ease rendering:
        #
        set duration [:get_duration [$p get_revision_sets]]
        $p set_property -new 1 _online-exam-seconds [dict get $duration seconds]
        $p set online-exam-fullName "$notification_dialog_button [$p set online-exam-fullName]"
      }

      ::xowiki::includelet::personal-notification-messages \
          modal_message_dialog_register_submit \
          -url [$wf pretty_link -query m=send-participant-message]

      set bulk_notification_HTML ""

      if {$state eq "done"} {
        set uc {tcl {[$p state] ne "done"}}
      } else {
        set uc {tcl {false}}

        if {[llength $user_list] > 0} {
          #
          # Provide bulk notification message dialog to send message to all users
          #
          set dialog_info [::xowiki::includelet::personal-notification-messages \
                               modal_message_dialog -to_user_id $user_list]
          append dialogs [dict get $dialog_info dialog] \n
          set notification_dialog_button [dict get $dialog_info link]
          set bulk_notification_HTML "<div class='bulk-personal-notification-message'>$notification_dialog_button #xowiki.Send_message_to# [llength $user_list] #xowf.Participants#</div>"
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
                    -uc $uc \
                    -view_field _online-exam-userName \
                    -view_filter_link [$wf pretty_link -query m=$view_all_method] \
                    {*}[expr {[info exists generate] ? [list -generate $generate] : ""}] \
                    -return_url [ad_return_url] \
                    -return_url_att local_return_url \
                   ]
      $table_widget destroy
      return $dialogs$HTML$bulk_notification_HTML
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: marked_results
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: answers_panel
    #----------------------------------------------------------------------
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

      set answers [:get_answer_attributes $wf]
      set nrParticipants [llength $answers]
      if {$current_question ne ""} {
        set answered [:FL answers_for_form \
                          [$current_question name] \
                          $answers]
      } else {
        set answered [:get_answer_attributes -state $target_state $wf]
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
        # Auto refresh of number of participants and submissions when
        # polling is on.
        #
        set url [$manager_obj pretty_link -query m=poll]
        template::add_body_script -script [subst -nocommands {
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
                  //activate links if a users started the exam
                  var answers = data.split('/');
                  if (answers.length == 2 && answers[1] > 0) {
                    var disabledLinkItems = document.querySelectorAll(".list-group-item.link-disabled");
                    disabledLinkItems.forEach(function(linkItem) {
                      linkItem.classList.remove("link-disabled");
                    });
                  }
                }
              };
              xhttp.send();
            }, 1000);
          })();
        }]
      }

      return $answerStatus
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: prevent_multiple_tabs
    #----------------------------------------------------------------------
    :public method prevent_multiple_tabs {
      {-cookie_name multiple_tabs}
    } {
      #
      # Prevent answering the same survey from multiple, concurrently
      # open tabs.
      #
      template::add_body_script -script [subst {
        var cookieLine = document.cookie.split('; ').find(row => row.startsWith('$cookie_name='));
        var cookieValue = (cookieLine === undefined) ? 1 : parseInt(cookieLine.split('=')\[1\]) + 1;
        // console.log("cookie $cookie_name " + cookieValue);
        if (cookieValue > 1) {
          alert('Already open!');
          window.open("about:blank", "_self").close();
        }
        document.cookie = "$cookie_name=" + cookieValue;
        // console.log("START finished -> " + document.cookie);

        window.onunload = function () {
          var cookieLine = document.cookie.split('; ').find(row => row.startsWith('$cookie_name='));
          var cookieValue = (cookieLine === undefined) ? 0 : parseInt(cookieLine.split('=')\[1\]) - 1;
          document.cookie = "$cookie_name=" + cookieValue;
          // console.log("UNLOAD finished -> " + document.cookie);
        };
      }]
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: countdown_timer
    #----------------------------------------------------------------------
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
      set nowIsoTime [clock format [expr {$nowMs/1000}] \
                          -format "%Y-%m-%dT%H:%M:%S"].[format %.3d [expr {$nowMs % 1000}]]

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
    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: get_exam_results
    #----------------------------------------------------------------------
    :public method get_exam_results {
      -obj:object,required
      property
      {default ""}
    } {
      set p [$obj childpage -name en:result -form inclass-exam-statistics.wf]
      set instance_attributes [$p instance_attributes]
      if {[dict exists $instance_attributes $property]} {
        #ns_log notice "get_exam_results <$property> returns value from " \
            "results page: [dict get $instance_attributes $property]"
        return [dict get $instance_attributes $property]
      }
      #ns_log notice "get_exam_results <$property> returns default"
      return $default
    }

    #----------------------------------------------------------------------
    # Class:  Answer_manager
    # Method: set_exam_results
    #----------------------------------------------------------------------
    :public method set_exam_results {
      -obj:object,required
      property
      value
    } {
      #ns_log notice "SES '$property' bytes [string length $value]"
      set p [$obj childpage -name en:result -form inclass-exam-statistics.wf]
      set instance_attributes [$p instance_attributes]
      dict set instance_attributes $property $value
      $p update_attribute_from_slot [$p find_slot instance_attributes] ${instance_attributes}
      #
      # cleanup of legacy values
      #
      set instance_attributes [$obj instance_attributes]
      foreach property_name [list $property __$property] {
        if {[dict exists $instance_attributes $property_name]} {
          ns_log notice "SES set_exam_results:" \
              "clearing values from earlier releases for '$property_name'" \
              "was <[dict get $instance_attributes $property_name]>"
          dict unset instance_attributes $property_name
          $obj set instance_attributes $instance_attributes
          #ns_log notice "FINAL IA <$instance_attributes> for item_id [$obj item_id]" \
              "revision_id [$obj revision_id]"
          $obj update_attribute_from_slot [$obj find_slot instance_attributes] $instance_attributes
          ::xo::xotcl_object_cache flush [$obj item_id]
          ::xo::xotcl_object_cache flush [$obj revision_id]
        }
      }
    }
  }

  AssessmentInterface {*}$register_command AM \
      [Answer_manager create answer_manager]
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
    #   - pagination_actions
    #
    #   - current_question_form
    #   - current_question_obj
    #   - current_question_name
    #   - current_question_title
    #   - nth_question_obj
    #   - nth_question_form
    #
    #   - exam_configuration_popup
    #   - exam_configuration_modifiable_field_names
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
    #   - exam_base_time
    #
    #   - percent_substitute_in_form
    #   - item_substitute_markup
    #
    #   - describe_form
    #   - question_summary
    #   - question_info_block
    #

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: initialize
    #----------------------------------------------------------------------
    :public method initialize {-wfi:object} {
      #
      # Initialize the question manager for a certain workflow
      # instance. This is needed for per-answer-workflow questions (as
      # for pool questions, where different questions are taken for
      # different users).
      #

      #ns_log notice "QM initialize wfi $wfi"
      set isAnswerInstance [expr {[$wfi is_wf_instance] == 1 && [$wfi is_wf] == 0}]
      if {$isAnswerInstance} {
        #ns_log notice "QM initialize answer instance [$wfi name] // [$wfi instance_attributes]"
        set :wfi $wfi
      } else {
        ns_log warning "initializing question manager for not an answer instance [$wfi name]" \
            "// [$wfi instance_attributes]"
      }
    }


    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: get_pool_replacement_candidates
    #----------------------------------------------------------------------
    :method get_pool_replacement_candidates {
      {-allowed_forms en:edit-interaction.wf}
      {-minutes}
      {-points}
      {-fc_dict}
      {-lang ""}
      pool_question_obj
    } {
      #
      # Obtain for the specs in the pool_question_obj potential
      # replacement items.
      #
      set parent_id [$pool_question_obj parent_id]
      set package_id [$pool_question_obj package_id]

      #
      # We want to select only instances of these edit workflows
      # specified in allowed_forms.
      #
      set form_objs [::$package_id instantiate_forms \
                         -parent_id $parent_id \
                         -forms $allowed_forms]
      set form_object_item_ids [lmap f $form_objs {$f item_id}]

      set pattern [dict get $fc_dict pattern]
      set item_types [dict get $fc_dict item_types]
      set folder [dict get $fc_dict folder]

      set item_ref_info [::$package_id item_ref \
                             -use_package_path 0 \
                             -default_lang en \
                             -parent_id $parent_id \
                            $folder]
      set folder_id [:dict_value $item_ref_info item_id]

      #
      # In case, all item types are selected, no additional clauses
      # are needed.
      #
      if {[::xowiki::formfield::pool_question all_item_types_selected $item_types]} {
        set w_clauses ""
      } else {
        set w_clauses [list "item_type = [join $item_types |]"]
      }

      #
      # Never include PoolQuestions as a replacement for a pool
      # question.
      #
      set u_clauses [list "item_type = PoolQuestion"]

      #
      # Perform language selection based on the name and combine this
      # with the provided pattern.
      #
      if {$pattern eq ""} {
        set pattern *
      }
      if {$lang ne ""} {
        lappend w_clauses "_name matches ${lang}:$pattern"
      } elseif {$pattern ne "*"} {
        lappend w_clauses "_name matches $pattern"
      } else {
        #
        # In case thjere is no pattern and no lang provided, there is
        # no filter necessary.
        #
      }

      # The matching of minutes and points are more complex due to
      # mutual completion (see below).
      #
      #if {$minutes ne ""} {
      #  lappend w_clauses "question matches *question.minutes $minutes*"
      #}

      set filters [::xowiki::FormPage compute_filter_clauses \
                       {*}[expr {[llength $u_clauses] > 0 ? [list -unless [join $u_clauses &&]] : ""}] \
                       {*}[expr {[llength $w_clauses] ? [list -where [join $w_clauses &&]] : ""}] \
                      ]

      #ns_log notice "get_pool_replacement_candidates filters $filters"
      #ns_log notice "get_pool_replacement_candidates filters WC $w_clauses -->\n[dict get $filters wc]"
      #ns_log notice "get_pool_replacement_candidates filters UC $u_clauses -->\n[dict get $filters uc]"

      #
      # In case the folder_id is a symbolic link to a different
      # folder, resolve the link and reset the folder_id to the
      # item_id of the link target.
      #
      # In case we have links to different packages, some more work
      # might be required (e.g. instantiate the other package, etc.).
      #
      if {![nsf::is object ::$folder_id]} {
        ::xowiki::FormPage get_instance_from_db -item_id $folder_id
      }
      if {[::$folder_id is_link_page]} {
        set targetObj [::$folder_id get_target_from_link_page]
        set folder_id [$targetObj item_id]
      }

      #
      # TODO: one has to check the performance of the generic
      # get_form_entries on learn with larger question pools. It would
      # be possible to provide a quicker query based on the
      # xowiki*item_index joined with acs-objects instead of the
      # generic view used in get_form_entries. ... but maybe the
      # current approach with caching is already quick enough.
      #
      set items [::xowiki::FormPage get_form_entries \
                     -base_item_ids ${form_object_item_ids} \
                     -form_fields {} \
                     -publish_status ready \
                     -parent_id $folder_id \
                     -package_id ${package_id} \
                     -h_where [dict get $filters wc] \
                     -h_unless [dict get $filters uc] \
                     -initialize false \
                     -from_package_ids ""]

      ns_log notice "get_pool_replacement_candidates parent_id $folder_id -> [llength [$items children]]"

      #
      # Since we allow the user to specify either minutes or points,
      # and use the specified values as defaults for the others, we
      # have to replace the empty values with the defaults (mutual
      # completion).
      #
      if {$minutes eq "" && $points ne ""} {
        set minutes $points
      } elseif {$minutes ne "" && $points eq ""} {
        set points $minutes
      }

      set result ""
      foreach item [$items children] {
        set qn [:qualified_question_names $item]
        set ia [$item set instance_attributes]
        set qa [dict get $ia question]

        #
        # Replace empty values for "minutes" and "points" with the
        # defaults before comparing.
        #
        set item_minutes [dict get $qa question.minutes]
        set item_points [dict get $qa question.points]
        if {$item_minutes eq "" && $item_points ne ""} {
          set item_minutes $item_points
        } elseif {$item_minutes ne "" && $item_points eq ""} {
          set item_points $item_minutes
        }
        #ns_log notice "get_pool_replacement_candidates filter" \
            "minutes '$minutes' <-> '$item_minutes'," \
            "points '$points ' <-> '$item_points'"
        if {$minutes ne "" && $item_minutes ne $minutes} {
          continue
        } elseif {$points ne "" && $item_points ne $points} {
          continue
        }

        dict set result $qn item_id [$item item_id]
        dict set result $qn item_type [dict get $ia item_type]
        #dict set result $qn question_dict $qa
      }

      #ns_log notice "=============== get_pool_replacement_candidates returns $result"
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: get_pool_questions
    #----------------------------------------------------------------------
    :public method get_pool_questions {
      {-allowed_forms en:edit-interaction.wf}
      {-field_name ""}
      pool_question_obj
      exam_question_names
    } {
      #
      # Obtain for the specs in the pool_question_obj potential
      # replacement items in form of a replacement dict. For raw forms
      # (i.e., not obtained via the renaming form-loader), we have just
      # the plain "answer", which can be provided via the "field_name"
      # attribute.
      #
      set query_dict [:fc_to_dict [$pool_question_obj property form_constraints]]
      if {$field_name eq ""} {
        #
        # No field name was provided, so get the field name from the
        # question obj.
        #
        set field_name [:FL form_name_based_attribute_stem [$pool_question_obj name]]
        if {![dict exists $query_dict $field_name]} {
          #
          # Fall back to field_name "answer". This will be necessary,
          # when called with question_objs not adapted by the renaming
          # form-loader.
          #
          if {[dict exists $query_dict answer]} {
            ns_log notice "get_pool_questions: fallback from field_name '$field_name' to 'answer'"
            set field_name answer
          }
        }
      } elseif {![dict exists $query_dict $field_name]} {
        ns_log warning "QM get_pool_questions: the provided field name '$field_name'" \
            "is not defined in the form_constraints, fall back to '[lindex [dict keys $query_dict] 0]'"
        set field_name [lindex [dict keys $query_dict] 0]
      }
      set question_attributes [dict get [$pool_question_obj instance_attributes] question]
      set minutes [dict get $question_attributes question.minutes]
      set points [dict get $question_attributes question.points]

      set fc_dict [dict get $query_dict $field_name]
      set lang [string range [$pool_question_obj nls_language] 0 1]

      append key test-item-replacement-cands \
          - $minutes - $points - $lang - $fc_dict - [$pool_question_obj revision_id]
      ns_log notice "get_pool_questions fetch via key: '$key'"

      return [ns_cache_eval -expires 1m -- ns:memoize $key {
        :get_pool_replacement_candidates \
            -minutes $minutes \
            -points $points \
            -fc_dict $fc_dict \
            -lang $lang \
            $pool_question_obj
      }]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: replace_pool_question
    #----------------------------------------------------------------------
    :public method replace_pool_question {
      -position
      -seed
      {-allowed_forms en:edit-interaction.wf}
      {-field_name ""}
      -pool_question_obj
      -exam_question_names
    } {
      #
      # @return an initialized replacement form obj if this is possible
      #
      set field_name ""; ## rely on fallback
      set candidate_dict [:get_pool_questions  \
                              -allowed_forms $allowed_forms \
                              -field_name $field_name \
                              $pool_question_obj \
                              $exam_question_names]

      set candidate_names [dict keys $candidate_dict]
      set nrCandidates [llength $candidate_names]
      if {$nrCandidates == 0} {
        set h [ns_set iget [ns_conn headers] referrer]
        set url [join [lrange [split [xo::cc url] /] 0 end-1] /]?m=edit
        util_user_message -message "could not find a replacement item for pool question: no matching item found"
        ad_returnredirect $url
        ad_script_abort
      }

      #
      # It might be the case that we select the same item for an exam
      # twice. Therefore, we have to iterate, until we find different
      # items.
      #
      expr {srand($seed)}
      set maxiter 100
      while {1} {
        set i [expr {int(($nrCandidates) * rand())}]
        set new_name [lindex $candidate_names $i]
        #ns_log notice "replace_pool_question position $position seed $seed random_index $i"

        set contained [expr {$new_name in $exam_question_names}]
        #ns_log notice "replace_pool_question replace [$pool_question_obj name] by $new_name contained in" \
        #    "[lsort $exam_question_names] contained $contained"
        if {!$contained || [incr maxiter -1] < 0} {
          break
        }
      }
      if {$contained} {
        error "could not find a replacement item for [$pool_question_obj name]: only duplicate items found"

      }
      set form_obj [::xowiki::FormPage get_instance_from_db \
                        -item_id [dict get $candidate_dict $new_name item_id]]

      #$form_obj initialize

      # ns_log notice [$form_obj serialize]
      return $form_obj
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: replace_pool_questions
    #----------------------------------------------------------------------
    :public method replace_pool_questions {
      -answer_obj:object
      -exam_obj:object
    } {
      #
      # Replaces all pool questions for the exam by random items.  In
      # case there were replacement items, set/update the property
      # "question" for the individual answer_obj.
      #
      # @param answer_obj the workflow instance of the answer workflow
      # @param exam_obj the exam objject to which the answer_object belongs to
      #
      if {[$answer_obj property question] ne ""} {
        ns_log notice "answer_obj $answer_obj has already a 'question' property" \
            [lsort [dict keys [$answer_obj instance_attributes]]]
        return
      }
      set exam_question_names [$exam_obj property question]
      set form_objs [:load_question_objs $exam_obj $exam_question_names]

      #
      # Make sure to normalize all names to ease comparison
      #
      set original_question_names [:qualified_question_names $form_objs]

      set replaced_form_objs {}
      set position 0
      set seeds [$answer_obj property seeds]
      foreach form_obj $form_objs {
        #ns_log notice "YYY check item_type '[$form_obj property item_type]' // [$form_obj instance_attributes]"
        if {[$form_obj property item_type] eq "PoolQuestion"} {
          set replaced_form_obj [:replace_pool_question \
                                     -position $position \
                                     -seed [lindex $seeds $position] \
                                     -pool_question_obj $form_obj \
                                     -exam_question_names $exam_question_names]
          set exam_question_names [lreplace $exam_question_names $position $position \
                                       [:qualified_question_names $replaced_form_obj]]
          lappend replaced_form_objs $replaced_form_obj
        } else {
          lappend replaced_form_objs $form_obj
        }
        incr position
      }
      #ns_log notice "YYYY OLD NAMES [join $original_question_names { }]"
      #ns_log notice "YYYY UPD NAMES [join $exam_question_names { }]"
      if {![:list_equal $original_question_names $exam_question_names]} {
        ns_log notice "YYYY store question names in user's answer workflow"
        $answer_obj set_property -new 1 question $exam_question_names
        #$answer_obj set_property -new 1 question_ids [lmap obj $replaced_form_objs {$obj item_id}]
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: goto_page
    #----------------------------------------------------------------------
    :public method goto_page {obj:object position} {
      #ns_log notice "===== goto_page $position"
      #
      # Set the position (test item number) of the workflow
      # (exam). This sets the question number shown to the user.
      #
      $obj set_property position $position
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: more_ahead
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: pagination_button_css
    #----------------------------------------------------------------------
    :method pagination_button_css {
      {-CSSclass "btn-sm"}
      {-cond:boolean,required}
      {-extra ""}
    } {
      if {$cond} {
        append CSSclass " " $extra
      }
      return $CSSclass
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: pagination_actions
    #----------------------------------------------------------------------
    :public method pagination_actions {
      -container:object
      -question_count:integer
      {-visited:integer,0..n {}}
      {-flagged:integer,0..n {}}
      -current_position:integer
      {-CSSclass "btn-sm"}
    } {
      #
      # Create actions used for pagination.
      #
      set actions ""

      if {$question_count > 1} {
        set extra_css [:pagination_button_css \
                           -CSSclass $CSSclass \
                           -cond [expr {$current_position == 0}] \
                           -extra "disabled"]
        ${container}::previousQuestion configure \
            -extra_css_class $extra_css \
            -label "&laquo;" \
            -label_noquote true \
            -wrapper_CSSclass "pagination"
        lappend actions previousQuestion

        for {set count 1} {$count <= $question_count} {incr count} {
          set visited_css [expr {($count - 1) in $visited ? "visited" : ""}]
          set flag_label [expr {($count - 1) in $flagged
                                ? " <span class='glyphicon glyphicon-flag text-danger'></span>" : ""}]
          set extra_css [:pagination_button_css \
                             -CSSclass "$CSSclass $visited_css" \
                             -cond [expr {$current_position == $count - 1 }] \
                             -extra "active current"]
          ${container}::Action create ${container}::q.$count \
              -label "$count$flag_label" \
              -label_noquote true \
              -state_safe true \
              -next_state working \
              -wrapper_CSSclass "pagination" \
              -extra_css_class $extra_css \
              -proc activate {obj} [subst {
                #ns_log notice "===== NAVIGATE next"
                next
                #ns_log notice "===== NAVIGATE goto [expr {$count - 1}]"
                :goto_page [expr {$count - 1}]
              }]
          lappend actions q.$count
        }
        set extra_css [:pagination_button_css \
                           -CSSclass $CSSclass \
                           -cond [expr {$current_position+2 > $question_count}] \
                           -extra "disabled"]
        ${container}::nextQuestion configure \
            -extra_css_class $extra_css \
            -label "&raquo;" \
            -label_noquote true \
            -wrapper_CSSclass "pagination"

        set flag_state [expr {$current_position in $flagged ? "delete" : "set"}]
        ${container}::flag configure \
            -label "#xowf.flag_${flag_state}#" \
            -title "#xowf.flag_${flag_state}_title#"

        lappend actions nextQuestion
      }
      return $actions
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: qualified_question_names
    #----------------------------------------------------------------------
    :method max_items {max:integer,0..1 list} {
      if {$max ne "" && $max < [llength $list]} {
        return [lrange $list 0 $max-1]
      }
      return $list
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: qualified_question_names
    #----------------------------------------------------------------------
    :method qualified_question_names {question_objs} {
      #
      # Return the question names with parent folder in form of an
      # item-ref. We assume here, all question_objs are from the same
      # xowf instance. We will need item-refs pointing to other
      # instances in the future.
      #
      lmap question_obj $question_objs {
        set parent_id [$question_obj parent_id]
        if {![nsf::is object ::$parent_id]} {
          ::xowiki::FormPage get_instance_from_db -item_id $parent_id
        }
        set ref [::$parent_id name]/[$question_obj name]
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: load_question_objs
    #----------------------------------------------------------------------
    :public method load_question_objs {obj:object names} {
      #
      # Load the question objects for the provided question names and
      # return the question objs.
      #

      set parent_id [$obj parent_id]
      #
      # Make sure to have names pointing to a folder.
      # In case, '$ref' refers to a site-wide page, a prefix with
      # the parent name would not help. In these cases, we expect
      # to have the parent obj not instantiated.
      #
      if {[nsf::is object ::$parent_id]} {
        set names [lmap ref $names {
          if {![string match "*/*" $ref]} {
            set ref [::$parent_id name]/$ref
          }
          set ref
        }]
      }
      #ns_log notice "XXX [$obj name] load_question_objs names = <$names>"
      #xo::show_stack
      set questionNames [join $names |]
      set questionForms [::[$obj package_id] instantiate_forms \
                             -default_lang [$obj lang] \
                             -forms $questionNames]

      if {[llength $questionForms] < [llength $names]} {
        if {[llength $names] == 1} {
          ns_log warning "load_question_objs: question '$names' could not be loaded"
        } else {
          set loaded [llength $questionForms]
          set out_of [llength $names]
          ns_log warning "load_question_objs: only $loaded out of $out_of from '$names' could be loaded"
        }
      }
      return $questionForms
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: current_question_name
    #----------------------------------------------------------------------
    :method current_question_name {obj:object} {
      set questions [:question_names $obj]
      return [lindex $questions [$obj property position]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: current_question_obj
    #----------------------------------------------------------------------
    :public method current_question_obj {obj:object} {
      #
      # Load the current question obj based on the current question
      # name.
      #
      return [:load_question_objs $obj [:current_question_name $obj]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: shuffled_index
    #----------------------------------------------------------------------
    :public method shuffled_index {{-shuffle_id:integer -1} obj:object position} {
      #
      # Return the shuffled index position, in case shuffling is turned on.
      #
      if {$shuffle_id > -1} {
        #
        # Take always all questions as the basis for randomization,
        # also when "max_items" is set.
        #
        set shuffled [::xowiki::randomized_indices \
                          -seed $shuffle_id \
                          [:question_count -all $obj]]
        set position [lindex $shuffled $position]
        #ns_log notice "shuffled_index question_count [:question_count $obj] -> <$shuffled> -> position $position"
      }
      return $position
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_objs
    #----------------------------------------------------------------------
    :public method question_objs {{-shuffle_id:integer -1} obj:object} {
      #
      # For the provided assessment object, return the question
      # objects in the right order, depending on the shuffle_id.
      #
      :assert_assessment $obj
      set form_objs [:load_question_objs $obj [:question_names $obj]]
      #ns_log notice "question_objs from $obj => $form_objs shuffle_id $shuffle_id"

      if {$shuffle_id > -1} {
        set result {}
        foreach i [::xowiki::randomized_indices -seed $shuffle_id [llength $form_objs]] {
          lappend result [lindex $form_objs $i]
        }
        set form_objs $result
      }

      #
      # Return at most max items, when specified.
      #
      return [:max_items [$obj property max_items ""] $form_objs]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_names
    #----------------------------------------------------------------------
    :public method question_names {obj:object} {
      #
      # Return the names of the questions of an assessment.
      #
      if {[info exists :wfi]} {
        if {![nsf::is object ${:wfi}]} {
          ns_log notice "we cannot trust :wfi '${:wfi}', probably a leftover"
          unset :wfi
        }
      }
      if {[info exists :wfi] && [${:wfi} property question] ne ""} {
        set names [${:wfi} property question]
        #ns_log notice "question_names returns obj-specific [join $names]"
      } else {
        set names [$obj property question]
        #ns_log notice "question_names returns wf-names ($obj property): [join $names]"
      }
      return $names
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_count
    #----------------------------------------------------------------------
    :public method question_count {{-all:switch false} obj:object} {
      #
      # Return the number questions in an exam. It is either the
      # number of defined questions, or it might be restricted by the
      # property max_items (if defined for "obj").
      #
      set nr_questions [llength [:question_names $obj]]
      if {!$all} {
        set max_items [$obj property max_items ""]
        if {$max_items ne ""} {
          if {$max_items < $nr_questions} {
            set nr_questions $max_items
          }
        }
      }
      return $nr_questions
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: add_seeds
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: nth_question_obj
    #----------------------------------------------------------------------
    :public method nth_question_obj {obj:object position:integer} {
      #
      # Return the nth question object of an assessment (based on
      # position).
      #
      :assert_assessment $obj
      set questions [:question_names $obj]
      set result [:load_question_objs $obj [lindex $questions $position]]
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: percent_substitute
    #----------------------------------------------------------------------
    :method percent_substitute {-verbose:switch -substvalues -seed text} {
      set result ""
      set start 0
      foreach {p0 p1 p2} [regexp -all -inline -indices {%([a-zA-Z0-9_]+)[.]?([a-zA-Z0-9_]*)%} $text] {
        lassign $p0 first last
        set match [string range $text $first $last]
        set m1 [string range $text {*}$p1]
        set m2 [string range $text {*}$p2]
        if {[dict exists $substvalues $m1]} {
          set values [dict get $substvalues $m1]
          if {[info exists seed]} {
            set index [::xowiki::randomized_index -seed $seed [llength $values]]
            #ns_log notice "XXX percent_substitute called with seed <$seed> -> index $index <[llength $values]>"
            set value [lindex $values $index]
          } else {
            set value [lindex $values 0]
          }
          if {$m2 ne "" && [dict exists $value $m2]} {
            set value [dict get $value $m2]
            if {$verbose} {
              #ns_log notice "XXX percent_substitute chooses '$value' for $m2 from <$values>"
            }
          }
          set replacement $value
        } else  {
          set replacement '$match'
        }
        append result \
            [string range $text $start $first-1] \
            $replacement
        set start [incr last]
      }
      append result [string range $text $start [string length $text]]
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: percent_substitute_in_form
    #----------------------------------------------------------------------
    :public method percent_substitute_in_form {
      -obj:object
      -form_obj:object
      -position:integer
      html
    } {
      #
      # Perform percent substitution in the provided HTML,
      # form_constraints and disabled_form_constraints and return the
      # result as a dict.
      #
      set form_name [$form_obj name]
      set seed [lindex [$obj property seeds] $position]
      set substvalues [$form_obj property substvalues]
      #ns_log notice "CHECK-AA $form_name seed <$seed> // seeds <[$obj property seeds]> // subs '$substvalues'"

      set fc [$form_obj property form_constraints]
      set dfc [$form_obj property disabled_form_constraints]

      if {$seed eq "" && $substvalues ne ""} {
        ns_log warning "percent_substitute_in_form cannot substitute percent variables in $form_name"
      } else {
        if {$substvalues ne ""} {
          set html [:percent_substitute \
                        -seed $seed \
                        -substvalues $substvalues \
                        $html]
          set fc [:percent_substitute \
                      -seed $seed \
                      -substvalues $substvalues \
                      $fc]
          set dfc [:percent_substitute -verbose \
                       -seed $seed \
                       -substvalues [$form_obj property substvalues] \
                       $dfc]
        }
      }
      return [list form $html form_constraints $fc disabled_form_constraints $dfc]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: item_substitute_markup
    #----------------------------------------------------------------------
    :public method item_substitute_markup {
      -obj:object
      -form_obj:object
      {-position:integer}
      {-do_substitutions:switch 1}
    } {
      #
      # Substitute everything item-specific in the text, including
      # markup (handling e.g. images resolving in the context of the
      # original question) and also percent-substitutions (if
      # desired).
      #
      ns_log notice "=== item_substitute_markup [$form_obj name] do percent subst [info exists position]"
      :assert_answer_instance $obj
      $obj do_substitutions $do_substitutions
      set html [$obj substitute_markup \
                    -context_obj $form_obj \
                    [$form_obj property form]]

      if {[info exists position]} {
        return [:percent_substitute_in_form \
                    -obj $obj \
                    -form_obj $form_obj \
                    -position $position \
                    $html]
      } else {
        set fc [$form_obj property form_constraints]
        set dfc [$form_obj property disabled_form_constraints]
        return [list form $html form_constraints $fc disabled_form_constraints $dfc]
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: disable_text_field_feature
    #----------------------------------------------------------------------
    :method disable_text_field_feature {form_obj:object feature} {
      #
      # This function changes the form_constraints of the provided
      # form object by adding "$feature=false" properties to textarea or
      # text_fields entries.
      #
      set fc {}
      foreach e [$form_obj property form_constraints] {
        if {[regexp {^[^:]+_:(textarea|text_fields)} $e]} {
          #ns_log notice "======= turn $feature off"
          append e , $feature=false
        }
        lappend fc $e
      }
      $form_obj set_property form_constraints $fc
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: disallow_paste
    #----------------------------------------------------------------------
    :public method disallow_paste {form_obj:object} {
      #
      # This function changes the form_constraints of the provided
      # form object by adding "paste=false" properties to textarea or
      # text_fields entries.
      :disable_text_field_feature $form_obj paste
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: disallow_spellcheck
    #----------------------------------------------------------------------
    :public method disallow_spellcheck {form_obj:object} {
      #
      # This function changes the form_constraints of the provided
      # form object by adding "spellcheck=false" properties to textarea or
      # text_fields entries.
      #
      :disable_text_field_feature $form_obj spellcheck
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_randomization_ok
    #----------------------------------------------------------------------
    :method question_randomization_ok {form_obj} {
      set randomizationOk 1
      set qd [:dict_value [$form_obj instance_attributes] question]
      if {$qd ne ""} {
        #
        # No question should have shuffle "always".
        #
        if {[:dict_value $qd question.shuffle] eq "always"} {
          #ns_log notice "FOUND shuffle $qd"
          set randomizationOk 0
        }
      }
      return $randomizationOk
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_is_autograded
    #----------------------------------------------------------------------
    :method question_is_autograded {form_obj} {
      #
      # Return boolean information whether this question is autograded.
      #

      set formAttributes [$form_obj instance_attributes]
      if {[dict exists $formAttributes question]} {
        #
        # Check autograding and randomization for exam.
        #
        set qd [dict get [$form_obj instance_attributes] question]

        #
        # For autoGrade, we assume currently to have either a grading,
        # or a question, where every alternative is exactly provided.
        #
        if {[dict exists $qd question.grading]} {
          #
          # autograde ok on the item type level
          #
          set autoGrade 1

        } elseif {[:dict_value $formAttributes auto_correct 0]} {
          #
          # auto_correct is in principle enabled, check details on
          # the concrete question item.
          #
          set autoGrade 1

          if {[:dict_value $formAttributes item_type] eq "ShortText"} {
            #
            # Check, if the correct_when specification of a short text
            # question is suited for autocorrection. On the longer
            # range, this function should be moved to a different
            # place.
            #

            set dict [lindex [:fc_to_dict [dict get $formAttributes form_constraints]] 1]
            foreach a [dict get $dict answer] {
              set op ""
              regexp {^(\S+)\s} $a . op
              if {$op ni {eq lt le gt ge btwn AND}} {
                ns_log notice "question_info [$form_obj name]: not suited for autoGrade: '$a'"
                set autoGrade 0
                break
              }
              if {$op eq "AND"} {
                foreach c [lrange $a 1 end] {
                  set op ""
                  regexp {^(\S+)\s} $c . op
                  if {$op ni {eq lt le gt ge btwn}} {
                    ns_log notice "question_info [$form_obj name]: not suited for autoGrade: AND clause '$c'"
                    set autoGrade 0
                    break
                  }
                }
              }
            }
          }
        } elseif [dict exists $qd question.interaction question.interaction.answer] {
          set autoGrade 1

          set answer [dict get $qd question.interaction question.interaction.answer]
          foreach k [dict keys $answer] {
            if {![dict exists $answer $k $k.correct]} {
              set autoGrade 0
            }
          }
        } else {
          set autoGrade 0
        }
        #ns_log notice "question_info [$form_obj name] [$form_obj title] autoGrade $autoGrade"
      } else {
        set autoGrade 0
      }
      return $autoGrade
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_form
    #----------------------------------------------------------------------
    :public method aggregated_form {
      {-titleless_form:switch false}
      {-with_grading_box ""}
      question_infos
    } {
      #
      # Compute an aggregated form (containing potentially multiple
      # questions) based on the chunks available in question_infos.
      #
      # @return HTML form content
      #
      set full_form ""
      set count 0
      foreach \
          question_form [dict get $question_infos question_forms] \
          title_info [dict get $question_infos title_infos] \
          question_obj [dict get $question_infos question_objs] {
            set item_type [$question_obj property item_type]
            append full_form \
                "<div class='test-item' data-item_type='$item_type'>"

            if {!$titleless_form} {
              append full_form \
                  "<h4>[dict get $title_info full_title]</h4>\n"
            }
            if {$with_grading_box ne ""} {
              set question_name [:FL form_name_based_attribute_stem [$question_obj name]]
              set visible [expr {$with_grading_box eq "hidden" ? "hidden" : ""}]
              if {$with_grading_box eq "hidden"} {
                set question_name answer_$question_name
              }
              append full_form [subst [ns_trim -delimiter | {
                |<div id='grading-box-[incr count]' class='grading-box $visible'
                |     data-question_name='$question_name' data-title='[$question_obj title]'
                |     data-question_id='[$question_obj item_id]'>
                |  #xowf.Points#: <span class='points'></span>
                |  <span class='percentage'></span>
                |  <span class='feedback-label'>#xowf.feedback#: </span><span class='comment'></span>
                |  <a class='manual-grade' href='#' data-toggle='modal' data-target='#grading-modal'>
                |    <span class='glyphicon glyphicon-pencil' aria-hidden='true'></span>
                |  </a>
                |</div>
              }]]
            }
            append full_form $question_form \n</div>
          }

      regsub -all {<[/]?form>} $full_form "" full_form
      #ns_log notice "aggregated_form: STRIP FORM xxx times from full_form"
      return $full_form
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_info
    #----------------------------------------------------------------------
    :public method question_info {
      {-numbers ""}
      {-with_title:switch false}
      {-with_minutes:switch false}
      {-with_points:switch false}
      {-titleless_form:switch false}
      {-obj:object}
      {-user_answers:object,0..1 ""}
      {-no_position:switch false}
      {-question_number_label #xowf.question#}
      {-positions:int,0..n ""}
      form_objs
    } {
      #
      # Returns a dict containing "form", "title_infos",
      # "form_constraints" "disabled_form_constraints"
      # "randomization_for_exam" "autograde" and "question_objs". This
      # information is obtained from the provided "form_objs".
      #
      # @return dict containing "title_infos", "form_constraints",
      #    "disabled_form_constraints", "randomization_for_exam",
      #     "autograde", "question_forms", "question_objs"
      set full_fc {}
      set full_disabled_fc {}
      set title_infos {}
      set question_forms {}

      set randomizationOk 1
      set autoGrade 1

      if {[llength $positions] == 0} {
        set position -1
        set positions [lmap form_obj $form_objs {incr position}]
      }

      foreach form_obj $form_objs number $numbers position $positions {
        set form_obj [:FL rename_attributes $form_obj]
        set form_title [$form_obj title]
        set minutes [:question_property $form_obj minutes]
        set points [:question_property $form_obj points]
        if {$points eq ""} {
          #ns_log notice "[$form_obj name]: NO POINTS, default to minutes $minutes"
          set points $minutes
        }
        set time_budget [$obj property time_budget]
        if {$time_budget ni {"" 100} && $minutes ne ""} {
          set minutes [expr {$time_budget*$minutes/100.0}]
          ns_log notice "[$form_obj name]: TIME BUDGET '$time_budget' -> minutes set to $minutes"
        }
        set mapping {show_points with_points show_minutes with_minutes}
        foreach property {show_points show_minutes} {
          if {[$obj property $property] ne ""} {
            set [dict get $mapping $property] [$obj property $property]
            #ns_log notice "[$form_obj name]: override flag via exam setting: '$property' -> [$obj property $property]"
          }
        }
        set title ""
        if {$number ne ""} {
          append title "$question_number_label $number:"
        }

        set title_components {}
        if {$with_title} {
          lappend title_components [ns_quotehtml $form_title]
        }
        if {$with_minutes} {
          lappend title_components [:minutes_string $form_obj]
        }
        if {$with_points} {
          lappend title_components [:points_string $form_obj]
        }
        append title " " [join $title_components " - "]

        #
        # The flag "no_position" is just provided for the composite
        # form, in cases where we are called at form generation time,
        # where the position is different from the position in the
        # exam. When the position is fixed, we do not provide it as an
        # argument. As a consequence, the percent substitution is not
        # performed, since it would return always very similar values
        # based on a fixed position.
        #
        if {$no_position} {
          set positionArg {}
        } else {
          set positionArg [list -position $position]
        }
        #ns_log notice "CHECK 0 user_answers <$user_answers> (obj is the inclass exam [$obj name])"
        if {$user_answers eq ""} {
          set user_answers $obj
        }
        #
        # Resolve links in the context of the resolve_object
        #
        set d [:item_substitute_markup \
                   -obj $user_answers \
                   {*}$positionArg \
                   -form_obj $form_obj]

        lappend question_forms [dict get $d form]
        lappend title_infos [list full_title $title \
                                 title $form_title \
                                 minutes $minutes \
                                 points $points \
                                 number $number]
        lappend full_fc [:add_to_fc \
                             -fc [dict get $d form_constraints] \
                             -minutes $minutes \
                             -points $points \
                             {*}$positionArg]

        lappend full_disabled_fc [:add_to_fc \
                                      -fc [dict get $d disabled_form_constraints] \
                                      -minutes $minutes \
                                      -points $points \
                                      {*}$positionArg]

        if {![:question_is_autograded $form_obj]} {
          set autoGrade 0
        }
        if {![:question_randomization_ok $form_obj]} {
          set randomizationOk 0
        }
      }

      return [list \
                  title_infos $title_infos \
                  form_constraints [join [lsort -unique $full_fc] \n] \
                  disabled_form_constraints [join [lsort -unique $full_disabled_fc] \n] \
                  randomization_for_exam $randomizationOk \
                  autograde $autoGrade \
                  question_forms $question_forms \
                  question_objs $form_objs]
    }


    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_property
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: minutes_string
    #----------------------------------------------------------------------
    :public method minutes_string {form_obj:object} {
      #
      # Get an attribute of the original question
      #
      set minutes [:question_property $form_obj minutes]
      if {$minutes ne ""} {
        set pretty_label [expr {$minutes eq "1" ? [_ xowf.Minute] : [_ xowf.Minutes]}]
        set minutes "($minutes $pretty_label)"
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: points_string
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: combined_question_form
    #----------------------------------------------------------------------
    :public method combined_question_form {
      {-with_numbers:switch false}
      {-with_title:switch false}
      {-with_minutes:switch false}
      {-with_points:switch false}
      {-user_specific:switch false}
      {-shuffle_id:integer -1}
      {-user_answers:object,0..1 ""}
      {-form_objs:object,0..1 ""}
      obj:object
    } {
      #
      # For the provided assessment, return a combined question_form
      # as a single (combined) form, containing the content of all
      # question forms. The result is a dict, containing also title
      # information etc. depending on the provided parameters.
      #
      # @param shuffle_id used only for selecting form_objs
      # @param obj is the exam
      # @param user_answers instance of the answer-wf.
      #        Needed for user-specific percent substitutions.

      #ns_log notice "combined_question_form called with user_answers <$user_answers> for $obj [$obj name]"
      #if {$user_answers eq ""} {xo::show_stack}

      set all_form_objs [:question_objs -shuffle_id $shuffle_id $obj]
      set positions {}
      if {[llength $form_objs] > 0} {
        foreach form_obj $form_objs {
          lappend positions [lsearch $all_form_objs $form_obj]
        }
      }
      #ns_log notice "XXX combined_question_form fos=$form_objs all_form_objs=$all_form_objs <$positions>"

      if {$user_specific} {
        set form_objs [:max_items [$obj property max_items ""] $form_objs]
      }
      if {$with_numbers} {
        set numbers ""
        for {set i 1} {$i <= [llength $all_form_objs]} {incr i} {
          lappend numbers $i
        }
        if {[llength $form_objs] > 0} {
          set new_numbers {}
          set new_form_objs {}
          foreach form_obj $all_form_objs number $numbers {
            if {$form_obj in $form_objs} {
              lappend new_numbers $number
              lappend new_form_objs $form_obj
            }
          }
          set numbers $new_numbers
          set form_objs $new_form_objs
        } else {
          set form_objs $all_form_objs
        }
        set extra_flags [list -numbers $numbers]
      } else {
        set form_objs $all_form_objs
        set extra_flags ""
      }
      return [:question_info \
                  -with_title=$with_title \
                  -with_minutes=$with_minutes \
                  -with_points=$with_points \
                  {*}$extra_flags \
                  -obj $obj \
                  -user_answers $user_answers \
                  -positions $positions \
                  $form_objs]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: pretty_nr_alternatives
    #----------------------------------------------------------------------
    :method pretty_nr_alternatives {question_infos} {
      set result {}
      foreach question_info $question_infos {
        if {$question_info ne ""} {
          #
          # The handled metrics are currently hardcoded here. So, we can
          # rely on having the returned value in the message keys. The
          # list order is important, since it determines also the ordering
          # in the message.
          #
          if {[:dict_value $question_info show_max ""] ne ""} {
            foreach key {choice_options sub_questions} {
              if {[dict exists $question_info $key]
                  && [dict get $question_info show_max] ne [dict get $question_info $key]
                } {
                set new "[dict get $question_info show_max] #xowf.out_of# [dict get $question_info $key]"
                dict set question_info question_structure $new
              }
            }
          }
          lappend result $question_info
        }
      }
      return $result
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: pretty_ncorrect
    #----------------------------------------------------------------------
    :method pretty_ncorrect {m} {
      return " (#xowf.Correct# $m) "
    }
    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: pretty_shuffle
    #----------------------------------------------------------------------
    :method pretty_shuffle {m} {
      if {$m ne ""} {
        return #xowf.shuffle_$m#
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: render_describe_infos
    #----------------------------------------------------------------------
    :method render_describe_infos {describe_infos} {
      set msgList {}
      foreach describe_info $describe_infos {
        if {$describe_info ne ""} {
          #
          # The handled metrics are currently hardcoded here. So, we can
          # rely on having the returned value in the message keys. The
          # list order is important, since it determines also the ordering
          # in the message.
          #
          set msg ""
          set hasStructure [dict exists $describe_info question_structure]
          set metrics [expr {$hasStructure ? "question_structure" : [list choice_options sub_questions]}]
          lappend metrics nrcorrect Minutes Points shuffle available_pool_items available_pool_item_stats
          foreach metric $metrics {
            if {[:dict_value $describe_info $metric] ne ""} {
              set m [dict get $describe_info $metric]
              switch $metric {
                nrcorrect { append msg [:pretty_ncorrect $m] }
                shuffle   { append msg "<strong>#xowf.Shuffle#:</strong> [:pretty_shuffle $m]" }
                default   { append msg "<strong>#xowf.$metric#:</strong> $m "}
              }
            }
          }
          #append  msg " <pre>$describe_info</pre> "
          lappend msgList "$msg\n"
        }
      }
      return $msgList
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: describe_form
    #----------------------------------------------------------------------
    :public method describe_form {
      {-asHTML:switch}
      {-field_name ""}
      form_obj
    } {
      #
      # Call for every form field of the form_obj the "describe"
      # method and return these infos in a form of a list.
      #
      # @result list of dicts describing the form fields.
      #

      if {[$form_obj property item_type] eq "Composite"} {
        #
        # In the case of a composite Composite question type, describe
        # the components rather than the compound part (maybe, we
        # should descibe in the future also the container, but this
        # actually less interesting).
        #
        set selection [dict get [$form_obj instance_attributes] \
                           question question.interaction question.interaction.selection]
        set form_objs [[$form_obj package_id] instantiate_forms \
                           -forms [join [split $selection \n] |] \
                           -default_lang en]
        return [join [lmap form_obj $form_objs {:describe_form -asHTML=$asHTML -field_name $field_name $form_obj}]]
      }

      set fc [$form_obj property form_constraints]

      #
      # We might be willing in the future to get the full set of all
      # options, i.e. remove "show_max" constraints etc.
      #
      #ns_log notice DESCRIBE-BEFORE--$fc
      #set fc [:replace_in_fc -fc $fc shuffle_kind none]
      #set fc [:replace_in_fc -fc $fc show_max ""]
      #ns_log notice DESCRIBE-changed

      set form_fields [$form_obj create_form_fields_from_form_constraints \
                           -lookup $fc]
      set describe_infos [lmap form_field $form_fields {
        $form_field describe -field_name $field_name
      }]

      #ns_log notice "describe_form [$form_obj name]: $question_infos"
      set describe_infos [:pretty_nr_alternatives $describe_infos]
      if {!$asHTML} {
        #ns_log notice "OOO [$form_obj name] early exit $describe_infos"
        return $describe_infos
      } else {
        set HTML [:render_describe_infos $describe_infos]
        return $HTML
      }
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_configuration_render_fields
    #----------------------------------------------------------------------
    :method exam_configuration_render_fields {{-modifiable ""} fields} {
      #ns_log notice "configuration_render called with modifiable <$modifiable>"
      ::xo::require_html_procs

      set content ""
      foreach f $fields {
        if {[$f name] ni $modifiable} {
          $f set_disabled true
          $f help_text ""
        }
        append content [tdom_render {
          $f render
        }]
      }
      return $content
    }
    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_configuration_block
    #----------------------------------------------------------------------
    :method exam_configuration_block {
      {-modifiable ""}
      -label
      -id
      -obj
      -form_constraints
      field_names
    } {
      set fields [$obj create_form_fields_from_names -lookup -set_values \
                      -form_constraints $form_constraints \
                      $field_names]
      return [subst {
        <p><button type="button" class="btn btn-small" data-toggle="collapse" data-target="#$id">
        <span class="glyphicon glyphicon-chevron-down">&nbsp;</span>$label</button>
        <div id="$id" class="collapse">
        [:exam_configuration_render_fields -modifiable $modifiable $fields]
        </div>
      }]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_configuration_modifiable_field_names
    #----------------------------------------------------------------------
    :public method exam_configuration_modifiable_field_names {obj} {
      #
      # Return the names of the modifiable field names in the current
      # state. The state is in essence defined on whether or not
      # students have started to work on this exam. This method can be
      # used to correct small things, even when the students are
      # already working on the exam.
      #
      set modifiable {
        allow_paste allow_spellcheck show_minutes show_points show_ip
        countdown_audio_alarm grading
      }
      set wf [:AM get_answer_wf $obj]
      if {![:AM student_submissions_exist $wf]} {
        lappend modifiable {*}{
          shuffle_items max_items
          time_budget synchronized time_window
          proctoring proctoring_options proctoring_record signature
        }
      }
      return $modifiable
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_configuration_popup
    #----------------------------------------------------------------------
    :public method exam_configuration_popup {obj} {
      #
      # Render the exam configuration popup, add it as a
      # content_header (to avoid putting it to the main workflow form,
      # since nested FORMS are not allowed) and return the rendering
      # of the button for popping-ip the configuration modal.
      #
      # @return HTML

      set modifiable [:exam_configuration_modifiable_field_names $obj]
      #ns_log notice "exam_configuration_popup modifiable '$modifiable'"

      set fcrepo [$obj get_fc_repository]
      set content ""
      append content \
          [:exam_configuration_block \
               -modifiable $modifiable \
               -label #xowf.Question_management# \
               -id config-question \
               -form_constraints $fcrepo \
               -obj $obj {
                 shuffle_items max_items allow_paste allow_spellcheck
                 show_minutes show_points show_ip
               }] \
          [:exam_configuration_block \
               -modifiable $modifiable \
               -label #xowf.Time_management# \
               -id config-time \
               -form_constraints $fcrepo \
               -obj $obj {
                 time_budget synchronized time_window countdown_audio_alarm
               }] \
          [:exam_configuration_block \
               -modifiable $modifiable \
               -label #xowf.Security# \
               -id config-security \
               -form_constraints $fcrepo \
               -obj $obj {
                 proctoring proctoring_options proctoring_record signature
               }] \
          [:exam_configuration_render_fields -modifiable $modifiable \
               [$obj create_form_fields_from_names -lookup -set_values \
                    -form_constraints $fcrepo \
                    {grading}]]

      ::template::add_body_script -script [ns_trim -delimiter | [subst -novariables {
        |$(document).ready(function() {
        |  $('.modal .confirm').on('click', function(ev) {
        |    //
        |    // Submit button of the dialog was pressed.
        |    //
        |    var data = new FormData(document.getElementById('configuration-form'));
        |    console.log(data);
        |    var xhttp = new XMLHttpRequest();
        |    xhttp.open('POST', '[$obj pretty_link -query m=update-config]', true);
        |    xhttp.onload = function () {
        |      if (this.readyState == 4) {
        |        if (this.status == 200) {
        |          var text = this.responseText;
        |          console.log('sent OK ok ' + text);
        |          //window.location.reload(true);
        |        } else {
        |          console.log('sent NOT ok');
        |        }
        |      }
        |    };
        |    xhttp.send(data);
        |  });
        |});
      }]]

      $obj content_header_append [ns_trim -delimiter | [subst {
        |<div class="modal fade" id="configuration-modal" tabindex="-1" role="dialog"
        |     aria-labelledby="configuration-modal-label" aria-hidden="true">
        |  <div class="modal-dialog" role="document">
        |    <div class="modal-content">
        |      <div class="modal-header">
        |        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
        |          <span aria-hidden="true">&#215;</span>
        |        </button>
        |        <h4 class="modal-title" id="configurationModalTitle">#xowf.Configuration#:
        |            <span id='configuration-participant'></span></h4>
        |      </div>
        |      <div class="modal-body">
        |        <form class="form-horizontal" id="configuration-form" role="form" action="#" method="post">
        |        $content
        |        </form>
        |      </div>
        |      <div class="modal-footer">
        |        <button type="button" class="btn btn-secondary"
        |                data-dismiss="modal">#acs-kernel.common_Cancel#
        |        </button>
        |        <button id="configuration-modal-confirm" type="button" class="btn btn-primary confirm"
        |                data-dismiss="modal">#acs-subsite.Confirm#
        |        </button>
        |      </div>
        |    </div>
        |  </div>
        |</div>
      }]]

      return [ns_trim -delimiter | [subst {
        |<a class="configuration-button" href="#" title="#xowf.Configuration_button_title#"
        |  data-toggle="modal" data-target='#configuration-modal'>
        |  <span class="glyphicon glyphicon-cog" aria-hidden="true" style="float: right;"></span>
        |</a>
      }]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_summary
    #----------------------------------------------------------------------
    :public method question_summary {obj} {
      #
      # Provide a summary of all questions of an exam.
      #
      set results [:AM get_exam_results -obj $obj results]
      if {$results ne ""} {
        set href [$obj pretty_link -query m=exam-results]
        set results_summary [subst {
          <p>#xowf.export_results#: <a title="#xowf.export_results_title#" href="$href">
          CSV <span class="glyphicon glyphicon-download" aria-hidden="true"></span></a>
        }]
      } else {
        set results_summary ""
      }

      set return_url [::xo::cc query_parameter local_return_url:localurl [$obj pretty_link]]
      return [ns_trim -delimiter | [subst {
        | [:question_info_block $obj]
        | $results_summary
        | <hr><p><a class="btn btn-default" href="$return_url">#xowiki.back#</a></p>
      }]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: question_info_block
    #----------------------------------------------------------------------
    :public method question_info_block {obj} {
      #
      # Provide question info block.
      #
      set href [$obj pretty_link -query m=print-answers]

      set form_objs [:question_objs $obj]

      set chunks {}
      foreach form_obj $form_objs {
        set chunk [lindex [:describe_form $form_obj] 0]
        set structure ""
        foreach att {
          question_structure choice_options sub_questions
        } {
          if {[dict exists $chunk $att]} {
            append structure [dict get $chunk $att]
            break
          }
        }
        if {[dict exists $chunk available_pool_items]} {
          append structure \
              " " [dict get $chunk available_pool_items] " " #xowf.questions# \
              " " ([dict get $chunk available_pool_item_stats])
        }
        if {[dict exists $chunk nrcorrect]} {
          append structure " " [:pretty_ncorrect [dict get $chunk nrcorrect]]
        }
        if {[$obj state] in {done submission_review}
            && ![dict exists $chunk available_pool_items]
          } {
          dict set chunk title_value [subst {
            <a href='$href&fos=[$form_obj item_id]'>[ns_quotehtml [$form_obj title]]</a>
          }]
        } else {
          dict set chunk title_value [ns_quotehtml [$form_obj title]]
        }
        dict set chunk structure $structure
        lappend chunks $chunk
      }

      append HTML [subst {
        <div class="panel panel-default">
        <div class="panel-heading">#xowf.question_summary#</div>
        <div class="panel-body">
        <div class='table-responsive'><table class='question_summary table table-condensed'>
        <tr><th></th><th>#xowf.question_structure#</th>
        <th style='text-align: center;'>#xowf.Minutes#</th>
        <th style='text-align: center;'>#xowf.Points#</th>
        <th style='text-align: center;'>#xowf.Shuffle#</th>
        <th style='text-align: center;'></th>
        </tr>
      }]

      foreach chunk $chunks {
        append HTML [subst {
          <tr>
          <td>[:dict_value $chunk title_value]</td>
          <td>[:dict_value $chunk type]: [:dict_value $chunk structure]</td>
          <td style='text-align: center;'>[:dict_value $chunk Minutes]</td>
          <td style='text-align: center;'>[:dict_value $chunk Points]</td>
          <td style='text-align: center;'>[:pretty_shuffle [:dict_value $chunk shuffle]]</td>
          <td style='text-align: center;'>[:dict_value $chunk grading]</td>
          </tr>}]
      }
      append HTML "</table></div></div></div>\n"

      #
      # When we have results, we can provide statistics
      #
      if {[$obj state] in {done submission_review}} {

        template::head::add_link -rel stylesheet -href /resources/xowf/test-item.css
        set combined_form_info [:combined_question_form -with_numbers $obj]

        #
        # Get the form-field objects with all alternatives (use flag
        # "-generic")
        #
        set form_field_objs [:AM answer_form_field_objs \
                                 -generic \
                                 -wf [:AM get_answer_wf $obj] \
                                 $combined_form_info]
        #
        # Get the persisted statistics from the workflow
        # instance. These statistics are computed when the exam
        # protocol is rendered.
        #
        set statistics [:AM get_exam_results -obj $obj statistics]
        if {$statistics ne ""} {
          foreach var {success_statistics count_statistics} key {success count} {
            if {[dict exists $statistics $key]} {
              set $var [dict get $statistics $key]
            } else {
              set $var ""
            }
          }

          #
          # Merge the statistics into the generic form-fields such we
          # can use the usual form-field based rendering.
          #
          foreach form_field_obj $form_field_objs {
            #
            # The linkage between the statistics and the form-fields
            # is performed via the form-field names. Note that in
            # cases, where multiple folders are used as a source, the
            # names have to be disambiguated.
            #
            set name [$form_field_obj name]
            set result_statistics ""
            if {[dict exists $success_statistics $name]} {
              set result_statistics [dict get $success_statistics $name]
            }
            if {[dict exists $count_statistics $name]} {
              #ns_log notice "statistics question_info_block $name count '[dict get $count_statistics $name]'"
              dict set result_statistics count [dict get $count_statistics $name]
              $form_field_obj set result_statistics $result_statistics
            }
          }
        }

        #
        # Substitute form-field place-holders ion the combined form.
        #
        set combined_form [:aggregated_form $combined_form_info]
        set form [$obj regsub_eval  \
                      [template::adp_variable_regexp] $combined_form \
                      {$obj form_field_as_html -mode display "\\\1" "\2" $form_field_objs}]

        append HTML $form
      }
      return $HTML
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_info_block
    #----------------------------------------------------------------------
    :public method exam_info_block {-combined_form_info obj} {
      #
      # Provide a summative overview of an exam.
      #
      if {![info exists combined_form_info]} {
        set combined_form_info [:combined_question_form -with_numbers $obj]
      }
      set proctoring   [$obj property proctoring 0]
      set synchronized [$obj property synchronized 0]
      set allow_paste  [$obj property allow_paste 1]
      set max_items    [$obj property max_items ""]
      set time_window  [$obj property time_window ""]
      set allow_spellcheck [$obj property allow_spellcheck true]

      append text [subst {<p>
        [expr {$synchronized ? "" : "Non-"}]Synchronized Exam
        [expr {$proctoring ? " with Proctoring" : ""}]
        </p>}]
      set question_objs     [dict get $combined_form_info question_objs]
      set nrQuestions       [llength [:question_names $obj]]
      set randomizationOk   [dict get $combined_form_info randomization_for_exam]
      set autograde         [dict get $combined_form_info autograde]

      set revision_sets     [$obj get_revision_sets]
      set published_periods [:AM state_periods $revision_sets -state published]
      set review_periods    [:AM state_periods $revision_sets -state submission_review]
      set total_minutes     [:total_minutes -max_items $max_items $combined_form_info]
      set total_points      [:total_points -max_items $max_items $combined_form_info]
      set max_items_msg     ""

      if {$max_items ne ""} {
        set all_minutes [lmap t [dict get $combined_form_info title_infos] {
          dict get $t minutes
        }]
        if {[llength [lsort -unique $all_minutes]] != 1} {
          set max_items_msg [_ xowf.Max_items_not_ok_duration [list n $max_items]]
        } elseif {$max_items > [llength $all_minutes]} {
          set max_items_msg [_ xowf.Max_items_not_ok_number [list n $max_items]]
        } else {
          set max_items_msg [_ xowf.Max_items_ok [list n $max_items]]
        }
      }

      set time_window_msg ""
      if {$time_window ne ""} {
        set dtstart [dict get $time_window time_window.dtstart]
        if {$dtstart ne ""} {
          regsub -all T $dtstart " " dtstart
          set dtend [dict get $time_window time_window.dtend]
          set time_window_msg <br>[_ xowf.Automatically_published_from_to [list from $dtstart to $dtend]]
          set time_window_msg "<br>Automatische Freischaltung der Prüfung von $dtstart bis $dtend"
        }
      }

      append text [subst {
        <p>
        [expr {$max_items_msg ne "" ? "$max_items_msg" : ""}]
        $nrQuestions [expr {$nrQuestions == 1 ? "#xowf.question#" : "#xowf.questions#"}],
        $total_minutes #xowf.Minutes#, $total_points #xowf.Points#<br>
        [expr {$autograde ? "#xowf.exam_review_possible#" : "#xowf.exam_review_not_possible#"}]<br>
        [expr {$randomizationOk ? "#xowf.randomization_for_exam_ok#" : "#xowf.randomization_for_exam_not_ok#"}]<br>
        [expr {$allow_paste ? "#xowf.Cut_and_paste_allowed#" : "#xowf.Cut_and_paste_not_allowed#"}]<br>
        [expr {$allow_spellcheck ? "#xowf.Spellcheck_allowed#" : "#xowf.Spellcheck_not_allowed#"}]<br>
        $time_window_msg
        [expr {[llength $published_periods] > 0 ? "<br>#xowf.inclass-exam-open#: [join $published_periods {, }]<br>" : ""}]
        [expr {[llength $review_periods] > 0 ? "#xowf.inclass-exam-review#: [join $review_periods {, }]<br>" : ""}]
        </p>
      }]
      return "<div class='exam-info-block'>$text</div>"
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: total
    #----------------------------------------------------------------------
    :method total {-property:required title_infos} {
      #
      # Sum up the values of the provided property from title_infos
      #
      set total 0
      foreach title_info $title_infos {
        if {[dict exists $title_info $property]} {
          set value [dict get $title_info  $property]
          if {$value eq ""} {
            ns_log notice "missing property '$property' in '$title_info'"
            set value 0
          }
          set total [expr {$total + $value}]
        }
      }
      return $total
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: title_infos
    #----------------------------------------------------------------------
    :method title_infos {{-max_items:integer,0..1 ""} form_info} {
      #
      # When max_items is nonempty, return the title infos of all
      # items. Otherwise, just the specified number of items.
      #
      return [:max_items $max_items [dict get $form_info title_infos]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: total_minutes
    #----------------------------------------------------------------------
    :public method total_minutes {{-max_items:integer,0..1 ""} form_info} {
      #
      # Compute the duration of an exam based on the form_info dict.
      #
      return [:total -property minutes [:title_infos -max_items $max_items $form_info]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: total_points
    #----------------------------------------------------------------------
    :public method total_points {{-max_items:integer,0..1 ""} form_info} {
      #
      # Compute the maximum achievable points of an exam based on the
      # form_info dict.
      #
      return [:total -property points [:title_infos -max_items $max_items $form_info]]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: total_minutes_for_exam
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_target_time
    #----------------------------------------------------------------------
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
      #ns_log notice "exam_target_time $base_time base clock $base_clock + total_minutes $total_minutes = ${target_time}.$secfrac"
      return ${target_time}.$secfrac
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: exam_base_time
    #----------------------------------------------------------------------
    :public method exam_base_time {-manager:object -answer_obj:object} {
      #
      # Calculate the exam base time for a student. This is the time
      # reference, when the timer starts. Depending on whether the
      # exam is synchronous, the time start is either the time when
      # the exam is opened, or when the student starts the exam.
      #
      # @return time string as returned from the database
      #
      if {[$manager property synchronized 0]} {
        set parent_obj [::xowiki::FormPage get_instance_from_db -item_id [$answer_obj parent_id]]
        set base_time [$parent_obj last_modified]
      } else {
        set base_time [$answer_obj creation_date]
      }
      return $base_time
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: current_question_form
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: nth_question_form
    #----------------------------------------------------------------------
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

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: current_question_number
    #----------------------------------------------------------------------
    :public method current_question_number {obj:object} {
      #
      # Translate the position of an object into its question number
      # (as e.g. used by current_question_title).
      #
      return [expr {[$obj property position] + 1}]
    }

    #----------------------------------------------------------------------
    # Class:  Question_manager
    # Method: current_question_title
    #----------------------------------------------------------------------
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
  set qm [Question_manager create question_manager]
  AssessmentInterface {*}$register_command QM $qm
  ::xowiki::formfield::TestItemField instforward QM  $qm
}

namespace eval ::xowiki::formfield {
  #
  # The following "describe" function should be moved to a more
  # generic place, probably to the formfield procs in xowiki (to the
  # relevant formfield classes). It is just kept here for the time
  # being, until we have a better understanding what's needed in
  # detail.
  #
  ::xowiki::formfield::FormField instproc describe {{-field_name ""}} {
    set d ""
    #
    # The dict keys of the result should correspond as far as possible
    # to message keys to ease multi-language communication.
    #
    set qa [${:object} property question]
    #ns_log notice "FormField describe gets question attributes <$qa> from ${:object}"

    foreach {key name} {
      question.minutes Minutes
      question.points Points
      question.grading grading
      question.show_max show_max
    } {
      if {[dict exists $qa $key]} {
        dict set d $name [dict get $qa $key]
      }
    }
    switch [:info class] {
      ::xowiki::formfield::radio -
      ::xowiki::formfield::checkbox {
        # mc and sc interaction
        set type [expr {[:info class] eq "::xowiki::formfield::checkbox" ? "MC" : "SC"}]
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
        #dict set d all [:serialize]
      }
      ::xowiki::formfield::text_fields {
        set type ShortText
        # short text interaction
        #
        # The factual (displayed) answer is in ${:answer}, but we want
        # to see the list of possibilities, so use the data from the
        # original spec (here in $options)
        #
        foreach s [split ${:spec} ,] {
          #ns_log warning "s=$s"
          if {[regexp {^options=(.*)$} $s . options]} {
            break
          }
        }
        dict set d all ${:spec}
        dict set d sub_questions [llength ${options}]
        dict set d shuffle ${:shuffle_kind}
      }
      ::xowiki::formfield::textarea {
        set type Text
      }
      ::xowiki::formfield::pool_question_placeholder {
        set type PoolQuestion
        set item_dict [:QM get_pool_questions \
                           -field_name $field_name ${:object} ""]

        set counts ""
        foreach {key value} $item_dict {
          dict incr counts [dict get $item_dict $key item_type]
        }

        dict set d available_pool_items [dict size $item_dict]
        dict set d available_pool_item_stats $counts
      }

      default {
        set type [:info class]
        ns_log warning "describe: class [:info class] not handled"
      }
    }
    dict set d type $type
    #ns_log notice "describe [:info class] [${:object} name] -> $d"

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
      {entry -name New.Item.CompositeInteraction -form en:edit-interaction.wf -query p.item_type=Composite}
      {entry -name New.Item.PoolQuestionInteraction -form en:edit-interaction.wf -query p.item_type=PoolQuestion}

      {entry -name New.Grading.Scheme -form en:edit-grading-scheme.wf}

      {entry -name New.App.OnlineExam -form en:online-exam.wf -disabled true}
      {entry -name New.App.InclassQuiz -form en:inclass-quiz.wf -disabled true}
      {entry -name New.App.InclassExam -form en:inclass-exam.wf -query p.realexam=1}

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
  ::xowiki::policy1 copy ::xowf::test_item::test-item-policy-edit

  #
  # Add policy rules as used in the demo workflows. We are permissive
  # for student actions and require admin right for teacher
  # activities.
  #
  #
  # Policy for creating and publishing of exams.
  #
  test-item-policy-publish contains {
    Class create FormPage -array set require_permission {
      answer         {{item_id read}}
      view-my-exam   {{item_id read}}
      proctor-answer {{item_id read}}
      proctor        {{item_id read}}
      view           admin
      poll           admin
      send-participant-message admin
      grade-single-item  admin
      edit               admin
      exam-results       admin
      question-summary   admin
      print-answers      admin
      proctoring-display admin
      print-answer-table admin
      print-participants admin
      delete             admin
      qrcode             admin
      make-live-revision admin
    }
  }

  #
  # Policy for editing test items.
  #
  test-item-policy-edit contains {
    Class create FormPage -array set require_permission {
      revisions       admin
      diff            admin
    }
  }

  #
  # Policy for answering test items.
  #
  test-item-policy-answer contains {
    Class create Package -array set require_permission {
      create-from-prototype admin
    }
    Class create FormPage -array set require_permission {
      poll            {{item_id read}}
      edit            creator
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
