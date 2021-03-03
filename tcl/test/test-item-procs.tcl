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
        
        "::xowiki::formfield::FormField instproc dict_to_fc"
        "::xowiki::formfield::CompoundField instproc get_named_sub_component_value"
    } create_test_items {

        Create a folder in various test-items and an exam with one item.

    } {
        #
        # Run the test under the current user_id.
        #
        set user_id [ad_conn user_id]
        set instance $_xowf_test_instance_name
        set testfolder .testfolder
        set locale [lang::system::locale]
        set lang [string range $locale 0 1]

        try {
            ###########################################################
            aa_section "Make sure we have a fresh test folder"
            ############################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -user_id $user_id \
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
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type Text}} \
                -update [subst {
                    _title "Sample Text Interaction"
                    _name sample_text_0
                    _nls_language $locale
                    question.points 4
                    question.interaction.text "Given is a very complex situation.<p> How can this be solved?"
                }]

            ###########################################################
            aa_section "Create an MC interaction"
            ###########################################################

            ::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:edit-interaction.wf \
                -extra_url_parameter {{p.item_type MC}} \
                -update [subst {
                    _title "Sample MC Interaction"
                    _name sample_mc_0
                    _nls_language $locale
                    question.points 3
                    question.shuffle peruser
                    question.interaction.text "Which of the following colors are used in a traffic lights?"
                    question.interaction.answer.1.text "Red"
                    question.interaction.answer.1.correct "t"
                    question.interaction.answer.2.text "Green"
                    question.interaction.answer.2.correct "t"
                    question.interaction.answer.3.text "Blue"
                    question.interaction.answer.3.correct ""
                }]

            ###########################################################
            aa_section "Create an inclass-exam"
            ###########################################################
            
            set d [::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name en:inclass-exam.wf \
                -update [subst {
                    _title "Sample Inclass Exam"
                    _nls_language $locale
                    question $testfolder/en:sample_mc_0
                }]]
            aa_log "inlclass exam created d=[ns_quotehtml $d]"

            
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
