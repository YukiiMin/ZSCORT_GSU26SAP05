class ZCL_SCORT_REPO_READER_032 definition
  public
  final
  create public
  global friends ZIF_SCORT_REPO_READER.

public section.

  interfaces ZIF_SCORT_REPO_READER.

protected section.
private section.

endclass.



CLASS ZCL_SCORT_REPO_READER_032 IMPLEMENTATION.


  METHOD zif_scort_repo_reader~get_objects.
    CLEAR et_objects.

    DATA(lt_valid_types) = zcl_scort_constants=>get_valid_types( ).

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


  METHOD zif_scort_repo_reader~get_object_detail.
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

    es_detail-object_type_desc = zcl_scort_constants=>get_object_label( iv_obj_type ).

    CASE iv_obj_type.

      WHEN zcl_scort_constants=>gc_obj_prog.
        SELECT SINGLE name FROM trdir
          INTO @DATA(lv_progname)
          WHERE name = @iv_obj_name.
        IF sy-subrc = 0.
          es_detail-description = |Program: { iv_obj_name }|.
        ENDIF.

      WHEN zcl_scort_constants=>gc_obj_tabl.
        SELECT SINGLE ddtext FROM dd02t
          INTO @DATA(lv_tabl_desc)
          WHERE tabname    = @iv_obj_name
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'.
        IF sy-subrc = 0. es_detail-description = lv_tabl_desc. ENDIF.

      WHEN zcl_scort_constants=>gc_obj_clas.
        SELECT SINGLE descript FROM seoclasstx
          INTO @DATA(lv_clas_desc)
          WHERE clsname = @iv_obj_name
            AND langu   = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_clas_desc. ENDIF.

      WHEN zcl_scort_constants=>gc_obj_tran.
        SELECT SINGLE ttext FROM tstct
          INTO @DATA(lv_tran_desc)
          WHERE tcode = @iv_obj_name
            AND sprsl = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_tran_desc. ENDIF.

      WHEN zcl_scort_constants=>gc_obj_fugr.
        SELECT SINGLE areat FROM tlibt
          INTO @DATA(lv_fugr_desc)
          WHERE area = @iv_obj_name
            AND spras = @sy-langu.
        IF sy-subrc = 0. es_detail-description = lv_fugr_desc. ENDIF.

      WHEN zcl_scort_constants=>gc_obj_dtel.
        SELECT SINGLE ddtext FROM dd04t
          INTO @DATA(lv_dtel_desc)
          WHERE rollname   = @iv_obj_name
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'.
        IF sy-subrc = 0. es_detail-description = lv_dtel_desc. ENDIF.

      WHEN zcl_scort_constants=>gc_obj_doma.
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


  METHOD zif_scort_repo_reader~get_statistics.
    CLEAR et_statistics.

    DATA(lt_valid_types) = zcl_scort_constants=>get_valid_types( ).

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
        <ls_stat>-object_desc = zcl_scort_constants=>get_object_label( <ls_stat>-object ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_scort_repo_reader~get_objects_by_tr.
    CLEAR et_tr_objects.

    DATA(lt_valid_types) = zcl_scort_constants=>get_valid_types( ).

    DATA(lt_final_types) = COND #(
      WHEN it_obj_type IS INITIAL THEN lt_valid_types
      ELSE it_obj_type
    ).

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

    SELECT DISTINCT
           e071~trkorr,
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


  METHOD zif_scort_repo_reader~get_package_tree.
    CLEAR et_objects.

    DATA(lt_valid_types) = zcl_scort_constants=>get_valid_types( ).

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


  METHOD zif_scort_repo_reader~get_objects_by_types.
    CLEAR et_objects.

    DATA(lt_final_types) = COND #(
      WHEN it_obj_type IS INITIAL
        THEN zcl_scort_constants=>get_valid_types( )
        ELSE it_obj_type
    ).

    TYPES: BEGIN OF ty_tadir,
             obj_name  TYPE tadir-obj_name,
             object    TYPE tadir-object,
             devclass  TYPE tadir-devclass,
             author    TYPE tadir-author,
             srcsystem TYPE tadir-srcsystem,
             versid    TYPE tadir-versid,
           END OF ty_tadir.
    DATA lt_tadir TYPE STANDARD TABLE OF ty_tadir.

    IF it_devclass IS NOT INITIAL.
      IF it_author IS NOT INITIAL.
        SELECT obj_name, object, devclass, author, srcsystem, versid
          FROM tadir
          INTO TABLE @lt_tadir
          WHERE devclass IN @it_devclass
            AND object   IN @lt_final_types
            AND author   IN @it_author
          ORDER BY object, obj_name.
      ELSE.
        SELECT obj_name, object, devclass, author, srcsystem, versid
          FROM tadir
          INTO TABLE @lt_tadir
          WHERE devclass IN @it_devclass
            AND object   IN @lt_final_types
          ORDER BY object, obj_name.
      ENDIF.
    ELSE.
      IF it_author IS NOT INITIAL.
        SELECT obj_name, object, devclass, author, srcsystem, versid
          FROM tadir
          INTO TABLE @lt_tadir
          WHERE object   IN @lt_final_types
            AND author   IN @it_author
          ORDER BY object, obj_name.
      ELSE.
        SELECT obj_name, object, devclass, author, srcsystem, versid
          FROM tadir
          INTO TABLE @lt_tadir
          WHERE object   IN @lt_final_types
          ORDER BY object, obj_name.
      ENDIF.
    ENDIF.

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


  METHOD zif_scort_repo_reader~get_objects_all_types.
    CLEAR et_objects.

    TYPES: BEGIN OF ty_tadir,
             obj_name  TYPE tadir-obj_name,
             object    TYPE tadir-object,
             devclass  TYPE tadir-devclass,
             author    TYPE tadir-author,
             srcsystem TYPE tadir-srcsystem,
             versid    TYPE tadir-versid,
           END OF ty_tadir.
    DATA lt_tadir TYPE STANDARD TABLE OF ty_tadir.

    IF it_devclass IS NOT INITIAL.
      IF it_author IS NOT INITIAL.
        IF it_obj_name IS NOT INITIAL.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE devclass IN @it_devclass
              AND author   IN @it_author
              AND obj_name IN @it_obj_name
            ORDER BY author, devclass, object, obj_name.
        ELSE.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE devclass IN @it_devclass
              AND author   IN @it_author
            ORDER BY author, devclass, object, obj_name.
        ENDIF.
      ELSE.
        IF it_obj_name IS NOT INITIAL.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE devclass IN @it_devclass
              AND obj_name IN @it_obj_name
            ORDER BY author, devclass, object, obj_name.
        ELSE.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE devclass IN @it_devclass
            ORDER BY author, devclass, object, obj_name.
        ENDIF.
      ENDIF.
    ELSE.
      IF it_author IS NOT INITIAL.
        IF it_obj_name IS NOT INITIAL.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE author   IN @it_author
              AND obj_name IN @it_obj_name
            ORDER BY author, devclass, object, obj_name.
        ELSE.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE author   IN @it_author
            ORDER BY author, devclass, object, obj_name.
        ENDIF.
      ELSE.
        IF it_obj_name IS NOT INITIAL.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            WHERE obj_name IN @it_obj_name
            ORDER BY author, devclass, object, obj_name.
        ELSE.
          SELECT obj_name, object, devclass, author, srcsystem, versid
            FROM tadir
            INTO TABLE @lt_tadir
            ORDER BY author, devclass, object, obj_name.
        ENDIF.
      ENDIF.
    ENDIF.

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

ENDCLASS.
