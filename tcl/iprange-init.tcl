#
# Register the IP ranges for restricted access.
#
namespace eval ::xowf::iprange {

    #
    # The "all" range should be available on every sites
    #
    ::xowf::IpRange create ::xowf::iprange::all \
        -title "All" \
        -allowed {*}

    #
    # One example for a WLAN. Note that multiple specs for allowed and
    # disalled can be specified. For the allowed formats, see:
    #
    #    https://openacs.org/xotcl/show-object?object=::xowf::IpRange
    #
    # ::xowf::IpRange create ::xowf::iprange::wlan \
    #    -title "WU WLAN" \
    #    -allowed {
    #        137.208.216.0/21
    #    }
}
