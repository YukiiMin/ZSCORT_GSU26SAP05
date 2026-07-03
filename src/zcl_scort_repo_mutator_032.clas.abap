class ZCL_SCORT_REPO_MUTATOR_032 definition
  public
  final
  create public
  friends ZIF_SCORT_REPO_MUTATOR .

public section.

  interfaces ZIF_SCORT_REPO_MUTATOR.

protected section.
private section.

  methods validate_user
    importing
      iv_user type AUTHOR
    raising
      ZCX_SCORT_EXCEPTION.

  methods validate_package
    importing
      iv_devclass type DEVCLASS
    raising
      ZCX_SCORT_EXCEPTION.

endclass.



CLASS ZCL_SCORT_REPO_MUTATOR_032 IMPLEMENTATION.


  METHOD zif_scort_repo_mutator~change_object_owner.

    IF iv_new_owner IS INITIAL.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'INVALID_USER'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = 'New owner cannot be empty.'.
    ENDIF.

    validate_user( iv_new_owner ).

    SELECT SINGLE author
      FROM tadir
      INTO @DATA(lv_current_owner)
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'OBJECT_NOT_FOUND'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = |Object { iv_obj_name } ({ iv_obj_type }) not found in TADIR.|.
    ENDIF.

    IF lv_current_owner = iv_new_owner.
      RETURN.
    ENDIF.

    UPDATE tadir
      SET author = @iv_new_owner
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'UPDATE_FAILED'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = |UPDATE TADIR failed for { iv_obj_name }. Check authorization.|.
    ENDIF.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD zif_scort_repo_mutator~change_object_package.

    IF iv_new_devclass IS INITIAL.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'INVALID_PACKAGE'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = 'New package cannot be empty.'.
    ENDIF.

    validate_package( iv_new_devclass ).

    SELECT SINGLE devclass
      FROM tadir
      INTO @DATA(lv_current_pkg)
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'OBJECT_NOT_FOUND'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = |Object { iv_obj_name } ({ iv_obj_type }) not found in TADIR.|.
    ENDIF.

    IF lv_current_pkg = iv_new_devclass.
      RETURN.
    ENDIF.

    UPDATE tadir
      SET devclass = @iv_new_devclass
      WHERE obj_name = @iv_obj_name
        AND object   = @iv_obj_type.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'UPDATE_FAILED'
          mv_object_name  = iv_obj_name
          mv_object_type  = iv_obj_type
          mv_error_text   = |UPDATE TADIR failed for { iv_obj_name }. Check authorization.|.
    ENDIF.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD validate_user.

    SELECT SINGLE bname FROM usr02
      INTO @DATA(lv_user)
      WHERE bname = @iv_user.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code   = 'INVALID_USER'
          mv_object_name  = ''
          mv_new_owner    = iv_user
          mv_error_text   = |User { iv_user } does not exist in the system.|.
    ENDIF.

  ENDMETHOD.


  METHOD validate_package.

    SELECT SINGLE devclass FROM tdevc
      INTO @DATA(lv_pkg)
      WHERE devclass = @iv_devclass.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_scort_exception
        EXPORTING
          mv_error_code     = 'INVALID_PACKAGE'
          mv_object_name    = ''
          mv_new_devclass   = iv_devclass
          mv_error_text     = |Package { iv_new_devclass } does not exist in TDEVC.|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
