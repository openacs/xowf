namespace eval ::xowf::test {
    ad_proc -private question_names_from_input_form {d} {

        Parse html reply and extract question names
        (test-item-convention) from the form content.

        @return list of question names
    } {
        acs::test::dom_html root [::xowiki::test::get_content $d] {
            set input_names [$root selectNodes {//input/@name}]
            lappend input_names {*}[$root selectNodes {//textarea/@name}]
            ns_log notice "TEXTAREAS [$root selectNodes {//textarea/@name}]"
        }
        ns_log notice "input_names <$input_names>"
        return [lmap input_name [lsort -unique $input_names] {
            set name [lindex [split [lindex $input_name 1] .] 0]
            if {[string match "__*" $name]} continue
            ns_log notice "... check '$name'"
            if {[string range $name end end] ne "_"} continue
            string range $name 0 end-1
        }]
    }
}
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
