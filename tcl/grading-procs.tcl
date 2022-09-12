::xo::library doc {

  Test Item grading procs - support for different kind of grading
  types and schemes.

  @author Gustaf Neumann

}

#
# Potential TODOs:
#   - support different grading labels (currently numeric 1..5)
#   - support finer granularity
#

namespace eval ::xowf::test_item::grading {
  nx::Class create Grading {
    :property {precision ""}
    :property {title ""}
    #
    # The following two properties are specified by the sub-classes
    # and ensure that no grading is defined accidentally from the
    # base class.
    #
    :property {percentage_boundaries:required}
    :property {csv:required}

    :method init {} {
      #
      # Provide a default, self-descriptive title
      #
      if {${:title} eq ""} {
        set roundingClass [namespace tail [:info class]]
        if {$roundingClass ne "GradingRoundNone" && [string match *Round* $roundingClass]} {
          set round_string "#xowf.Rounding_scheme#: #xowf.Rounding_scheme-$roundingClass#,"
        } else {
          set round_string ""
        }
        if {$roundingClass ne "GradingRoundNone" && ${:precision} ne ""} {
          set precision "#xowf.Rounding_precision#: ${:precision},"
        } else {
          set precision ""
        }
        set :title "[namespace tail [self]]: $round_string $precision #xowf.Grade_boundaries#: ${:percentage_boundaries}"
        ns_log notice "[self] initialized with title ${:title}"
      }
      next
    }

    :method calc_grade {-percentage -points -achievable_points} {
      #
      # Return a numeric grade for an exam submission based on
      # percentage and the property "percentage_mapping". On
      # invalid data, return 0.
      #
      # When "-percentage" is provided, use this for calculation
      # Otherwise calculate percentage based on "-points" (which might
      # be custom rounded) and "-achievable_points".
      #

      if {![info exists percentage] && $achievable_points > 0} {
        set percentage \
            [format %.2f [expr {($points*100/$achievable_points) + 0.00001}]]
      }
      if {[info exists percentage]} {
        set grade 1
        set nrGrades [expr {[llength ${:percentage_boundaries}]+1}]
        if {$nrGrades ne 5} {
          ns_log warning "grading [self]: unexpected number of grades: $nrGrades"
        }
        set gradePos 0
        foreach boundary ${:percentage_boundaries} {
          if {$percentage < $boundary} {
            set grade [expr {$nrGrades - $gradePos}]
            break
          }
          incr gradePos
        }
      } else {
        set grade 0
      }
      return $grade
    }

    :method complete_dict {achieved_points} {

      # Important dict members of "achieved_points":
      #  - achievedPoints: points that the student has achieved in her exam
      #  - achievablePoints: points that the student could have achieved so far
      #  - totalPoints: points that the student can achieve when finishing the exam
      #
      #     achieved_points:    {achievedPoints 4.0 achievablePoints 4 totalPoints 4}
      #     percentage_mapping: {50.0 60.0 70.0 80.0}
      #
      # While "achievedPoints" and "achievablePoints" are calculated by
      # iterating over the submitted values, "totalPoints" contains
      # the sum of points of all questions of the exam, no matter if
      # these were answered or not.
      #
      if {![dict exists $achieved_points achievablePoints] && [dict exists $achieved_points totalPoints]} {
        ns_log warning "test_item::grading legacy call, use 'achievablePoints' instead of 'totalPoints'"
        dict set achieved_points achievablePoints [dict get $achieved_points totalPoints]
      }
      #
      # When the "achievedPoints" member is set to empty, and "details" are
      # provided, the caller can request a new calculation based on
      # the "details" member.
      #
      if {[dict get $achieved_points achievedPoints] eq ""
          && [dict exists $achieved_points details]
        } {
        set achievablePoints 0
        set achievedPoints 0
        #ns_log notice "RECALC in complete_dict "
        foreach detail [dict get $achieved_points details] {
          #ns_log notice "RECALC in complete_dict '$detail'"
          set achievedPoints   [expr {$achievedPoints   + [dict get $detail achieved]}]
          set achievablePoints [expr {$achievablePoints + [dict get $detail achievable]}]
        }
        dict set achieved_points achievedPoints $achievedPoints
        dict set achieved_points achievablePoints $achievablePoints
      }

      foreach key {
        achievedPoints
        achievablePoints
        totalPoints
      } {
        if {![dict exists $achieved_points $key]} {
          ns_log warning "test_item::grading dict without $key: $achieved_points"
          ::xo::show_stack
          dict set achieved_points $key 0
        }
      }
      #
      # Format all values with two comma precision. The values
      # achievedPointsRounded and "percentageRounded" are rounded to
      # the custom precision.
      #
      dict with achieved_points {
        dict set achieved_points achievedPointsRounded [format %.${:precision}f $achievedPoints]
        set achievedPoints [format %.2f $achievedPoints]
        set percentage  [format %.2f [expr {$totalPoints > 0 ? ($achievedPoints*100.0/$totalPoints) : 0}]]
        dict set achieved_points percentage $percentage
        dict set achieved_points percentageRounded [format %.${:precision}f $percentage]
      }
      #ns_log notice "R=$achieved_points"
      return $achieved_points
    }

    :public method print {-achieved_points:required} {
      #
      # Return a dict containing the members "panel" and "csv"
      # depending on the type of rounding options
      #
      set achieved_points  [:complete_dict $achieved_points]
      set grade            [:grade -achieved_points $achieved_points]
      dict with achieved_points {
        return [list panel [_ xowf.panel_[namespace tail [:info class]]] csv [subst ${:csv}]]
      }
    }
  }

  #----------------------------------------------------------------------
  # Class: xowf::test_item::grading::GradingRoundPoints
  #----------------------------------------------------------------------
  nx::Class create GradingRoundPoints -superclass Grading {
    :property {csv {$achievedPoints\t$achievedPointsRounded\t$percentage%\t$grade}}

    :public method grade {-achieved_points:required} {
      #
      # Return a numeric grade for an exam submission based on rounded
      # points. On invalid data, return 0.
      #
      set achieved_points [:complete_dict $achieved_points]
      dict with achieved_points {
        return [:calc_grade -points $achievedPointsRounded -achievable_points $totalPoints]
      }
    }
  }

  #----------------------------------------------------------------------
  # Class: xowf::test_item::grading::GradingRoundPercentage
  #----------------------------------------------------------------------
  nx::Class create GradingRoundPercentage -superclass Grading {
    :property {csv {$achievedPoints\t$percentage%\t$percentageRounded%\t$grade}}

    :public method grade {-achieved_points:required} {
      #
      # Return a numeric grade for an exam submission based on rounded
      # percentage. On invalid data, return 0.
      #
      set achieved_points [:complete_dict $achieved_points]
      if {[dict exists $achieved_points achievedPoints]} {
        dict with achieved_points {
          return [:calc_grade -percentage $percentageRounded]
        }
      }
    }
  }

  #----------------------------------------------------------------------
  # Class: xowf::test_item::grading::GradingRoundNone
  #----------------------------------------------------------------------
  nx::Class create GradingRoundNone -superclass Grading {
    :property {csv {$achievedPoints\t$percentage%\t$grade}}

    :public method grade {-achieved_points:required} {
      #
      # Return a numeric grade for an exam submission based with no
      # special rounding (2 digits). On invalid data, return 0.
      #
      if {[dict exists $achieved_points achievedPoints]} {
        set achieved_points [:complete_dict $achieved_points]
        dict with achieved_points {
          return [:calc_grade -percentage $percentage]
        }
      }
    }
  }

  #----------------------------------------------------------------------
  # Class: xowf::test_item::grading::GradingNone
  #----------------------------------------------------------------------
  nx::Class create GradingNone -superclass Grading {
    #
    # Grading scheme, which omits grading at all.
    #
    :property {csv {$achievedPoints\t$percentage%}}

    :public method grade {-achieved_points:required} {
      #
      # No grading scheme defined, return grading 0.
      #
      return 0
    }
  }

  #----------------------------------------------------------------------
  # Create instances of the Grading Schemes
  #----------------------------------------------------------------------
  GradingRoundPoints create ::xowf::test_item::grading::round-points \
      -precision 2 \
      -percentage_boundaries {50 60 70 80}

  GradingRoundPercentage create ::xowf::test_item::grading::round-percentage \
      -precision 2 \
      -percentage_boundaries {50 60 70 80}

  GradingRoundNone create ::xowf::test_item::grading::round-none \
      -percentage_boundaries {50 60 70 80}

  GradingNone create ::xowf::test_item::grading::none -percentage_boundaries {} \
      -title #xowf.Grading_scheme-None#


  #----------------------------------------------------------------------
  # Class: xowf::test_item::grading::gradingGradingRoundNone
  #----------------------------------------------------------------------

  ad_proc -private ::xowf::test_item::grading::grading_scheme_wf_item_id {
    -package_id:required
    -parent_id:required
  } {

    Return and cache the item_id of the edit-grading-scheme.wf. Maybe,
    we should generalize this function for other cases as well,
    therefore, we make this for the time being private.

  } {
    #
    # The mapping of the "edit-grading-scheme.wf" to its item_id is
    # very stable, unless someone defines another workflow
    # "edit-grading-scheme.wf". So we use here global cache, knowing
    # that this might not be universally correct.
    #
    set form_item_id [acs::misc_cache eval xowf-edit-grading-scheme.wf {
      #ns_log notice "??? load edit-grading-scheme-wf"
      ::$package_id instantiate_forms \
          -parent_id $parent_id \
          -default_lang en \
          -forms edit-grading-scheme.wf
    }]

    return $form_item_id
  }

  ad_proc -private ::xowf::test_item::grading::flush_grading_schemes {
    -package_id:required
    -parent_id:required
  } {

    Helper to hide the implementation details of the flushed cache.
    For now, we flush all grading schemes, but probably it would be
    sufficient to flush just a subset. The tricky part is that the
    grading objects are loaded potentially from the foll search
    hierarchy, starting with the local folder, reaching to the global
    objects. So, if anything is changed there, we would not notice
    immediately. Therefore, the passed-in package_id and parent_id are
    not used currently.

    This function is called, whenever a grading scheme is edited.
  } {
    ns_log notice "??? acs::misc_cache :flush_pattern xowf-grading-schemes*"
    acs::misc_cache flush_pattern -partition_key 0 xowf-grading-schemes*
  }

  ad_proc ::xowf::test_item::grading::load_grading_schemes {
    -package_id:required
    -parent_id:required
  } {

    Load the actual grading scheme objects defined for the package_id
    and parent_id.  It might be the case that this function is called
    multiple times by a single request (when e.g. multiple exams are
    on a single page). So we are caching the result to avoid repeated
    computations of the same result.

  } {
    set t0 [clock clicks -microseconds]
    #
    # Load the actual grading scheme objects
    #
    set grading_info [acs::misc_cache eval xowf-grading-schemes($package_id,$parent_id) {
      #
      # First get the item_id of the edit-grading-scheme.wf
      #
      set form_item_id [grading_scheme_wf_item_id \
                            -parent_id $parent_id \
                            -package_id $package_id]
      #
      # Get its instances. When creating the instances, the grading
      # objects are as well created.
      #
      ::xowiki::FormPage get_form_entries \
          -base_item_ids $form_item_id \
          -form_fields {} \
          -publish_status ready|production \
          -parent_id $parent_id \
          -package_id $package_id \
          -initialize true

      set grading_info ""
      foreach gso [::xowf::test_item::grading::Grading info instances -closure] {
        dict set grading_info $gso [$gso serialize]
      }
      set grading_info
    }]

    #
    # Recreate the grading scheme objects that do not exist in the
    # current thread.
    #
    foreach gso [dict keys $grading_info] {
      if {![nsf::is object $gso]} {
        eval [dict get $grading_info $gso]
        $gso destroy_on_cleanup
      }
    }
    set t1 [clock clicks -microseconds]
    ns_log notice "??? load_grading_schemes part2 [expr {($t1-$t0)/1000.0}]ms "
  }

}

::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    eval: (setq tcl-type-alist (remove* "method" tcl-type-alist :test 'equal :key 'car))
#    indent-tabs-mode: nil
# End:
