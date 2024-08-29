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
    # The parameter page needs a creation user. Since we are running
    # in a callback, the user_id is 0, which is not defined in the
    # users table. Therefore, we fetch the first site-wide admin user.
    #
    set user_id [::xo::dc list get_admin {
      select user_id,p.object_id from acs_permissions p, users u, acs_magic_objects m
      where user_id = p.grantee_id and p.object_id = m.object_id and m.name = 'security_context_root'
      FETCH FIRST 1 ROWS ONLY
    }]
    #
    # Initialize the package
    #
    ns_log notice ".... ::xowf::after-instantiate initialize package with -package_id $package_id -user_id $user_id"
    ::xowf::Package initialize -package_id $package_id -user_id $user_id

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
