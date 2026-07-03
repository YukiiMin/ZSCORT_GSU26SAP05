class ZCX_SCORT_EXCEPTION definition
  public
  inheriting from CX_NO_CHECK
  final
  create public.

public section.

  constants:
    begin of GC_ERR_INVALID_USER,
      msgid type MSGID value 'ZSCORT',
      msgno type MSGNO value '001',
    end of GC_ERR_INVALID_USER,
    begin of GC_ERR_INVALID_PACKAGE,
      msgid type MSGID value 'ZSCORT',
      msgno type MSGNO value '002',
    end of GC_ERR_INVALID_PACKAGE,
    begin of GC_ERR_OBJECT_NOT_FOUND,
      msgid type MSGID value 'ZSCORT',
      msgno type MSGNO value '003',
    end of GC_ERR_OBJECT_NOT_FOUND,
    begin of GC_ERR_UPDATE_FAILED,
      msgid type MSGID value 'ZSCORT',
      msgno type MSGNO value '004',
    end of GC_ERR_UPDATE_FAILED,
    begin of GC_ERR_LOCK_FAILED,
      msgid type MSGID value 'ZSCORT',
      msgno type MSGNO value '005',
    end of GC_ERR_LOCK_FAILED.

  methods CONSTRUCTOR
    importing
      !TEXTID like IF_T100_DYN_MSG=>T100KEY optional
      !PREVIOUS like PREVIOUS optional
      !MV_ERROR_CODE type STRING optional
      !MV_OBJECT_NAME type SOBJ_NAME optional
      !MV_OBJECT_TYPE type TROBJTYPE optional
      !MV_NEW_OWNER type AUTHOR optional
      !MV_NEW_DEVCLASS type DEVCLASS optional
      !MV_ERROR_TEXT type STRING optional.

  data:
    MV_ERROR_CODE type STRING read-only,
    MV_OBJECT_NAME type SOBJ_NAME read-only,
    MV_OBJECT_TYPE type TROBJTYPE read-only,
    MV_NEW_OWNER type AUTHOR read-only,
    MV_NEW_DEVCLASS type DEVCLASS read-only,
    MV_ERROR_TEXT type STRING read-only.

protected section.
private section.
endclass.



CLASS ZCX_SCORT_EXCEPTION IMPLEMENTATION.

  METHOD CONSTRUCTOR.
    super->constructor( previous = previous textid = textid ).
    me->MV_ERROR_CODE = MV_ERROR_CODE.
    me->MV_OBJECT_NAME = MV_OBJECT_NAME.
    me->MV_OBJECT_TYPE = MV_OBJECT_TYPE.
    me->MV_NEW_OWNER = MV_NEW_OWNER.
    me->MV_NEW_DEVCLASS = MV_NEW_DEVCLASS.
    me->MV_ERROR_TEXT = MV_ERROR_TEXT.
  ENDMETHOD.

ENDCLASS.
