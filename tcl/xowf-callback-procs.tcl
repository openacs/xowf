::xo::library doc {
  XoWiki - Callback procs

  @creation-date 2006-08-08
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowf {

  ad_proc -private after-instantiate {-package_id:required } {
    Callback when this an xowf instance is created
  } {
    ns_log notice "++++ BEGIN ::xowf::after-instantiate -package_id $package_id"

    #
    # Create a parameter page for convenience
    #
    ::xowf::Package initialize -package_id $package_id
    ::xowf::Package configure_fresh_instance \
        -package_id $package_id \
        -parameters [::xowf::Package default_package_parameters] \
        -parameter_page_info [::xowf::Package default_package_parameter_page_info]

    ns_log notice "++++ END ::xowf::after-instantiate -package_id $package_id"
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
