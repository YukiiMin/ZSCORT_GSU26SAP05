*  &---------------------------------------------------------------------*
*  & Report: REPORT ZSCORT_MAIN.
*  & Title  : SCORT - Repository Object Manager (v2 - REQ1 Enhancement)
*  & Author : DEV-032 | Package : ZSCORT_GSU26SAP05
*  & Date   : 2026-06-29
*  & Desc   : Main entry point for SCORT system - Requirement 1
*  &          Displays Repository Objects from TADIR with filter and ALV
*  &          v2: + TR Search | + Change Package | + Change Owner | + SE03   Tools
*  & Pattern : OO-ABAP MVC (Controller Pattern)
*  &   Model      : ZCL_SCORT_REPOSITORY_032 (Global Class - SE24)
*  &   View       : CL_SALV_TABLE + Selection Screen
*  &   Controller : LCL_CONTROLLER (Local Class - no FORM/PERFORM)
*  &---------------------------------------------------------------------*
  REPORT zscort_main.

*  --------------------------------------------------------------------*
*   SECTION 1: SELECTION SCREEN DEFINITION - View Layer
*  --------------------------------------------------------------------*
  DATA:
    gv_objnam TYPE tadir-obj_name,
    gv_objtyp TYPE tadir-object,
    gv_devcla TYPE tadir-devclass,
    gv_author TYPE tadir-author,
    gv_trkorr TYPE trkorr,
    gv_trownr TYPE as4user.

  " === Block 1: Search by Object Properties ===
  SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
    SELECT-OPTIONS:
      s_objnam FOR gv_objnam NO INTERVALS,
      s_objtyp FOR gv_objtyp,
      s_devcla FOR gv_devcla,
      s_author FOR gv_author.
  SELECTION-SCREEN END OF BLOCK b1.

  " === Block 2: Search by Transport Request (NEW v2) ===
  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
    SELECT-OPTIONS:
      s_trkorr FOR gv_trkorr,
      s_trownr FOR gv_trownr.
  SELECTION-SCREEN END OF BLOCK b2.

  " === Block 3: Display Options ===
  SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
    PARAMETERS p_max TYPE i DEFAULT 1000.
  SELECTION-SCREEN END OF BLOCK b3.

  SELECTION-SCREEN COMMENT /1(79) TEXT-c01.

*  --------------------------------------------------------------------*
*   SECTION 2: LOCAL CLASS DEFINITIONS (Controller)
*  --------------------------------------------------------------------*
  CLASS lcl_controller DEFINITION FINAL.
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
      DATA:
        mo_repo        TYPE REF TO zcl_scort_repository_032,
        mo_alv         TYPE REF TO cl_salv_table,
        mt_objects     TYPE zscort_t_objects,
        mt_tr_objects  TYPE zscort_t_tr_objects,
        mt_statistics  TYPE zscort_t_statistics,
        mv_total_count TYPE i,
        mv_search_mode TYPE string.

      METHODS:
        fetch_data,
        display_alv,
        display_tr_alv,
        configure_columns,
        configure_tr_columns
          IMPORTING io_alv TYPE REF TO cl_salv_table,
        add_toolbar_buttons,
        show_detail_popup
          IMPORTING is_detail TYPE zscort_s_obj_detail,
        do_change_package
          IMPORTING is_object TYPE zscort_s_object,
        do_change_owner
          IMPORTING is_object TYPE zscort_s_object.
  ENDCLASS.

*  --------------------------------------------------------------------*
*   SECTION 3: GLOBAL VARIABLE
*  --------------------------------------------------------------------*
  DATA: go_controller TYPE REF TO lcl_controller.

*  --------------------------------------------------------------------*
*   SECTION 4: SAP EVENTS
*  --------------------------------------------------------------------*
  INITIALIZATION.
    s_objnam-sign = 'I'.
    s_objnam-option = 'CP'.
    s_objnam-low = 'Z*'.
    APPEND s_objnam.
    s_devcla-sign = 'I'.
    s_devcla-option = 'CP'.
    s_devcla-low = 'Z*'.
    APPEND s_devcla.
    CREATE OBJECT go_controller.
    go_controller->initialize( ).

  START-OF-SELECTION.
    go_controller->run( ).

*  --------------------------------------------------------------------*
*   SECTION 5: LOCAL CLASS IMPLEMENTATIONS (Controller)
*  --------------------------------------------------------------------*
  CLASS lcl_controller IMPLEMENTATION.

    METHOD initialize.
      CREATE OBJECT mo_repo.
    ENDMETHOD.

    METHOD run.
      fetch_data( ).
      IF mv_search_mode = 'TR'.
        display_tr_alv( ).
      ELSE.
        display_alv( ).
      ENDIF.
    ENDMETHOD.

    METHOD fetch_data.
      CLEAR: mt_objects, mt_tr_objects, mt_statistics, mv_total_count.

      IF s_trkorr[] IS NOT INITIAL OR s_trownr[] IS NOT INITIAL.
        mv_search_mode = 'TR'.

        TRY.
            mo_repo->get_objects_by_tr(
              EXPORTING
                it_tr_number  = s_trkorr[]
                it_tr_owner   = s_trownr[]
                it_obj_type   = s_objtyp[]
              IMPORTING
                et_tr_objects = mt_tr_objects
            ).
          CATCH cx_root.
            CLEAR mt_tr_objects.
        ENDTRY.

        mv_total_count = lines( mt_tr_objects ).

      ELSE.
        mv_search_mode = 'OBJ'.

        TRY.
            mo_repo->get_statistics(
              EXPORTING
                it_devclass   = s_devcla[]
                it_author     = s_author[]
              IMPORTING
                et_statistics = mt_statistics
            ).
          CATCH cx_root.
            CLEAR mt_statistics.
        ENDTRY.

        TRY.
            mo_repo->get_objects(
              EXPORTING
                it_obj_name = s_objnam[]
                it_obj_type = s_objtyp[]
                it_devclass = s_devcla[]
                it_author   = s_author[]
              IMPORTING
                et_objects  = mt_objects
            ).
          CATCH cx_root.
            CLEAR mt_objects.
        ENDTRY.

        mv_total_count = lines( mt_objects ).
      ENDIF.

      IF mv_total_count > p_max.
        IF mv_search_mode = 'TR'.
          DELETE mt_tr_objects FROM p_max + 1.
        ELSE.
          DELETE mt_objects FROM p_max + 1.
        ENDIF.
        MESSAGE |Found { mv_total_count } objects. Display limited to {   p_max } hits.| TYPE 'S' DISPLAY LIKE 'W'.
      ELSEIF mv_total_count > 0.
        MESSAGE |Found { mv_total_count } objects.| TYPE 'S'.
      ELSE.
        MESSAGE 'No objects found matching your search criteria.' TYPE 'S'   DISPLAY LIKE 'W'.
      ENDIF.
    ENDMETHOD.

    METHOD display_alv.
      DATA: lo_display TYPE REF TO cl_salv_display_settings,
            lo_sorts   TYPE REF TO cl_salv_sorts,
            lv_h1      TYPE string,
            lv_h2      TYPE string,
            lv_header  TYPE lvc_title.

      " Build header as ONE single string
      lv_h1 = 'SCORT - Repository Object Manager'.
      lv_h2 = mv_total_count.
      CONCATENATE lv_h1 ' - ' lv_h2 ' hits' INTO lv_header SEPARATED BY ' '.

      TRY.
          cl_salv_table=>factory(
            IMPORTING r_salv_table = mo_alv
            CHANGING  t_table      = mt_objects
          ).
        CATCH cx_salv_msg INTO DATA(lx_salv).
          MESSAGE lx_salv->get_text( ) TYPE 'E'.
          RETURN.
      ENDTRY.

      mo_alv->get_functions( )->set_all( abap_true ).

      lo_display = mo_alv->get_display_settings( ).
      lo_display->set_list_header( lv_header ).
      lo_display->set_list_header_size(   cl_salv_display_settings=>c_header_size_large ).
      lo_display->set_striped_pattern( abap_true ).

      configure_columns( ).
      add_toolbar_buttons( ).

      lo_sorts = mo_alv->get_sorts( ).
      TRY.
          lo_sorts->add_sort( columnname = 'OBJ_NAME' ).
        CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
          " ignore
      ENDTRY.

      SET HANDLER me->on_double_click FOR mo_alv->get_event( ).
      SET HANDLER me->on_user_command FOR mo_alv->get_event( ).

      mo_alv->display( ).
    ENDMETHOD.

    METHOD display_tr_alv.
      DATA: lo_tr_alv TYPE REF TO cl_salv_table,
            lo_sorts  TYPE REF TO cl_salv_sorts,
            lv_h1     TYPE string,
            lv_h2     TYPE string,
            lv_header TYPE lvc_title.

      lv_h1 = 'TR Search Results'.
      lv_h2 = mv_total_count.
      CONCATENATE lv_h1 '-' lv_h2 'objects found - DEV-032 SCORT'
        INTO lv_header SEPARATED BY ' '.

      TRY.
          cl_salv_table=>factory(
            IMPORTING r_salv_table = lo_tr_alv
            CHANGING  t_table      = mt_tr_objects
          ).
        CATCH cx_salv_msg INTO DATA(lx_msg).
          MESSAGE lx_msg->get_text( ) TYPE 'E'.
          RETURN.
      ENDTRY.

      lo_tr_alv->get_display_settings( )->set_list_header( lv_header ).
      lo_tr_alv->get_display_settings( )->set_list_header_size(
        cl_salv_display_settings=>c_header_size_large ).
      lo_tr_alv->get_display_settings( )->set_striped_pattern( abap_true ).
      lo_tr_alv->get_functions( )->set_all( abap_true ).

      configure_tr_columns( lo_tr_alv ).

      lo_sorts = lo_tr_alv->get_sorts( ).
      TRY.
          lo_sorts->add_sort( columnname = 'TRKORR'  subtotal = abap_true ).
          lo_sorts->add_sort( columnname = 'OBJECT' ).
        CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
          " ignore
      ENDTRY.

      lo_tr_alv->display( ).
    ENDMETHOD.

    METHOD configure_tr_columns.
      DATA(lo_cols_tr) = io_alv->get_columns( ).
      lo_cols_tr->set_optimize( abap_true ).

      TRY.
          lo_cols_tr->get_column( 'TRKORR'        )->set_medium_text( 'TR   Number' ).
          lo_cols_tr->get_column( 'TR_DESC'       )->set_medium_text(   'Description' ).
          lo_cols_tr->get_column( 'TR_STATUS'     )->set_medium_text(   'Status Code' ).
          lo_cols_tr->get_column( 'TR_STATUS_DESC')->set_medium_text(   'Status' ).
          lo_cols_tr->get_column( 'TR_OWNER'      )->set_medium_text( 'TR   Owner' ).
          lo_cols_tr->get_column( 'PGMID'         )->set_visible( abap_false   ).
          lo_cols_tr->get_column( 'OBJECT'        )->set_medium_text( 'Type'   ).
          lo_cols_tr->get_column( 'OBJ_NAME'      )->set_medium_text(   'Object Name' ).
          lo_cols_tr->get_column( 'DEVCLASS'      )->set_medium_text(   'Package' ).
          lo_cols_tr->get_column( 'AUTHOR'        )->set_medium_text( 'Obj.   Author' ).
        CATCH cx_salv_not_found.
          " ignore
      ENDTRY.
    ENDMETHOD.

    METHOD configure_columns.
      DATA(lo_columns) = mo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      TRY.
          DATA(lo_col) = lo_columns->get_column( 'OBJ_NAME' ).
          lo_col->set_medium_text( 'Object Name' ).
          lo_col->set_long_text(   'Repository Object Name' ).
          lo_col->set_output_length( 40 ).

          lo_col = lo_columns->get_column( 'OBJECT' ).
          lo_col->set_medium_text( 'Type' ).
          lo_col->set_long_text(   'Object Type (TADIR)' ).
          lo_col->set_output_length( 8 ).

          lo_col = lo_columns->get_column( 'DEVCLASS' ).
          lo_col->set_medium_text( 'Package' ).
          lo_col->set_long_text(   'Development Package' ).
          lo_col->set_output_length( 20 ).

          lo_col = lo_columns->get_column( 'AUTHOR' ).
          lo_col->set_medium_text( 'Author' ).
          lo_col->set_long_text(   'Created By (Author)' ).
          lo_col->set_output_length( 12 ).

          lo_col = lo_columns->get_column( 'SRCSYSTEM' ).
          lo_col->set_medium_text( 'Src System' ).
          lo_col->set_long_text(   'Source System' ).
          lo_col->set_output_length( 10 ).

          lo_col = lo_columns->get_column( 'VERSNO' ).
          lo_col->set_medium_text( 'Version' ).
          lo_col->set_long_text(   'Version Identifier (VERSID)' ).
          lo_col->set_output_length( 12 ).

        CATCH cx_salv_not_found.
          " ignore
      ENDTRY.
    ENDMETHOD.

    METHOD add_toolbar_buttons.
      DATA(lo_functions) = mo_alv->get_functions( ).

      TRY.
          lo_functions->add_function(
            name     = 'REFRESH'
            icon     = '@3I@'
            text     = 'Refresh'
            tooltip  = 'Re-fetch object list from TADIR'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_existing cx_salv_wrong_call   cx_salv_method_not_supported.
      ENDTRY.

      TRY.
          lo_functions->add_function(
            name     = 'GOTO_SE80'
            icon     = '@0Q@'
            text     = 'Open in SE80'
            tooltip  = 'Navigate to selected object in SE80 Object Navigator'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_existing cx_salv_wrong_call   cx_salv_method_not_supported.
      ENDTRY.

      TRY.
          lo_functions->add_function(
            name     = 'CHANGE_PKG'
            icon     = '@BW@'
            text     = 'Change Package'
            tooltip  = 'Move selected object to a different Development   Package'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_existing cx_salv_wrong_call   cx_salv_method_not_supported.
      ENDTRY.

      TRY.
          lo_functions->add_function(
            name     = 'CHANGE_OWN'
            icon     = '@IO@'
            text     = 'Change Owner'
            tooltip  = 'Transfer ownership (AUTHOR) of selected object'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_existing cx_salv_wrong_call   cx_salv_method_not_supported.
      ENDTRY.

      TRY.
          lo_functions->add_function(
            name     = 'GOTO_SE03'
            icon     = '@IM@'
            text     = 'SE03 Tools'
            tooltip  = 'Open SE03 Transport Organizer Tools'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_existing cx_salv_wrong_call   cx_salv_method_not_supported.
      ENDTRY.
    ENDMETHOD.

    METHOD on_double_click.
      IF row = 0.
        RETURN.
      ENDIF.

      TRY.
          DATA(ls_object) = mt_objects[ row ].
        CATCH cx_sy_itab_line_not_found.
          MESSAGE 'Row data not found.' TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.

      DATA: ls_detail TYPE zscort_s_obj_detail.
      TRY.
          mo_repo->get_object_detail(
            EXPORTING
              iv_obj_name = ls_object-obj_name
              iv_obj_type = ls_object-object
            IMPORTING
              es_detail   = ls_detail
          ).
        CATCH cx_root.
          CLEAR ls_detail.
      ENDTRY.

      show_detail_popup( ls_detail ).
    ENDMETHOD.

    METHOD on_user_command.
      DATA: lo_selections  TYPE REF TO cl_salv_selections,
            ls_cell        TYPE salv_s_cell,
            ls_sel_object  TYPE zscort_s_object,
            ls_obj_pkg     TYPE zscort_s_object,
            ls_obj_own     TYPE zscort_s_object.

      CASE e_salv_function.

        WHEN 'REFRESH'.
          fetch_data( ).
          mo_alv->refresh( ).
          MESSAGE |{ lines( mt_objects ) } objects refreshed.| TYPE 'S'.

        WHEN 'GOTO_SE80'.
          lo_selections = mo_alv->get_selections( ).
          ls_cell       = lo_selections->get_current_cell( ).

          IF ls_cell-row = 0.
            MESSAGE 'Please select a row first.' TYPE 'S' DISPLAY LIKE 'W'.
            RETURN.
          ENDIF.

          TRY.
              ls_sel_object = mt_objects[ ls_cell-row ].
            CATCH cx_sy_itab_line_not_found.
              RETURN.
          ENDTRY.

          CALL FUNCTION 'RS_TOOL_ACCESS'
            EXPORTING
              operation    = 'SHOW'
              object_name  = ls_sel_object-obj_name
              object_type  = ls_sel_object-object
              devclass     = ls_sel_object-devclass
            EXCEPTIONS
              not_executed = 1
              OTHERS       = 2.

          IF sy-subrc <> 0.
            CALL TRANSACTION 'SE80'.
          ENDIF.

        WHEN 'CHANGE_PKG'.
          lo_selections = mo_alv->get_selections( ).
          ls_cell       = lo_selections->get_current_cell( ).
          IF ls_cell-row = 0.
            MESSAGE 'Please select an object row first.' TYPE 'S' DISPLAY   LIKE 'W'.
            RETURN.
          ENDIF.
          TRY.
              ls_obj_pkg = mt_objects[ ls_cell-row ].
            CATCH cx_sy_itab_line_not_found.
              RETURN.
          ENDTRY.
          do_change_package( ls_obj_pkg ).

        WHEN 'CHANGE_OWN'.
          lo_selections = mo_alv->get_selections( ).
          ls_cell       = lo_selections->get_current_cell( ).
          IF ls_cell-row = 0.
            MESSAGE 'Please select an object row first.' TYPE 'S' DISPLAY   LIKE 'W'.
            RETURN.
          ENDIF.
          TRY.
              ls_obj_own = mt_objects[ ls_cell-row ].
            CATCH cx_sy_itab_line_not_found.
              RETURN.
          ENDTRY.
          do_change_owner( ls_obj_own ).

        WHEN 'GOTO_SE03'.
          CALL TRANSACTION 'SE03'.

        WHEN OTHERS.
          " ignore

      ENDCASE.
    ENDMETHOD.

    METHOD show_detail_popup.
      TYPES: BEGIN OF lty_row,
               field_label TYPE string,
               field_value TYPE string,
             END OF lty_row.

      DATA: lt_display     TYPE TABLE OF lty_row,
            lo_popup_alv   TYPE REF TO cl_salv_table,
            lt_popup_text  TYPE TABLE OF tline,
            ls_line        TYPE tline,
            lo_cols        TYPE REF TO cl_salv_columns_table.

      lt_display = VALUE #(
        ( field_label = 'Object Name'   field_value = is_detail-obj_name )
        ( field_label = 'Object Type'   field_value = is_detail-object )
        ( field_label = 'Type Desc.'    field_value =   is_detail-object_type_desc )
        ( field_label = 'Package'       field_value = is_detail-devclass )
        ( field_label = 'Author'        field_value = is_detail-author )
        ( field_label = 'Created Date'  field_value = is_detail-created_date )
        ( field_label = 'Version ID'    field_value = is_detail-versno )
        ( field_label = 'Source System' field_value = is_detail-srcsystem )
        ( field_label = 'Description'   field_value = is_detail-description )
      ).

      TRY.
          cl_salv_table=>factory(
            IMPORTING r_salv_table = lo_popup_alv
            CHANGING  t_table      = lt_display
          ).
        CATCH cx_salv_msg.
          ls_line-tdformat = '/'.
          ls_line-tdline   = |Object: { is_detail-obj_name } ({   is_detail-object }) Pkg: { is_detail-devclass }|.
          APPEND ls_line TO lt_popup_text.
          CALL FUNCTION 'POPUP_TO_DISPLAY_TEXT'
            EXPORTING titel    = 'SCORT - Object Detail'
            TABLES    text_tab = lt_popup_text.
          RETURN.
      ENDTRY.

      lo_popup_alv->get_display_settings( )->set_list_header( |SCORT Detail:   { is_detail-obj_name }| ).
      lo_popup_alv->get_functions( )->set_all( abap_false ).
      lo_cols = lo_popup_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      TRY.
          lo_cols->get_column( 'FIELD_LABEL' )->set_medium_text( 'Field' ).
          lo_cols->get_column( 'FIELD_VALUE' )->set_medium_text( 'Value' ).
        CATCH cx_salv_not_found.
          " ignore
      ENDTRY.

      lo_popup_alv->display( ).
    ENDMETHOD.

    METHOD do_change_package.
      DATA:
        lt_fields    TYPE TABLE OF sval,
        lv_new_pkg   TYPE devclass,
        ls_field     TYPE sval,
        lv_retcode   TYPE char1,
        lv_ok        TYPE abap_bool.

      lt_fields = VALUE #(
        ( tabname   = 'TADIR'
          fieldname = 'DEVCLASS'
          fieldtext = 'New Package'
          value     = is_object-devclass )
      ).

      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title = |Change Package - { is_object-obj_name }|
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
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      lv_new_pkg = ls_field-value.

      IF lv_new_pkg IS INITIAL OR lv_new_pkg = is_object-devclass.
        RETURN.
      ENDIF.

      TRY.
          lv_ok = mo_repo->change_object_package(
            iv_obj_name     = is_object-obj_name
            iv_obj_type     = is_object-object
            iv_new_devclass = lv_new_pkg
          ).
        CATCH cx_root.
          lv_ok = abap_false.
      ENDTRY.

      IF lv_ok = abap_true.
        MESSAGE |{ is_object-obj_name }: Package changed to { lv_new_pkg }   successfully.| TYPE 'S'.
        fetch_data( ).
        mo_alv->refresh( ).
      ELSE.
        MESSAGE 'Failed to change package. Check package name or   authorization.' TYPE 'E'.
      ENDIF.
    ENDMETHOD.

    METHOD do_change_owner.
      DATA:
        lt_fields    TYPE TABLE OF sval,
        lv_new_own   TYPE author,
        ls_field     TYPE sval,
        lv_retcode   TYPE char1,
        lv_ok        TYPE abap_bool.

      lt_fields = VALUE #(
        ( tabname   = 'TADIR'
          fieldname = 'AUTHOR'
          fieldtext = 'New Owner'
          value     = is_object-author )
      ).

      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title = |Change Owner - { is_object-obj_name }|
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
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      lv_new_own = ls_field-value.

      IF lv_new_own IS INITIAL OR lv_new_own = is_object-author.
        RETURN.
      ENDIF.

      TRY.
          lv_ok = mo_repo->change_object_owner(
            iv_obj_name  = is_object-obj_name
            iv_obj_type  = is_object-object
            iv_new_owner = lv_new_own
          ).
        CATCH cx_root.
          lv_ok = abap_false.
      ENDTRY.

      IF lv_ok = abap_true.
        MESSAGE |{ is_object-obj_name }: Owner changed to { lv_new_own }   successfully.| TYPE 'S'.
      fetch_data( ).
      mo_alv->refresh( ).
    ELSE.
      MESSAGE 'Failed to change owner. Check user ID or authorization.' TYPE 'E'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
