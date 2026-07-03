INTERFACE zif_scort_repo_mutator PUBLIC.

  METHODS change_object_package
    importing
      !iv_obj_name type SOBJ_NAME
      !iv_obj_type type TROBJTYPE
      !iv_new_devclass type DEVCLASS
    raising
      ZCX_SCORT_EXCEPTION.

  METHODS change_object_owner
    importing
      !iv_obj_name type SOBJ_NAME
      !iv_obj_type type TROBJTYPE
      !iv_new_owner type AUTHOR
    raising
      ZCX_SCORT_EXCEPTION.

ENDINTERFACE.
