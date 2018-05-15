namespace eval ::xowf::test {

    ad_proc -private ::xowf::test::get_object_name {node} {
	return [$node selectNodes {string(//form//input[@name="__object_name"]/@value)}]
    }
    ad_proc -private ::xowf::test::get_form_value {node id name} {
	set q string(//form//input\[@id='F.$id.$name'\]/@value)
	return [$node selectNodes $q]
    }

    ad_proc -private ::xowf::test::get_url_from_location {d} {
	set location [ns_set iget [dict get $d headers] Location ""]
	set url [ns_parseurl $location]
	aa_log "parse url [ns_parseurl $location]"
	if {[dict get $url tail] ne ""} {
	    set url [dict get $url path]/[dict get $url tail]
	} else {
	    set url [dict get $url path]
	}
	return $url
    }


    ad_proc -private ::xowf::test::get_form_values {node className} {
	set values {}
	foreach n [$node selectNodes //form\[contains(@class,'$className')\]//input] {
	    set name  [$n getAttribute name]
	    set value [$n getAttribute value]
	    lappend values $name $value
	}
	return $values
    }
    ad_proc -private ::xowf::test::get_form_action {node className} {
	return [$node selectNodes string(//form\[contains(@class,'$className')\]/@action)]
    }

    ad_proc -private ::xowf::test::form_reply {
	-user_id
	-url
	{-update {}}
	form_content
    } {
	foreach {att value} $update {
	    dict set form_content $att $value
	}
	ns_log notice "final form_content $form_content"
	set export {}
	foreach {att value} $form_content {
	    lappend export [list $att $value]
	}
	set body [export_vars $export]
	ns_log notice "body=$body"
	return [aa_http \
		    -user_id $user_id \
		    -method POST -body $body \
		    -headers {Content-Type application/x-www-form-urlencoded} \
		    $url]

    }

    aa_register_case -cats {web} -procs {
	"::xowf::Pacakge instproc initialize"
    } create_folder {

	Create a folder in a xowf instance
    } {

	# run the test under the current user_id.
	set user_id [ad_conn user_id]
	ns_log notice USER=$user_id

	set instance /xowf
	set testfolder testfolder
	#::caldav::test::basic_setup -user_id $user_id -once -private=true

	try {
	    #
	    # First check, of test folder exists already.
	    #
	    set d [aa_http -user_id $user_id $instance/$testfolder]
	    if {[dict get $d status] == 200} {
		aa_log "test folder $testfolder exists already, ... delete it"
		set d [aa_http -user_id $user_id $instance/$testfolder?m=delete&return_url=/$instance/]
		aa_equals "Status code valid" [dict get $d status] 302
		set location [::xowf::test::get_url_from_location $d]
		set d [aa_http -user_id $user_id $location/]
		aa_equals "Status code valid" [dict get $d status] 200
	    } else {
		aa_log "create a frest test folder $testfolder"
	    }

	    #
	    # When we try folder creation without being logged in, we
	    # expect a permission denied error.
	    #
	    set d [aa_http -user_id 0 $instance/folder.form?m=create-new&return_url=/$instance/]
	    aa_equals "Status code valid" [dict get $d status] 403

	    #
	    # Try folder-creation with the current user. We expect
	    # this to redirect us to the newly created form page.
	    #
	    set d [aa_http -user_id $user_id $instance/folder.form?m=create-new&return_url=/$instance/]
	    aa_equals "Status code valid" [dict get $d status] 302

	    #
	    # aa_http allows just relative URLs, so get it from the location
	    #
	    set location [::xowf::test::get_url_from_location $d]
	    aa_true "location '$location' is valid" {$location ne ""}

	    #
	    # Call edit method on the newly created form page
	    #
	    set d [aa_http -user_id $user_id $location]
	    aa_equals "Status code valid" [dict get $d status] 200

	    set response [dict get $d body]

	    aa_dom_html root $response {
		aa_xpath::non_empty $root {
		    //form[contains(@class,'Form-folder')]//button
		}
		set id          [::xowf::test::get_object_name $root]
		set folder_name [::xowf::test::get_form_value $root $id _name]
		set creator     [::xowf::test::get_form_value $root $id _creator]
		aa_true "folder_name '$folder_name' is non-empty" {$folder_name ne ""}
		aa_true "creator '$creator' is non-empty" {$creator ne ""}

		set form_action  [::xowf::test::get_form_action $root Form-folder]
		aa_true "form_action '$form_action' is non-empty" {$form_action ne ""}

		set form_content [::xowf::test::get_form_values $root Form-folder]
		set names [dict keys $form_content]
		aa_true "form has at least 10 fields" { [llength $names] >= 10 }
	    }

	    set d [::xowf::test::form_reply -user_id $user_id -url $form_action -update {
		_title "Test folder"
		_name en:testfolder
	    } $form_content]
	    aa_equals "Status code valid" [dict get $d status] 302

	    set location [::xowf::test::get_url_from_location $d]
	    aa_true "location '$location' is valid" {$location ne ""}

	    set d [aa_http -user_id $user_id $location/]
	    aa_equals "Status code valid" [dict get $d status] 200

	    ########################################################################
	    # Create a page.form instance in the new testfolder
	    ########################################################################
	    ::xowf::Package initialize -url /$instance/
	    set folder_id [::$package_id lookup -name $testfolder]

	    aa_log "... create a page in test test folder $folder_id"
	    set d [aa_http \
		       -user_id $user_id \
		       $instance/$testfolder/page.form?m=create-new&parent_id=$folder_id&return_url=/$instance/$testfolder/]
	    aa_equals "Status code valid" [dict get $d status] 302
	    set location [::xowf::test::get_url_from_location $d]
	    aa_true "location '$location' is valid" {$location ne ""}

	    #
	    # call edit on the new page
	    #
	    set d [aa_http -user_id $user_id $location/]
	    aa_equals "Status code valid" [dict get $d status] 200

	    set response [dict get $d body]
	    aa_dom_html root $response {
		aa_xpath::non_empty $root {
		    //form[contains(@class,'Form-page')]//button
		}
		set id          [::xowf::test::get_object_name $root]
		set page_name   [::xowf::test::get_form_value $root $id _name]
		set creator     [::xowf::test::get_form_value $root $id _creator]
		aa_true "page_name '$page_name' is empty" {$page_name eq ""}
		aa_true "creator '$creator' is non-empty" {$creator ne ""}

		set form_action  [::xowf::test::get_form_action $root Form-page]
		aa_true "form_action '$form_action' is non-empty" {$form_action ne ""}

		set form_content [::xowf::test::get_form_values $root Form-page]
		set names [dict keys $form_content]
		aa_log "form names: [lsort $names]"
		aa_true "page has at least 9 fields" { [llength $names] >= 9 }
	    }

	    set d [::xowf::test::form_reply -user_id $user_id -url $form_action -update {
		_title "Sample page"
		_name en:page
		_text "Hello world!"
	    } $form_content]
	    aa_equals "Status code valid" [dict get $d status] 302

	    set location [::xowf::test::get_url_from_location $d]
	    aa_true "location '$location' is valid" {$location ne ""}

	    set d [aa_http -user_id $user_id $location/]
	    aa_equals "Status code valid" [dict get $d status] 200

	    set page_info [::$package_id item_ref -default_lang en -parent_id $folder_id en:page]
	    set item_id [dict get $page_info item_id]
	    aa_log "lookup of $testfolder/page -> $item_id"
	    ::xo::db::CrClass get_instance_from_db -item_id $item_id

	    set d [aa_http -user_id $user_id \
		       $instance/admin/set-publish-state?state=ready&revision_id=[$item_id revision_id]]
	    aa_equals "Status code valid" [dict get $d status] 302


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
