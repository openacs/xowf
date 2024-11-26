::xo::library doc {
  IP range procs - support different kind of IP ranges

  These class defined here is not related to the test-items, other
  than the fact that exams can be restricted. Since the IP-ranges are
  typically site specific, it is expected that sites define
  interesting IP ranges (such as e.g., WLAN, on-site, VPN, ...) in the
  iprange-init.tcl file.

  @author Gustaf Neumann
}

namespace eval ::xowf {
  nx::Class create IpRange {
    #
    # Class representing a range of IPs to be used to enforce access
    # control.
    #

    :property {allowed ""}
    :property {disallowed ""}
    :property {title ""}

    :method match {spec ip} {
      if {[string first / $spec] > -1 && [ns_ip match $spec $ip]} {
        return 1
      } elseif {[string first * $spec] > -1 && [string match $spec $ip]} {
        return 1
      } elseif {$spec eq $ip} {
        return 1
      }
      return 0
    }

    :public method allow_access {ip} {
      #
      # Check, if provided IP address is in the provided ranges of
      # disallowed or allowed addresses. First, the explicitly
      # disallowed addresses are checked, then the explicitly allowed
      # ones. Addresses can be specified in the following formats:
      #
      # <ul>
      #  <li> IP address in CIDR format (e.g., 127.208.0.0/16)
      #  <li> IP address containing wildcard "*"
      #  <li> literal IP address
      # </ul>
      # @return boolean value expressing success

      foreach spec ${:disallowed} {
        if {[:match $spec $ip]} {
          return 0
        }
      }

      foreach spec ${:allowed} {
        if {[:match $spec $ip]} {
          return 1
        }
      }
      return 0
    }
  }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    eval: (setq tcl-type-alist (remove* "method" tcl-type-alist :test 'equal :key 'car))
#    indent-tabs-mode: nil
# End:
