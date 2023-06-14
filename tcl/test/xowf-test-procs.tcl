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
        "::xowiki::test::edit_form_page"
        "::xowiki::test::require_test_folder"

        "::acs::test::dom_html"
        "::acs::test::form_get_fields"
        "::acs::test::form_reply"
        "::acs::test::get_form"
        "::acs::test::get_url_from_location"
        "::acs::test::xpath::get_form"
        "::acs::test::xpath::get_form_values"
        "::ad_log"
        "::ad_return_complaint"
        "::ad_script_abort"
        "::ad_urlencode_query"
        "::xo::Context instproc invoke_object"
        "::xo::Package instproc reply_to_user"
        "::xo::PackageMgr instproc require"
        "::xo::db::CrClass instproc get_instance_from_db"
        "::xo::db::CrClass proc lookup"
        "::xo::db::CrItem instproc is_package_root_folder"
        "::xo::db::CrItem instproc set_live_revision"
        "::xotcl::Class instproc instmixin"
        "::xowf::Package instproc initialize"
        "::xowiki::BootstrapNavbar instproc render"
        "::xowiki::BootstrapNavbarDropdownMenu instproc render"
        "::xowiki::BootstrapNavbarDropdownMenuItem instproc render"
        "::xowiki::BootstrapNavbarDropzone instproc render"
        "::xowiki::FormPage instproc set_live_revision"
        "::xowiki::Includelet proc html_encode"
        "::xowiki::MenuItem instproc init"
        "::xowiki::Package instproc invoke"
        "::xowiki::require_parameter_page"

    } create_folder_with_page {

        Create a folder in an xowf instance with a form page and edit this

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
            aa_section "Create a simple form page in the folder."
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name page.form \
                -update [subst {
                    _title "Sample page"
                    _name hello
                    _text "Hello world!"
                    _nls_language $locale
                }]


            ###########################################################
            aa_section "Edit the form page."
            ###########################################################

            ::xowiki::test::edit_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder/hello \
                -update [subst {
                    _title "Sample page 2"
                    _text "Brave new world!"
                    _nls_language $locale
                }]

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
        "::xowiki::test::create_form"
        "::xowiki::test::create_form_page"
        "::xowiki::test::edit_form_page"
        "::xowiki::test::require_test_folder"
        "::xowf::WorkflowPage instproc www-edit"
        "::xowf::WorkflowPage instproc www-view"

        "::acs::test::form_get_fields"
        "::acs::test::form_set_fields"
        "::ad_log"
        "::ad_return_complaint"
        "::ad_script_abort"
        "::export_vars"
        "::security::csrf::validate"
        "::xo::ConnectionContext instproc form_parameter"
        "::xo::ConnectionContext instproc mobile"
        "::xo::ConnectionContext instproc set_parameter"
        "::xo::ConnectionContext instproc url"
        "::xo::ConnectionContext instproc user_id"
        "::xo::Context instproc invoke_object"
        "::xo::Package instproc reply_to_user"
        "::xo::Page proc requireCSS"
        "::xo::db::CrClass proc get_instance_from_db"
        "::xo::db::CrItem instproc is_package_root_folder"
        "::xo::db::CrItem instproc set_live_revision"
        "::xo::require_html_procs"
        "::xotcl::Class instproc instmixin"
        "::xowf::Context proc require"
        "::xowf::Package instproc destroy"
        "::xowf::Package instproc initialize"
        "::xowf::WorkflowPage instproc footer"
        "::xowf::WorkflowPage instproc get_action_obj"
        "::xowf::WorkflowPage instproc is_wf"
        "::xowf::WorkflowPage instproc is_wf_instance"
        "::xowf::WorkflowPage instproc post_process_dom_tree"
        "::xowf::WorkflowPage instproc post_process_form_fields"
        "::xowf::WorkflowPage instproc render_form_action_buttons"
        "::xowf::WorkflowPage instproc render_form_action_buttons_widgets"
        "::xowf::WorkflowPage instproc render_icon"
        "::xowf::WorkflowPage instproc wf_context"
        "::xowiki::BootstrapNavbar instproc render"
        "::xowiki::BootstrapNavbarDropdownMenu instproc render"
        "::xowiki::BootstrapNavbarDropdownMenuItem instproc render"
        "::xowiki::BootstrapNavbarDropzone instproc render"
        "::xowiki::FormPage instproc set_live_revision"
        "::xowiki::FormPage instproc www-edit"
        "::xowiki::Includelet proc html_encode"
        "::xowiki::MenuItem instproc init"
        "::xowiki::Package instproc invoke"
        "::xowiki::Package proc get_package_id_from_page_id"
        "::xowiki::Package proc instantiate_page_from_id"
        "::xowiki::autoname proc basename"
        "::xowiki::autoname proc new"
        "::xowiki::test::edit_form_page"
        rp_internal_redirect
    } create_workflow_with_instance {

        Create an xowf workflow and a instance in a folder.

        The procs list contains the public methods called via the web
        interface.
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
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $d \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]

            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}
            set locale [lang::system::locale]
            set lang [string range $locale 0 1]
            ::xowiki::test::create_form \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $lang:tip.form \
                -update [subst {
                    title "TIP Form"
                    nls_language $locale
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
                }]
            aa_log "Form  $lang:tip.form created"

            ###########################################################
            aa_section "Create the TIP workflow"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name Workflow.form \
                -update [subst -nocommands {
                    _title "TIP Workflow"
                    _name tip.wf
                    _nls_language $locale
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
                            :log "\$obj is going to state [:next_state]"
                        }
                        Action accept -next_state accepted
                        Action reject -next_state rejected
                        Action mark_implemented -next_state implemented

                        # States
                        #   - form: the form to be used in a state
                        #   - view_method: Typically "view" (default) or "edit"
                        # State parameter {{form "$lang:tip-form"} {view_method edit}}
                        # assigns the specified form to all states

                        State parameter {{form "$lang:tip.form"} {extra_js 1.js}}

                        State initial  -actions {save propose}
                        State proposed -actions {save accept reject}
                        State accepted -actions {save mark_implemented}
                        State rejected -actions {save}
                        State implemented -actions {save}
                    }
                    form_constraints {@table:_name,wf_current_state,_creator,_last_modified}
                }]

            aa_log "Workflow $lang:tip.wf created"

            ###########################################################
            aa_section "Create an instance of the TIP workflow and save it."
            # The workflow name is provided via "-form_name"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $lang:tip.wf \
                -update [subst {
                    _title "TIP 1"
                    _name tip1
                    _text {Should we create a tip?}
                    __action_save ""
                    _nls_language $locale
                }]

            aa_log "Workflow instance tip1 created"

            ###########################################################
            aa_section "Edit the workflow instance and propose the TIP"
            # (call the workflow action "propose")
            ###########################################################

            ::xowiki::test::edit_form_page \
                -last_request $d \
                -instance $instance \
                -path $testfolder/tip1 \
                -update {
                    __action_propose ""
                }


        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
        }
    }



    aa_register_case -cats {api} -procs {
        "::xowf::WorkflowConstruct instproc get_value"
    } workflow_constructs {

        Test behavior of conditional and non-conditional expressions
        of WorkflowConstructs.

    } {

        ::xowf::WorkflowConstruct instforward true set "" 1
        ::xowf::WorkflowConstruct instforward false set "" 0

        ::xowf::WorkflowConstruct x

        aa_equals "non-conditional test with empty" [x get_value ""] ""
        aa_equals "non-conditional test with nonempty scalar" [x get_value "a"] "a"

        aa_equals "non-conditional test with nonempty list" [x get_value {a b}] "a b"
        aa_equals "non-conditional test with nonempty list" [x get_value "a b"] "a b"

        aa_equals "conditional test, true branch" [x get_value "? true a default b"] "a"
        aa_equals "conditional test, false branch" [x get_value "? false a default b"] "b"

        aa_equals "conditional test, true branch list" [x get_value "? true {a b} default {b c}"] "a b"
        aa_equals "conditional test, false branch list" [x get_value "? false {a b} default {b c}"] "b c"
    }

    aa_register_case \
        -cats {api} \
        -init_classes {xowf_require_test_instance} \
        -procs {
            "::xowf::Package proc create_new_workflow_page"
        } create_new_workflow_page {

            Test ::xowf::Package create_new_workflow_page

        } {
            aa_run_with_teardown -rollback -test_code {
                set instance $_xowf_test_instance_name
                set testfolder .testfolder

                set n [site_node::get_from_url -url $instance]
                set package_id [dict get $n object_id]

                ::xowf::Package initialize -package_id $package_id
                set parent_id [$package_id folder_id]

                set item_ref_info [$package_id item_ref \
                                       -use_site_wide_pages true \
                                       -default_lang en \
                                       -parent_id $parent_id \
                                       en:Workflow.form]
                set page_template [dict get $item_ref_info item_id]

                set name testWF
                set title testWFTitle
                set wf [::xowf::Package create_new_workflow_page \
                            -package_id $package_id \
                            -parent_id $parent_id \
                            -name $name \
                            -title $title \
                            -instance_attributes {
                                a b
                                c d
                            }]

                aa_equals "$wf: name is correct" $name [$wf name]
                aa_equals "$wf: title is correct" $title [$wf title]
                aa_equals "$wf: property 'a' is correct" b [$wf property a]
                aa_equals "$wf: property 'c' is correct" d [$wf property c]

                aa_false "$wf: package_id is not set on the fresh object" [$wf exists package_id]

                $wf set package_id $package_id
                $wf save_new

                set item_id [$wf item_id]
                set found_p [::xo::dc 0or1row check_wf {
                    select instance_attributes from
                    xowiki_form_instance_item_index i,
                    cr_revisions r,
                    xowiki_page_instance pi
                    where i.item_id = :item_id
                    and r.item_id = i.item_id
                    and r.revision_id = pi.page_instance_id
                    and i.package_id = :package_id
                    and i.page_template = :page_template
                    and i.name like '%' || name
                    and r.title = :title
                }]
                aa_true "Workflow was created in the database" $found_p
                if {$found_p} {
                    aa_equals "Properties have been stored correctly" \
                        [dict create {*}$instance_attributes] [dict create a b c d]
                }
            }
        }

    #
    # This test could be used to make sure binaries in use in the code are
    # actually available to the system.
    #
    # aa_register_case -cats {
    #     smoke production_safe
    # } -procs {
    #     util::which
    # } xowf_exec_dependencies {
    #     Test external command dependencies for this package.
    # } {
    #     foreach cmd [list \
    #                      [::util::which qrencode] \
    #                 ] {
    #         aa_true "'$cmd' is executable" [file executable $cmd]
    #     }
    # }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
