*&---------------------------------------------------------------------*
*& Report : ZSCORT_PKG_032
*& Title  : SCORT - Repository Explorer (ADT-style tree)
*& Author : DEV-032 | Package: ZSCORT_GSU26SAP05
*& Date   : 2026-07-03
*& Desc   : Browse repository objects as a hierarchical tree:
*&          Owner > Package > Object Type > Object
*&          - Right-click context menu on any node (View Details, Change Owner, Change Package, Open in SE80)
*&          - Double-click object leaf → View Details
*&          - Double-click parent node → expand/collapse
*&          - Checkbox on object rows: multi-select for mass actions
*& Pattern: OO-ABAP MVC (Controller Pattern)
*&   Model      : ZCL_SCORT_REPOSITORY_032 (Global Class)
*&   View       : CL_SALV_TREE + Selection Screen
*&   Controller : LCL_PKG_CONTROLLER (Local Class)
*&---------------------------------------------------------------------*
REPORT zscort_pkg_032
    NO STANDARD PAGE HEADING.

*& SECTION 1: SELECTION SCREEN
DATA: gv_author TYPE author.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS s_author FOR gv_author.
SELECTION-SCREEN END OF BLOCK b1.

DATA: gv_devcla TYPE tadir-devclass.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS s_devcla FOR gv_devcla NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b2.

DATA: gv_objname TYPE sobj_name.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  SELECT-OPTIONS s_obj FOR gv_objname NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN COMMENT /1(79) TEXT-c01.

TYPES:
  BEGIN OF lty_node_info,
    node_key TYPE lvc_nkey,
    level    TYPE char1,
    obj_name TYPE sobj_name,
    obj_type TYPE trobjtype,
    devclass TYPE devclass,
  END OF lty_node_info,
  tt_node_info TYPE TABLE OF lty_node_info,

  BEGIN OF lty_node_map,
    node_key TYPE lvc_nkey,
    obj_name TYPE sobj_name,
    obj_type TYPE trobjtype,
  END OF lty_node_map,
  tt_node_map TYPE TABLE OF lty_node_map.

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
      on_added_function
        FOR EVENT added_function OF cl_salv_events_tree
        IMPORTING e_salv_function.

  PRIVATE SECTION.

    DATA:
      mo_reader     TYPE REF TO zif_scort_repo_reader,
      mo_mutator    TYPE REF TO zif_scort_repo_mutator,
      mo_tree        TYPE REF TO cl_salv_tree,
      mt_objects     TYPE zscort_t_objects,
      mt_node_keys   TYPE tt_node_map,
      mt_node_info   TYPE tt_node_info,
      mt_checked     TYPE tt_node_map,
      mv_total_count TYPE i.

    METHODS:
      fetch_data,
      display_tree,
      show_detail_popup
        IMPORTING is_object TYPE zscort_s_object,
      do_change_owner_single
        IMPORTING is_object TYPE zscort_s_object,
      do_change_package_single
        IMPORTING is_object TYPE zscort_s_object,
      collect_checked_objects
        RETURNING VALUE(rt_objects) TYPE zscort_t_objects.
ENDCLASS.

*&=====================================================================*
*& SECTION 3: GLOBAL VARIABLE
*&=====================================================================*
DATA: go_ctrl TYPE REF TO lcl_pkg_controller.

*&=====================================================================*
*& SECTION 4: SAP EVENTS
*&=====================================================================*
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
    mo_reader  = zcl_scort_factory=>get_reader( ).
    mo_mutator = zcl_scort_factory=>get_mutator( ).
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
    CLEAR: mt_objects, mt_node_keys, mt_node_info, mt_checked, mv_total_count.

    TRY.
        mo_reader->get_objects_all_types(
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

    SORT mt_objects BY author devclass object obj_name.
    mv_total_count = lines( mt_objects ).
  ENDMETHOD.

  METHOD display_tree.
    DATA: lo_tree      TYPE REF TO cl_salv_tree,
          lo_nodes     TYPE REF TO cl_salv_nodes,
          lo_node      TYPE REF TO cl_salv_node,
          lo_item      TYPE REF TO cl_salv_item,
          lo_funcs     TYPE REF TO cl_salv_functions_tree,
          lo_cols      TYPE REF TO cl_salv_columns_tree,
          lo_col       TYPE REF TO cl_salv_column,
          lo_evt       TYPE REF TO cl_salv_events_tree,
          lt_empty     TYPE TABLE OF zscort_s_object.

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

    lo_tree->get_tree_settings( )->set_hierarchy_header(
      CONV #( |Repository Explorer - { mv_total_count } object(s)| )
    ).

    lo_funcs = lo_tree->get_functions( ).
    lo_funcs->set_all( abap_true ).

    lo_cols = lo_tree->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        lo_col = lo_cols->get_column( 'OBJECT' ).
        lo_col->set_medium_text( 'Type' ).
        lo_col->set_output_length( 8 ).
        lo_col = lo_cols->get_column( 'OBJ_NAME' ).
        lo_col->set_medium_text( 'Object Name' ).
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

    " ===================================================================
    " Build ADT-style tree: Owner > Package > Object Type > Object
    " No intermediate Folder level — Object Type already distinguishes
    " Dictionary vs Source Code Library in its label
    " ===================================================================
    lo_nodes = lo_tree->get_nodes( ).
    CLEAR: mt_node_keys, mt_node_info.

    DATA: lv_cur_author TYPE author,
          lv_cur_pkg    TYPE devclass,
          lv_cur_type   TYPE trobjtype,
          lv_author_key TYPE lvc_nkey,
          lv_pkg_key    TYPE lvc_nkey,
          lv_type_key   TYPE lvc_nkey,
          ls_node_map   TYPE lty_node_map,
          ls_node_info  TYPE lty_node_info,
          ls_empty      TYPE zscort_s_object.

    TRY.
        LOOP AT mt_objects INTO DATA(ls_obj).

          " Level 1: Owner (root) — create new root node when author changes
          IF ls_obj-author <> lv_cur_author.
            lv_cur_author = ls_obj-author.
            CLEAR: lv_cur_pkg, lv_cur_type.

            DATA(lv_owner_pkg_cnt) = REDUCE i(
              INIT c = 0
              FOR w IN mt_objects WHERE ( author = ls_obj-author )
              NEXT c = c + 1 ).

            CLEAR ls_empty.
            ls_empty-author = ls_obj-author.
            lo_node = lo_nodes->add_node(
              related_node = ''
              relationship  = if_salv_c_node_relation=>parent
              data_row      = ls_empty
            ).
            lo_node->set_text( |{ ls_obj-author } ({ lv_owner_pkg_cnt })| ).
            lo_node->set_expander( abap_true ).
            lv_author_key = lo_node->get_key( ).
          ENDIF.

          " Level 2: Package
          IF ls_obj-devclass <> lv_cur_pkg.
            lv_cur_pkg = ls_obj-devclass.
            CLEAR lv_cur_type.

            DATA(lv_pkg_obj_cnt) = REDUCE i(
              INIT c = 0
              FOR w IN mt_objects
              WHERE ( author = lv_cur_author AND devclass = ls_obj-devclass )
              NEXT c = c + 1 ).

            " Fetch package description from TDEVC
            DATA lv_tdevc_desc TYPE tdevc-ctext.
            DATA lv_pkg_label TYPE string.
            SELECT SINGLE ctext FROM tdevc
              INTO @lv_tdevc_desc
              WHERE devclass = @ls_obj-devclass.
            IF sy-subrc = 0 AND lv_tdevc_desc IS NOT INITIAL.
              lv_pkg_label = |{ ls_obj-devclass } ({ lv_pkg_obj_cnt }) - { lv_tdevc_desc }|.
            ELSE.
              lv_pkg_label = |{ ls_obj-devclass } ({ lv_pkg_obj_cnt })|.
            ENDIF.

            CLEAR ls_empty.
            ls_empty-devclass = ls_obj-devclass.
            lo_node = lo_nodes->add_node(
              related_node = lv_author_key
              relationship  = if_salv_c_node_relation=>last_child
              data_row      = ls_empty
            ).
            lo_node->set_text( CONV lvc_value( lv_pkg_label ) ).
            lo_node->set_expander( abap_true ).
            lv_pkg_key = lo_node->get_key( ).
          ENDIF.

          " Level 3: Object Type (e.g. CLAS, PROG, TABL)
          IF ls_obj-object <> lv_cur_type.
            lv_cur_type = ls_obj-object.

            DATA(lv_type_cnt) = REDUCE i(
              INIT c = 0
              FOR w IN mt_objects
              WHERE ( author = lv_cur_author
                  AND devclass = lv_cur_pkg
                  AND object = ls_obj-object )
              NEXT c = c + 1 ).

            " Human-readable type label: e.g. "CLAS - ABAP Classes"
            DATA lv_type_label TYPE string.
            lv_type_label = SWITCH #(
              ls_obj-object
              WHEN 'CLAS' THEN |CLAS - ABAP Classes ({ lv_type_cnt })|
              WHEN 'PROG' THEN |PROG - Programs/Reports ({ lv_type_cnt })|
              WHEN 'TABL' THEN |TABL - Database Tables ({ lv_type_cnt })|
              WHEN 'VIEW' THEN |VIEW - Views ({ lv_type_cnt })|
              WHEN 'DTEL' THEN |DTEL - Data Elements ({ lv_type_cnt })|
              WHEN 'DOMA' THEN |DOMA - Domains ({ lv_type_cnt })|
              WHEN 'FUGR' THEN |FUGR - Function Groups ({ lv_type_cnt })|
              WHEN 'FUNC' THEN |FUNC - Function Modules ({ lv_type_cnt })|
              WHEN 'ENQU' THEN |ENQU - Lock Objects ({ lv_type_cnt })|
              WHEN 'SHLP' THEN |SHLP - Search Helps ({ lv_type_cnt })|
              WHEN 'TTYP' THEN |TTYP - Table Types ({ lv_type_cnt })|
              WHEN 'STOB' THEN |STOB - Storage BOs ({ lv_type_cnt })|
              WHEN 'TRAN' THEN |TRAN - Transactions ({ lv_type_cnt })|
              WHEN 'IASC' THEN |IASC - Incl. ABAP Sources ({ lv_type_cnt })|
              WHEN 'INTF' THEN |INTF - Interfaces ({ lv_type_cnt })|
              WHEN 'MSAG' THEN |MSAG - Messages ({ lv_type_cnt })|
              WHEN 'REPS' THEN |REPS - Include Programs ({ lv_type_cnt })|
              WHEN 'DYNP' THEN |DYNP - Screens ({ lv_type_cnt })|
              WHEN 'CUAD' THEN |CUAD - GUI Downloads ({ lv_type_cnt })|
              WHEN 'DREF' THEN |DREF - Docu References ({ lv_type_cnt })|
              WHEN 'XSLT' THEN |XSLT - XSL Transformations ({ lv_type_cnt })|
              WHEN 'SMOD' THEN |SMOD - Enhancements ({ lv_type_cnt })|
              WHEN 'SXSD' THEN |SXSD - BDS Schemas ({ lv_type_cnt })|
              WHEN 'STCP' THEN |STCP - BDS Instances ({ lv_type_cnt })|
              WHEN 'DOCV' THEN |DOCV - Documentation ({ lv_type_cnt })|
              ELSE |{ ls_obj-object } ({ lv_type_cnt })|
            ).

            CLEAR ls_empty.
            ls_empty-object = ls_obj-object.
            lo_node = lo_nodes->add_node(
              related_node = lv_pkg_key
              relationship  = if_salv_c_node_relation=>last_child
              data_row      = ls_empty
            ).
            lo_node->set_text( CONV lvc_value( lv_type_label ) ).
            lo_node->set_expander( abap_true ).
            lv_type_key = lo_node->get_key( ).
          ENDIF.

          " Level 4: Object leaf
          lo_node = lo_nodes->add_node(
            related_node = lv_type_key
            relationship  = if_salv_c_node_relation=>last_child
            data_row      = ls_obj
          ).
          lo_node->set_text( CONV #( ls_obj-obj_name ) ).

          " Leaf: editable checkbox
          lo_item = lo_node->get_hierarchy_item( ).
          lo_item->set_type( if_salv_c_item_type=>checkbox ).
          lo_item->set_editable( abap_true ).

          CLEAR ls_node_map.
          ls_node_map-node_key = lo_node->get_key( ).
          ls_node_map-obj_name = ls_obj-obj_name.
          ls_node_map-obj_type = ls_obj-object.
          APPEND ls_node_map TO mt_node_keys.

          " Store node info for context menu lookup
          CLEAR ls_node_info.
          ls_node_info-node_key = ls_node_map-node_key.
          ls_node_info-level    = '4'.
          ls_node_info-obj_name = ls_obj-obj_name.
          ls_node_info-obj_type = ls_obj-object.
          ls_node_info-devclass = ls_obj-devclass.
          APPEND ls_node_info TO mt_node_info.

        ENDLOOP.

        lo_nodes->expand_all( ).

      CATCH cx_salv_not_found cx_salv_msg.
        MESSAGE 'Tree node build failed.' TYPE 'W'.
        RETURN.
    ENDTRY.

    " Register standard SALV event handlers
    lo_evt = mo_tree->get_event( ).
    SET HANDLER me->on_double_click         FOR lo_evt.
    SET HANDLER me->on_checkbox_change      FOR lo_evt.
    SET HANDLER me->on_added_function       FOR lo_evt.

    mo_tree->display( ).
  ENDMETHOD.

  METHOD on_double_click.
    DATA: ls_node TYPE lty_node_map,
          ls_obj  TYPE zscort_s_object.

    " Only handle OBJ_NAME column on object leaves
    CHECK columnname = 'OBJ_NAME'.

    " Find node in our map (only object leaves are registered)
    READ TABLE mt_node_keys INTO ls_node
      WITH KEY node_key = CONV lvc_nkey( node_key ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Load full object data
    READ TABLE mt_objects INTO ls_obj
      WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Open object in SE38/SE24/SE11... via RS_TOOL_ACCESS
    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation   = 'SHOW'
        object_name = ls_obj-obj_name
        object_type = ls_obj-object
        devclass    = ls_obj-devclass
      EXCEPTIONS
        not_executed = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      CALL TRANSACTION 'SE80'.
    ENDIF.
  ENDMETHOD.

  METHOD on_checkbox_change.
    DATA: lv_k   TYPE lvc_nkey,
          ls_key TYPE lty_node_map.

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

  METHOD on_added_function.
    DATA: ls_node TYPE lty_node_map,
          ls_obj  TYPE zscort_s_object.

    CASE e_salv_function.

      WHEN 'REFRESH'.
        LEAVE TO TRANSACTION sy-tcode.

      WHEN 'VIEW_DETAIL'.
        READ TABLE mt_node_keys INTO ls_node INDEX 1.
        IF sy-subrc = 0.
          READ TABLE mt_objects INTO ls_obj
            WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
          IF ls_obj IS NOT INITIAL.
            show_detail_popup( ls_obj ).
          ENDIF.
        ENDIF.

      WHEN 'OPEN_SE80'.
        READ TABLE mt_node_keys INTO ls_node INDEX 1.
        IF sy-subrc = 0.
          READ TABLE mt_objects INTO ls_obj
            WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
          IF ls_obj IS NOT INITIAL.
            CALL FUNCTION 'RS_TOOL_ACCESS'
              EXPORTING operation   = 'SHOW'
                        object_name = ls_obj-obj_name
                        object_type = ls_obj-object
                        devclass    = ls_obj-devclass
              EXCEPTIONS not_executed = 1 OTHERS = 2.
            IF sy-subrc <> 0.
              CALL TRANSACTION 'SE80'.
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'CHG_OWNER' OR 'CHG_OWNER_CTX'.
        READ TABLE mt_node_keys INTO ls_node INDEX 1.
        IF sy-subrc = 0.
          READ TABLE mt_objects INTO ls_obj
            WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
          IF ls_obj IS NOT INITIAL.
            do_change_owner_single( ls_obj ).
          ENDIF.
        ENDIF.

      WHEN 'CHG_PKG' OR 'CHG_PKG_CTX'.
        READ TABLE mt_node_keys INTO ls_node INDEX 1.
        IF sy-subrc = 0.
          READ TABLE mt_objects INTO ls_obj
            WITH KEY obj_name = ls_node-obj_name object = ls_node-obj_type.
          IF ls_obj IS NOT INITIAL.
            do_change_package_single( ls_obj ).
          ENDIF.
        ENDIF.

      WHEN OTHERS.
        IF mt_checked IS NOT INITIAL.
          READ TABLE mt_checked INTO DATA(ls_first) INDEX 1.
          READ TABLE mt_objects INTO ls_obj
            WITH KEY obj_name = ls_first-obj_name object = ls_first-obj_type.
          CASE e_salv_function.
            WHEN 'CHG_OWNER'.
              do_change_owner_single( ls_obj ).
            WHEN 'CHG_PKG'.
              do_change_package_single( ls_obj ).
            WHEN 'OPEN_SE80'.
              CALL FUNCTION 'RS_TOOL_ACCESS'
                EXPORTING operation   = 'SHOW'
                          object_name = ls_obj-obj_name
                          object_type = ls_obj-object
                          devclass    = ls_obj-devclass
                EXCEPTIONS not_executed = 1 OTHERS = 2.
              IF sy-subrc <> 0.
                CALL TRANSACTION 'SE80'.
              ENDIF.
          ENDCASE.
        ELSE.
          MESSAGE 'Please select an object first.' TYPE 'S' DISPLAY LIKE 'W'.
        ENDIF.

    ENDCASE.
  ENDMETHOD.

  METHOD show_detail_popup.
    TYPES: BEGIN OF lty_row,
             field_label TYPE string,
             field_value TYPE string,
           END OF lty_row.
    DATA: lt_display TYPE TABLE OF lty_row,
          ls_row     TYPE lty_row,
          lo_popup   TYPE REF TO cl_salv_table,
          lo_cols    TYPE REF TO cl_salv_columns,
          lo_detail  TYPE zscort_s_obj_detail.

    " Fetch extended detail from repository
    mo_reader->get_object_detail(
      EXPORTING iv_obj_name = is_object-obj_name
                iv_obj_type = is_object-object
      IMPORTING es_detail   = lo_detail
    ).

    " Build display rows
    ls_row-field_label = 'Object Name'. ls_row-field_value = is_object-obj_name.  APPEND ls_row TO lt_display.
    ls_row-field_label = 'Object Type'. ls_row-field_value = is_object-object.   APPEND ls_row TO lt_display.
    IF lo_detail-object_type_desc IS NOT INITIAL.
      ls_row-field_label = 'Type Description'. ls_row-field_value = lo_detail-object_type_desc. APPEND ls_row TO lt_display.
    ENDIF.
    ls_row-field_label = 'Package'.       ls_row-field_value = is_object-devclass.  APPEND ls_row TO lt_display.
    ls_row-field_label = 'Author'.        ls_row-field_value = is_object-author.    APPEND ls_row TO lt_display.
    ls_row-field_label = 'Src System'.     ls_row-field_value = is_object-srcsystem. APPEND ls_row TO lt_display.
    ls_row-field_label = 'Version'.       ls_row-field_value = is_object-versno.    APPEND ls_row TO lt_display.
    IF lo_detail-created_date IS NOT INITIAL.
      ls_row-field_label = 'Created On'.   ls_row-field_value = |{ lo_detail-created_date DATE = USER }|.
      APPEND ls_row TO lt_display.
    ENDIF.
    IF lo_detail-description IS NOT INITIAL.
      ls_row-field_label = 'Description'. ls_row-field_value = lo_detail-description. APPEND ls_row TO lt_display.
    ENDIF.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_popup
          CHANGING  t_table      = lt_display
        ).
      CATCH cx_salv_msg.
        RETURN.
    ENDTRY.

    lo_popup->get_display_settings( )->set_list_header(
      |Object Detail: { is_object-obj_name }|
    ).
    lo_popup->get_functions( )->set_all( abap_false ).

    lo_cols = lo_popup->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        lo_cols->get_column( 'FIELD_LABEL' )->set_medium_text( 'Field' ).
        lo_cols->get_column( 'FIELD_VALUE' )->set_medium_text( 'Value' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    lo_popup->display( ).
  ENDMETHOD.

  METHOD do_change_owner_single.
    DATA: lt_fields  TYPE TABLE OF sval,
          ls_field   TYPE sval,
          lv_retcode TYPE char1,
          lv_owner   TYPE author.

    ls_field-tabname   = 'TADIR'.
    ls_field-fieldname = 'AUTHOR'.
    ls_field-fieldtext = 'New Owner (user ID)'.
    ls_field-value     = is_object-author.
    APPEND ls_field TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING popup_title = |Change Owner: { is_object-obj_name }|
      IMPORTING returncode = lv_retcode TABLES fields = lt_fields EXCEPTIONS OTHERS = 1.

    IF sy-subrc <> 0 OR lv_retcode = 'A'. RETURN. ENDIF.

    READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'AUTHOR'.
    lv_owner = ls_field-value.

    IF lv_owner IS INITIAL.
      MESSAGE 'Owner cannot be empty.' TYPE 'S' DISPLAY LIKE 'W'. RETURN.
    ENDIF.

    TRY.
        mo_mutator->change_object_owner(
          iv_obj_name  = is_object-obj_name
          iv_obj_type  = is_object-object
          iv_new_owner = lv_owner ).
        MESSAGE |Owner changed for { is_object-obj_name }. Please REFRESH (F8) to see updates.| TYPE 'S'.
      CATCH zcx_scort_exception INTO DATA(lo_ex_own).
        MESSAGE lo_ex_own->mv_error_text TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD do_change_package_single.
    DATA: lt_fields  TYPE TABLE OF sval,
          ls_field   TYPE sval,
          lv_retcode TYPE char1,
          lv_pkg     TYPE devclass.

    ls_field-tabname   = 'TADIR'.
    ls_field-fieldname = 'DEVCLASS'.
    ls_field-fieldtext = 'New Package (DEVCLASS)'.
    ls_field-value     = is_object-devclass.
    APPEND ls_field TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING popup_title = |Change Package: { is_object-obj_name }|
      IMPORTING returncode = lv_retcode TABLES fields = lt_fields EXCEPTIONS OTHERS = 1.

    IF sy-subrc <> 0 OR lv_retcode = 'A'. RETURN. ENDIF.

    READ TABLE lt_fields INTO ls_field WITH KEY fieldname = 'DEVCLASS'.
    lv_pkg = ls_field-value.

    IF lv_pkg IS INITIAL.
      MESSAGE 'Package cannot be empty.' TYPE 'S' DISPLAY LIKE 'W'. RETURN.
    ENDIF.

    TRY.
        mo_mutator->change_object_package(
          iv_obj_name     = is_object-obj_name
          iv_obj_type     = is_object-object
          iv_new_devclass = lv_pkg ).
        MESSAGE |Package changed for { is_object-obj_name }. Please REFRESH (F8) to see updates.| TYPE 'S'.
      CATCH zcx_scort_exception INTO DATA(lo_ex_pkg).
        MESSAGE lo_ex_pkg->mv_error_text TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
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

ENDCLASS.

*&---------------------------------------------------------------------*
*& TEXT SYMBOLS
*&---------------------------------------------------------------------*
" TEXT-b01 = 'Owner (Person Responsible)'.
" TEXT-b02 = 'Package (optional)'.
" TEXT-b03 = 'Object Name Filter'.
" TEXT-c01 = 'All object types from TADIR are included. Use Object Name for substring search. Use Owner as Level 1 root.'.
