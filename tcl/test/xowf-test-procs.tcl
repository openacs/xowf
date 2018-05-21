namespace eval ::xowf::test {

    aa_register_case -cats {web} -procs {
        "::xowf::Package instproc initialize"
    } create_folder_with_page {

        Create a folder in a xowf instance with a form page and edit this
    } {

        # run the test under the current user_id.
        set user_id [ad_conn user_id]
        ns_log notice USER=$user_id

        set instance /xowf
        set testfolder testfolder
        #::caldav::test::basic_setup -user_id $user_id -once -private=true

        try {
            #
            # Make sure we have a test folder
            #
            set folder_info [::xowiki::test::require_test_folder \
                                 -user_id $user_id \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]

            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            #
            # Create a test page in the folder
            #
            ::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name page.form \
                -update {
                    _title "Sample page"
                    _name en:hello
                    _text "Hello world!"
                }

            #
            # Edit page
            #
            ::xowiki::test::edit_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder/hello \
                -update {
                    _title "Sample page 2"
                    _text "Brave new world!"
                }

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #calendar::delete -calendar_id $temp_calendar_id

        }
    }

    aa_register_case -cats {web} -procs {
        "::xowf::Package instproc initialize"
    } create_workflow_with_instance {

        Create a xowf workflow and a instance in a folder
    } {

        # run the test under the current user_id.
        set user_id [ad_conn user_id]
        ns_log notice USER=$user_id

        set instance /xowf
        set testfolder .testfolder

        try {
            #
            # Make sure we have a test folder
            #
            set folder_info [::xowiki::test::require_test_folder \
                                 -user_id $user_id \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]

            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}
            
            ::xowiki::test::create_form \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name en:tip.form \
                -update {
                    title "TIP Form"
                    nls_language en_US
                    text {<p>@_text@</p>
                        <p>State: @wf_current_state@</p>
                    }
                    text.format text/html
                    form {<form> @_text@ @wf_current_state@&amp;nbsp; @_description@</form>}
                    form.format text/html
                    form_constraints {
                        {wf_current_state:current_state}
                        _page_order:hidden
                    }
                }
            aa_log "===== Form  en:tip.form created"
            
            #
            # Create the TIP workflow
            #
            ::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name Workflow.form \
                -update {
                    _title "TIP Workflow"
                    _name en:tip.wf
                    workflow_definition {
                        # Actions are used here with the following parameters:
                        #   next_state: state after activation of action
                        #   roles: a list of roles; if the current user has one of these
                        #          roles, he is allowed to perform the action
                        #          Currently implemented roles: 
                        #            all, swa, registered_user, unregistered user, admin, 
                        #            creator, app_group_member, community_member
                        #
                        Action save -roles admin
                        Action propose -next_state proposed -proc activate {obj} {
                            my msg "$obj is going to state [my next_state]"
                        }
                        Action accept -next_state accepted
                        Action reject -next_state rejected
                        Action mark_implemented -next_state implemented

                        # States
                        #   - form: the form to be used in a state
                        #   - view_method: Typically "view" (default) or "edit"
                        #State parameter {{form "en:tip-form"} {view_method edit}} 
                        #assigns the specified form to all states

                        State parameter {{form "en:tip.form"} {extra_js 1.js}}

                        State initial  -actions {save propose}
                        State proposed -actions {save accept reject}
                        State accepted -actions {save mark_implemented} 
                        State rejected -actions {save}
                        State implemented -actions {save}                        
                    }
                    form_constraints {@table:_name,wf_current_state,_creator,_last_modified}
                }
            
            aa_log "===== Workflow en:tip.wf created"



        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #calendar::delete -calendar_id $temp_calendar_id

        }
    }
    
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
