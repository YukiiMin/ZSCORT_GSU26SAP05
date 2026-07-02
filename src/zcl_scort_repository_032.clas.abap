class ZCL_SCORT_REPOSITORY_032 definition
  public
  final
  create public .

public section.

  types:
    " 2. Types for Range Tables
    tt_obj_range   TYPE RANGE OF sobj_name .
  types:
    tt_type_range  TYPE RANGE OF trobjtype .
  types:
    tt_pkg_range   TYPE RANGE OF devclass .
  types:
    tt_auth_range  TYPE RANGE OF author .
  types:
    tt_trkorr_rng  TYPE RANGE OF trkorr .
  types:
    tt_as4user_rng TYPE RANGE OF as4user .

    " 1. Constants
  constants GC_OBJ_PROG type TADIR-OBJECT value 'PROG' ##NO_TEXT.
  constants GC_OBJ_CLAS type TADIR-OBJECT value 'CLAS' ##NO_TEXT.
  constants GC_OBJ_TABL type TADIR-OBJECT value 'TABL' ##NO_TEXT.
  constants GC_OBJ_DOMA type TADIR-OBJECT value 'DOMA' ##NO_TEXT.
  constants GC_OBJ_DTEL type TADIR-OBJECT value 'DTEL' ##NO_TEXT.
  constants GC_OBJ_FUGR type TADIR-OBJECT value 'FUGR' ##NO_TEXT.
  constants GC_OBJ_TRAN type TADIR-OBJECT value 'TRAN' ##NO_TEXT.

    " 3. Methods Definitions
  methods GET_OBJECTS
    importing
      !IT_OBJ_NAME type TT_OBJ_RANGE optional
      !IT_OBJ_TYPE type TT_TYPE_RANGE optional
      !IT_DEVCLASS type TT_PKG_RANGE optional
      !IT_AUTHOR type TT_AUTH_RANGE optional
    exporting
      !ET_OBJECTS type ZSCORT_T_OBJECTS .
  methods GET_STATISTICS
    importing
      !IT_DEVCLASS type TT_PKG_RANGE optional
      !IT_AUTHOR type TT_AUTH_RANGE optional
    exporting
      !ET_STATISTICS type ZSCORT_T_STATISTICS .
  methods GET_OBJECT_DETAIL
    importing
      value(IV_OBJ_NAME) type SOBJ_NAME
      value(IV_OBJ_TYPE) type TROBJTYPE
    exporting
      !ES_DETAIL type ZSCORT_S_OBJ_DETAIL .
  methods GET_OBJECTS_BY_TR
    importing
      !IT_TR_NUMBER type TT_TRKORR_RNG
      !IT_TR_OWNER type TT_AS4USER_RNG
      !IT_OBJ_TYPE type TT_TYPE_RANGE
    exporting
      !ET_TR_OBJECTS type ZSCORT_T_TR_OBJECTS .
  methods GET_PACKAGE_TREE
    importing
      value(IV_DEVCLASS) type DEVCLASS
    exporting
      !ET_OBJECTS type ZSCORT_T_OBJECTS .
  methods GET_OBJECTS_BY_TYPES
    importing
      !IT_DEVCLASS type TT_PKG_RANGE
      !IT_OBJ_TYPE type TT_TYPE_RANGE
    exporting
      !ET_OBJECTS type ZSCORT_T_OBJECTS
    returning
      value(RV_COUNT) type I .
  methods CHANGE_OBJECT_PACKAGE
    importing
      value(IV_OBJ_NAME) type SOBJ_NAME
      value(IV_OBJ_TYPE) type TROBJTYPE
      value(IV_NEW_DEVCLASS) type DEVCLASS
    returning
      value(RV_SUCCESS) type ABAP_BOOL .
  methods CHANGE_OBJECT_OWNER
    importing
      value(IV_OBJ_NAME) type SOBJ_NAME
      value(IV_OBJ_TYPE) type TROBJTYPE
      value(IV_NEW_OWNER) type AUTHOR
    returning
      value(RV_SUCCESS) type ABAP_BOOL .
  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_SCORT_REPOSITORY_032 IMPLEMENTATION.


  METHOD get_objects.
*--------------------------------------------------------------------*
* SCORT: Get list of Repository Objects from TADIR
*--------------------------------------------------------------------*
    CLEAR et_objects.

    DATA(lt_valid_types) = VALUE RSELOPTION(
      ( sign = 'I' option = 'EQ' low = gc_obj_prog )
      ( sign = 'I' option = 'EQ' low = gc_obj_clas )
      ( sign = 'I' option = 'EQ' low = gc_obj_tabl )
      ( sign = 'I' option = 'EQ' low = gc_obj_doma )
      ( sign = 'I' option = 'EQ' low = gc_obj_dtel )
      ( sign = 'I' option = 'EQ' low = gc_obj_fugr )
      ( sign = 'I' option = 'EQ' low = gc_obj_tran )
    ).

    SELECT obj_name, object, devclass, author, srcsystem, versid
      FROM tadir
      INTO TABLE @DATA(lt_tadir)
      WHERE obj_name IN @it_obj_name
        AND object   IN @it_obj_type
        AND object   IN @lt_valid_types
        AND devclass IN @it_devclass
        AND author   IN @it_author.

    IF sy-subrc = 0.
      et_objects = VALUE #( FOR ls_tadir IN lt_tadir (
        obj_name  = ls_tadir-obj_name
        object    = ls_tadir-object
        devclass  = ls_tadir-devclass
        author    = ls_tadir-author
        srcsystem = ls_tadir-srcsystem
        versno    = ls_tadir-versid
      ) ).
      SORT et_objects BY object obj_name.
    ENDIF.

  ENDMETHOD.


  METHOD get_object_detail.
*--------------------------------------------------------------------*
* SCORT: Get detailed information of a specific Repository Object
*--------------------------------------------------------------------*
    CLEAR es_detail.

    SELECT SINGLE obj_name, object, devclass, author,
                  created_on, srcsystem, versid
      FROM tadir
      INTO @DATA(ls_tadir)
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    MOVE-CORRESPONDING ls_tadir TO es_detail.
    es_detail-created_date = ls_tadir-created_on.
    es_detail-versno       = ls_tadir-versid.

    es_detail-object_type_desc = SWITCH #( iv_obj_type
      WHEN gc_obj_prog THEN 'Programs / Reports'
      WHEN gc_obj_clas THEN 'ABAP Classes'
      WHEN gc_obj_tabl THEN 'Database Tables'
      WHEN gc_obj_doma THEN 'Domains'
      WHEN gc_obj_dtel THEN 'Data Elements'
      WHEN gc_obj_fugr THEN 'Function Groups'
      WHEN gc_obj_tran THEN 'Transactions'
      ELSE 'Other'
    ).

    CASE iv_obj_type.

      WHEN gc_obj_prog.
        SELECT SINGLE name FROM trdir
          INTO @DATA(lv_progname)
          WHERE name = @iv_obj_name.
        IF sy-subrc = 0.
          es_detail-description = |Program: { iv_obj_name }|.
        ENDIF.

      WHEN gc_obj_tabl.
        SELECT SINGLE ddtext FROM dd02t
          INTO @DATA(lv_tabl_desc)
          WHERE tabname    = @iv_obj_name
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'.
        IF sy-subrc = 0. es_detail-description = lv_tabl_desc. ENDIF.

      WHEN gc_obj_clas.
        SELECT SINGLE descript FROM seoclasstx
          INTO @DATA(lv_clas_desc)
          WHERE clsname = @iv_obj_name
            AND langu   = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_clas_desc. ENDIF.

      WHEN gc_obj_tran.
        SELECT SINGLE ttext FROM tstct
          INTO @DATA(lv_tran_desc)
          WHERE tcode = @iv_obj_name
            AND sprsl = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_tran_desc. ENDIF.

      WHEN gc_obj_fugr.
        SELECT SINGLE areat FROM tlibt
          INTO @DATA(lv_fugr_desc)
          WHERE area = @iv_obj_name
            AND spras = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_fugr_desc. ENDIF.

      WHEN gc_obj_dtel.
        SELECT SINGLE ddtext FROM dd04t
          INTO @DATA(lv_dtel_desc)
          WHERE rollname   = @iv_obj_name
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'.
        IF sy-subrc = 0. es_detail-description = lv_dtel_desc. ENDIF.

      WHEN gc_obj_doma.
        SELECT SINGLE ddtext FROM dd01t
          INTO @DATA(lv_doma_desc)
          WHERE domname    = @iv_obj_name
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'.
        IF sy-subrc = 0. es_detail-description = lv_doma_desc. ENDIF.

      WHEN OTHERS.
        es_detail-description = |{ iv_obj_type }: { iv_obj_name }|.
    ENDCASE.
  ENDMETHOD.


  METHOD get_statistics.
*--------------------------------------------------------------------*
* SCORT: Get count of objects grouped by type
*--------------------------------------------------------------------*
    CLEAR et_statistics.

    DATA(lt_valid_types) = VALUE RSELOPTION(
      ( sign = 'I' option = 'EQ' low = gc_obj_prog )
      ( sign = 'I' option = 'EQ' low = gc_obj_clas )
      ( sign = 'I' option = 'EQ' low = gc_obj_tabl )
      ( sign = 'I' option = 'EQ' low = gc_obj_doma )
      ( sign = 'I' option = 'EQ' low = gc_obj_dtel )
      ( sign = 'I' option = 'EQ' low = gc_obj_fugr )
      ( sign = 'I' option = 'EQ' low = gc_obj_tran )
    ).

    " Aggregate query — INTO CORRESPONDING không hỗ trợ GROUP BY
    " → dùng inline @DATA rồi map thủ công
    SELECT object,
           COUNT(*) AS obj_count
      FROM tadir
      INTO TABLE @DATA(lt_stat)
      WHERE object   IN @lt_valid_types
        AND devclass IN @it_devclass
        AND author   IN @it_author
      GROUP BY object
      ORDER BY object.

    IF sy-subrc = 0.
      et_statistics = VALUE #(
        FOR ls IN lt_stat (
          object    = ls-object
          obj_count = ls-obj_count
        )
      ).

      LOOP AT et_statistics ASSIGNING FIELD-SYMBOL(<ls_stat>).
        <ls_stat>-object_desc = SWITCH #( <ls_stat>-object
          WHEN gc_obj_prog THEN 'Programs / Reports'
          WHEN gc_obj_clas THEN 'ABAP Classes'
          WHEN gc_obj_tabl THEN 'Database Tables'
          WHEN gc_obj_doma THEN 'Domains'
          WHEN gc_obj_dtel THEN 'Data Elements'
          WHEN gc_obj_fugr THEN 'Function Groups'
          WHEN gc_obj_tran THEN 'Transactions'
          ELSE 'Other'
        ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD change_object_owner.
*--------------------------------------------------------------------*
* SCORT: Đổi owner/author của object trong TADIR
*--------------------------------------------------------------------*
    rv_success = abap_false.

    IF iv_new_owner IS INITIAL.
      RETURN.
    ENDIF.

    " Validate — user mới phải tồn tại
    SELECT SINGLE bname FROM usr02
      INTO @DATA(lv_user)
      WHERE bname = @iv_new_owner.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE author
      FROM tadir
      INTO @DATA(lv_current_owner)
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_current_owner = iv_new_owner.
      rv_success = abap_true.
      RETURN.
    ENDIF.

    UPDATE tadir
      SET author = @iv_new_owner
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
      rv_success = abap_true.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

  ENDMETHOD.


  METHOD change_object_package.
*--------------------------------------------------------------------*
* SCORT: Chuyển object sang package (DEVCLASS) khác
*--------------------------------------------------------------------*
    rv_success = abap_false.

    IF iv_new_devclass IS INITIAL.
      RETURN.
    ENDIF.

    " Validate — package đích phải tồn tại
    SELECT SINGLE devclass FROM tdevc
      INTO @DATA(lv_pkg)
      WHERE devclass = @iv_new_devclass.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Validate — object phải tồn tại trong TADIR
    SELECT SINGLE devclass
      FROM tadir
      INTO @DATA(lv_current_pkg)
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_current_pkg = iv_new_devclass.
      rv_success = abap_true.
      RETURN.
    ENDIF.

    UPDATE tadir
      SET devclass = @iv_new_devclass
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
      rv_success = abap_true.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

  ENDMETHOD.


  METHOD get_objects_by_tr.
*--------------------------------------------------------------------*
* SCORT: Find Repository Objects via Transport Request (E070 + E071 join)
*--------------------------------------------------------------------*
    CLEAR et_tr_objects.

    DATA(lt_valid_types) = VALUE RSELOPTION(
      ( sign = 'I' option = 'EQ' low = gc_obj_prog )
      ( sign = 'I' option = 'EQ' low = gc_obj_clas )
      ( sign = 'I' option = 'EQ' low = gc_obj_tabl )
      ( sign = 'I' option = 'EQ' low = gc_obj_doma )
      ( sign = 'I' option = 'EQ' low = gc_obj_dtel )
      ( sign = 'I' option = 'EQ' low = gc_obj_fugr )
      ( sign = 'I' option = 'EQ' low = gc_obj_tran )
    ).

    DATA(lt_final_types) = COND #(
      WHEN it_obj_type IS INITIAL THEN lt_valid_types
      ELSE it_obj_type
    ).

    " ⚠️ Khai báo explicit structure vì inline @DATA với JOIN + AS alias không work
    TYPES: BEGIN OF ty_tr_raw,
             trkorr    TYPE e071-trkorr,
             pgmid     TYPE e071-pgmid,
             object    TYPE e071-object,
             obj_name  TYPE e071-obj_name,
             tr_owner  TYPE e070-as4user,
             tr_status TYPE e070-trstatus,
             tr_desc   TYPE e07t-as4text,
           END OF ty_tr_raw.

    DATA lt_raw TYPE STANDARD TABLE OF ty_tr_raw.
    DATA ls_raw TYPE ty_tr_raw.

    " ⚠️ E07T của bạn không có cột AS4POS (chỉ có TRKORR + LANGU + AS4TEXT)
    " → bỏ filter AS4POS, chỉ join theo (TRKORR, LANGU)
    SELECT e071~trkorr,
           e071~pgmid,
           e071~object,
           e071~obj_name,
           e070~as4user  AS tr_owner,
           e070~trstatus AS tr_status,
           e07t~as4text  AS tr_desc
      FROM e071
      INNER JOIN e070 ON e071~trkorr = e070~trkorr
      LEFT OUTER JOIN e07t ON e07t~trkorr = e071~trkorr
                           AND e07t~langu = @sy-langu
      INTO TABLE @lt_raw
      WHERE e071~trkorr IN @it_tr_number
        AND e070~as4user IN @it_tr_owner
        AND e071~object  IN @lt_final_types
        AND e071~pgmid   = 'R3TR'.

    IF sy-subrc <> 0 AND sy-subrc <> 4.
      RETURN.
    ENDIF.

    " Khai báo ls_out trước vòng lặp
    DATA ls_out TYPE zscort_s_tr_object.

    LOOP AT lt_raw INTO ls_raw.
      ls_out = CORRESPONDING #( ls_raw ).

      ls_out-tr_status_desc = SWITCH #( ls_raw-tr_status
        WHEN 'D' THEN 'Modifiable'
        WHEN 'O' THEN 'Released'
        WHEN 'R' THEN 'Released (WL)'
        ELSE ls_raw-tr_status
      ).

      SELECT SINGLE devclass, author
        FROM tadir
        INTO (@ls_out-devclass, @ls_out-author)
        WHERE obj_name = @ls_raw-obj_name
          AND object   = @ls_raw-object.

      APPEND ls_out TO et_tr_objects.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_package_tree.
*--------------------------------------------------------------------*
* SCORT: Lấy tất cả objects trong một package (dùng cho Package Explorer)
*--------------------------------------------------------------------*
    CLEAR et_objects.

    DATA(lt_valid_types) = VALUE RSELOPTION(
      ( sign = 'I' option = 'EQ' low = gc_obj_prog )
      ( sign = 'I' option = 'EQ' low = gc_obj_clas )
      ( sign = 'I' option = 'EQ' low = gc_obj_tabl )
      ( sign = 'I' option = 'EQ' low = gc_obj_doma )
      ( sign = 'I' option = 'EQ' low = gc_obj_dtel )
      ( sign = 'I' option = 'EQ' low = gc_obj_fugr )
      ( sign = 'I' option = 'EQ' low = gc_obj_tran )
    ).

    SELECT obj_name, object, devclass, author, srcsystem, versid
      FROM tadir
      INTO TABLE @DATA(lt_tadir)
      WHERE devclass = @iv_devclass
        AND object   IN @lt_valid_types
      ORDER BY object, obj_name.

    IF sy-subrc = 0.
      et_objects = VALUE #( FOR ls IN lt_tadir (
        obj_name  = ls-obj_name
        object    = ls-object
        devclass  = ls-devclass
        author    = ls-author
        srcsystem = ls-srcsystem
        versno    = ls-versid
      ) ).
    ENDIF.

  ENDMETHOD.


  METHOD get_objects_by_types.
*--------------------------------------------------------------------*
* SCORT: Get objects by package range + object-type range
*        Used by Package Explorer with user-selected types
*        If it_obj_type is empty → match all valid types (full TADIR scan)
*--------------------------------------------------------------------*
    CLEAR: et_objects, rv_count.

    " Fallback: empty type range = match all valid types
    DATA(lt_final_types) = COND #(
      WHEN it_obj_type IS INITIAL THEN VALUE tt_type_range(
        ( sign = 'I' option = 'EQ' low = gc_obj_prog )
        ( sign = 'I' option = 'EQ' low = gc_obj_clas )
        ( sign = 'I' option = 'EQ' low = gc_obj_tabl )
        ( sign = 'I' option = 'EQ' low = gc_obj_doma )
        ( sign = 'I' option = 'EQ' low = gc_obj_dtel )
        ( sign = 'I' option = 'EQ' low = gc_obj_fugr )
        ( sign = 'I' option = 'EQ' low = gc_obj_tran )
      )
      ELSE it_obj_type
    ).

    SELECT obj_name, object, devclass, author, srcsystem, versid
      FROM tadir
      INTO TABLE @DATA(lt_tadir)
      WHERE devclass IN @it_devclass
        AND object   IN @lt_final_types
      ORDER BY object, obj_name.

    IF sy-subrc = 0.
      et_objects = VALUE #( FOR ls IN lt_tadir (
        obj_name  = ls-obj_name
        object    = ls-object
        devclass  = ls-devclass
        author    = ls-author
        srcsystem = ls-srcsystem
        versno    = ls-versid
      ) ).
      rv_count = lines( et_objects ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
