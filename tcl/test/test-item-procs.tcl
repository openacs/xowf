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
        "::xowiki::test::edit_form_page"

        "::xo::ConnectionContext instproc eval_as_user"
        "::xowf::Package instproc destroy"
        "::xowf::Package instproc initialize"
        "::xowf::WorkflowPage instproc childpage"
        "::xowf::WorkflowPage instproc get_revision_sets"
        "::xowf::WorkflowPage instproc is_wf"
        "::xowf::WorkflowPage instproc is_wf_instance"
        "::xowf::WorkflowPage instproc stats_record_count"
        "::xowf::WorkflowPage instproc stats_record_detail"
        "::xowf::WorkflowPage instproc www-view"
        "::xowf::test_item::Answer_manager instproc achieved_points"
        "::xowf::test_item::Answer_manager instproc allow_answering"
        "::xowf::test_item::Answer_manager instproc answer_form_field_objs"
        "::xowf::test_item::Answer_manager instproc answers_panel"
        "::xowf::test_item::Answer_manager instproc countdown_timer"
        "::xowf::test_item::Answer_manager instproc create_workflow"
        "::xowf::test_item::Answer_manager instproc delete_all_answer_data"
        "::xowf::test_item::Answer_manager instproc get_IPs"
        "::xowf::test_item::Answer_manager instproc get_answer_attributes"
        "::xowf::test_item::Answer_manager instproc get_answer_wf"
        "::xowf::test_item::Answer_manager instproc get_answers"
        "::xowf::test_item::Answer_manager instproc get_duration"
        "::xowf::test_item::Answer_manager instproc get_exam_results"
        "::xowf::test_item::Answer_manager instproc get_wf_instances"
        "::xowf::test_item::Answer_manager instproc grading_dialog_setup"
        "::xowf::test_item::Answer_manager instproc grading_scheme"
        "::xowf::test_item::Answer_manager instproc grading_table"
        "::xowf::test_item::Answer_manager instproc last_time_in_state"
        "::xowf::test_item::Answer_manager instproc last_time_switched_to_state"
        "::xowf::test_item::Answer_manager instproc marked_results"
        "::xowf::test_item::Answer_manager instproc participants_table"
        "::xowf::test_item::Answer_manager instproc prevent_multiple_tabs"
        "::xowf::test_item::Answer_manager instproc render_answers"
        "::xowf::test_item::Answer_manager instproc revisions_up_to"
        "::xowf::test_item::Answer_manager instproc runtime_panel"
        "::xowf::test_item::Answer_manager instproc set_exam_results"
        "::xowf::test_item::Answer_manager instproc state_periods"
        "::xowf::test_item::Answer_manager instproc student_submissions_exist"
        "::xowf::test_item::Answer_manager instproc time_window_setup"
        "::xowf::test_item::AssessmentInterface instproc render_feedback_files"
        "::xowf::test_item::Question_manager instproc add_seeds"
        "::xowf::test_item::Question_manager instproc combined_question_form"
        "::xowf::test_item::Question_manager instproc disallow_paste"
        "::xowf::test_item::Question_manager instproc disallow_spellcheck"
        "::xowf::test_item::Question_manager instproc disallow_translation"
        "::xowf::test_item::Question_manager instproc exam_base_time"
        "::xowf::test_item::Question_manager instproc exam_configuration_modifiable_field_names"
        "::xowf::test_item::Question_manager instproc exam_configuration_popup"
        "::xowf::test_item::Question_manager instproc exam_info_block"
        "::xowf::test_item::Question_manager instproc exam_target_time"
        "::xowf::test_item::Question_manager instproc hint_boxes"
        "::xowf::test_item::Question_manager instproc initialize"
        "::xowf::test_item::Question_manager instproc item_substitute_markup"
        "::xowf::test_item::Question_manager instproc load_question_objs"
        "::xowf::test_item::Question_manager instproc minutes_string"
        "::xowf::test_item::Question_manager instproc more_ahead"
        "::xowf::test_item::Question_manager instproc nth_question_form"
        "::xowf::test_item::Question_manager instproc nth_question_obj"
        "::xowf::test_item::Question_manager instproc pagination_actions"
        "::xowf::test_item::Question_manager instproc points_string"
        "::xowf::test_item::Question_manager instproc question_count"
        "::xowf::test_item::Question_manager instproc question_info"
        "::xowf::test_item::Question_manager instproc question_names"
        "::xowf::test_item::Question_manager instproc question_objs"
        "::xowf::test_item::Question_manager instproc question_property"
        "::xowf::test_item::Question_manager instproc questions_without_minutes"
        "::xowf::test_item::Question_manager instproc replace_pool_questions"
        "::xowf::test_item::Question_manager instproc shuffled_index"
        "::xowf::test_item::Question_manager instproc total_minutes"
        "::xowf::test_item::Question_manager instproc total_minutes_for_exam"
        "::xowf::test_item::Question_manager instproc total_points"
        "::xowf::test_item::Renaming_form_loader instproc answer_attributes"
        "::xowf::test_item::Renaming_form_loader instproc form_name_based_attribute_stem"
        "::xowf::test_item::Renaming_form_loader instproc name_to_question_obj_dict"
        "::xowf::test_item::Renaming_form_loader instproc rename_attributes"
        "::xowf::test_item::grading::Grading instproc grading_dict"
        "::xowf::test_item::grading::Grading instproc print"
        "::xowf::test_item::grading::GradingNone instproc grade"
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

            set r [::xowiki::test::create_form_page \
                       -last_request $d \
                       -instance $instance \
                       -path $testfolder \
                       -parent_id $folder_id \
                       -form_name en:edit-interaction.wf \
                       -extra_url_parameter {{p.item_type Text}} \
                       -update {
                           _title "Sample Text Interaction"
                           _name sample_text_0
                           _nls_language en_US
                           question.points 4
                           question.interaction.text {
                               Given is a very complex situation.<p> How can this be solved?
                               [[image:sample_text_0_image|Sample Text Interaction Image]]
                           }
                       }]

            # Save an image under the question
            set file_object [::xowiki::File new -destroy_on_cleanup \
                                 -title "Sample Text Interaction Image" \
                                 -name file:sample_text_0_image \
                                 -parent_id [dict get $r page_info item_id] \
                                 -mime_type image/png \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/acs-templating/www/resources/sort-ascending.png
            $file_object save_new

            ###########################################################
            aa_section "Create an MC interaction"
            ###########################################################

            set r [::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type MC}} \
                -update {
                    _title "Sample MC Interaction"
                    _name sample_mc_0
                    _nls_language en_US
                    question.points 3
                    question.shuffle peruser
                    question.interaction.text {
                        Which of the following colors are used in a traffic lights?
                        [[image:sample_mc_0_image|Sample MC Interaction Image]]
                        [[.SELF./image:sample_mc_0_image|Sample MC Interaction Image via SELF]]
                    }
                    question.interaction.answer.1.text "Red"
                    question.interaction.answer.1.correct "t"
                    question.interaction.answer.2.text "Green"
                    question.interaction.answer.2.correct "t"
                    question.interaction.answer.3.text "Blue"
                    question.interaction.answer.3.correct "f"
                }]

            # Save an image under the question
            set file_object [::xowiki::File new -destroy_on_cleanup \
                                 -title "Sample MC Interaction Image" \
                                 -name file:sample_mc_0_image \
                                 -parent_id [dict get $r page_info item_id] \
                                 -mime_type image/png \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/acs-templating/www/resources/sort-ascending.png
            $file_object save_new

            ###########################################################
            aa_section "Create a ShortText interaction with a file submission"
            ###########################################################

            set r [::xowiki::test::create_form_page \
                       -last_request $d \
                       -instance $instance \
                       -path $testfolder \
                       -parent_id $folder_id \
                       -form_name en:edit-interaction.wf \
                       -extra_url_parameter {{p.item_type ShortText}} \
                       -update {
                           _title "Sample ShortText Interaction"
                           _name sample_st_0
                           _nls_language en_US
                           question.points 2
                           question.shuffle none
                           question.interaction.text {
                               Write a program, which loops forever
                               [[image:sample_st_0_image|Sample ShortText Interaction]]
                           }
                           question.interaction.answer.1.text "Please, upload your submission"
                           question.interaction.answer.1.options "file_upload"
                       }]

            # Save an image under the question
            set file_object [::xowiki::File new -destroy_on_cleanup \
                                 -title "Sample ShortText Interaction Image" \
                                 -name file:sample_st_0_image \
                                 -parent_id [dict get $r page_info item_id] \
                                 -mime_type image/png \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/acs-templating/www/resources/sort-ascending.png
            $file_object save_new

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
                               $testfolder/en:sample_text_0
                           }
                       }]]
            aa_log "inclass exam created d=[ns_quotehtml $d]"

            ###########################################################
            aa_section "Create exam with the selected question"
            ###########################################################

            #ns_log warning $d
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

            #
            # Every answer page for a student consists of a single
            # question. In case randomization is activated, we can't
            # be sure, which question this will be. Therefore, we use
            # a dict for the expected results.
            #
            dict set q_dict sample_mc_0 type MC
            dict set q_dict sample_mc_0 nr_hrefs 2
            dict set q_dict sample_mc_0 reply_fields {
                sample_mc_0_ 1
                sample_mc_0_ 2
            }

            set fn $::acs::rootdir/packages/xowf/tcl/test/test-item-procs.tcl
            set F [ad_opentmpfile tmpfile test]
            set F0 [open $fn]; set content [read $F0]; close $F0
            close $F

            dict set q_dict sample_st_0 type ShortText
            dict set q_dict sample_st_0 nr_hrefs 1
            dict set q_dict sample_st_0 reply_fields \
                [list \
                     sample_st_0_.answer1 test-item-procs.tcl \
                     sample_st_0_.answer1.content-type text/plain \
                     sample_st_0_.answer1.tmpfile $tmpfile]

            dict set q_dict sample_text_0 type Text
            dict set q_dict sample_text_0 nr_hrefs 1
            dict set q_dict sample_text_0 reply_fields {
                sample_text_0_ "Hello world"
            }

            set question_names [xowf::test::question_names_from_input_form $d1]
            set question_name [lindex $question_names 0]

            aa_section "... fill out question 1 ($question_name, [dict get $q_dict $question_name type])"

            #
            # Check, of images are successfully rendered.
            #
            acs::test::dom_html root [::xowiki::test::get_content $d1] {
                set hrefs [$root selectNodes {//img[@class='image']/@src}]
                set expected_nr_hrefs [dict get $q_dict $question_name nr_hrefs]
                aa_true "$expected_nr_hrefs images '$hrefs' were found on $question_name" {
                    [llength $hrefs] == $expected_nr_hrefs
                }
            }

            #
            # Can we download these images?
            #
            foreach pair $hrefs {
                set d2 [acs::test::http -last_request $d1 [dict get $pair src]]
                acs::test::reply_has_status_code $d2 200
                set content_type [ns_set iget [dict get $d2 headers] content-type]
                aa_equals "Content type is an image" image/png $content_type
            }

            #
            # Fill in answer for question 1 and click on question "2".
            #
            set path [string range $location [string length $instance] end]
            set url_info [ns_parseurl $path]

            set reply_fields [dict get $q_dict $question_name reply_fields]

            set d2 [::xowiki::test::edit_form_page \
                        -last_request $d \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -next_page_must_contain "#xowf.question# 2" \
                        -update [list {*}$reply_fields __action_q.2 "" ] \
                       ]

            acs::test::reply_has_status_code $d2 200

            set question_names [xowf::test::question_names_from_input_form $d2]
            set question_name [lindex $question_names 0]

            aa_section "... fill out question 2 ($question_name, [dict get $q_dict $question_name type])"

            set reply_fields [dict get $q_dict $question_name reply_fields]

            set d3 [::xowiki::test::edit_form_page \
                        -last_request $d2 \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -next_page_must_contain "#xowf.question# 3" \
                        -update [list {*}$reply_fields __action_q.3 "" ] \
                       ]

            acs::test::reply_has_status_code $d3 200

            aa_section "... submit the exam (Action logout) with a return_url"

            set d4 [::xowiki::test::edit_form_page \
                        -last_request $d3 \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -next_page_must_contain "Sample Inclass Exam" \
                        -update [list __action_logout "" return_url a-url] \
                       ]

            acs::test::reply_has_status_code $d4 200
            set d $d4

            set submission_id [[$package_id resolve_page \
                                    [dict get $url_info path]/[dict get $url_info tail] _] item_id]

            aa_equals "Submission '$submission_id' is in state 'done'" \
                [::xo::dc get_value get_state {
                    select state from xowiki_form_instance_item_index
                    where item_id = :submission_id
                }] \
                done

            aa_section "... submit the exam (Action logout) without return_url"

            set d4 [::xowiki::test::edit_form_page \
                        -last_request $d4 \
                        -path [dict get $url_info path]/[dict get $url_info tail] \
                        -update [list __action_logout ""] \
                       ]

            acs::test::reply_has_status_code $d4 200

            aa_equals "Submission '$submission_id' is in state 'done'" \
                [::xo::dc get_value get_state {
                    select state from xowiki_form_instance_item_index
                    where item_id = :submission_id
                }] \
                done

            set d $d4

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

    aa_register_case -init_classes {xowf_require_test_instance} -cats {web} -procs {
        "::lang::system::locale"
        "::xowf::test_item::Question_manager instproc aggregated_form"
        "::xowf::test_item::Question_manager instproc describe_form"
        "::xowf::test_item::Question_manager instproc percent_substitute_in_form"
        "::xowiki::Page instproc www-create-new"
        "::xowiki::test::create_form_page"
        "::xowiki::test::require_test_folder"

        "::xowiki::FormPage proc compute_filter_clauses"
    } create_composite_test_item {

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

            ##############################################################
            aa_section "Create a simple text interaction with a file link"
            ##############################################################
            # {config -use test-items}

            set dt [::xowiki::test::create_form_page \
                        -last_request $d \
                        -instance $instance \
                        -path $testfolder \
                        -parent_id $folder_id \
                        -form_name en:edit-interaction.wf \
                        -extra_url_parameter {{p.item_type Text}} \
                        -update {
                            _title "Sample Text Interaction"
                            _name sample_text_0
                            _nls_language en_US
                            question.points 4
                            question.interaction.text {Given a text with a file filled out for the page [[file:somefile]]
                                and some unresolved link [[file:unresolved]]
                                and as an image [[image:sample_text_0_image1.png|Some image1]]
                                and a SELF image [[.SELF./image:sample_text_0_image2.png|Some image2]].}
                        }]
            #
            # When the text interaction is opened with preview, and a
            # file is provided of the unresolved link, it is saved as
            # a child the question.
            #
            set text_page [::xo::db::CrClass get_instance_from_db -item_id [dict get $dt item_id]]

            aa_section "Create file 'file:somefile' as child of '[$text_page name]' [$text_page item_id]"
            set file_object [::xowiki::File new \
                                 -destroy_on_cleanup \
                                 -title "somefile" \
                                 -name file:somefile \
                                 -parent_id [$text_page item_id] \
                                 -mime_type text/plain \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/xowf/tcl/test/test-item-procs.tcl
            $file_object save_new

            foreach img {image1.png image2.png} {
                aa_section "Create image 'file:sample_text_0_$img' as child of '[$text_page name]' [$text_page item_id]"
                set image_object [::xowiki::File new \
                                      -destroy_on_cleanup \
                                      -title "sample_text_0_$img" \
                                      -name file:sample_text_0_$img \
                                      -parent_id [$text_page item_id] \
                                      -mime_type image/png \
                                      -package_id $package_id \
                                      -creation_user [dict get $user_info user_id]]
                $image_object set import_file \
                    $::acs::rootdir/packages/acs-subsite/www/resources/attach.png
                $image_object save_new
            }

            #############################################################
            aa_section "Call preview workflow for '[$text_page name]'"

            set d [::xowiki::test::edit_form_page \
                       -last_request $dt \
                       -refetch=0 \
                       -path $testfolder/[$text_page name] \
                       -update {
                           __action_preview ""
                           __form_action "save-form-data"
                       }]
            acs::test::reply_has_status_code $d 302
            set location /[::acs::test::get_url_from_location $d]
            set d [acs::test::http -last_request $d $location]
            acs::test::reply_has_status_code $d 302
            set location /[::acs::test::get_url_from_location $d]
            set d [acs::test::http -last_request $d $location]

            acs::test::dom_html root [dict get $d body] {
                set resolved   [lmap p [$root selectNodes {//a[@class='file']/@href}] {file tail [lindex $p 1]}]
                set unresolved [lmap p [$root selectNodes {//a[@class='missing']/@href}] {file tail [lindex $p 1]}]
                set images     [lmap p [$root selectNodes {//img[@class='image']/@src}] {file tail [lindex $p 1]}]
            }
            aa_log "RESOLVED='$resolved'"
            aa_log "UNRESOLVED='$unresolved'"
            aa_log "IMAGES='$images'"

            aa_true "link 'somefile' is resolved" {"somefile" in $resolved}
            aa_true "link 'unresolved' is not resolved" [string match "*file:unresolved*" $unresolved]
            aa_true "image 'sample_text_0_image1' is resolved" {"sample_text_0_image1.png" in $images}
            aa_true "image 'sample_text_0_image2' is resolved" {"sample_text_0_image2.png" in $images}

            ##########################################################################################
            aa_section "create composite page 'sample_composite_0'"

            set dt [::xowiki::test::create_form_page \
                        -last_request $d \
                        -instance $instance \
                        -path $testfolder \
                        -parent_id $folder_id \
                        -form_name en:edit-interaction.wf \
                        -extra_url_parameter {{p.item_type Composite}} \
                        -update {
                            _title "Sample composite Interaction"
                            _name sample_composite_0
                            _nls_language en_US
                            question.points 4
                            question.twocol f
                            question.interaction.text {
                                Given a text with an [[file:otherfile]]
                                img [[image:sample_composite_0_image1.png|Some image]]
                                SELF img [[.SELF./image:sample_composite_0_image2.png|Some image2-self]].}
                            question.interaction.selection .testfolder/en:sample_text_0
                        }]

            set composite_page [::xo::db::CrClass get_instance_from_db -item_id [dict get $dt item_id]]

            aa_section "Create file 'file:somefile' as child of '[$text_page name]'"
            set file_object [::xowiki::File new \
                                 -destroy_on_cleanup \
                                 -title "otherfile" \
                                 -name file:otherfile \
                                 -parent_id [$composite_page item_id] \
                                 -mime_type text/plain \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/xowf/tcl/test/test-item-procs.tcl
            $file_object save_new

            foreach img {image1.png image2.png} {
                set image_object [::xowiki::File new \
                                      -destroy_on_cleanup \
                                      -title "sample_composite_0_$img" \
                                      -name file:sample_composite_0_$img \
                                      -parent_id [$composite_page item_id] \
                                      -mime_type image/png \
                                      -package_id $package_id \
                                      -creation_user [dict get $user_info user_id]]
                $image_object set import_file \
                    $::acs::rootdir/packages/acs-subsite/www/resources/attach.png
                $image_object save_new
            }

            #############################################################
            aa_section "Call preview workflow for '[$composite_page name]'"

            set d [::xowiki::test::edit_form_page \
                       -last_request $dt \
                       -refetch=0 \
                       -path $testfolder/[$composite_page name] \
                       -update {
                           __action_preview ""
                           __form_action "save-form-data"
                       }]
            acs::test::reply_has_status_code $d 302
            set location /[::acs::test::get_url_from_location $d]
            set d [acs::test::http -last_request $d $location]
            acs::test::reply_has_status_code $d 302
            set location /[::acs::test::get_url_from_location $d]
            set d [acs::test::http -last_request $d $location]

            acs::test::dom_html root [dict get $d body] {
                set resolved   [lmap p [$root selectNodes {//a[@class='file']/@href}] {file tail [lindex $p 1]}]
                set unresolved [lmap p [$root selectNodes {//a[@class='missing']/@href}] {file tail [lindex $p 1]}]
                set images     [lmap p [$root selectNodes {//img[@class='image']/@src}] {file tail [lindex $p 1]}]
            }
            aa_log "RESOLVED='$resolved'"
            aa_log "UNRESOLVED='$unresolved'"
            aa_log "IMAGES='$images'"

            aa_true "link 'somefile' is resolved" {"somefile" in $resolved}
            aa_true "link 'otherfile' is resolved" {"otherfile" in $resolved}

            foreach filename {
                sample_text_0_image1.png
                sample_text_0_image2.png
                sample_composite_0_image1.png
                sample_composite_0_image2.png
            } {
                aa_true "image '$filename' is resolved" {$filename in $images}
            }

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
