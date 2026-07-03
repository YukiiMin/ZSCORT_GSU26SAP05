*&---------------------------------------------------------------------*
*& Report : ZSCORT_PKG_032
*& Title  : SCORT - Repository Explorer (ADT-style tree)
*& Author : DEV-032 | Package: ZSCORT_GSU26SAP05
*& Date   : 2026-07-03
*& Desc   : Browse repository objects as a hierarchical tree:
*&          Owner (Person Responsible) > Package > Folder > Object Type > Object
*&          - Package is optional; Owner is Level 1 root of the tree
*&          - No hard-coded object type filter: all types from TADIR are included
*&          - Text filter: search objects by name substring
*&          - Filter bar on ALV tree for Object Type columns (built-in CL_SALV)
*&          - Toolbar: Change Owner, Change Package, Open in SE80, Refresh
*&          - Double-click object: open in SE80
*&          - Checkbox on object rows: multi-select for mass actions
*& Pattern: OO-ABAP MVC (Controller Pattern)
*&   Model      : ZCL_SCORT_REPOSITORY_032 (Global Class)
*&   View       : CL_SALV_TREE + Selection Screen
*&   Controller : LCL_PKG_CONTROLLER (Local Class)
*&---------------------------------------------------------------------*
REPORT zscort_pkg_032
    NO STANDARD PAGE HEADING.

*&=====================================================================*
*& SECTION 1: SELECTION SCREEN
*&=====================================================================*

" --- Block 1: Owner (Person Responsible) ---
DATA: gv_author TYPE author.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS s_author FOR gv_author.
SELECTION-SCREEN END OF BLOCK b1.

" --- Block 2: Package (optional) ---
DATA: gv_devcla TYPE tadir-devclass.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS s_devcla FOR gv_devcla NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b2.

" --- Block 3: Object Name filter ---
DATA: gv_objname TYPE sobj_name.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  SELECT-OPTIONS s_obj FOR gv_objname NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN COMMENT /1(79) TEXT-c01.

*&=====================================================================*
*& SECTION 2: LOCAL CLASS DEFINITION - Controller
*&=====================================================================*
CLASS lcl_pkg_controller DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS:
      initialize,
      run,
      on_double_click
        FOR EVENT double_click OF cl_salv_events_tree
        IMPORTING node_key columnname,
      on_checkbox_change
        FOR EVENT checkbox_change OF cl_salv_events_tree
        IMPORTING node_key checked,
      on_user_command
        FOR EVENT added_function OF cl_salv_events
        IMPORTING e_salv_function.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF lty_node_map,
        node_key TYPE lvc_nkey,
        obj_name TYPE sobj_name,
        obj_type TYPE trobjtype,
      END OF lty_node_map,
      tt_node_map TYPE TABLE OF lty_node_map.

    DATA:
      mo_repo        TYPE REF TO zcl_scort_repository_032,
      mo_tree        TYPE REF TO cl_salv_tree,
      mt_objects     TYPE zscort_t_objects,
      mt_node_keys   TYPE tt_node_map,
      mt_checked     TYPE tt_node_map,
      mv_total_count TYPE i.

    METHODS:
      fetch_data,
      display_tree,
      show_detail_popup
        IMPORTING is_object TYPE zscort_s_object,
      do_change_owner_mass,
      do_change_package_mass,
      do_change_owner
        IMPORTING iv_new_owner TYPE author
                  is_object    TYPE zscort_s_object OPTIONAL
        CHANGING  ct_objects   TYPE zscort_t_objects,
      do_change_package
        IMPORTING iv_new_package TYPE devclass
                  is_object      TYPE zscort_s_object OPTIONAL
        CHANGING  ct_objects     TYPE zscort_t_objects,
      collect_checked_objects
        RETURNING VALUE(RT_OBJECTS) TYPE zscort_t_objects.
ENDCLASS.

*&=====================================================================*
*& SECTION 3: GLOBAL VARIABLE
*&=====================================================================*
DATA: go_ctrl TYPE REF TO lcl_pkg_controller.

*&=====================================================================*
*& SECTION 4: SAP EVENTS
*&=====================================================================*

" --- INITIALIZATION: construct controller first ---

INITIALIZATION.
  CREATE OBJECT go_ctrl.
  go_ctrl->initialize( ).

START-OF-SELECTION.
  go_ctrl->run( ).

*&=====================================================================*
*& SECTION 5: CLASS IMPLEMENTATION
*&=====================================================================*
CLASS lcl_pkg_controller IMPLEMENTATION.

  METHOD initialize.
    CREATE OBJECT mo_repo.
  ENDMETHOD.

  METHOD run.
    fetch_data( ).
    IF mt_objects IS INITIAL.
      MESSAGE 'No objects found. Check Owner / Package / Object Name filter.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    display_tree( ).
  ENDMETHOD.

  METHOD fetch_data.
    CLEAR: mt_objects, mt_node_keys, mt_checked, mv_total_count.

    TRY.
        " No object type restriction — all types from TADIR are included
        mo_repo->get_objects_all_types(
          EXPORTING
            it_devclass = s_devcla[]
            it_author   = s_author[]
            it_obj_name = s_obj[]
          IMPORTING
            et_objects  = mt_objects
        ).
      CATCH cx_root.
        CLEAR mt_objects.
    ENDTRY.

    " Sort: Owner > Package > Object Type > Object Name (required for sequential tree build)
    SORT mt_objects BY author devclass object obj_name.

    mv_total_count = lines( mt_objects ).
  ENDMETHOD.

  METHOD display_tree.
    DATA: lo_tree      TYPE REF TO cl_salv_tree,
          lo_nodes     TYPE REF TO cl_salv_nodes,
          lo_node      TYPE REF TO cl_salv_node,
          lo_item     TYPE REF TO cl_salv_item,
          lt_empty    TYPE TABLE OF zscort_s_object,
          lo_funcs     TYPE REF TO cl_salv_functions_tree,
          lo_cols     TYPE REF TO cl_salv_columns_tree,
          lo_col      TYPE REF TO cl_salv_column.

    TRY.
        cl_salv_tree=>factory(
          IMPORTING r_salv_tree = lo_tree
          CHANGING  t_table    = lt_empty
        ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    mo_tree = lo_tree.

    DATA(lo_tree_settings) = lo_tree->get_tree_settings( ).
    lo_tree_settings->set_hierarchy_header(
      CONV #( |Repository Explorer - { mv_total_count } objects - DEV-032 SCORT| )
    ).

    lo_funcs = lo_tree->get_functions( ).
    lo_funcs->set_all( abap_true ).

    " Configure columns
    lo_cols = lo_tree->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        lo_col = lo_cols->get_column( 'OBJECT' ).
        lo_col->set_medium_text( 'Type' ).
        lo_col->set_output_length( 8 ).
        lo_col = lo_cols->get_column( 'OBJ_NAME' ).
        lo_col->set_medium_text( 'Object Name' ).
        lo_col->set_long_text( 'Repository Object Name' ).
        lo_col->set_output_length( 40 ).
        lo_col = lo_cols->get_column( 'DEVCLASS' ).
        lo_col->set_medium_text( 'Package' ).
        lo_col->set_output_length( 20 ).
        lo_col = lo_cols->get_column( 'AUTHOR' ).
        lo_col->set_medium_text( 'Author' ).
        lo_col->set_output_length( 12 ).
        lo_col = lo_cols->get_column( 'SRCSYSTEM' ).
        lo_col->set_medium_text( 'Src System' ).
        lo_col->set_output_length( 10 ).
        lo_col = lo_cols->get_column( 'VERSNO' ).
        lo_col->set_medium_text( 'Version' ).
        lo_col->set_output_length( 8 ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " =======================================================================
    " Build ADT-style tree: Owner > Package > Folder > Object Type > Object
    " =======================================================================
    lo_nodes = lo_tree->get_nodes( ).
    CLEAR mt_node_keys.

    " Pre-define DDIC types set once (avoid recreating VALUE string_table in each REDUCE)
    DATA(lt_ddic_types) = VALUE string_table(
      ( `TABL` ) ( `VIEW` ) ( `DTEL` ) ( `DOMA` )
      ( `SHLP` ) ( `TTYP` ) ( `STOB` )
    ).

    " Track current node keys at each level
    DATA: lv_cur_author  TYPE author,
          lv_cur_pkg     TYPE devclass,
          lv_cur_folder  TYPE string,
          lv_cur_type    TYPE trobjtype,
          lv_author_key  TYPE lvc_nkey,
          lv_pkg_key     TYPE lvc_nkey,
          lv_folder_key  TYPE lvc_nkey,
          lv_type_key    TYPE lvc_nkey,
          ls_parent      LIKE LINE OF mt_objects,
          ls_node_map    TYPE lty_node_map.

    " Cached package descriptions
    DATA: ls_pkg_desc TYPE zscort_s_object.

    TRY.
        LOOP AT mt_objects INTO DATA(ls_obj).

          " ---------- Level 1: Owner ----------
          IF ls_obj-author <> lv_cur_author.
            lv_cur_author = ls_obj-author.
            CLEAR: lv_cur_pkg, lv_cur_folder, lv_cur_type.
            " All packages under this owner
            DATA(lv_owner_pkg_cnt) = REDUCE i(
              INIT c = 0
              FOR wa IN mt_objects WHERE ( author = ls_obj-author )
              NEXT c = c + 1 ).

            CLEAR ls_parent.
            ls_parent-author = ls_obj-author.
            lo_node = lo_nodes->add_node(
              related_node = ''
              relationship  = if_salv_c_node_relation=>parent
              data_row      = ls_parent
            ).
            lo_node->set_text( |{ ls_obj-author } ({ lv_owner_pkg_cnt })| ).
            lv_author_key = lo_node->get_key( ).
          ENDIF.

          " ---------- Level 2: Package ----------
          IF ls_obj-devclass <> lv_cur_pkg.
            lv_cur_pkg = ls_obj-devclass.
            CLEAR: lv_cur_folder, lv_cur_type.
            " All objects under this package
            DATA(lv_pkg_obj_cnt) = REDUCE i(
              INIT c = 0
              FOR wa IN mt_objects
              WHERE ( author = lv_cur_author AND devclass = ls_obj-devclass )
              NEXT c = c + 1 ).

            " Fetch package description from TDEVC
            DATA(lv_pkg_desc) = VALUE string( ).
            SELECT SINGLE descript FROM tdevc
              INTO @DATA(lv_tdevc_desc)
              WHERE devclass = @ls_obj-devclass.
            IF sy-subrc = 0 AND lv_tdevc_desc IS NOT INITIAL.
              lv_pkg_desc = | - { lv_tdevc_desc }|.
            ENDIF.

            CLEAR ls_parent.
            ls_parent-devclass = ls_obj-devclass.
            lo_node = lo_nodes->add_node(
              related_node = lv_author_key
              relationship  = if_salv_c_node_relation=>last_child
              data_row      = ls_parent
            ).
            lo_node->set_text( |{ ls_obj-devclass } ({ lv_pkg_obj_cnt }){ lv_pkg_desc }| ).
            IF lv_pkg_desc IS NOT INITIAL.
              lo_node->set_tooltip( CONV #( lv_pkg_desc ) ).
            ENDIF.
            lv_pkg_key = lo_node->get_key( ).
          ENDIF.

          " ---------- Level 3: Folder (Dictionary or Source Code Library) ----------
          DATA(lv_folder) = COND string(
            WHEN ls_obj-object IN VALUE string_table(
              ( `TABL` ) ( `VIEW` ) ( `DTEL` ) ( `DOMA` )
              ( `SHLP` ) ( `TTYP` ) ( `STOB` ) )
            THEN `Dictionary`
            ELSE `Source Code Library`
          ).

          IF lv_folder <> lv_cur_folder.
            lv_cur_folder = lv_folder.
            CLEAR lv_cur_type.
            " Count objects in this folder under current package
            IF lv_folder = `Dictionary`.
              DATA(lv_folder_cnt) = REDUCE i(
                INIT c = 0
                FOR wa IN mt_objects
                WHERE ( author = lv_cur_author
                    AND devclass = lv_cur_pkg
                    AND object IN lt_ddic_types )
                NEXT c = c + 1 ).
            ELSE.
              lv_folder_cnt = REDUCE i(
                INIT c = 0
                FOR wa IN mt_objects
                WHERE ( author = lv_cur_author
                    AND devclass = lv_cur_pkg
                    AND object NOT IN lt_ddic_types )
                NEXT c = c + 1 ).
            ENDIF.

            CLEAR ls_parent.
            lo_node = lo_nodes->add_node(
              related_node = lv_pkg_key
              relationship  = if_salv_c_node_relation=>last_child
              data_row      = ls_parent
            ).
            lo_node->set_text( |{ lv_folder } ({ lv_folder_cnt })| ).
            lv_folder_key = lo_node->get_key( ).
          ENDIF.

          " ---------- Level 4: Object Type ----------
          IF ls_obj-object <> lv_cur_type.
            lv_cur_type = ls_obj-object.
            " Count objects of this type under current package
            DATA(lv_type_cnt) = REDUCE i(
              INIT c = 0
              FOR wa IN mt_objects
              WHERE ( author = lv_cur_author
                  AND devclass = lv_cur_pkg
                  AND object = ls_obj-object )
              NEXT c = c + 1 ).

            CLEAR ls_parent.
            ls_parent-object = ls_obj-object.
            lo_node = lo_nodes->add_node(
              related_node = lv_folder_key
              relationship  = if_salv_c_node_relation=>last_child
              data_row      = ls_parent
            ).
            lo_node->set_text( |{ ls_obj-object } ({ lv_type_cnt })| ).
            lv_type_key = lo_node->get_key( ).
          ENDIF.

          " ---------- Level 5: Object leaf ----------
          lo_node = lo_nodes->add_node(
            related_node = lv_type_key
            relationship  = if_salv_c_node_relation=>last_child
            data_row      = ls_obj
          ).
          lo_node->set_text( ls_obj-obj_name ).

          " Leaf gets checkbox (editable)
          lo_item = lo_node->get_hierarchy_item( ).
          lo_item->set_type( if_salv_c_item_type=>checkbox ).
          lo_item->set_editable( abap_true ).

          ls_node_map-node_key = lo_node->get_key( ).
          ls_node_map-obj_name = ls_obj-obj_name.
          ls_node_map-obj_type = ls_obj-object.
          APPEND ls_node_map TO mt_node_keys.

        ENDLOOP.

        lo_nodes->expand_all( ).
      CATCH cx_salv_not_found cx_salv_msg.
        MESSAGE 'Tree node build failed - object list returned but tree could not render.' TYPE 'W'.
        RETURN.
    ENDTRY.

    " Register events
    SET HANDLER me->on_double_click    FOR mo_tree->get_event( ).
    SET HANDLER me->on_checkbox_change FOR mo_tree->get_event( ).
    SET HANDLER me->on_user_command    FOR mo_tree->get_event( ).

    " Add custom toolbar buttons
    TRY.
        lo_funcs->add_function(
          name     = 'CHG_OWNER'
          icon     = '@IO@'
          text     = 'Change Owner'
          tooltip  = 'Change owner for selected object(s)'
          position = if_salv_c_function_position=>right_of_salv_functions
        ).
      CATCH cx_salv_existing cx_salv_wrong_call cx_salv_method_not_supported.
    ENDTRY.

    TRY.
        lo_funcs->add_function(
          name     = 'CHG_PKG'
          icon     = '@BW@'
          text     = 'Change Package'
          tooltip  = 'Move selected object(s) to a different Development Package'
          position = if_salv_c_function_position=>right_of_salv_functions
        ).
      CATCH cx_salv_existing cx_salv_wrong_call cx_salv_method_not_supported.
    ENDTRY.

    TRY.
        lo_funcs->add_function(
          name     = 'OPEN_SE80'
          icon     = '@0Q@'
          text     = 'Open in SE80'
          tooltip  = 'Open selected object in SE80'
          position = if_salv_c_function_position=>right_of_salv_functions
        ).
      CATCH cx_salv_existing cx_salv_wrong_call cx_salv_method_not_supported.
    ENDTRY.

    TRY.
        lo_funcs->add_function(
          name     = 'REFRESH'
          icon     = '@3I@'
          text     = 'Refresh'
          tooltip  = 'Re-fetch and rebuild tree'
          position = if_salv_c_function_position=>right_of_salv_functions
        ).
      CATCH cx_salv_existing cx_salv_wrong_call cx_salv_method_not_supported.
    ENDTRY.

    mo_tree->display( ).
  ENDMETHOD.

  METHOD on_double_click.
    DATA: ls_node TYPE lty_node_map,
          ls_obj  TYPE zscort_s_object.

    " Only respond to clicks on OBJ_NAME or OBJECT columns (avoid spurious fires)
    CHECK columnname = 'OBJ_NAME' OR columnname = 'OBJECT'.

    " Find which node was clicked via internal map (node_key is unique per row)
    READ TABLE mt_node_keys INTO ls_node
      WITH KEY node_key = CONV lvc_nkey( node_key ).
    IF sy-subrc <> 0.
      " Either parent (group header) or not in map - silent return
      RETURN.
    ENDIF.

    " Look up full object data
    READ TABLE mt_objects INTO ls_obj
      WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Open in SE80/RS_TOOL_ACCESS - this is the user's expected double-click behavior
    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation    = 'SHOW'
        object_name  = ls_obj-obj_name
        object_type  = ls_obj-object
        devclass     = ls_obj-devclass
      EXCEPTIONS
        not_executed = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      " Fallback to plain SE80
      CALL TRANSACTION 'SE80'.
    ENDIF.
  ENDMETHOD.

  METHOD on_checkbox_change.
    DATA: lv_k    TYPE lvc_nkey,
          ls_key  TYPE lty_node_map.

    lv_k = CONV lvc_nkey( node_key ).
    IF checked = abap_true.
      READ TABLE mt_node_keys INTO ls_key WITH KEY node_key = lv_k.
      IF sy-subrc = 0.
        READ TABLE mt_checked TRANSPORTING NO FIELDS WITH KEY node_key = lv_k.
        IF sy-subrc <> 0.
          APPEND ls_key TO mt_checked.
        ENDIF.
      ENDIF.
    ELSE.
      DELETE mt_checked WHERE node_key = lv_k.
    ENDIF.
  ENDMETHOD.

  METHOD collect_checked_objects.
    LOOP AT mt_checked INTO DATA(ls_checked).
      READ TABLE mt_objects INTO DATA(ls_obj)
        WITH KEY obj_name = ls_checked-obj_name object = ls_checked-obj_type.
      IF sy-subrc = 0.
        APPEND ls_obj TO rt_objects.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD do_change_owner.
    " is_object: single-object entry point (popup with prefilled value)
    " ct_objects: list to update; updated with new AUTHOR
    DATA: lv_ok_count  TYPE i,
          lv_err_count TYPE i,
          lv_err_log   TYPE string,
          lv_obj       TYPE zscort_s_object.

    " If is_object supplied but ct_objects empty: treat as single-object mode
    IF ct_objects IS INITIAL AND is_object IS NOT INITIAL.
      lv_obj = is_object.
      APPEND lv_obj TO ct_objects.
    ENDIF.

    LOOP AT ct_objects INTO lv_obj.
      TRY.
          DATA(lv_success) = mo_repo->change_object_owner(
            iv_obj_name  = lv_obj-obj_name
            iv_obj_type  = lv_obj-object
            iv_new_owner = iv_new_owner
          ).
          IF lv_success = abap_true.
            ADD 1 TO lv_ok_count.
            lv_obj-author = iv_new_owner.
            MODIFY ct_objects FROM lv_obj.
          ELSE.
            ADD 1 TO lv_err_count.
            lv_err_log = |{ lv_err_log } { lv_obj-object }-{ lv_obj-obj_name };|.
          ENDIF.
        CATCH cx_root.
          ADD 1 TO lv_err_count.
      ENDTRY.
    ENDLOOP.

    IF lv_ok_count > 0.
      MESSAGE |Owner changed for { lv_ok_count } object(s) successfully.| TYPE 'S'.
    ENDIF.
    IF lv_err_count > 0.
      MESSAGE |{ lv_err_count } object(s) failed: { lv_err_log }| TYPE 'W'.
    ENDIF.
    IF lv_ok_count = 0 AND lv_err_count = 0.
      MESSAGE 'No object updated.' TYPE 'S'.
    ENDIF.
  ENDMETHOD.

  METHOD do_change_package.
    DATA: lv_ok_count  TYPE i,
          lv_err_count TYPE i,
          lv_err_log   TYPE string,
          lv_obj       TYPE zscort_s_object.

    IF ct_objects IS INITIAL AND is_object IS NOT INITIAL.
      lv_obj = is_object.
      APPEND lv_obj TO ct_objects.
    ENDIF.

    LOOP AT ct_objects INTO lv_obj.
      TRY.
          DATA(lv_success) = mo_repo->change_object_package(
            iv_obj_name     = lv_obj-obj_name
            iv_obj_type     = lv_obj-object
            iv_new_devclass = iv_new_package
          ).
          IF lv_success = abap_true.
            ADD 1 TO lv_ok_count.
            lv_obj-devclass = iv_new_package.
            MODIFY ct_objects FROM lv_obj.
          ELSE.
            ADD 1 TO lv_err_count.
            lv_err_log = |{ lv_err_log } { lv_obj-object }-{ lv_obj-obj_name };|.
          ENDIF.
        CATCH cx_root.
          ADD 1 TO lv_err_count.
      ENDTRY.
    ENDLOOP.

    IF lv_ok_count > 0.
      MESSAGE |Package changed for { lv_ok_count } object(s) successfully.| TYPE 'S'.
    ENDIF.
    IF lv_err_count > 0.
      MESSAGE |{ lv_err_count } object(s) failed: { lv_err_log }| TYPE 'W'.
    ENDIF.
  ENDMETHOD.

  METHOD do_change_owner_mass.
    DATA: lt_objects TYPE zscort_t_objects.

    lt_objects = collect_checked_objects( ).

    IF lt_objects IS INITIAL.
      MESSAGE 'Please check at least one object first (click the checkbox in the row).' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Determine initial value (existing owner)
    DATA(lv_initial) = VALUE author( ).
    READ TABLE lt_objects INTO DATA(ls_first) INDEX 1.
    IF sy-subrc = 0.
      lv_initial = ls_first-author.
    ENDIF.

    DATA: lt_fields  TYPE TABLE OF sval,
          ls_field   TYPE sval,
          lv_retcode TYPE char1,
          lv_owner   TYPE author.

    ls_field-tabname   = 'TADIR'.
    ls_field-fieldname = 'AUTHOR'.
    ls_field-fieldtext = 'New Owner (user ID)'.
    ls_field-value     = lv_initial.
    APPEND ls_field TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title = |Change Owner for { lines( lt_objects ) } object(s)|
      IMPORTING
        returncode  = lv_retcode
      TABLES
        fields      = lt_fields
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0 OR lv_retcode = 'A'.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'AUTHOR'.
    lv_owner = ls_field-value.

    IF lv_owner IS INITIAL.
      MESSAGE 'Owner cannot be empty.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    do_change_owner(
      EXPORTING iv_new_owner = lv_owner
      CHANGING  ct_objects  = lt_objects
    ).

    " ALV Tree caches data per-node, mt_objects changes don't refresh UI
    " → ask user to click REFRESH (or LEAVE TO TRANSACTION for clean rebuild)
    MESSAGE 'Owner changed. Please click REFRESH (or F8) to reload tree with updated author.' TYPE 'S'.
  ENDMETHOD.

  METHOD do_change_package_mass.
    DATA: lt_objects TYPE zscort_t_objects.

    lt_objects = collect_checked_objects( ).

    IF lt_objects IS INITIAL.
      MESSAGE 'Please check at least one object first (click the checkbox in the row).' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_initial) = VALUE devclass( ).
    READ TABLE lt_objects INTO DATA(ls_first) INDEX 1.
    IF sy-subrc = 0.
      lv_initial = ls_first-devclass.
    ENDIF.

    DATA: lt_fields  TYPE TABLE OF sval,
          ls_field   TYPE sval,
          lv_retcode TYPE char1,
          lv_pkg     TYPE devclass.

    ls_field-tabname   = 'TADIR'.
    ls_field-fieldname = 'DEVCLASS'.
    ls_field-fieldtext = 'New Package'.
    ls_field-value     = lv_initial.
    APPEND ls_field TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title = |Change Package for { lines( lt_objects ) } object(s)|
      IMPORTING
        returncode  = lv_retcode
      TABLES
        fields      = lt_fields
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0 OR lv_retcode = 'A'.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'DEVCLASS'.
    lv_pkg = ls_field-value.

    IF lv_pkg IS INITIAL.
      MESSAGE 'Package cannot be empty.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    do_change_package(
      EXPORTING iv_new_package = lv_pkg
      CHANGING  ct_objects     = lt_objects
    ).

    " ALV Tree caches data per-node, mt_objects changes don't refresh UI
    " → ask user to click REFRESH (or LEAVE TO TRANSACTION for clean rebuild)
    MESSAGE 'Package changed. Please click REFRESH (or F8) to reload tree with updated package.' TYPE 'S'.
  ENDMETHOD.

  METHOD show_detail_popup.
    TYPES: BEGIN OF lty_row,
             field_label TYPE string,
             field_value TYPE string,
           END OF lty_row.
    DATA: lt_display TYPE TABLE OF lty_row,
          ls_row     TYPE lty_row,
          lo_popup   TYPE REF TO cl_salv_table,
          lo_cols    TYPE REF TO cl_salv_columns.

    " Build display table
    ls_row-field_label = 'Object Name'. ls_row-field_value = is_object-obj_name.  APPEND ls_row TO lt_display.
    ls_row-field_label = 'Object Type'. ls_row-field_value = is_object-object.    APPEND ls_row TO lt_display.
    ls_row-field_label = 'Package'.     ls_row-field_value = is_object-devclass.  APPEND ls_row TO lt_display.
    ls_row-field_label = 'Author'.      ls_row-field_value = is_object-author.    APPEND ls_row TO lt_display.
    ls_row-field_label = 'Src System'.  ls_row-field_value = is_object-srcsystem. APPEND ls_row TO lt_display.
    ls_row-field_label = 'Version'.     ls_row-field_value = is_object-versno.    APPEND ls_row TO lt_display.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_popup
          CHANGING  t_table      = lt_display
        ).
      CATCH cx_salv_msg.
        " Skip popup if ALV factory fails - silent fall-through
        RETURN.
    ENDTRY.

    lo_popup->get_display_settings( )->set_list_header( |SCORT Detail: { is_object-obj_name }| ).
    lo_popup->get_functions( )->set_all( abap_false ).
    lo_cols = lo_popup->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        lo_cols->get_column( 'FIELD_LABEL' )->set_medium_text( 'Field' ).
        lo_cols->get_column( 'FIELD_VALUE' )->set_medium_text( 'Value' ).
      CATCH cx_salv_not_found.
        " column not found - ignore
    ENDTRY.

    lo_popup->display( ).
  ENDMETHOD.

  METHOD on_user_command.
    DATA: ls_obj TYPE zscort_s_object.

    CASE e_salv_function.

      WHEN 'REFRESH'.
        " LEAVE TO TRANSACTION: clean restart without nested call stack
        LEAVE TO TRANSACTION sy-tcode.

      WHEN 'CHG_OWNER'.
        do_change_owner_mass( ).

      WHEN 'CHG_PKG'.
        do_change_package_mass( ).

      WHEN 'OPEN_SE80'.
        DATA(lt_checked_obj) = collect_checked_objects( ).
        IF lt_checked_obj IS INITIAL.
          MESSAGE 'Please check at least one object first (click the checkbox in the row).' TYPE 'S' DISPLAY LIKE 'W'.
          RETURN.
        ENDIF.

        READ TABLE lt_checked_obj INTO ls_obj INDEX 1.

        CALL FUNCTION 'RS_TOOL_ACCESS'
          EXPORTING
            operation    = 'SHOW'
            object_name  = ls_obj-obj_name
            object_type  = ls_obj-object
            devclass     = ls_obj-devclass
          EXCEPTIONS
            not_executed = 1
            OTHERS       = 2.
        IF sy-subrc <> 0.
          CALL TRANSACTION 'SE80'.
        ENDIF.

      WHEN OTHERS.
        " unknown
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

"*&---------------------------------------------------------------------*
"*& TEXT SYMBOLS
"*&---------------------------------------------------------------------*
" TEXT-b01 = 'Owner (Person Responsible)'.
" TEXT-b02 = 'Package (optional)'.
" TEXT-b03 = 'Object Name Filter'.
" TEXT-c01 = 'All object types from TADIR are included. Use Object Name for substring search. Use Owner as Level 1 root.'.
