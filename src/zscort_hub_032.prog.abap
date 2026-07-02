*&---------------------------------------------------------------------*
*& Report : ZSCORT_HUB_032
*& Title  : SCORT - Main Hub (Developer Workbench)
*& Author : DEV-032 | Package: ZSCORT_GSU26SAP05
*& Date   : 2026-06-29
*& Desc   : Entry point of SCORT system.
*&          SE03-style launcher - double-click navigates to sub-features.
*& Pattern: OO-ABAP MVC
*&   View      : CL_SALV_TABLE (Launcher grid)
*&   Controller: LCL_HUB_CONTROLLER (Local class)
*&---------------------------------------------------------------------*
REPORT ZSCORT_HUB_032
    NO STANDARD PAGE HEADING.

*&=====================================================================*
*& SECTION 1: TYPE DEFINITIONS
*&=====================================================================*
TYPES:
  BEGIN OF lty_hub_item,
    sortkey     TYPE i,
    category    TYPE string,
    title       TYPE string,
    description TYPE string,
    feature_id  TYPE string,
    status      TYPE string,
    req_label   TYPE string,
  END OF lty_hub_item.

*&=====================================================================*
*& SECTION 2: LOCAL CLASS DEFINITION
*&=====================================================================*
CLASS lcl_hub_controller DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS:
      run,
      on_double_click
        FOR EVENT double_click OF cl_salv_events_table
        IMPORTING row column.

  PRIVATE SECTION.
    DATA: mo_alv       TYPE REF TO cl_salv_table,
          mt_hub_items TYPE STANDARD TABLE OF lty_hub_item.

    METHODS:
      build_menu,
      display_hub,
      configure_columns,
      navigate_to
        IMPORTING iv_feature_id TYPE string.
ENDCLASS.

*&=====================================================================*
*& SECTION 3: GLOBAL VARIABLE
*&=====================================================================*
DATA: go_hub TYPE REF TO lcl_hub_controller.

*&=====================================================================*
*& SECTION 4: SAP EVENTS
*&=====================================================================*
START-OF-SELECTION.
  CREATE OBJECT go_hub.
  go_hub->run( ).

*&=====================================================================*
*& SECTION 5: CLASS IMPLEMENTATION
*&=====================================================================*
CLASS lcl_hub_controller IMPLEMENTATION.

  METHOD run.
    build_menu( ).
    display_hub( ).
  ENDMETHOD.

  METHOD build_menu.
*------------------------------------------------------------------*
* status = ACTIVE means clickable
* status = COMING_SOON means blocked
*------------------------------------------------------------------*
    mt_hub_items = VALUE #(
      ( sortkey = 10
        category    = 'Object Management'
        title       = 'Object Finder'
        description = 'Search repository objects by Package, Author, Type, or Transport Request'
        feature_id  = 'OBJ_FINDER'
        status      = 'ACTIVE'
        req_label   = 'REQ1' )

      ( sortkey = 20
        category    = 'Object Management'
        title       = 'Package Explorer'
        description = 'Browse package contents - view all objects grouped by type'
        feature_id  = 'PKG_EXPLORER'
        status      = 'ACTIVE'
        req_label   = 'REQ1' )

      ( sortkey = 30
        category    = 'Transport Management'
        title       = 'Transport Request Manager'
        description = '[REQ2] Create, browse and manage Transport Requests'
        feature_id  = 'TR_MANAGER'
        status      = 'COMING_SOON'
        req_label   = 'REQ2' )

      ( sortkey = 40
        category    = 'Transport Management'
        title       = 'Auto-TR Creator'
        description = '[REQ2] Automatically create TR tasks on object changes'
        feature_id  = 'TR_AUTO'
        status      = 'COMING_SOON'
        req_label   = 'REQ2' )

      ( sortkey = 50
        category    = 'Version and Diff'
        title       = 'Version History'
        description = '[REQ3] View version history of repository objects'
        feature_id  = 'VERSION_HIST'
        status      = 'COMING_SOON'
        req_label   = 'REQ3' )

      ( sortkey = 60
        category    = 'Version and Diff'
        title       = 'Cross-System Diff'
        description = '[REQ3] Compare object versions across different SAP systems'
        feature_id  = 'CROSS_DIFF'
        status      = 'COMING_SOON'
        req_label   = 'REQ3' )
    ).
  ENDMETHOD.

  METHOD display_hub.
    DATA: lo_display   TYPE REF TO cl_salv_display_settings,
          lo_functions TYPE REF TO cl_salv_functions_list,
          lv_header    TYPE lvc_title.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = mo_alv
          CHANGING  t_table      = mt_hub_items
        ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    " Header
    lv_header = 'SCORT - Developer Workbench - Double-click to open - DEV-032'.

    lo_display = mo_alv->get_display_settings( ).
    lo_display->set_list_header( lv_header ).
    lo_display->set_list_header_size(
      cl_salv_display_settings=>c_header_size_large
    ).
    lo_display->set_striped_pattern( abap_true ).

    " Turn off standard toolbar
    lo_functions = mo_alv->get_functions( ).
    lo_functions->set_all( abap_false ).

    " Configure columns
    configure_columns( ).

    " Register event handler
    SET HANDLER me->on_double_click FOR mo_alv->get_event( ).

    " Display
    mo_alv->display( ).
  ENDMETHOD.

  METHOD configure_columns.
    DATA: lo_cols TYPE REF TO cl_salv_columns_table,
          lo_col  TYPE REF TO cl_salv_column.

    lo_cols = mo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    TRY.
        " Hide internal columns
        lo_col = lo_cols->get_column( 'SORTKEY' ).
        lo_col->set_visible( abap_false ).

        lo_col = lo_cols->get_column( 'FEATURE_ID' ).
        lo_col->set_visible( abap_false ).

        " CATEGORY column
        lo_col = lo_cols->get_column( 'CATEGORY' ).
        lo_col->set_medium_text( 'Category' ).
        lo_col->set_output_length( 25 ).

        " TITLE column
        lo_col = lo_cols->get_column( 'TITLE' ).
        lo_col->set_medium_text( 'Feature' ).
        lo_col->set_long_text( 'Feature Name' ).
        lo_col->set_output_length( 30 ).

        " DESCRIPTION column
        lo_col = lo_cols->get_column( 'DESCRIPTION' ).
        lo_col->set_medium_text( 'Description' ).
        lo_col->set_long_text( 'Feature Description' ).
        lo_col->set_output_length( 70 ).

        " STATUS column
        lo_col = lo_cols->get_column( 'STATUS' ).
        lo_col->set_medium_text( 'Status' ).
        lo_col->set_output_length( 15 ).

        " REQ_LABEL column
        lo_col = lo_cols->get_column( 'REQ_LABEL' ).
        lo_col->set_medium_text( 'Req.' ).
        lo_col->set_output_length( 8 ).

      CATCH cx_salv_not_found.
        " ignore
    ENDTRY.
  ENDMETHOD.

  METHOD on_double_click.
    IF row = 0.
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_item) = mt_hub_items[ row ].
      CATCH cx_sy_itab_line_not_found.
        RETURN.
    ENDTRY.

    " Block Coming Soon features
    IF ls_item-status = 'COMING_SOON'.
      MESSAGE |Feature { ls_item-title } planned for { ls_item-req_label } - coming soon!|
        TYPE 'I'.
      RETURN.
    ENDIF.

    navigate_to( ls_item-feature_id ).
  ENDMETHOD.

  METHOD navigate_to.
*------------------------------------------------------------------*
* Navigate to sub-program using SUBMIT ... AND RETURN
* This keeps Hub running in stack - F3 returns to Hub
*------------------------------------------------------------------*
    DATA: lv_program TYPE progname.

    CASE iv_feature_id.
      WHEN 'OBJ_FINDER'.
        lv_program = 'ZSCORT_MAIN'.

      WHEN 'PKG_EXPLORER'.
        lv_program = 'ZSCORT_PKG_032'.

      WHEN OTHERS.
        MESSAGE |Unknown feature: { iv_feature_id }| TYPE 'I'.
        RETURN.
    ENDCASE.

    SUBMIT (lv_program) AND RETURN.
  ENDMETHOD.

ENDCLASS.
