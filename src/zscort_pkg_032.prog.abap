*&---------------------------------------------------------------------*
*& Report : ZSCORT_PKG_032
*& Title  : SCORT - Package Explorer
*& Author : DEV-032 | Package: ZSCORT_GSU26SAP05
*& Date   : 2026-06-29
*& Desc   : Browse package contents — view all objects grouped by type.
*&          Dùng CL_SALV_TABLE với sort + subtotal thay vì CL_SALV_TREE
*&          (không cần Dynpro, phù hợp thesis timeline)
*& Pattern: OO-ABAP MVC
*&---------------------------------------------------------------------*
REPORT ZSCORT_PKG_032
    NO STANDARD PAGE HEADING.

*&=====================================================================*
*& SECTION 1: SELECTION SCREEN — View Layer
*&=====================================================================*
DATA: gv_devcla TYPE tadir-devclass.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS s_devcla FOR gv_devcla OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

*&=====================================================================*
*& SECTION 2: LOCAL CLASS DEFINITION — Controller
*&=====================================================================*
CLASS lcl_pkg_controller DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS:
      initialize,
      run,
      on_double_click
        FOR EVENT double_click OF cl_salv_events_table
        IMPORTING row column,
      on_user_command
        FOR EVENT added_function OF cl_salv_events
        IMPORTING e_salv_function.

  PRIVATE SECTION.
    DATA: mo_repo    TYPE REF TO zcl_scort_repository_032,
          mo_alv     TYPE REF TO cl_salv_table,
          mt_objects TYPE zscort_t_objects.

    METHODS:
      fetch_data,
      display_alv,
      configure_columns,
      add_toolbar_buttons,
      show_detail_message
        IMPORTING is_object TYPE zscort_s_object.
ENDCLASS.

*&=====================================================================*
*& SECTION 3: GLOBAL VARIABLE
*&=====================================================================*
DATA: go_ctrl TYPE REF TO lcl_pkg_controller.

*&=====================================================================*
*& SECTION 4: SAP EVENTS
*&=====================================================================*

START-OF-SELECTION.
  CREATE OBJECT go_ctrl.
  go_ctrl->initialize( ).
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
    display_alv( ).
  ENDMETHOD.

  METHOD fetch_data.
    CLEAR mt_objects.

    LOOP AT s_devcla INTO DATA(ls_range).
      DATA lt_pkg_objects TYPE zscort_t_objects.
      CLEAR lt_pkg_objects.

      IF ls_range-option = 'EQ' OR ls_range-option = 'CP'.
        mo_repo->get_package_tree(
          EXPORTING iv_devclass = ls_range-low
          IMPORTING et_objects  = lt_pkg_objects
        ).
        APPEND LINES OF lt_pkg_objects TO mt_objects.
      ENDIF.
    ENDLOOP.

    " Fallback: nếu get_package_tree không trả kết quả → dùng get_objects
    IF mt_objects IS INITIAL.
      mo_repo->get_objects(
        EXPORTING it_devclass = s_devcla[]
        IMPORTING et_objects  = mt_objects
      ).
    ENDIF.

    " Sort: type trước → name (tạo visual grouping)
    SORT mt_objects BY object obj_name.

    DATA(lv_count) = lines( mt_objects ).
    IF lv_count = 0.
      MESSAGE 'No objects found in the specified package(s).' TYPE 'S' DISPLAY LIKE 'W'.
    ELSE.
      MESSAGE |Package Explorer: { lv_count } objects found.| TYPE 'S'.
    ENDIF.
  ENDMETHOD.

  METHOD display_alv.
    " Build header
    DATA: lt_type_set TYPE SORTED TABLE OF trobjtype WITH UNIQUE KEY table_line.
    LOOP AT mt_objects INTO DATA(ls_obj).
      INSERT ls_obj-object INTO TABLE lt_type_set.
    ENDLOOP.

    DATA lv_header TYPE lvc_title.
      lv_header = |Package Explorer - { lines( mt_objects ) } objects in { lines( lt_type_set ) } types - DEV-032 SCORT|.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = mo_alv
          CHANGING  t_table      = mt_objects
        ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    " Display settings
    DATA(lo_display) = mo_alv->get_display_settings( ).
    lo_display->set_list_header( lv_header ).
    lo_display->set_list_header_size(
      cl_salv_display_settings=>c_header_size_large
    ).
    lo_display->set_striped_pattern( abap_true ).

    " Toolbar
    mo_alv->get_functions( )->set_all( abap_true ).

    " Sort: type chính, name phụ → subtotal theo type
    DATA(lo_sorts) = mo_alv->get_sorts( ).
    TRY.
        lo_sorts->add_sort(
          columnname = 'OBJECT'
          subtotal   = abap_true
        ).
        lo_sorts->add_sort( columnname = 'OBJ_NAME' ).
      CATCH cx_salv_not_found
            cx_salv_existing
            cx_salv_data_error.
    ENDTRY.

    configure_columns( ).
    add_toolbar_buttons( ).

    SET HANDLER me->on_double_click FOR mo_alv->get_event( ).
    SET HANDLER me->on_user_command FOR mo_alv->get_event( ).

    mo_alv->display( ).
  ENDMETHOD.

  METHOD configure_columns.
    DATA(lo_cols) = mo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    TRY.
        DATA(lo_col) = lo_cols->get_column( 'OBJECT' ).
        lo_col->set_medium_text( 'Type' ).
        lo_col->set_long_text( 'Object Type' ).
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
  ENDMETHOD.

  METHOD add_toolbar_buttons.
    DATA(lo_func) = mo_alv->get_functions( ).
    TRY.
        lo_func->add_function(
          name     = 'OPEN_SE80'
          icon     = '@0Q@'
          text     = 'Open in SE80'
          tooltip  = 'Navigate to selected object in SE80 Object Navigator'
          position = if_salv_c_function_position=>right_of_salv_functions
        ).
      CATCH cx_salv_existing
            cx_salv_wrong_call
            cx_salv_method_not_supported.
    ENDTRY.
  ENDMETHOD.

  METHOD on_double_click.
    IF row = 0. RETURN. ENDIF.
    TRY.
        DATA(ls_obj) = mt_objects[ row ].
      CATCH cx_sy_itab_line_not_found.
        RETURN.
    ENDTRY.
    show_detail_message( ls_obj ).
  ENDMETHOD.

  METHOD on_user_command.
    CHECK e_salv_function = 'OPEN_SE80'.

    DATA(lo_sel) = mo_alv->get_selections( ).
    DATA(ls_cell) = lo_sel->get_current_cell( ).

    IF ls_cell-row = 0.
      MESSAGE 'Please select an object row first.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_sel_obj) = mt_objects[ ls_cell-row ].
      CATCH cx_sy_itab_line_not_found.
        RETURN.
    ENDTRY.

    " Mở object trong SE80
    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation   = 'SHOW'
        object_name = ls_sel_obj-obj_name
        object_type = ls_sel_obj-object
        devclass    = ls_sel_obj-devclass
      EXCEPTIONS
        not_executed = 1
        OTHERS       = 2.

    IF sy-subrc <> 0.
      " Fallback: mở SE80 nếu FM không hỗ trợ object type này
      CALL TRANSACTION 'SE80'.
    ENDIF.
  ENDMETHOD.

  METHOD show_detail_message.
    MESSAGE
      |{ is_object-object } \| { is_object-obj_name } \| Pkg: { is_object-devclass } \| Author: { is_object-author }|
      TYPE 'I'.
  ENDMETHOD.

ENDCLASS.
