::xo::library doc {
  XoWiki Workflow - main library classes and objects

  @author Gustaf Neumann
  @creation-date 2008-03-05
}

# TODO:
# - after import, references are not updated
#   (same for plain references); after_import methods?
#
# - Roles
# - assignment
# - workflow-assignment includelet (over multiple workflows and
#   package instances)

::xo::library require -package xowiki xowiki-procs
::xo::library require -package xotcl-core 06-package-procs
::xo::library require -package xowiki menu-procs

namespace eval ::xowf {
  #
  # Should we use a shared or a per-context workflow definition.
  #
  set ::xowf::sharedWorkflowDefinition 1

  ::xo::PackageMgr create ::xowf::Package \
      -package_key "xowf" -pretty_name "XoWiki Workflow" \
      -superclass ::xowiki::Package

  Package site_wide_package_parameter_page_info {
    name en:xowf-site-wide-parameter
    title "Xowf Site-wide Parameter"
    instance_attributes {
      index_page table-of-contents
      MenuBar t
      top_includelet none
      production_mode f
      with_user_tracking t with_general_comments f with_digg f with_tags f
      with_delicious f with_notifications f
      security_policy ::xowiki::policy1
    }}

  Package site_wide_package_parameters {
    parameter_page en:xowf-site-wide-parameter
  }

  Package site_wide_pages {
    Workflow.form
    atjob-form

    TestItemText.form
    TestItemShortText.form
    TestItemMC.form
    TestItemSC.form
    TestItemReorder.form
    TestItemUpload.form
    TestItemComposite.form
    TestItemPoolQuestion.form

    ExamFolder

    online-exam.wf
    inclass-quiz.wf
    inclass-exam.wf
    inclass-exam-statistics.wf
    edit-interaction.wf
    edit-grading-scheme.wf
    answer-single-question.wf

    quiz-select_question.form
    select_question.form
    select-topics.form
    select-group-members.form
  }

  Package default_package_parameters {
    parameter_page en:xowf-default-parameter
  }

  Package default_package_parameter_page_info {
    name en:xowf-default-parameter
    title "Xowf Default Parameter"
    instance_attributes {
      MenuBar t top_includelet none production_mode f with_user_tracking t with_general_comments f
      with_digg f with_tags f
      ExtraMenuEntries {{config -use xowf}}
      with_delicious f with_notifications f security_policy ::xowiki::policy1
    }
  }

  Package ad_proc create_new_workflow_page {
    -package_id:required
    -parent_id:required
    -name:required
    -title:required
    {-instance_attributes ""}
  } {
    Helper proc for loading workflow prototype page with less effort.
  } {
    #
    # Load Workflow.form
    #
    xo::Package require $package_id
    set item_ref_info [$package_id item_ref -use_site_wide_pages true -default_lang en \
                           -parent_id $parent_id \
                           en:Workflow.form]
    set page_template [dict get $item_ref_info item_id]
    if {$page_template != 0} {
      #
      # Create FormPage
      #
      set p [::xowiki::FormPage new \
                 -name $name \
                 -title $title \
                 -set text {} \
                 -instance_attributes $instance_attributes \
                 -page_template $page_template]
    } else {
      ns_log error "could not load Workflow form, therefore, creation of workflow $name failed as well"
      set p ""
    }
    return $p
  }


  Package ad_instproc initialize {} {
    Add mixin ::xowf::WorkflowPage to every FormPage.
  } {
    #
    # This method is called, whenever an xowf package is initialized.
    #
    next
    #:msg "::xowiki::FormPage instmixin add ::xowf::WorkflowPage"
    ::xowiki::FormPage instmixin add ::xowf::WorkflowPage
  }

  Package instproc call {object method options} {
    if {[$object istype ::xowiki::FormPage]} {
      if {[$object is_wf_instance]} {
        set ctx [::xowf::Context require $object]
        #:msg "wfi: creating context form object $object = $ctx, chlds=[$ctx info children]"
        #:msg "wfi: o $object has mixins [$object info mixin]"
      } elseif {[$object is_wf]} {
        set ctx [::xowf::Context require $object]
        #:msg "wf: creating context form object $object = $ctx, chlds=[$ctx info children]"
        #:msg "wf: o $object has mixins [$object info mixin]"
      }
    }
    next
  }

  Package ad_instproc destroy {} {
    remove mixin
  } {
    #
    # In general, it is possible, that multiple xowf packages are
    # concurrently active in one thread. We want to remove the mixin
    # only, when the last instance is deleted.
    #
    if {[llength [[self class] allinstances]] == 1} {
      ::xowiki::FormPage instmixin delete ::xowf::WorkflowPage
    }
    next
  }



  #   Package instproc delete {-item_id -name} {
  #     # Provide a method to delete the foreign key references, when
  #     # an item for an atjob is deleted. We do here the same magic
  #     # as in ::xowiki::Package to obtain the item_id
  #     if {![info exists item_id]} {set item_id [:query_parameter item_id:int32]}
  #     if {$item_id ne ""} {
  #       db_dml dbqd..xowf_delete "delete from xowf_atjob where owner_id = :item_id"
  #     }
  #     next
  #   }


  #
  # Most primitive class, used it for WorkflowConstructs (things, user
  # can write in their workflow definitions) and WorkflowContainer.
  #
  ::xotcl::Class create WorkflowObject

  WorkflowObject instproc wf_context {} {
    #
    # Try to determine the workflow context via call-stack.
    #
    set max [info level]
    for {set i 0} {$i < $max} {incr i} {
      if {![catch {set s [uplevel $i self]} msg]} {
        set obj [lindex $s 0]
        if {[$obj istype ::xowf::Context]} {
          #:log "$obj [nsf::is object $obj] precedence: [$obj info precedence]"
          return $obj
        }
        if {[$obj hasclass ::xowf::WorkflowPage]} {
            return [$obj wf_context]
        }
      }
    }
    #
    # If everything fails, fall back to the old-style method, which is
    # incorrect for shared workflow definitions. This fallback is
    # just for transitional code.
    #
    ad_log warning "cannot determine wf_context from call-stack"
    return [:info parent]
  }


  if {$::xowf::sharedWorkflowDefinition > 0} {

    #
    # Workflow Container
    #
    Class create WorkflowContainer -superclass WorkflowObject -parameter {
      {autoname}
      {auto_form_constraints ""}
      {auto_form_template ""}
      {debug 0}
      {shared_definition 1}
    }

    WorkflowContainer instproc object-specific args {
      #
      # make sure, we have always a value
      #
      if {![info exists :object-specific]} {
        set :object-specific ""
      }
      #
      # If called without args, return the current value, otherwise
      # aggregate the values.
      #
      set l [llength $args]
      switch $l {
        0 {
          #
          # Called without args, return the current value
          #
          return ${:object-specific}
        }
        1 {
          #
          # Called with a single value, aggregate partial values (and
          # separate these by an empty line for safety)
          #
          append :object-specific \n [lindex $args 0]
          #ns_log notice "=== object-specific [self] ${:object-specific}"
        }
        default {
          error "wrong number of arguments"
        }
      }
    }

    #
    # The methods "object-specific" and "wf-specific" are pretty
    # similar but these define different instance
    # variables. "object-specific" is for instances of a workflow,
    # "wf-specific" is for the workflow object itself.
    #
    WorkflowContainer instproc object-specific args {
      :specific object {*}$args
    }
    WorkflowContainer instproc wf-specific args {
      :specific wf {*}$args
    }

    WorkflowContainer instproc specific {type args} {
      #
      # Make sure, we have always a value.
      #
      if {![info exists :$type-specific]} {
        set :$type-specific ""
      }
      #
      # If called without args, return the current value, otherwise
      # aggregate the values.
      #
      set l [llength $args]
      switch $l {
        0 {
          #
          # Called without args, return the current value
          #
          return [set :$type-specific]
        }
        1 {
          #
          # Called with a single value, aggregate partial values (and
          # separate these by an empty line for safety)
          #
          append :$type-specific \n [lindex $args 0]
          #ns_log notice "=== $type-specific [self] [set :$type-specific]"
        }
        default {
          error "wrong number of arguments"
        }
      }
    }


    WorkflowContainer instproc init {} {
      set :creation_time [clock seconds]
      ::xo::add_cleanup [self] [list [self] cleanup]
      next
    }

    WorkflowContainer instproc cleanup {} {
      #
      #  Keep workflow container 10 minutes in the per-thread cache.
      #
      if {[clock seconds] - ${:creation_time} > 600} {
        #ns_log notice "======================== WorkflowContainer [self] self destroys"
        ::xo::remove_cleanup [self]
        :destroy
      }
    }


    WorkflowContainer instproc object {} {
      #
      # Method for emulating "object". Object specific code cannot
      # work in shared workflow definitions, since one workflow
      # definition is used in the shared case for many objects at the
      # same time. Object specific code should use the
      # "object-specific" method below.
      #
      # Here we fall back to the unshared case
      #
      set ctx [:wf_context]
      set object [$ctx object]
      set template [$object page_template]
      if {${:shared_definition}} {
        ns_log warning "Workflow $template [$template name] does not work with\
           shared definitions since it refers to 'object'; fall back to unshared definition"
        set :shared_definition 0
      }
      return $object
    }

  }

  #
  # Workflow Context
  #
  Class create Context -parameter {
    {current_state "[self]::initial"}
    workflow_definition
    object
    {all_roles false}
    {default_definition ""}
    in_role
    wf_container
  }

  # forward property management to the workflow object
  Context instforward property {%set :object} %proc
  Context instforward get_property {%set :object} %proc
  Context instforward set_property {%set :object} %proc
  Context instforward set_new_property {%set :object} set_property -new 1

  # forward form_constraints, view_method, form, and form_loader the to current state object
  Context instforward get_form_constraints {%set :current_state} form_constraints
  Context instforward get_view_method      {%set :current_state} view_method
  Context instforward form                 {%set :current_state} form
  Context instforward form_loader          {%set :current_state} form_loader

  #
  # The following methods autoname, auto_form_constraints,
  # auto_form_template, and debug contain legacy access methods for
  # cases, where no shared workflow definition is used.
  #
  Context instproc autoname {} {
    #
    # We want to distinguish between a set "autoname" and an
    # unspecified "autoname". Therefore, we do not want to use a
    # default in the WorkflowContainer
    #
    if {${:wf_container} ne [self]} {
      if {[${:wf_container} exists autoname]} {
        return [${:wf_container} autoname]
      }
    } elseif {[info exists :autoname]} {
      return ${:autoname}
    }
    return "f"
  }
  Context instproc auto_form_constraints {} {
    if {${:wf_container} ne [self]} {
      return [${:wf_container} auto_form_constraints]
    } elseif {[info exists :auto_form_constraints]} {
      return ${:auto_form_constraints}
    }
    return ""
  }
  Context instproc auto_form_template {} {
    if {${:wf_container} ne [self]} {
      return [${:wf_container} auto_form_template]
    } elseif {[info exists :auto_form_template]} {
      return ${:auto_form_template}
    }
    return ""
  }
  Context instproc debug {} {
    if {${:wf_container} ne [self]} {
      return [${:wf_container} debug]
    } elseif {[info exists :debug]} {
      return ${:debug}
    }
    return 0
  }

  Context instproc wf-specific args {
    if {[llength $args] > 0} {
      ns_log warning "wf-specific NOT SUPPORTED for non shared workflow " \
          "${:object} [${:object} name]: $args"
    }
  }

  Context instproc object-specific {code} {
    #:log "=== legacy call <$code>"
    :uplevel [list ${:object} eval $code]
  }

  #
  # container specific methods on Context
  #
  Context instproc wf_definition_object {name} {
    return ${:wf_container}::$name
  }

  Context instproc set_current_state {value} {
    set :current_state ${:wf_container}::$value
  }

  Context instproc get_current_state {} {
    namespace tail ${:current_state}
  }

  Context instproc get_actions {} {
    set actions [list]
    foreach action [${:current_state} get_actions] {
      lappend actions ${:wf_container}::$action
    }
    #:msg "for ${:current_state} actions '$actions"
    return $actions
  }
  Context instproc defined {what} {
    set result [list]
    foreach c [${:wf_container} info children] {
      if {[$c istype $what]} {lappend result $c}
    }
    return $result
  }

  Context instproc resolve_form_name {-object:required name} {
    set package_id [$object package_id]
    set parent_id [$object parent_id]
    set item_info [::$package_id item_ref -normalize_name false \
                       -use_package_path 1 \
                       -use_site_wide_pages true \
                       -default_lang [$object lang] \
                       -parent_id $parent_id \
                       $name]
    #ns_log notice "*** resolve_form_name <$name> in $parent_id [$parent_id name] => $item_info"
    set item_id [dict get $item_info item_id]
    set form_name [dict get $item_info prefix]:[dict get $item_info stripped_name]
    return [list form_id $item_id name $form_name]
  }

  Context instproc default_load_form_id {form_name} {
    #:msg "resolving $form_name in state [:current_state] via default form loader"
    set form_id 0
    if {$form_name ne ""} {
      set resolved [:resolve_form_name -object ${:object} $form_name]
      set form_id [dict get $resolved form_id]
      if {$form_id == 0} {
        ns_log warning "could not resolve '$form_name' for ${:object}: $resolved"
      }
      #:msg ".... object ${:object} ==> id = $form_id"
    }
    return $form_id
  }
  ::nsf::method::property Context default_load_form_id returns integer

  Context instproc create_auto_form {object} {
    #
    # Create a form on the fly. The created form can be influenced by
    # "auto_form_template" and "auto_form_constraints".
    #
    set vars [dict keys [$object set instance_attributes]]
    set template [:auto_form_template]
    if {$template ne ""} {
      :log "USE autoform template"
    } elseif {[llength $vars] == 0} {
      #set template "AUTO form, no instance variables defined,<br>@_text@"
      set template "@_text@"
    } else {
      set template "@[join $vars @,@]@<br>@_text@"
    }

    #:log "USE auto-form template=$template, vars=$vars \
    #        IA=[$object set instance_attributes], \
    #        V=[$object info vars] auto [:autoname]"

    set package_id [$object package_id]
    return [::xowiki::Form new \
                -package_id $package_id \
                -parent_id [::$package_id folder_id] \
                -name "Auto-Form" \
                -anon_instances [:autoname] \
                -form {} \
                -text [list $template text/html] \
                -form_constraints [:auto_form_constraints] \
                -destroy_on_cleanup ]
  }

  Context instproc force_named_form {form_name} {
    #
    # By using this method in the "initialize" action, one can bypass
    # the state specific forms and force a form to the certain name
    #
    set form_id [:default_load_form_id $form_name]
    if {$form_id == 0} {
      ns_log warning "use_named_form: could not locate form $form_name"
    } else {
      if {![nsf::is object ::${form_id}]} {
        ::xo::db::CrClass get_instance_from_db -item_id ${form_id}
      }
      set :form_id $form_id
    }
  }
  Context instproc flush_form_object {} {
    unset -nocomplain :form_obj
  }
  Context instproc form_object {object} {
    set parent_id [$object parent_id]
    # After this method is activated, the form object of the form of
    # the current state is created and the instance variable form_id
    # is set.
    #
    # Load the actual form only once for this context.  We cache the
    # object name of the form in the context.
    #
    if {[info exists :form_obj]} {
      return ${:form_obj}
    }

    set package_id [$object package_id]
    #
    # We have to load the form, maybe via a form loader.  If the
    # form_loader is set nonempty and the method exists, then use the
    # form loader instead of the plain lookup. In case the form_loader
    # fails, it is supposed to return 0.
    #
    set loader [:form_loader]
    #:msg form_loader=$loader

    # TODO why no procsearch instead of "info methods"?
    if {$loader eq "" || [:info methods $loader] eq ""} {
      set form_id [:default_load_form_id [${:current_state} form]]
      if {$form_id == 0} {
        :log "=== NO default_load_form_id state ${:current_state} form <[${:current_state} form]>"
        #
        # When no form was found by the form loader ($form_id == 0) we
        # create automatically a form.
        #
        set form_object [:create_auto_form $object]
        :log "=== autoform $form_object"
      }
    } else {
      #:msg "using custom form loader $loader for [:form]"
      set form_object [:$loader [:form]]
    }

    #
    # At this place, the variable "form_id" might contain an id
    # (integer) or an object, provided by the custom file loader.
    #
    #:msg form_id=$form_id

    if {![info exists form_object]
        && [string is integer -strict $form_id]
        && $form_id > 0
      } {
      # just load the object conditionally
      if {![nsf::is object ::$form_id]} {
        ::xo::db::CrClass get_instance_from_db -item_id $form_id
      }
      set form_object ::$form_id
      #:msg form_object=$form_object
    }

    if {[$form_object istype "::xowiki::Form"]} {
      #
      # The item returned from the form loader was a form,
      # everything is fine.
      #
      #:msg form_object=$form_object-isForm

    } elseif {[$form_object istype "::xowiki::FormPage"]} {
      #
      # We got a FormPage. This FormPage might be a pseudo form (a
      # FormPage containing the property "form"). If not, add a "form"
      # property from the rendered content.
      #
      #:msg form_object=$form_object-pseudoForm-with-form=[$form_object property form]
      if {[$form_object property form] eq ""} {
        #
        # The FormPage contains no form, so try to provide one.  We
        # obtain the content by rendering the page_content. In some
        # cases it might be more efficient to obtain the content
        # from property "_text", but this might lead to unexpected
        # cases where the formpage uses _text for partial
        # information.
        #
        set text [$form_object render_content]
        $form_object set_property -new 1 form "<form>$text</form>"
        #:msg "_text=[$form_object property _text]"
      }
    } elseif {[$form_object info class] eq "::xowiki::Page"} {

      #
      # The $form_object is in reality an xowiki Page, make it look
      # like a form (with form buttons).
      #
      set form_object [::xowiki::Form new \
                           -package_id $package_id \
                           -parent_id [::$package_id folder_id] \
                           -name "Auto-Form" \
                           -anon_instances [:autoname] \
                           -form "<form>[$form_object get_html_from_content [::$form_id text]]</form>" \
                           -text "" \
                           -form_constraints "" \
                           -destroy_on_cleanup ]
    }

    set :form_obj $form_object
    return $form_object
  }
  ::nsf::method::property Context form_object returns object


  #Context instproc destroy {} {
  #  :log "DESTROY vars <[:info vars]>"
  #  next
  #}

  Context instproc create_workflow_definition {workflow_definition} {
    #
    # Validation: since for shared workflow definitions, the workflow
    # container is named after the revision, we need only a validation
    # of "xowf::include" content (external source content). So the,
    # container-specific workflow_definition is revision specific, and
    # it will never change.
    #
    # set :__workflow_definition [list $workflow_definition]
    #
    if {[catch {${:wf_container} contains "
       Class create Action   -superclass  ::xowf::Action
       Class create State    -superclass  ::xowf::State
       Class create Condition -superclass ::xowf::Condition
       Class create Property -superclass  ::xowf::Property -set abstract 1
       [:default_definition]
       $workflow_definition"} errorMsg]} {
      ns_log error "Error in workflow definition ([${:object} name]): $errorMsg\n$::errorInfo\n\
         ===== default_definition: [:default_definition] \n\
         ===== workflow_definition: $workflow_definition"
      :msg -html t "Error in workflow definition of [${:object} name]: [ns_quotehtml $errorMsg]"
    }

    #
    # Store state of xowf-depends in the container for later
    # comparison.
    #
    if {[info exists ::__xowf_depends]} {
      ${:wf_container} set __xowf_depends [set ::__xowf_depends]
    }

    if {${:all_roles}} {
      #:msg want.to.create=[array names :handled_roles]
      foreach role [array names :handled_roles] {
        Context create ${:wf_container}-$role \
            -workflow_definition $workflow_definition \
            -in_role $role \
            -object ${:object}
      }
    }
  }

  Context instproc require_workflow_definition {workflow_definition} {
    #
    # We define the classes Action, State and Property either
    # - per workflow instance (sub-object of the FormPage) or
    # - shared based on the revision_id of the workflow definition.
    #
    # Per-instance definitions have the advantage of allowing
    # e.g. per-object mixins for workflow context definitions, but
    # this can be costly for complex workflow definitions, e.g. when
    # multiple workflow instances are created for a single workflow
    # definition in a request.
    #
    #:log START-CREATES-sharedWorkflowDefinition=$::xowf::sharedWorkflowDefinition
    if {$::xowf::sharedWorkflowDefinition} {
      if {[${:object} is_wf]} {
        set source_obj ${:object}
      } else {
        set source_obj [${:object} page_template]
      }

      set revision_id [$source_obj revision_id]
      if {$revision_id == 0} {
        #
        # We have no "revision_id", but we have to have an
        # "item_id". Therefore, get then "item_id" from the
        # "revision_id" via SQL function
        # content_item.get_live_revision.
        #
        set revision_id [::acs::dc call content_item get_live_revision \
                             -item_id [$source_obj item_id]]
        ns_log warning "xowf: tried to create a wf_container with revision_id 0 -> fixed to $revision_id"
      }

      set :wf_container ::xowf::$revision_id

      #
      # Validate workflow container: We cannot trust the shared
      # definition in case some xowf-include files were changed. When
      # we detect such situations, we delete the shared worklow
      # container, which will be recreated later.
      #
      if {[nsf::is object ${:wf_container}]} {
        set ok 1
        #set ok [expr {$workflow_definition eq [${:wf_container} set __workflow_definition]}]
        if {[${:wf_container} exists __xowf_depends]} {
          set depends [${:wf_container} set __xowf_depends]
          foreach {fn mtime} $depends {
            if {[ad_file mtime $fn] ne $mtime} {
              set ok 0
              break
            }
          }
        }
        if {!$ok} {
          ${:wf_container} destroy
          ns_log notice "xowf: invalidate container ${:wf_container}"
        }
      }

      if {![nsf::is object ${:wf_container}]} {
        #
        # We require an xotcl::Object, since the container needs the
        # method "contains"
        #
        #:log "=== create WorkflowContainer ${:wf_container}"
        WorkflowContainer create ${:wf_container}
        #:log "=== call create :create_workflow_definition"
        :create_workflow_definition $workflow_definition
        #:log "==== def\n$workflow_definition"
        #:log "==== wf_container children <[${:wf_container} info children]>"
      }
      #
      # This is for transitional code. For certain workflows in the
      # transition, we can define in the workflow whether or not is
      # shall be really shared by setting in the definition the
      # variable "shared_definition".
      #
      set use_shared_definition [${:wf_container} shared_definition]
    } else {
      set use_shared_definition 0
    }

    if {$use_shared_definition == 0} {
      set :wf_container [self]
      :create_workflow_definition $workflow_definition
      #:log [:serialize]
    } else {
      #
      # Evaluate once per request the object-specific code of the
      # workflow.
      #
      if {[${:object} is_wf_instance]} {
        set os_code [${:wf_container} object-specific]
        if {$os_code ne ""} {
          #:log "=== object-specific ${:object} eval <$os_code>"
          ${:object} eval $os_code
        }
      }
    }

    #:log [:serialize]
    #:log END-CREATES
  }

  Context instproc init {} {
    array set :handled_roles {}
    #
    # Register the context for the associated object. This has to be
    # before the creation of the workflow definition, since this might
    # refer to the context.
    #
    ${:object} wf_context [self]
    #
    # Create or share workflow definition
    #
    :require_workflow_definition ${:workflow_definition}
  }

  # -debug
  Context proc require {{-new:switch false} obj} {
    #
    # Make sure, the context object for workflow '$obj exists. The
    # flag "-new" can be used to make sure, a new and fresh context is
    # available.
    #
    #:log "START-require"
    #
    set ctx $obj-wfctx
    if {$new && [nsf::is object $ctx]} {
      $ctx destroy
    }

    if {![nsf::is object $ctx]} {
      set wfContextClass [$obj wf_property workflow_context_class [self]]

      regsub -all \r\n [$obj wf_property workflow_definition] \n workflow_definition
      $wfContextClass create $ctx \
          -object $obj \
          -workflow_definition $workflow_definition \
          -destroy_on_cleanup
      $ctx initialize_context $obj
    }

    #:log "END-require ctx <$ctx>"
    return $ctx
  }

  Context instproc initialize_context {obj} {
    #:log "START-initialize_context <$obj>"
    #
    # Keep the object in an instance variable.
    #
    set :object $obj

    # set the state to a well defined starting point
    set state [$obj state]
    if {$state eq ""} {
      set state "initial"
      #:log "===== resetting state of $obj to $state"
    }
    :set_current_state $state

    if {![nsf::is object ${:current_state}]} {
      if {$state eq "initial"} {
        ns_log warning "no state object ${:current_state}"
      } else {
        #
        # The state was probably deleted from the workflow definition,
        # but the workflow instance does still need it. We complain an
        # reset the state to "initial", which should be always present.
        #
        :log "===== Workflow instance [$obj name] is in an undefined state '$state', reset to initial"
        $obj msg "Workflow instance [$obj name] is in an undefined state '$state', reset to initial"
        :set_current_state initial
      }
    }

    #
    # In most cases, the package_id is initialized here already
    #
    set package_id [$obj package_id]
    #:log "... OBJECT $obj HAS $package_id /[info commands ::$package_id/]"
    if {[info commands ::$package_id] eq ""}  {
      :log "... OBJECT $obj HAS $package_id, which is not initialized yet"
      xo::Package require $package_id
    }

    #
    # Set the embedded_context to the workflow context,
    # used e.g. by "behavior" of form-fields.
    #
    [::$package_id context] set embedded_context [self]

    set stateObj ${:current_state}
    catch {$stateObj eval [$stateObj eval_when_active]}

    if {[$obj istype ::xowiki::FormPage] && [$obj is_wf_instance]} {
      #
      # The workflow context may have the following variables:
      #   - "debug"
      #   - "policy"
      #   - "autoname"
      #   - "auto_form_constraints"
      #   - "auto_form_template"
      #   - "shared_definition"
      #
      if {[${:wf_container} exists debug] && [${:wf_container} set debug] > 0} {
        :show_debug_info $obj
      }

      if {[${:wf_container} exists policy]} {
        set policy [${:wf_container} set policy]
        if {![nsf::is object $policy]} {
          :msg "ignore non-existent policy '$policy'"
        } else {
          [$obj package_id] set policy $policy
        }
      }
    }
    #:log "END-initialize_context <$obj>\n\t  context vars: [lsort [:info vars]]\n\tcontainer vars: [lsort [${:wf_container} info vars]]"
  }


  Context instproc show_debug_info {obj} {
    set form        [${:current_state} form]
    set view_method [${:current_state} view_method]
    set form_loader [${:current_state} form_loader]
    if {$form eq ""} {set form NONE}
    if {$view_method eq ""} {set view_method NONE}
    if {$form_loader eq ""} {set form_loader NONE}

    $obj debug_msg "State: [${:current_state} name], Form: $form,\
        View method: $view_method, Form loader: $form_loader,\
        Context class: [:info class]"

    #set conds [list]
    #foreach c [:defined Condition] {
    #  lappend conds "[$c name] [$c]"
    #}
    #$obj debug_msg "Conditions: [join $conds {, }]"
    $obj debug_msg "Instance attributes: [list [$obj instance_attributes]]"
    foreach kind {State Action Condition} {
      $obj debug_msg "...${kind}s: [lsort [:defined $kind]]"
    }
  }

  Context instproc draw_arc {from_state next_state action label style} {
    if {$next_state eq ""} {set next_state $from_state}
    set key transition($from_state,$next_state,$action)
    if {[info exists :$key]} {
      return ""
    }
    set :$key 1
    return "  state_$from_state -> state_$next_state \[label=\"$label\"$style\];\n"
  }
  Context instproc draw_transition {from action role} {
    #:msg "[self args]"

    if {[$action state_safe]} {
      set arc_style {,style="dashed",penwidth=1,color=gray}
    } else {
      set arc_style ""
    }
    set cond_values [$action get_cond_values [$action next_state]]
    set result ""
    if {[llength $cond_values]>2} {
      # we have conditional values
      set c cond_[$from name]_[incr :condition_count]
      append arc_style {,style="setlinewidth(1)",penwidth=1,color=gray}
      append result "  state_$c \[shape=diamond, fixedsize=1, width=0.2, height=0.2, fixedsize=1,style=solid,color=gray,label=\"\"\];\n"
      append result [:draw_arc [$from name] $c [$action name]-1 $role[$action label] ""]
      foreach {cond value} $cond_values {
        if {$cond ne ""} {set prefix "$cond"} {set prefix "else"}
        append result [:draw_arc $c $value [$action name] \[$prefix\] $arc_style]
      }
    } else {
      set prefix ""
      append result [:draw_arc [$from name] [lindex $cond_values 1] [$action name] $role$prefix[$action label] $arc_style]
    }
    return $result
  }


  Context instproc dotcode {{-current_state ""} {-visited ""} {-dpi 96}} {
    set obj_id [namespace tail ${:object}]
    set dotcode [subst {digraph workflow_$obj_id \{
      dpi = $dpi;
      node \[shape=doublecircle, margin=0.001, fontsize=8, fixedsize=1, width=0.4, style=filled\]; start;
      node \[shape=ellipse, fontname="Courier", color=lightblue2, style=filled,
      fixedsize=0, fontsize=10, margin=0.06\];
      edge \[fontname="Courier", fontsize=9\];
    }]
    foreach s [:defined State] {
      if {[$s name] eq $current_state} {
        set color ",color=orange"
      } elseif {[$s name] in $visited} {
        set color ",color=yellow"
      } else {
        set color ""
      }
      append dotcode "  state_[$s name] \[label=\"[$s label]\"$color\];\n"
    }
    set initializeObj [:wf_definition_object initialize]
    if {[nsf::is object $initializeObj]} {
      append dotcode "start->state_initial \[label=\"[$initializeObj label]\"\];\n"
    } else {
      append dotcode "start->state_initial;\n"
    }

    set :condition_count 0
    foreach s [:defined State] {
      foreach a [$s get_actions -set true] {
        set actionObj [:wf_definition_object $a]
        append dotcode [:draw_transition $s $actionObj ""]
        set drawn($actionObj) 1
      }
      foreach role [$s set handled_roles] {
        set role_ctx [self]-$role
        #:msg exists?role=$role->[self]-$role->[nsf::is object ${role_ctx}]
        if {[nsf::is object ${role_ctx}::[$s name]]} {
          foreach a [${role_ctx}::[$s name] get_actions] {
            append dotcode [:draw_transition $s ${role_ctx}::$a "$role:"]
          }
        }
      }
    }
    #
    # State-safe actions might be called from every state. Draw the
    # arcs if not done yet.
    #
    foreach action [:defined Action] {
      if {[info exists drawn($action)]} {continue}
      if {[$action state_safe]} {
        foreach s [:defined State] {
          append dotcode [:draw_transition $s $action ""]
        }
      }
    }

    append dotcode "\}\n"
    return $dotcode
  }


  Context instproc as_graph {{-current_state ""} {-visited ""} {-dpi 72} {-style "width:20%"}} {
    set dot ""
    set dot [::util::which dot]
    if {$dot eq ""} {
      return "<font color='red'>Program 'dot' is not available! No graph displayed.</font>"
    }
    set dotcode [:dotcode -current_state $current_state -visited $visited -dpi $dpi]

    set svg [util::inline_svg_from_dot -css [subst {
      svg g a:link {text-decoration: none;}
      div.inner svg {height:100%; overflow: visible; $style; margin: 0 auto;}
    }] $dotcode]
    return $svg
  }

  Context instproc check {} {
    ns_log notice "--- check context"
    # Check minimal contents
    set o [:wf_definition_object initial]
    if {![nsf::is object $o] || ![$o istype State]} {
      return [list rc 1 errorMsg "No State 'initial' defined"]
    }
    # ease access to workflow constructs
    foreach s [:defined State]     {set state([$s name])  $s}
    foreach a [:defined Action]    {set action([$a name]) $a}
    foreach a [:defined Condition] {set condition([$a name]) $a}
    array set condition {else 1 true 1 default 1}
    # Check actions
    foreach a [:defined Action] {
      # Are some "next_states" undefined?
      foreach {cond value} [$a get_cond_values [$a next_state]] {
        if {$cond ne "" && ![info exists condition($cond)]} {
          return [list rc 1 errorMsg "Error in action [$a name]: no such condition '$cond' defined \
        (valid: [lsort [array names condition]])"]
        }
        if {$value ne "" && ![info exists state($value)]} {
          return [list rc 1 errorMsg "Error in action [$a name]: no such state '$value' defined \
        (valid: [lsort [array names state]])"]
        }
      }
    }
    foreach s [:defined State] {
      # Are some "actions" undefined?
      foreach {cond actions} [$s get_cond_values [$s actions]] {
        foreach a $actions {
          if {![info exists action($a)]} {
            return [list rc 1 errorMsg "Error in state [$s name]: no such action '$a' defined \
        (valid: [lsort [array names action]])"]
          }
        }
      }
      if {[$s form_loader] eq "" && [$s form] ne ""} {
        set :forms([$s form]) 1
      }
    }
    foreach p [:defined ::xowiki::formfield::FormField] {
      if {[$p exists parampage]} {set :parampages([$p set parampage]) 1}
    }

    #:msg "forms=[array names :forms], parampages=[array names :parampages] in-role [info exists :in_role] [array names :handled_roles]"

    if {![info exists :in_role]} {
      foreach role [array names :handled_roles] {
        set role_ctx [self]-$role
        if {[nsf::is object $role_ctx]} {
          set info [$role_ctx check]
          if {[dict get $info rc] == 1} {
            return $info
          }
          array set :forms [$role_ctx array get forms]
          array set :parampage [$role_ctx array get parampage]
        }
      }
      #:msg "forms=[array names :forms], parampages=[array names :parampages]"
      set page ${:object}
      $page references clear
      $page set __unresolved_object_type ::xowiki::Form
      foreach {type pages} [list wf_form [array names :forms] wf_parampage [array names :parampages]] {
        foreach p $pages {
          set form_info [:resolve_form_name -object $page $p]
          set l [::xowiki::Link new -volatile \
                     -lang en \
                     -page $page \
                     -type $type \
                     -name [dict get $form_info name] \
                     -item_id [dict get $form_info form_id]]
          #
          # The "render" method of the link does the optional fetch of
          # the names, and maintains the variable references of the
          # page object (similar to render).
          #
          set link_text [$l render]
        }
      }
      set references [$page references get resolved]
      #:log "-- link_text=$link_text// $references"

      if {[llength $references] > 0} {
        #:msg "updating references refs=$references"
        $page references_update [lsort -unique $references]
        $page set __extra_references $references
        $page references clear
      }
      if {[llength [$page references get unresolved]] > 0} {
        #
        # TODO: We should provide a link to create the missing
        # forms. Maybe we change unresolved_references to a list...,
        # or maybe we write these into the DB.
        #
        :msg -html t "Missing forms: [join [$page references get unresolved] {, }]"
      }
    }
    return [list rc 0]
  }


  #
  # WorkflowConstruct, the base class for workflow definitions
  #
  Class create WorkflowConstruct -superclass WorkflowObject -parameter {
    {handled_roles [list]}
    {label "[namespace tail [self]]"}
    {name  "[namespace tail [self]]"}
  }

  #
  # One should probably deactivate the following convenience calls,
  # which are potentially costly and seldom used.
  #
  WorkflowConstruct instforward property         {%[:wf_context] object} %proc
  WorkflowConstruct instforward set_property     {%[:wf_context] object} %proc
  WorkflowConstruct instforward set_new_property {%[:wf_context] object} set_property -new 1
  WorkflowConstruct instforward object           {%:wf_context} object

  WorkflowConstruct instproc init {args} {
    #
    # Warn about potentially dangerous names, shadowing global
    # commands.  Not sure, this is the best place (or whether this
    # should be always executed), since this method might be executed
    # several hundreds of times for a view instantiating a high number
    # of workflow instances. Maybe we should define a developer-mode
    # defining this and more other calls via mxin classes.
    #
    if {[nsf::is object ::${:name}]} {
      set ctx [:wf_context]
      if {[nsf::is object $ctx]} {
        set obj [$ctx object]
        set wfName [[$obj page_template] name]
        if {$wfName ne "en:Workflow.form"} {
          ns_log warning "Workflow $wfName defines [namespace tail [:info class]]\
               with name '${:name}' potentially shadowing global commands"
        }
      }
    }
    next
  }

  WorkflowConstruct instproc in_role {role configuration} {
    set ctx [:wf_context]
    set obj [$ctx object]
    #:msg parent=$obj,cl=[$obj info class],name=[$obj name]
    if {[$ctx exists in_role]} {
      set success [expr {[$ctx in_role] eq $role}]
    } else {
      set success [$obj check_role $role]
    }
    #:msg role-$role->$success
    lappend :handled_roles $role
    $ctx set handled_roles($role) 1
    if {$success} {
      :configure {*}$configuration
    }
  }
  #   WorkflowConstruct instproc get_condition {conditional_entry} {
  #     set e [split $conditional_entry :?]
  #     if {[llength $e]==2} {return [list cond [lindex $e 0] value [lindex $e 1]]}
  #     return [list cond "" value $conditional_entry]
  #   }

  WorkflowConstruct instproc get_cond_values {values} {
    if {[lindex $values 0] eq "?"} {
      return [lrange $values 1 end]
    } elseif {$values eq ""} {
      return ""
    } else {
      if {[regexp {^(.+):([^ ]+) } $values _ cond value]} {
        :msg "switch '$values' to new syntax: ? $cond $value ..."
      }
      return [list "" $values]
    }
  }
  WorkflowConstruct instproc get_value {values} {
    foreach {cond value} [:get_cond_values $values] {
      if {$cond eq "" || $cond eq "default" || $cond eq "else" ||
          $cond == "true"} {
        return $value
      } elseif {[:$cond]} {
        return $value
      }
    }
  }
  WorkflowConstruct instproc get_value_set {values} {
    set result [list]
    foreach {cond value} [:get_cond_values $values] {
      foreach v $value {lappend result $v}
    }
    return [lsort -unique $result]
  }
}

namespace eval ::xowf {

  Class create State -superclass WorkflowConstruct -parameter {
    {actions ""}
    {view_method ""}
    {form ""}
    {form_loader ""}
    {form_constraints ""}
    {assigned_to}
    {eval_when_active ""}
    {extra_js ""}
    {extra_css ""}
  }

  State instproc get_actions {{-set false}} {
    if {!$set} {
      return [:get_value [:actions]]
    } else {
      return [:get_value_set [:actions]]
    }
  }
  State instproc get_all_actions {} {
    return [:get_value [:actions]]
  }

  Class create Condition -superclass WorkflowConstruct -parameter expr
  Condition instproc init {} {
    set wfc [[:wf_context] wf_container]
    ${wfc}::Action instforward [namespace tail [self]] [self]
    ${wfc}::State  instforward [namespace tail [self]] [self]
  }
  Condition instproc defaultmethod {} {
    set obj [[:wf_context] object]
    expr ${:expr}
  }

  #{label "#xowf.form-button-[namespace tail [self]]#"}
  Class create Action -superclass WorkflowConstruct -parameter {
    {next_state ""}
    {payload ""}
    {roles all}
    {state_safe false}
    {extra_css_class ""}
    {wrapper_CSSclass ""}
    {label_noquote false}
    {title}
  }
  Action instproc activate {obj} {;}
  Action instproc get_next_state {} {
    return [:get_value [:next_state]]
  }
  Action instproc invoke {{-attributes ""}} {
    set action_name [namespace tail [self]]
    set object [[:wf_context] object]
    set package_id [$object package_id]
    set package ::$package_id
    :log  "--xowf invoke action [self]"
    # We fake a work request with the given instance attributes
    set last_context [expr {[$package exists context] ? [$package context] : "::xo::cc"}]
    set last_object [$package set object]
    set cc [::xo::ConnectionContext new -user_id [$last_context user_id]]
    $package context $cc
    $cc array set form_parameter \
        [list __object_name [::security::parameter::signed [$object name]] \
             _name [$object name] \
             _nls_language [$last_context locale] \
             __form_action save-form-data \
             __form_redirect_method __none \
             __action_$action_name $action_name]
    #ns_log notice "call_action pushed form_param to $cc: [$cc array get form_parameter]"

    $cc load_form_parameter_from_values $attributes

    $package set object "[$package folder_path -parent_id [$object parent_id]][$object name]"

    #:log "call_action calls:   $package invoke -method edit -batch_mode 1 // obj=[$package set object]"
    ad_try {
      $package invoke -method edit -batch_mode 1
    } on error {errorMsg} {
      ns_log error "$errorMsg\n$::errorInfo"
      error $errorMsg
    }

    #:log  "RESETTING package_id object"
    $package set object $last_object
    $package context $last_context
    $cc destroy

    #:log "CHECK batch mode: [$package  exists __batch_mode]"
    if {[$package  exists __batch_mode]} {
      #:msg "RESETTING BATCH MODE"
      :log "RESETTING BATCH MODE"
      $package unset __batch_mode
    }
    return "OK"
  }

  Class create Property \
      -superclass ::xowiki::formfield::FormField -parameter {{name "[namespace tail [self]]"}} \
      -parameter {{allow_query_parameter false}}
  Property set abstract 1

  Property instproc wf_context {} {
    set max [info level]
    for {set i 0} {$i < $max} {incr i} {
      if {![catch {set s [uplevel $i self]} msg]} {
        set obj [lindex $s 0]
        if {[$obj istype ::xowf::Context]} {
          #:log "$obj [nsf::is object $obj] precedence: [$obj info precedence]"
          return $obj
        }
      }
    }

    return [:info parent]
  }

  Property instproc init {} {
    #
    # Mostly compatibility fix for XOTcl 2.0. Provide a default
    # property for $object, if the property does not exist in the
    # instance attributes, but provided in the Property definition.
    #
    set object [[:wf_context] object]
    $object instvar instance_attributes
    if {[info exists :default] && ![dict exists $instance_attributes ${:name}]} {
      dict set instance_attributes ${:name} ${:default}
      #:msg "set :default of $object to [:default]"
    }
  }

  Property instproc get_default_from {page} {
    set :parampage $page
    set :default [[:wf_context] get_property -source $page -name ${:name} -default ""]
  }
  #namespace export State Action Property


  #
  # MixinClass for implementing the workflow definition and workflow instance
  #
  Class create WorkflowPage

  #WorkflowPage instproc init {} {
  #  :log "===== WorkflowPage INIT <${:state}>"
  #  next
  #}

  WorkflowPage ad_instproc wf_context {{ctx ""}} {

    Return for a workflow page the workflow context object.  The same
    function can be used as well for setting the workflow context at
    the first places (e.g. on initialization of the wf-context).

  } {
    if {$ctx ne ""} {
      set :_wf_context $ctx
    }
    return ${:_wf_context}
  }

  WorkflowPage ad_instproc is_wf {} {
    Check, if the current page is a workflow page (page, defining a workflow)
  } {
    if {[info exists :__wf(workflow_definition)]} {
      return 1
    } elseif {[:property workflow_definition] ne ""} {
      array set :__wf ${:instance_attributes}
      return 1
    } else {
      return 0
    }
  }

  WorkflowPage ad_instproc is_wf_instance {} {
    Check, if the current page is a workflow instance (page, referring to a workflow)
  } {
    if {[array exists :__wfi]} {
      return 1
    }
    #
    # We cannot call get_template_object here, because this will lead
    # to a recursive loop.
    #
    if {![nsf::is object ::${:page_template}]} {
      ::xo::db::CrClass get_instance_from_db -item_id ${:page_template}
    }
    if {${:state} ne ""
        && [${:page_template} hasclass ::xowf::WorkflowPage]
        && [${:page_template} is_wf]
      } {
      array set :__wfi [${:page_template} instance_attributes]
      return 1
    }
    return 0
  }

  WorkflowPage instproc check_role {role} {
    if {[::xo::cc info methods role=$role] eq ""} {
      :msg "ignoring unknown role '$role'"
      return 0
    }
    if {$role eq "creator"} {
      #
      # Meaning: "creator of the object", requires the object as
      # additional attribute.
      #
      return [::xo::cc role=$role \
                  -object [self] \
                  -user_id [::xo::cc user_id] \
                  -package_id [:package_id]]
    } else {
      return [::xo::cc role=$role \
                  -user_id [::xo::cc user_id] \
                  -package_id ${:package_id}]
    }
  }

  WorkflowPage instproc evaluate_form_field_condition {cond} {
    set ctx [::xowf::Context require [self]]
    if {[nsf::is object ${ctx}::$cond]} {
      return [${ctx}::$cond]
    }
    return 0
  }

  WorkflowPage ad_instproc render_icon {} {
    Provide an icon or text for describing the kind of application.
  } {
    if {[:info procs render_icon] ne ""} {
      #
      # In case, we have a per-object method (i.e., defined via the
      # workflow), use this with highest precedence.
      #
      next

    } elseif {[:is_wf_instance]} {
      set page_template ${:page_template}
      set title [::$page_template title]
      regsub {[.]wf$} $title "" title
      return [list text $title is_richtext false]
    } elseif {[:is_wf]} {
      return [list text "Workflow" is_richtext false]
    } else {
      next
    }
  }

  WorkflowPage ad_instproc render_form_action_buttons_widgets {{-CSSclass ""} buttons} {
    With the given set of buttons, produce the HTML for the button
    container and the included inputs.
  } {
    if {[llength $buttons] > 0} {
      #
      # Build button groups based on "form_button_wrapper_CSSclass".
      #
      set previous_wrapper_class "NONE"
      set wrapper_groups {}
      set group_num 0
      foreach f $buttons {
        set wrapper_class [$f form_button_wrapper_CSSclass]
        if {$wrapper_class eq $previous_wrapper_class} {
          dict lappend wrapper_groups [list $wrapper_class $group_num] $f
          continue
        }
        incr group_num
        dict lappend wrapper_groups [list $wrapper_class $group_num] $f
        set previous_wrapper_class $wrapper_class
      }

      foreach wrapper_group [dict keys $wrapper_groups] {
        ::html::div -class [lindex $wrapper_group 0] {
          foreach f [dict get $wrapper_groups $wrapper_group] {
            $f render_input
          }
        }
      }
    }
  }

  WorkflowPage ad_instproc render_form_action_buttons {
    {-formfieldButtonClass ::xowiki::formfield::submit_button}
    {-CSSclass ""}
  } {
    Render the defined actions in the current state with submit buttons
  } {
    if {[:is_wf_instance]} {

      set ctx [::xowf::Context require [self]]
      set buttons {}
      foreach action [$ctx get_actions] {
        set success 0
        foreach role [$action roles] {
          set success [:check_role $role]
          if {$success} break
        }
        if {$success} {
          set f [$formfieldButtonClass new \
                     -name __action_[namespace tail $action] \
                     -form_button_wrapper_CSSclass [$action wrapper_CSSclass] \
                     -label_noquote [$action label_noquote] \
                     -CSSclass $CSSclass \
                     -destroy_on_cleanup \
                    ]
          if {[$action extra_css_class] ne ""} {
            #$f append form_button_CSSclass " " [$action extra_css_class]
            $f CSSclass_list_add form_button_CSSclass [$action extra_css_class]
          }
          $f CSSclass_list_add form_button_CSSclass prevent-double-click
          #ns_log notice "RENDER BUTTON has CSSclass [$f CSSclass] // [$f form_button_CSSclass]"
          if {[$action exists title]} {
            $f title [$action title]
          }
          $f value [$action label]
          lappend buttons $f
        }
      }
      #
      # Render the button widgets.
      #
      :render_form_action_buttons_widgets -CSSclass $CSSclass $buttons
    } else {
      next
    }
  }

  WorkflowPage ad_instproc post_process_form_fields {form_fields} {
    Propagate the feedback mode setting of this workflow page to the
    supplied formfields.
  } {
    #:log ------------------post_process_form_fields-feedback_mode=[info exists :__feedback_mode]
    if {[info exists :__feedback_mode]} {
      #
      # Provide feedback for every alternative
      #
      foreach f $form_fields {
        $f set_feedback ${:__feedback_mode}
      }
    }
    #:log ------------------post_process_form_fields-feedback_mode=[info exists :__feedback_mode]-DONE
  }

  WorkflowPage ad_instproc post_process_dom_tree {dom_doc dom_root form_fields} {
    post-process form in edit mode to provide feedback in feedback mode
  } {
    # In feedback mode, we set the CSS class to correct or incorrect

    if {[info exists :__feedback_mode]} {
      unset :__feedback_mode
      ::xo::Page requireCSS /resources/xowf/feedback.css
      set form [lindex [$dom_root selectNodes "//form"] 0]
      $form setAttribute class "[$form getAttribute class] feedback"

      #
      # In cases, where the HTML exercise was given, we process the HTML
      # to flag the result.
      #
      # TODO: What should we do with the feedback. "util_user_message" is
      # not optimal...
      #
      foreach f $form_fields {
        if {[$f exists __rendered]} continue
        if {[$f exists evaluated_answer_result]} {
          set result [$f set evaluated_answer_result]
          foreach n [$dom_root selectNodes "//form//*\[@name='[$f name]'\]"] {
            set oldCSSClass [expr {[$n hasAttribute class] ? [$n getAttribute class] : ""}]
            $n setAttribute class [string trim "$oldCSSClass [$f form_widget_CSSclass]"]
            $f form_widget_CSSclass $result

            set helpText [$f help_text]
            if {$helpText ne ""} {
              #set divNode [$dom_doc createElement div]
              #$divNode setAttribute class [$f form_widget_CSSclass]
              #$divNode appendChild [$dom_doc createTextNode $helpText]
              #[$n parentNode] insertBefore $divNode [$n nextSibling]

              #set spanNode [$dom_doc createElement span]
              #$spanNode setAttribute class "glyphicon glyphicon-ok [$f form_widget_CSSclass]"
              #[$n parentNode] insertBefore $spanNode [$n nextSibling]

              set parentNode [$n parentNode]
              set oldClass [$parentNode getAttribute class ""]
              $parentNode setAttribute class "selection [$f form_widget_CSSclass]"
              $parentNode setAttribute title $helpText

              #util_user_message -message "field [$f name], value [$f value]: $helpText"
            }
          }
        }
      }
      #
      # Provide feedback for the whole exercise.
      #
      if {[:answer_is_correct]} {
        set feedback [:get_from_template feedback_correct]
      } else {
        set feedback [:get_from_template feedback_incorrect]
      }
      if {$feedback ne ""} {
        $dom_root appendFromScript {
          html::div -class feedback {
            html::t -disableOutputEscaping $feedback
          }
        }
      }
    }
  }

  WorkflowPage instproc util_user_message {-html:switch -message} {
    if {[ns_conn isconnected]} {
      ::util_user_message -message $message -html=$html
    } else {
      ns_log notice "util_user_message suppressed (no connection): $message"
    }
  }


  WorkflowPage instproc debug_msg {msg} {
    #util_user_message -message $msg
    ns_log notice "--WF $msg"
    catch {ds_comment $msg}
  }

  WorkflowPage ad_instproc www-edit args {
    Hook for editing workflow pages
  } {
    if {[:is_wf_instance]} {
      set ctx [::xowf::Context require [self]]
      set s [$ctx current_state]
      :include_header_info -css [$s extra_css] -js [$s extra_js]
    }
    next
  }

  WorkflowPage ad_instproc www-view {{content ""}} {
    Provide additional view modes:
    - edit: instead of viewing a page, it is opened in edit mode
    - view_user_input: show user the provided input
    - view_user_input_with_feedback: show user the provided input with feedback
  } {
    # The edit method calls view with an HTML content as argument.
    # To avoid a loop, when "view" is redirected to "edit",
    # we make sure that we only check the redirect on views
    # without content.

    #:msg "view [self args] [:is_wf_instance]"

    if {[:is_wf_instance] && $content eq ""} {
      set ctx [::xowf::Context require [self]]
      set method [$ctx get_view_method]
      set s [$ctx current_state]
      :include_header_info -css [$s extra_css] -js [$s extra_js]

      if {$method ne "" && $method ne "view"} {
        #:msg "view redirects to $method in state [$ctx get_current_state]"
        switch -- $method {
          view_user_input {
            #:msg "calling edit with disable_input_fields=1"
            return [:www-edit -disable_input_fields 1]
          }
          view_user_input_with_feedback {
            set :__feedback_mode 1
            #:msg "calling edit with disable_input_fields=1"
            return [:www-edit -disable_input_fields 1]
          }
          default {
            #:msg "calling $method"
            return [::${:package_id} invoke -method $method]
          }
        }
      }
    }
    next
  }

  WorkflowPage instproc get_assignee {assigned_to} {
    return [:assignee]
  }

  WorkflowPage instproc get_fc_repository {} {
    set container [[:wf_context] wf_container]
    if {[$container exists fc_repository]} {
      return [$container set fc_repository]
    }
    #ns_log warning "get_fc_repository returns empty"
    return ""
  }

  WorkflowPage instproc send_to_assignee {
    -subject
    -from
    -body
    {-mime_type text/plain}
    {-with_ical:boolean false}
  } {
    set wf_name [${:page_template} name]

    if {![info exists subject]} {
      set subject "\[$wf_name\] ${:title} (${:state})"
    }
    if {![info exists :from]} {set from ${:creation_user}}
    acs_user::get -user_id ${:assignee} -array to_info
    acs_user::get -user_id $from -array from_info

    set message_id [mime::uniqueID]
    set message_date [acs_mail_lite::utils::build_date]
    set tokens [mime::initialize \
                    -canonical $mime_type \
                    -encoding "quoted-printable" -string $body]

    if {$with_ical} {
      set items [::xo::OrderedComposite new -destroy_on_cleanup -mixin ::xo::ical::VCALENDAR]
      # hmm, mozilla just supports VEVENT, a VTODO would be nice.
      $items add [::xo::ical::VEVENT new \
                      -creation_date ${:creation_date} \
                      -last_modified ${:last_modified} \
                      -dtstart "now" \
                      -uid ${:package_id}-${:revision_id} \
                      -url [:pretty_link -absolute true] \
                      -summary $subject \
                      -description "Workflow instance of workflow $wf_name ${:description}"]
      $items configure -prodid "-//WU Wien//NONSGML XoWiki Content Flow//EN" -method request
      set ical [$items as_ical]
      lappend tokens [mime::initialize \
                          -canonical text/calendar \
                          -param [list method request] \
                          -param [list charset UTF-8] \
                          -header [list "Content-Disposition" "attachment; filename=\"todo.vcs\""] \
                          -encoding "quoted-printable" -string $ical]
      lappend tokens [mime::initialize \
                          -canonical application/ics -param [list name "invite.ics"] \
                          -header [list "Content-Disposition" "attachment; filename=\"todo.ics\""] \
                          -encoding "quoted-printable" -string $ical]
    }

    if {[llength $tokens]>1} {
      set tokens [mime::initialize -canonical "multipart/mixed" -parts $tokens]
    }

    set headers_list [list]
    lappend headers_list \
        [list From $from_info(email)] \
        [list To $to_info(email)] \
        [list Subject $subject]

    set originator [acs_mail_lite::bounce_address -user_id $from \
                        -package_id ${:package_id} \
                        -message_id $message_id]

    acs_mail_lite::smtp -multi_token $tokens -headers $headers_list -originator $originator
    mime::finalize $tokens -subordinates all

  }

  WorkflowPage instproc activate {{-verbose true} ctx action} {
    #
    # Execute action and compute next state of the action.
    #
    set actionObj [$ctx wf_definition_object $action]
    #
    # Check, if action is defined.
    #
    if {![nsf::is object $actionObj]} {
      #
      # There is no such action the current context.
      #
      if {$verbose} {ns_log notice "Warning: ${:name} No action $action in workflow context"}
      return ""
    }
    #
    # Activate action
    #
    ad_try {
      $actionObj activate [self]

    } on error {errorMsg errorDict} {
      #
      # Something went wrong in the application specific
      # code. Depending on batch_mode, report the error to the user or
      # to the variable __evaluation_error in the package object.
      #
      #:log "--WF: error in action $action ERRORDICT <$errorDict>"

      set errorInfo [dict get $errorDict -errorinfo]
      set error "error in action '$action' of workflow instance ${:name}\
               of workflow [${:page_template} name]:"
      if {[::${:package_id} exists __batch_mode]} {
        ::${:package_id} set __evaluation_error "$error\n\n$errorInfo"
        incr validation_errors
      } else {
        :msg -html 1 "$error <pre>[ns_quotehtml $errorInfo]</pre>"
      }
      ad_log error "--WF: evaluation $error\n$errorInfo"
      set next_state ""

    } on ok {result} {
      #
      # The action went ok. The call to "get_next_state" is here to
      # allow the developer to influence the outcome of
      # "get_next_state" by the activated method.
      #
      set next_state [$actionObj get_next_state]
      #:log "ACTIVATE ${:name} no error next-state <$next_state>"
    }
    return $next_state
  }

  WorkflowPage instproc get_form_data args {
    if {[:is_wf_instance]} {
      lassign [next] validation_errors category_ids
      if {$validation_errors == 0} {
        #:msg "validation ok"
        set ctx [::xowf::Context require [self]]
        set cc [${:package_id} context]
        foreach {name value} [$cc get_all_form_parameter] {
          if {[regexp {^__action_(.+)$} $name _ action]} {
            set actionObj [:get_action_obj -action $action]
            set next_state [:activate $ctx $action]
            #:log "after activate next_state=$next_state, current_state=[$ctx get_current_state], ${:instance_attributes}"
            if {$next_state ne ""} {
              if {[$actionObj exists assigned_to]} {
                :assignee [:get_assignee [$actionObj assigned_to]]
              }
              $ctx set_current_state $next_state
            }
            break
          }
        }
      }
      #ns_log notice "===== get_form_data returns [list $validation_errors $category_ids]"
      return [list $validation_errors $category_ids]
    } else {
      next
    }
  }

  WorkflowPage instproc instantiated_form_fields {} {
    # Helper method to
    #  - obtain the field_names from the current form, to
    #  - create form_field instances from that and to
    #  - provide the values from the instance attributes into it.
    lassign [:field_names_from_form] _ field_names
    set form_fields [:create_form_fields $field_names]
    :load_values_into_form_fields $form_fields
    return $form_fields
  }

  WorkflowPage ad_instproc solution_set {} {
    Compute solution set in form of attribute=value pairs
    based on "answer" attribute of form fields.
  } {
    set solutions [list]
    foreach f [:instantiated_form_fields] {
      if {![$f exists answer]} continue
      lappend solutions [$f name]=[$f answer]
    }
    return [join [lsort $solutions] ", "]
  }


  WorkflowPage ad_instproc answer_is_correct {} {

    Check, if answer is correct based on "answer" and "correct_when"
    attributes of form fields and provided user input.

  } {
    set correct 0
    :log "WorkflowPage(${:name}).answer_is_correct autocorrect '[:get_from_template auto_correct]' -- [string is true -strict [:get_from_template auto_correct]]"
    if {[string is true -strict [:get_from_template auto_correct]]} {
      :log "==== answer_is_correct '[:instantiated_form_fields]'"
      foreach f [:instantiated_form_fields] {
        #:log [$f serialize]
        #:log "checking correctness [$f name] [$f info class] answer?[$f exists value] correct_when ?[$f exists correct_when]"
        if {[$f exists value]} {
          set r [$f answer_is_correct]
          #:log [$f serialize]
          if {$r != 1} {
            #:log [$f serialize]
            #:log "checking correctness [$f name] failed ([$f answer_is_correct])"
            set correct -1
            break
          }
          set correct 1
        }
      }
    }
    return $correct
  }

  WorkflowPage ad_instproc stats_record_count {name} {

    Record that the specified question was used.

  } {
    dict incr :__stats_count $name
  }

  WorkflowPage ad_instproc stats_record_detail {
    -label
    -value
    -name
    -correctly_answered:boolean
  } {
    Record the stat detail of the question.
  } {
    dict set :__stats_label $name label $value $label
    if {[info exists :__stats_success] && [dict exists ${:__stats_success} $name $value]} {
      set details [dict get ${:__stats_success} $name $value]
    } else {
      set details ""
    }
    dict incr details $correctly_answered
    dict set :__stats_success $name $value $details
  }

  WorkflowPage instproc unset_temporary_instance_variables {} {
    # never save/cache the following variables
    unset -nocomplain :__wfi
    unset -nocomplain :__wf
    next
  }

  WorkflowPage instproc save_data args {
    if {[:is_wf_instance]} {
      #
      # update the state in the workflow instance
      #
      set ctx [::xowf::Context require [self]]
      set prev_state ${:state}
      set :state [$ctx get_current_state]

      if {$prev_state ne ${:state}} {
        # The form object in the cache is still that from the previous
        # state, make sure we flush it.
        $ctx flush_form_object
      }
    }
    next
  }

  WorkflowPage instproc save args {
    set r [next]
    :save_in_hstore
    return $r
  }

  WorkflowPage instproc save_new args {
    set r [next]
    :save_in_hstore
    return $r
  }

  WorkflowPage instproc hstore_attributes {} {
    #
    # We do not want to save the workflow definition in every workflow
    # instance.
    #
    return [dict remove ${:instance_attributes} workflow_definition]
  }

  WorkflowPage instproc save_in_hstore {} {
    #
    if {[::xo::dc has_hstore] && [${:package_id} get_parameter use_hstore 0]} {
      set hkey [::xowiki::hstore::dict_as_hkey [:hstore_attributes]]
      set revision_id ${:revision_id}
      xo::dc dml update_hstore "update xowiki_page_instance \
                set hkey = :hkey \
                where page_instance_id = :revision_id"
    }
  }
  WorkflowPage instproc wf_property {name {default ""}} {
    if {[info exists :__wf]} {set key :__wf($name)} else {set key :__wfi($name)}
    if {[info exists $key]} { return [set $key] }
    return $default
  }
  WorkflowPage instproc get_template_object {} {
    if {[:is_wf_instance]} {
      set key :__wfi(wf_form_id)
      if {![info exists $key]} {
        set ctx [::xowf::Context require [self]]
        set $key [$ctx form_object [self]]
      }
      set form_obj [set $key]
      if {![nsf::is object $form_obj]} {
        ad_log error "deprecated usage: method 'form_object' did NOT return an object. Will raise an error in the future"
        set form_id [string trimleft $form_obj :]
        set form_obj [::xo::db::CrClass get_instance_from_db -item_id $form_id]
      }
      return $form_obj
    } else {
      return [next]
    }
  }

  WorkflowPage instproc create-or-use_view {-package_id:required -parent_id:required name } {
    # the link should be able to view return_url and template_file
    return [::$package_id returnredirect [::$package_id pretty_link -parent_id $parent_id $lang:$stripped_name]]
  }

  WorkflowPage instproc www-create-or-use {
    {-parent_id:integer 0}
    {-view_method:wordchar edit}
    {-name ""}
    {-nls_language ""}
  } {
    #:msg "instance = [:is_wf_instance], wf=[:is_wf]"
    if {[:is_wf]} {
      #
      # In a first step, we call "allocate". Allocate is an Action
      # defined in a workflow, which is called *before* the workflow
      # instance is created. Via allocate, it is e.g. possible to
      # provide a computed name for the workflow instance from within
      # the workflow definition.
      #
      set ctx [::xowf::Context require [self]]
      set wfc [$ctx wf_container]
      :activate $ctx allocate

      #
      # After allocate, the payload might contain "name", "parent_id"
      # or "m". Using the payload dict has the advantage that it does
      # not touch the instance variables.
      #
      set payload [${wfc}::allocate payload]
      #ns_log notice "AFTER ALLOCATE www-create-or-use <$payload>"
      set m ""
      set title ""
      foreach p {name title parent_id m} {
        if {[dict exists $payload $p]} {
          set $p [dict get $payload $p]
        }
      }
      set package ::${:package_id}
      if {$title ne ""} {
        ::xo::cc set_query_parameter title $title
      }

      #
      # If these values are not set, try to obtain it the old-fashioned way.
      #
      if {$parent_id == 0} {
        set parent_id [:query_parameter parent_id:cr_item_of_package,arg=${:package_id} [$package folder_id]]
      }
      if {$name eq ""} {
        set name [:property name ""]
      }

      #
      # Check, if allocate has provided a name:
      #
      if {$name ne ""} {
        # Ok, a name was provided. Check if an instance with this name
        # exists in the current folder.
        set default_lang [:lang]
        $package get_lang_and_name -default_lang $default_lang -name $name lang stripped_name
        set id [::xo::db::CrClass lookup -name $lang:$stripped_name -parent_id $parent_id]
        #:log "after allocate lookup of $lang:$stripped_name returned $id, default-lang(${:name})=$default_lang [:nls_language]"
        if {$id != 0} {
          #
          # The instance exists already. Either call method "m"
          # directly (if provided) or redirect to the item.
          #
          if {$m eq ""} {
            return [$package returnredirect \
                        [export_vars -no_base_encode \
                             -base [$package pretty_link -parent_id $parent_id $lang:$stripped_name] \
                             {return_url template_file}]]
          } else {
            set item [::xo::db::CrClass get_instance_from_db -item_id $id]
            # missing: policy check.
            return [$item www-$m]
          }
        } else {
          if {$lang ne $default_lang} {
            set nls_language [:get_nls_language_from_lang $lang]
          } else {
            set nls_language [:nls_language]
          }
          #:msg "We want to create $lang:$stripped_name"
          set name $lang:$stripped_name
        }
      }
    }
    # method "m" is ignored, always edit
    next -parent_id $parent_id -view_method $view_method -name $name -nls_language $nls_language
  }

  WorkflowPage instproc initialize_loaded_object {} {
    next
    #
    # Call "initialize" for workflows and workflow instances.  Before,
    # we called "initialize" only, when [:is_wf_instance] was true.
    #
    if {[:is_wf_instance] || [:is_wf]} {
      :initialize
    }
  }

  WorkflowPage instproc initialize {} {
    #:log "START-initialize is_wf_instance [:is_wf_instance]"
    #
    # A fresh workflow page was created (called only once per
    # workflow page at initial creation)
    #
    if {[:is_wf_instance]} {
      #
      # Get context and call user defined "constructor"
      #
      # set the state to a well defined starting point
      if {${:state} eq ""} {set :state initial}

      set ctx [::xowf::Context require -new [self]]
      :activate -verbose false $ctx initialize

      # Ignore the returned next_state, since the initial state is
      # always set to the same value from the ctx (initial)
      #:msg "[self] is=${:instance_attributes}"

    } elseif {[:is_wf] && [info exists :item_id]} {
      #
      # We are initializing a fully created workflow object.
      #
      # The test for "exists :item_id" is important, since when a
      # workflow is created via "create_form_page_instance", the
      # workflow object is create via "new", it has not been saved yet
      # and has therefore no "item_id" yet.
      #

      set ctx [::xowf::Context require -new [self]]
      set code [[$ctx wf_container] wf-specific]
      #ns_log notice "...initialize wf, wf-specific code: $code"
      if {$code ne ""} {
        eval $code
      }
    }
    next
    #:log END-initialize
  }

  WorkflowPage instproc default_instance_attributes {} {
    # Provide the default list of instance attributes to derived
    # FormPages.
    if {[:is_wf]} {
      #
      # We have a workflow page. Get the initial state of the workflow
      # instance from the workflow.
      #
      set instance_attributes ""
      set ctx [::xowf::Context require [self]]
      foreach p [$ctx defined ::xowiki::formfield::FormField] {
        set name [$p name]
        set value [$p default]
        if {[::xo::cc exists_query_parameter $name]} {
          #
          # Never clobber instance attributes from query parameters
          # blindly.
          #
          #:msg "ignore $name"
          continue
        }
        if {[::xo::cc exists_query_parameter p.$name]
            && [$p exists allow_query_parameter]} {
          #
          # We allow the value to be taken from the query parameter.
          #
          set value [::xo::cc query_parameter p.$name]
          $p value $value
          $p validate $p
        }
        dict set instance_attributes $name $value
        set f($name) $p
      }

      ## save instance attributes
      #set instance_attributes [array get __ia]
      #:msg "[self] ${:name} setting default parameter"
      #:log ia=$instance_attributes,props=[$ctx defined Property]

      :state [$ctx get_current_state]
      #:msg "setting initial state to '[:state]'"

      return $instance_attributes
    } else {
      next
    }
  }
  WorkflowPage instproc constraints_as_dict {{-fc_repository ""} c} {
    set result ""
    foreach name_and_spec $c {
      set p [string first : $name_and_spec]
      if {$p > -1} {
        set spec_name [string range $name_and_spec 0 $p-1]
        set short_spec [string range $name_and_spec $p+1 end]
        if {$short_spec eq "" && [dict exists $fc_repository $spec_name]} {
          set short_spec [dict get $fc_repository $spec_name]
          #:log "======= use fc_repository for <$spec_name> <$short_spec>"
        }
        dict set result $spec_name $short_spec
      } else {
        ns_log warning "ignore invalid fc: <$name_and_spec>"
      }
    }
    return $result
  }
  WorkflowPage instproc merge_constraints {c1 args} {
    # Load into the base_constraints c1 the constraints from the argument list.
    # The first constraints have the lowest priority
    set fcrepo [:constraints_as_dict [:get_fc_repository]]
    set merged [:constraints_as_dict -fc_repository $fcrepo $c1]
    foreach c2 $args {
      foreach {att value} [:constraints_as_dict -fc_repository $fcrepo $c2] {
        if {[dict exists $merged $att]} {
          dict append merged $att ",$value"
        } else {
          dict set merged $att "$value"
        }
      }
    }
    return [lmap {att value} $merged {string cat $att:$value}]
  }
  WorkflowPage instproc wfi_merged_form_constraints {constraints_from_form} {
    set ctx [::xowf::Context require [self]]
    set wf_specific_constraints [${:page_template} property form_constraints]
    set m [:merge_constraints $wf_specific_constraints \
               $constraints_from_form [$ctx get_form_constraints]]
    #:msg "merged:$m"
    return $m
  }
  WorkflowPage instproc wf_merged_form_constraints {constraints_from_form} {
    return $constraints_from_form
    #return [:merge_constraints $constraints_from_form [:property form_constraints]]
  }

  WorkflowPage instproc get_anon_instances {} {
    if {[:istype ::xowiki::FormPage] && [:is_wf_instance]} {
      #
      # In case, the workflow definition has the autoname variable set,
      # it has the highest weight of all other sources.
      #
      set wfc [[::xowf::Context require [self]] wf_container]
      if {[$wfc exists autoname]} {
        return [$wfc set autoname]
      }
    }
    next
  }

  WorkflowPage instproc get_form_constraints {{-trylocal false}} {
    #:log ""
    if {[:istype ::xowiki::FormPage] && [:is_wf]} {
      #:msg "get_form_constraints is_wf"
      return [::xo::cc cache [list [self] wf_merged_form_constraints [next]]]
    } elseif {[:istype ::xowiki::FormPage] && [:is_wf_instance]} {
      #:msg "get_form_constraints is_wf_instance"
      return [::xo::cc cache [list [self] wfi_merged_form_constraints [next]]]
    } else {
      #:msg "get_form_constraints next"
      next
    }
  }
  WorkflowPage instproc visited_states {} {
    set item_id ${:item_id}
    foreach state [xo::dc list history {
      select DISTINCT state from xowiki_form_page p, cr_items i, cr_revisions r
      where i.item_id = :item_id and r.item_id = i.item_id and xowiki_form_page_id = r.revision_id}] {
      set visited($state) 1
    }
    #:msg "visited states of item $item_id = [array names visited]"
    return [array names visited]
  }

  WorkflowPage ad_instproc get_revision_sets {-with_instance_attributes:switch} {

    Return a list of ns_sets containing revision_id, creation_date,
    creation_user, creation_ip, and state for the current workflow
    instance.

  } {
    set item_id ${:item_id}
    if {$with_instance_attributes} {
      set revision_sets [::xo::dc sets -prepare integer wf_revisions {
        SELECT revision_id, creation_date, last_modified, creation_user,
               creation_ip, state, assignee, instance_attributes
        FROM cr_revisions cr, acs_objects o, xowiki_form_page x, xowiki_page_instance pi
        WHERE cr.item_id = :item_id
        AND   o.object_id = cr.revision_id
        AND   x.xowiki_form_page_id = cr.revision_id
        AND   pi.page_instance_id = cr.revision_id
        ORDER BY cr.revision_id ASC
      }]
    } else {
      set revision_sets [::xo::dc sets -prepare integer wf_revisions {
        SELECT revision_id, creation_date, last_modified, creation_user, creation_ip, state, assignee
        FROM cr_revisions cr, acs_objects o, xowiki_form_page x
        WHERE cr.item_id = :item_id
        AND   o.object_id = cr.revision_id
        AND   x.xowiki_form_page_id = cr.revision_id
        ORDER BY cr.revision_id ASC
      }]
    }
    return $revision_sets
  }


  WorkflowPage ad_instproc footer {} {
    Provide a tailored footer for workflow definition pages and
    workflow instance pages containing controls for instantiating
    forms or providing links to the workflow definition.
  } {
    if {[info exists :__no_form_page_footer]} {
      next
    } else {
      set parent_id [:parent_id]
      set form_item_id ${:page_template}
      #:msg "is wf page [:is_wf], is wf instance page [:is_wf_instance]"
      if {[:is_wf]} {
        #
        # page containing a work flow definition
        #
        #set ctx [::xowf::Context require [self]]
        set work_flow_form [::xo::db::CrClass get_instance_from_db -item_id $form_item_id]
        set work_flow_base [$work_flow_form pretty_link]

        set wf [self]
        set wf_base [$wf pretty_link]
        set button_objs [list]

        # create new workflow instance button with start form
        #if {[:parent_id] != [::${:package_id} folder_id]} {
        #  set parent_id [:parent_id]
        #}
        set link [::${:package_id} make_link -link $wf_base $wf create-new parent_id return_url]
        lappend button_objs [::xowiki::includelet::form-menu-button-new new -volatile \
                                 -parent_id $parent_id \
                                 -form $wf -link $link]

        # list workflow instances button
        set obj [::xowiki::includelet::form-menu-button-wf-instances new -volatile \
                     -package_id ${:package_id} -parent_id $parent_id \
                     -base $wf_base -form $wf]
        if {[info exists return_url]} {
          $obj return_url $return_url
        }
        lappend button_objs $obj

        # work flow definition button
        set obj [::xowiki::includelet::form-menu-button-form new -volatile \
                     -package_id ${:package_id} -parent_id $parent_id \
                     -base $work_flow_base -form $work_flow_form]
        if {[info exists return_url]} {$obj return_url $return_url}
        lappend button_objs $obj

        # make menu
        return [:include [list form-menu -form_item_id ${:item_id} -button_objs $button_objs]]

      } elseif {[:is_wf_instance]} {
        #
        # work flow instance
        #
        set entry_form_item_id [:wf_property wf_form_id]
        set work_flow_form [::xo::db::CrClass get_instance_from_db -item_id $form_item_id]
        set work_flow_base [$work_flow_form pretty_link]
        set button_objs [list]

        #:msg entry_form_item_id=$entry_form_item_id-exists?=[nsf::is object $entry_form_item_id]

        # form definition button
        if {![nsf::is object $entry_form_item_id]} {
          # In case, the id is a form object, it is a dynamic form,
          # that we can't edit; therefore, we provide no link.
          #
          # Here, we have an id that we use for fetching...
          #
          set form [::xo::db::CrClass get_instance_from_db -item_id $entry_form_item_id]
          set base [$form pretty_link]
          set obj [::xowiki::includelet::form-menu-button-form new -volatile \
                       -package_id ${:package_id} -parent_id $parent_id \
                       -base $base -form $form]
          if {[info exists return_url]} {
            $obj return_url $return_url
          }
          lappend button_objs $obj
        }
        #
        # work flow definition button
        #
        set obj [::xowiki::includelet::form-menu-button-wf new -volatile \
                     -package_id ${:package_id} -parent_id $parent_id \
                     -base $work_flow_base -form $work_flow_form]
        if {[info exists return_url]} {$obj return_url $return_url}
        lappend button_objs $obj
        # make menu
        return [:include [list form-menu -form_item_id ${:page_template} -button_objs $button_objs]]
      } else {
        next
      }
    }
  }

  WorkflowPage ad_instproc call_action_foreach {-action:required {-attributes ""} page_names} {
    Call the specified action for each of the specified pages denoted
    by the list of page names
  } {
    foreach page_name $page_names {
      set page [${:package_id} get_page_from_name -parent_id [:parent_id] -name $page_name]
      if {$page ne ""} {
        $page call_action -action $action -attributes $attributes
      } else {
        ns_log notice "WF: could not call action $action, since $page_name in [:parent_id] failed"
      }
    }
  }

  WorkflowPage ad_instproc get_action_obj {-action:required} {

    Check if the action can be executed in the current state,
    and if so, return the action_obj.

  } {
    set ctx [::xowf::Context require [self]]
    #
    # First try to call the action in the current state
    #
    foreach a [$ctx get_actions] {
      if {[namespace tail $a] eq "$action"} {
        # In the current state, the specified action is allowed
        :log  "--xowf action $action allowed -- name='${:name}'"
        return $a
      }
    }
    #
    # Some actions are state-safe, these can be called in every state
    #
    set actionObj [$ctx wf_definition_object $action]
    if {[nsf::is object $actionObj] && [$actionObj state_safe]} {
      # The action is defined as state-safe, so if can be called in every state
      :log  "--xowf action $action state_safe -- name='${:name}'"
      return $actionObj
    }
    error "No state-safe action '$action' available in workflow instance [self] of \
    [${:page_template} name] in state [$ctx get_current_state]\n\
    Available actions: [[$ctx current_state] get_actions]"
  }

  WorkflowPage ad_instproc call_action {-action {-attributes {}}} {
    Call the specified action in the current workflow instance.
    The specified attributes are provided like form_parameters to
    the action of the workflow.
  } {
    if {![:is_wf_instance]} {
      error "Page [self] is not a Workflow Instance"
    }

    set actionObj [:get_action_obj -action $action]
    return [$actionObj invoke -attributes $attributes]
  }


  WorkflowPage ad_instproc childpage {-name:required -form} {

    Return the child page of the current object with the provided
    name. In case the child object does not exist, create it as an
    instance of the provided form.

    @return page object
  } {
    if {[info exists form]} {
      set child_page_id [::${:package_id} lookup \
                             -use_package_path false \
                             -default_lang en \
                             -name $name \
                             -parent_id ${:item_id}]
      if {$child_page_id == 0} {
        ns_log notice "child page '$name' does not exist"
        set form_obj [::${:package_id} instantiate_forms \
                          -default_lang "en" \
                          -forms $form]
        if {[llength $form_obj] == 0} {
          error "childpage: cannot instantiate $form"
        }
        set p [$form_obj create_form_page_instance \
                   -name $name \
                   -nls_language en_US \
                   -parent_id ${:item_id} \
                   -package_id ${:package_id} \
                   -instance_attributes {}]
        $p save_new
      } else {
        #ns_log notice "child page '$name' exists already (item_id $child_page_id)"
        set p [::xo::db::CrClass get_instance_from_db -item_id $child_page_id]
      }
      return $p
    } else {
      error "cannot create '$name': API supports so far only form pages"
    }
 }

  #
  # Interface to atjobs
  #
  WorkflowPage ad_instproc schedule_action {
    -time:required
    -party_id
    -action:required
    {-attributes {}}
  } {
    Schedule the specified action for the current workflow instance at
    the given time. The specified attributes are provided like
    form_parameters to the action of the workflow.

    @param time       time when the atjob should be executed
    @param party_id   party_id for the user executing the atjob
    @param action     workflow action to be executed
    @param attributes arguments provided to the workflow action
                      (attribute value pairs)
  } {
    if {![:is_wf_instance]} {
      error "Page [self] is not a Workflow Instance"
    }
    if {![info exists party_id]} {
      set party_id [::xo::cc user_id]
    }
    :schedule_job -time $time -party_id $party_id \
        [list call_action -action $action -attributes $attributes]
  }

  WorkflowPage ad_instproc schedule_job {-time:required -party_id cmd} {

    Schedule the specified Tcl command for the current package
    instance at the given time.

  } {
    :log "-at $time"
    set j [::xowf::atjob new \
               -time $time \
               -party_id $party_id \
               -cmd $cmd \
               -url [:pretty_link] \
               -object [self]]
    $j persist
  }

  ad_proc -private migrate_from_wf_current_state {} {
    #
    # Transform the former instance_attributes
    #   "wf_current_state" to the xowiki::FormPage attribute "state", and
    #   "wf_assignee" to the xowiki::FormPage attribute "assignee".
    #
    set count 0
    foreach atts [xo::dc list_of_lists entries {
      select p.state,p.assignee,pi.instance_attributes,p.xowiki_form_page_id
      from xowiki_form_page p, xowiki_page_instance pi, cr_items i, cr_revisions r
      where r.item_id = i.item_id and p.xowiki_form_page_id = r.revision_id and
      pi.page_instance_id = r.revision_id
    }] {
      lassign $atts state assignee instance_attributes xowiki_form_page_id
      if {[dict exists $instance_attributes wf_current_state]
          && [dict get $instance_attributes wf_current_state] ne $state} {

        #Object msg "must update state $state for $xowiki_form_page_id to [dict get $instance_attributes wf_current_state]"

        xo::db dml update_state "update xowiki_form_page \
                set state = '[dict get $instance_attributes wf_current_state]'
                where xowiki_form_page_id  = :xowiki_form_page_id"
        incr count
      }
      if {[dict exists $instance_attributes wf_assignee]
          && [dict get $instance_attributes wf_assignee] ne $assignee
        } {
        #Object msg "must update assignee $assignee for $xowiki_form_page_id to [dict get $instance_attributes wf_assignee]"
        set wf_assignee [dict get $instance_attributes wf_assignee]
        xo::dc dml update_state "update xowiki_form_page set assignee = :wf_assignee \
                where xowiki_form_page_id = :xowiki_form_page_id"
        incr count
      }
    }
    return $count
  }

}



#
# In order to provide either a REST or a DAV interface, we have to
# switch to basic authentication, since non-OpenACS software packages
# don't know how to handle OpenACS cookies. The basic authentication
# interface can be established in three steps:
#
#  1) Create a basic authentication handler, Choose a URL and
#     define optionally the package to be initialized:
#     Example:
#            ::xowf::dav create ::xowf::baHandler -url /handler -package ::xowf::Package
#
#  2) Make sure, the basic authentication handler is initialized during
#     startup. Write a *-init.tcl file containing a call to the
#     created handler.
#     Example:
#            ::xowf::baHandler register
#
#  3) Write procs with names such as GET, PUT, POST to handle
#     the requests. These procs overload the predefined behavior.
#

namespace eval ::xowf {
  # ::xo::dav should be probably changed to ::xo::ProtocolHandler for release
  ::xotcl::Class create ::xowf::dav -superclass ::xo::dav

  ::xowf::dav instproc get_package_id {} {
    if {${:uri} eq "/"} {
      set :wf ""
      #
      # Take the first package instance
      #
      set {:package_id} [lindex [$package instances] 0]
      ${:package} initialize -package_id ${:package_id}
    } else {
      set :wf /${:uri}
      ${:package} initialize -url ${:uri}
    }
    # :log package_id=${:package_id}
    return ${:package_id}
  }

  ::xowf::dav instproc call_action {-uri -action -attributes} {
    ${:package} initialize -url $uri
    set object_name [::$package_id set object]
    set page [::$package_id resolve_request -path $object_name method]
    if {$page eq ""} {
      set errorMsg cannot resolve '$object_name' in package [::$package_id package_url]
      ad_log error $errorMsg
      ns_return 406 text/plain "Error: $errorMsg"
    } elseif {[catch {set msg [$page call_action \
                                   -action $action \
                                   -attributes $attributes]} errorMsg]} {
      ad_log error "$uri $action $attributes resulted in $errorMsg"
      ns_return 406 text/plain "Error: $errorMsg\n"
    } else {
      ns_return 200 text/plain "Success: $msg\n"
    }
  }


  ::xowf::dav create ::xowf::dav-todo -url /dav-todo -package ::xowf::Package

  ::xowf::dav-todo proc GET {} {
    set p [::xowiki::Page new -package_id ${:package_id}]
    $p include [list wf-todo -ical 1 -workflow ${:wf}]
    #ns_return 200 text/plain GET-${:uri}-XXX-pid=${:package_id}-wf=${:wf}-[::xo::cc serialize]
  }

  #   ::xowf::dav-todo proc GET {} {
  #     set uri /xowf/153516
  #     set uri /xowf/18362
  #     set uri /xowf/18205
  #     :call_action -uri $uri -action work -attributes [list comment hello3 effort 4]
  #   }

  proc include {wfName {vars ""}} {
    uplevel [::xowf::include_get -level 2 $wfName $vars]
  }

  ad_proc -private include_get {{-level 1} wfName {vars ""}} {

    Implement inclusion of workflow definitions.

  } {
    if {![string match "/packages/*/lib/*" $wfName]} {
      error "path leading to workflow name must look like /packages/*/lib/*"
    }
    set fname $::acs::rootdir/$wfName

    if {![ad_file readable $fname]} {
      error "file '$fname' not found"
    }

    #
    # Tell the caller, what files were included in the thread
    # invocation. It would be nicer to have this more OO, such we can
    # avoid the global variable ::__xowf_depends.
    #
    lappend ::__xowf_depends $fname [ad_file mtime $fname]

    set f [open $fname]; set wfDefinition [read $f]; close $f
    #::xotcl::Object log "INCLUDE $wfName [list $vars]"
    if {[llength $vars] > 0} {
      foreach var $vars {
        lappend substMap @$var@ [uplevel $level [list set $var]]
      }
      set wfDefinition [string map $substMap $wfDefinition]
    }
    #::xotcl::Object log "AFTER SUBST $wfName [list $vars]\n$wfDefinition"
    return [list eval $wfDefinition]
  }

}

namespace eval ::xowiki {
  ::xowiki::MenuBar instproc config=xowf {
    {-bind_vars {}}
    -current_page:required
    -package_id:required
    -folder_link:required
    -return_url
  } {
    :config=default \
        -bind_vars $bind_vars \
        -current_page $current_page \
        -package_id $package_id \
        -folder_link $folder_link \
        -return_url $return_url

    return {
      {entry -name New.Extra.Workflow   -form en:Workflow.form}
      {entry -name New.Extra.ExamFolder -form en:folder.form -query p.source=ExamFolder}
    }
  }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
