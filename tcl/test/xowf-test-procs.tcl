namespace eval ::xowf::test {

    aa_register_case -cats {web} -procs {
        "::xowf::Package instproc initialize"
        "::xowiki::Package instproc invoke"
        "::xo::Package instproc reply_to_user"        
    } create_folder_with_page {

        Create a folder in a xowf instance with a form page and edit this
        
    } {
        #
        # Run the test under the current user_id.
        #
        set user_id [ad_conn user_id]
        ns_log notice USER=$user_id

        set instance /xowf
        set testfolder .testfolder

        try {
            #
            # Make sure we have a fresh test folder
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
            # Create a simple form page in the folder.
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
            # Edit the form page.
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
        "::xowiki::Package instproc invoke"
        "::xo::Package instproc reply_to_user"        
    } create_workflow_with_instance {

        Create a xowf workflow and a instance in a folder.
        
    } {
        #
        # Run the test under the current user_id.
        #
        set user_id [ad_conn user_id]
        ns_log notice USER=$user_id

        set instance /xowf
        set testfolder .testfolder

        try {
            #
            # Make sure we have a test folder
            #
            #set d [aa_http -user_id $user_id $instance/]
            #set set_cookies [ns_set array [dict get $d headers]]
            #aa_log set_cookies=$set_cookies
            
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
                    form {<form> @_text@ @wf_current_state@ @_description@</form>}
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
                            :log "$obj is going to state [:next_state]"
                        }
                        Action accept -next_state accepted
                        Action reject -next_state rejected
                        Action mark_implemented -next_state implemented

                        # States
                        #   - form: the form to be used in a state
                        #   - view_method: Typically "view" (default) or "edit"
                        # State parameter {{form "en:tip-form"} {view_method edit}} 
                        # assigns the specified form to all states

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

            #
            # Create an instance of the TIP workflow and save it.
            # The workflow name is provided via "-form_name"
            #
            ::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name tip.wf \
                -update {
                    _title "TIP 1"
                    _name en:tip1
                    _text {Should we create a tip?}
                    __action_save ""
                }

            aa_log "===== Workflow instance tip1 created"

            #
            # Edit the workflow instance and propose the TIP (call the
            # workflow action "propose")
            #
            ::xowiki::test::edit_form_page \
                -user_id $user_id \
                -instance $instance \
                -path $testfolder/tip1 \
                -update {
                    __action_propose ""
                }

            
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
