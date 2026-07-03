INTERFACE zif_scort_repo_reader PUBLIC.

  types tt_obj_range TYPE RANGE OF sobj_name.
  types tt_type_range TYPE RANGE OF trobjtype.
  types tt_pkg_range TYPE RANGE OF devclass.
  types tt_auth_range TYPE RANGE OF author.
  types tt_trkorr_rng TYPE RANGE OF trkorr.
  types tt_as4user_rng TYPE RANGE OF as4user.

  METHODS get_objects
    importing
      !it_obj_name type TT_OBJ_RANGE optional
      !it_obj_type type TT_TYPE_RANGE optional
      !it_devclass type TT_PKG_RANGE optional
      !it_author type TT_AUTH_RANGE optional
    exporting
      !et_objects type ZSCORT_T_OBJECTS.

  METHODS get_statistics
    importing
      !it_devclass type TT_PKG_RANGE optional
      !it_author type TT_AUTH_RANGE optional
    exporting
      !et_statistics type ZSCORT_T_STATISTICS.

  METHODS get_object_detail
    importing
      !iv_obj_name type SOBJ_NAME
      !iv_obj_type type TROBJTYPE
    exporting
      !es_detail type ZSCORT_S_OBJ_DETAIL.

  METHODS get_objects_by_tr
    importing
      !it_tr_number type TT_TRKORR_RNG
      !it_tr_owner type TT_AS4USER_RNG
      !it_obj_type type TT_TYPE_RANGE
    exporting
      !et_tr_objects type ZSCORT_T_TR_OBJECTS.

  METHODS get_package_tree
    importing
      !iv_devclass type DEVCLASS
    exporting
      !et_objects type ZSCORT_T_OBJECTS.

  METHODS get_objects_by_types
    importing
      !it_devclass type TT_PKG_RANGE
      !it_obj_type type TT_TYPE_RANGE
      !it_author type TT_AUTH_RANGE optional
    exporting
      !et_objects type ZSCORT_T_OBJECTS.

  METHODS get_objects_all_types
    importing
      !it_devclass type TT_PKG_RANGE optional
      !it_author type TT_AUTH_RANGE optional
      !it_obj_name type TT_OBJ_RANGE optional
    exporting
      !et_objects type ZSCORT_T_OBJECTS.

ENDINTERFACE.