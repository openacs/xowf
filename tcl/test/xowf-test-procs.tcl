namespace eval ::xowf::test {

    aa_register_case -cats {web} -procs {
        "::xowf::Pacakge instproc initialize"
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
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
