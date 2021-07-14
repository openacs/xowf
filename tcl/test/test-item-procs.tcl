namespace eval ::xowf::test {

    aa_register_init_class \
        xowf_require_test_instance {
            Make sure the test instance is there and create it if necessary.
        } {
            aa_export_vars {_xowf_test_instance_name}
            set _xowf_test_instance_name /xowf-test
            ::acs::test::require_package_instance \
                -package_key xowf \
                -instance_name $_xowf_test_instance_name
        } {
            # Here one might unmount the package afterwards. Right now
            # we decide to keep it so it is possible to e.g. inspect
            # the results or test further in the mounted instance.
        }

    aa_register_case -init_classes {xowf_require_test_instance} -cats {web} -procs {
        "::lang::system::locale"
        "::xowiki::test::create_form_page"
        "::xowiki::test::require_test_folder"
        "::xowiki::Page instproc www-create-new"

        "::xo::ConnectionContext instproc eval_as_user"
        "::xowf::Package instproc destroy"
        "::xowf::WorkflowPage instproc get_revision_sets"
        "::xowf::WorkflowPage instproc is_wf"
        "::xowf::WorkflowPage instproc is_wf_instance"
        "::xowf::WorkflowPage instproc www-view"
        "::xowf::test_item::Answer_manager instproc achieved_points"
        "::xowf::test_item::Answer_manager instproc answers_panel"
        "::xowf::test_item::Answer_manager instproc countdown_timer"
        "::xowf::test_item::Answer_manager instproc create_workflow"
        "::xowf::test_item::Answer_manager instproc delete_all_answer_data"
        "::xowf::test_item::Answer_manager instproc get_IPs"
        "::xowf::test_item::Answer_manager instproc get_answer_wf"
        "::xowf::test_item::Answer_manager instproc get_answers"
        "::xowf::test_item::Answer_manager instproc get_duration"
        "::xowf::test_item::Answer_manager instproc get_wf_instances"
        "::xowf::test_item::Answer_manager instproc grading_table"
        "::xowf::test_item::Answer_manager instproc last_time_in_state"
        "::xowf::test_item::Answer_manager instproc marked_results"
        "::xowf::test_item::Answer_manager instproc participants_table"
        "::xowf::test_item::Answer_manager instproc prevent_multiple_tabs"
        "::xowf::test_item::Answer_manager instproc render_answers"
        "::xowf::test_item::Answer_manager instproc revisions_up_to"
        "::xowf::test_item::Answer_manager instproc runtime_panel"
        "::xowf::test_item::Answer_manager instproc state_periods"
        "::xowf::test_item::Question_manager instproc add_seeds"
        "::xowf::test_item::Question_manager instproc combined_question_form"
        "::xowf::test_item::Question_manager instproc disallow_paste"
        "::xowf::test_item::Question_manager instproc exam_base_time"
        "::xowf::test_item::Question_manager instproc exam_info_block"
        "::xowf::test_item::Question_manager instproc exam_target_time"
        "::xowf::test_item::Question_manager instproc item_substitute_markup"
        "::xowf::test_item::Question_manager instproc minutes_string"
        "::xowf::test_item::Question_manager instproc more_ahead"
        "::xowf::test_item::Question_manager instproc nth_question_form"
        "::xowf::test_item::Question_manager instproc nth_question_obj"
        "::xowf::test_item::Question_manager instproc pagination_actions"
        "::xowf::test_item::Question_manager instproc points_string"
        "::xowf::test_item::Question_manager instproc question_count"
        "::xowf::test_item::Question_manager instproc question_info"
        "::xowf::test_item::Question_manager instproc question_objs"
        "::xowf::test_item::Question_manager instproc question_property"
        "::xowf::test_item::Question_manager instproc shuffled_index"
        "::xowf::test_item::Question_manager instproc total_minutes"
        "::xowf::test_item::Question_manager instproc total_minutes_for_exam"
        "::xowf::test_item::Question_manager instproc total_points"
        "::xowf::test_item::Renaming_form_loader instproc answer_attributes"
        "::xowf::test_item::Renaming_form_loader instproc form_name_based_attribute_stem"
        "::xowf::test_item::Renaming_form_loader instproc name_to_question_obj_dict"
        "::xowf::test_item::Renaming_form_loader instproc rename_attributes"
        "::xowiki::FormPage instproc extra_html_fields"
        "::xowiki::FormPage instproc get_property"
        "::xowiki::Page instproc www-create-or-use"
        "::xowiki::formfield::CompoundField instproc get_named_sub_component_value"
        "::xowiki::formfield::FormField instproc dict_to_fc"
        "::xowiki::formfield::enumeration instproc scores"
        "::xowiki::includelet::personal-notification-messages proc modal_message_dialog_register_submit"

    } create_test_items {

        Create a folder in various test-items and an exam with one item.

    } {
        set instance $_xowf_test_instance_name
        set testfolder .testfolder
        set locale [lang::system::locale]
        set lang [string range $locale 0 1]

        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowf@acs-testing.test -admin]
        set d [::acs::test::login $user_info]

        try {
            ###########################################################
            aa_section "Make sure we have a fresh test folder"
            ############################################################
            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $d \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]

            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            ###########################################################
            aa_section "Create a simple text interaction"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type Text}} \
                -update [subst {
                    _title "Sample Text Interaction"
                    _name sample_text_0
                    _nls_language en_US
                    question.points 4
                    question.interaction.text "Given is a very complex situation.<p> How can this be solved?"
                }]

            ###########################################################
            aa_section "Create an MC interaction"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type MC}} \
                -update [subst {
                    _title "Sample MC Interaction"
                    _name sample_mc_0
                    _nls_language en_US
                    question.points 3
                    question.shuffle peruser
                    question.interaction.text "Which of the following colors are used in a traffic lights?"
                    question.interaction.answer.1.text "Red"
                    question.interaction.answer.1.correct "t"
                    question.interaction.answer.2.text "Green"
                    question.interaction.answer.2.correct "t"
                    question.interaction.answer.3.text "Blue"
                    question.interaction.answer.3.correct "f"
                }]

            ###########################################################
            aa_section "Create a ShortText interaction with a file submission"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type ShortText}} \
                -update [subst {
                    _title "Sample ShortText Interaction"
                    _name sample_st_0
                    _nls_language en_US
                    question.points 2
                    question.shuffle none
                    question.interaction.text "Write a program, which loops forever"
                    question.interaction.answer.1.text "Please, upload your submission"
                    question.interaction.answer.1.options "file_upload"
                }]

            ###########################################################
            aa_section "Create an inclass-exam"
            ###########################################################

            set d [::xowiki::test::create_form_page \
                       -last_request $d \
                       -instance $instance \
                       -path $testfolder \
                       -parent_id $folder_id \
                       -form_name en:inclass-exam.wf \
                       -update [subst {
                           _title "Sample Inclass Exam"
                           _nls_language en_US
                           question {
                               $testfolder/en:sample_mc_0
                               $testfolder/en:sample_st_0
                               $testfolder/sample_text_0
                           }
                       }]]
            aa_log "inclass exam created d=[ns_quotehtml $d]"

            ###########################################################
            aa_section "Create exam with the selected question"
            ###########################################################

            #set page_name [dict get $d page_info stripped_name]
            set page_name [dict get $d page_info link]
            set d [::xowiki::test::edit_form_page \
                       -last_request $d \
                       -path $testfolder/$page_name \
                       -update {
                           __action_select ""
                       }]
            aa_log "inclass exam edited d=[ns_quotehtml $d]"

            ###########################################################
            aa_section "Publish exam"
            ###########################################################

            set d [::xowiki::test::edit_form_page \
                       -last_request $d \
                       -path $testfolder/$page_name \
                       -update {
                           __action_publish ""
                       }]
            #aa_log "inclass exam edited d=[ns_quotehtml $d]"
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            set answer_link ""

            acs::test::dom_html root $response {
                set answer_link_info [$root selectNodes {//a[@class='answer']/@href}]
                aa_log "answer link info is '$answer_link_info'"
                set answer_link [lindex $answer_link_info 0 1]
                aa_true "answer link is non empty '$answer_link'" {[string length $answer_link] > 0}
            }

            ###########################################################
            aa_section "Go to answer page and fill out exam"
            ###########################################################

            set d1 [acs::test::follow_link -last_request $d -label $answer_link]
            aa_log "inclass exam answer page d=[ns_quotehtml $d]"
            acs::test::reply_has_status_code $d1 302
            set location /[::acs::test::get_url_from_location $d1]
            aa_log "fill-out page=[ns_quotehtml $location]"

            set d1 [acs::test::http -last_request $d $location]
            acs::test::reply_has_status_code $d1 200

            aa_section "... fill out question 1 (MC)"

            set path [string range $location [string length $instance] end]
            set url_info [ns_parseurl $path]
            set d2 [::xowiki::test::edit_form_page \
                        -last_request $d \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -next_page_must_contain "#xowf.question# 2" \
                        -update {
                            __action_q.2 ""
                            sample_mc_0_ 1
                            sample_mc_0_ 2
                        }]
            acs::test::reply_has_status_code $d2 200

            aa_section "... fill out question 2 (Short text with file submission)"

            set tmpfile [ad_tmpnam]
            file copy $::acs::rootdir/packages/xowf/tcl/test/test-item-procs.tcl $tmpfile
            set d3 [::xowiki::test::edit_form_page \
                        -last_request $d2 \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -next_page_must_contain "#xowf.question# 3" \
                        -update [subst {
                            __action_q.3 ""
                            sample_st_0_.answer1 test-item-procs.tcl
                            sample_st_0_.answer1.content-type text/plain
                            sample_st_0_.answer1.tmpfile $tmpfile
                        }]]
            acs::test::reply_has_status_code $d3 200
            set d $d3
            ###########################################################
            aa_section "Check participants during exam"
            ###########################################################

            set d1 [acs::test::http \
                       -last_request $d \
                       [export_vars -base $instance/$testfolder/$page_name {{m print-participants}}]]
            acs::test::reply_has_status_code $d1 200
            aa_log "check participants d=[ns_quotehtml $d1]"
            #ns_log notice "participants [dict get $d1 body]"

            ###########################################################
            aa_section "Close exam"
            ###########################################################

            set d [::xowiki::test::edit_form_page \
                       -last_request $d \
                       -path $testfolder/$page_name \
                       -update {
                           __action_unpublish ""
                       }]
            aa_log "inclass exam edited d=[ns_quotehtml $d]"

            ###########################################################
            aa_section "Visit exam protocol"
            ###########################################################
            set d [acs::test::http \
                       -last_request $d \
                       [export_vars -base $instance/$testfolder/$page_name {{m print-answers}}]]
            acs::test::reply_has_status_code $d 200

            aa_log "inclass exam edited d=[ns_quotehtml $d]"

            ###########################################################
            aa_section "Check participants after exam"
            ###########################################################

            set d [acs::test::http \
                       -last_request $d \
                       [export_vars -base $instance/$testfolder/$page_name {{m print-participants}}] \
                      ]
            aa_log "inclass exam edited d=[ns_quotehtml $d]"
            acs::test::reply_has_status_code $d1 200

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
        }
    }
}


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
